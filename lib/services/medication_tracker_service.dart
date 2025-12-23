import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'adherence_service.dart';
import 'schedule_service.dart';
import '../models/schedule.dart';
import '../models/sensor.dart';

/// Sensör değişikliklerini izleyip otomatik ilaç alma kaydı yapar (RAW bazlı)
class MedicationTrackerService {
  static final MedicationTrackerService _instance =
      MedicationTrackerService._internal();
  factory MedicationTrackerService() => _instance;
  MedicationTrackerService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AdherenceService _adherenceService = AdherenceService();
  final ScheduleService _scheduleService = ScheduleService();

  // sensorKey = "$deviceId|$sensorId"
  final Map<String, int> _previousCounts = {};   // sensorKey -> önceki count
  final Map<String, DateTime> _lastLogTime = {}; // sensorKey -> son log zamanı
  final Map<String, int> _pendingTaken = {};     // sensorKey -> doğrulama bekleyen azalma

  Timer? _pollingTimer;

  String? get _userId => _auth.currentUser?.uid;

  /// Tracking'i başlat (dakikada bir kontrol)
  Future<void> startTracking() async {
    if (_userId == null) {
      print('⚠️ User ID null, tracking başlatılamıyor');
      return;
    }

    stopTracking();

    print('🎯 Medication tracker başlatılıyor (dakikada bir kontrol)');

    await _checkAllSensors();

    _pollingTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _checkAllSensors();
    });

    print('✅ Medication tracker başlatıldı');
  }

  /// Tüm sensörleri kontrol et (schedule'lardan sensörleri tekilleştirerek)
  Future<void> _checkAllSensors() async {
    final userId = _userId;
    if (userId == null) return;

    final schedules = await _scheduleService.fetchUserSchedules(userId);
    print('🔍 Sensör kontrolü: ${schedules.length} schedule');

    // 1) sensorKey bazında schedule listesi oluştur (tekilleştirme)
    final Map<String, List<Schedule>> sensorToSchedules = {};
    for (final s in schedules) {
      if (s.linkedSensorId == null || s.linkedDeviceId == null) continue;
      final key = '${s.linkedDeviceId}|${s.linkedSensorId}';
      (sensorToSchedules[key] ??= []).add(s);
    }

    if (sensorToSchedules.isEmpty) {
      print('ℹ️ Bağlı sensör yok');
      return;
    }

    // 2) deviceId bazında grupla -> her device için RTDB'den 1 kere oku
    final Map<String, List<String>> deviceToSensorKeys = {};
    for (final key in sensorToSchedules.keys) {
      final deviceId = key.split('|').first;
      (deviceToSensorKeys[deviceId] ??= []).add(key);
    }

    // 3) Her device verisini 1 kez çek, içindeki sensörleri işle
    for (final entry in deviceToSensorKeys.entries) {
      final deviceId = entry.key;
      final keysForDevice = entry.value;

      try {
        final snapshot = await _db.ref('devices/$deviceId').get();
        if (!snapshot.exists || snapshot.value == null) {
          print('⚠️ Device bulunamadı: $deviceId');
          continue;
        }

        final deviceData = Map<String, dynamic>.from(snapshot.value as Map);

        for (final sensorKey in keysForDevice) {
          final sensorId = sensorKey.split('|')[1];
          final schedulesForSensor = sensorToSchedules[sensorKey]!;
          await _checkSensorWithDeviceData(
            deviceId: deviceId,
            sensorId: sensorId,
            schedules: schedulesForSensor,
            deviceData: deviceData,
          );
        }
      } catch (e) {
        print('❌ Device okuma hatası ($deviceId): $e');
      }
    }
  }

  /// Seçilen deviceData ile tek bir sensörü kontrol et (RAW bazlı)
  Future<void> _checkSensorWithDeviceData({
    required String deviceId,
    required String sensorId,
    required List<Schedule> schedules,
    required Map<String, dynamic> deviceData,
  }) async {
    final sensorKey = '$deviceId|$sensorId';

    try {
      // liveData'dan raw değeri al
      final liveData = deviceData['liveData'] as Map<dynamic, dynamic>?;
      if (liveData == null || !liveData.containsKey(sensorId)) return;

      final sensorData = Map<String, dynamic>.from(liveData[sensorId] as Map);
      final rawValue = (sensorData['raw'] as num?)?.toDouble() ?? 0.0;

      // config'den tare ve oneItemWeight al
      final config = deviceData['config'] as Map<dynamic, dynamic>?;
      if (config == null || !config.containsKey(sensorId)) return;

      final configData = Map<String, dynamic>.from(config[sensorId] as Map);
      final tareValue = (configData['tareValue'] as num?)?.toDouble() ?? 0.0;
      final oneItemWeight =
          (configData['oneItemWeight'] as num?)?.toDouble() ?? 1.0;

      // Sensor modeli ile sayım
      final sensor = Sensor(
        id: sensorId,
        name: sensorId,
        rawValue: rawValue,
        tareValue: tareValue,
        oneItemWeight: oneItemWeight,
      );

      final currentCount = sensor.currentPillCount;

      // UI'lar buradan okuyabilsin diye yaz
      await _db
          .ref('devices/$deviceId/liveData/$sensorId/currentPillCount')
          .set(currentCount);

      final label = schedules.isNotEmpty ? schedules.first.medicationName : sensorId;
      print('📊 $label ($sensorId): $currentCount adet');

      // İlk değer baseline
      if (!_previousCounts.containsKey(sensorKey)) {
        _previousCounts[sensorKey] = currentCount;
        _pendingTaken.remove(sensorKey);
        print('📌 Başlangıç değeri: $sensorKey = $currentCount');
        return;
      }

      final previousCount = _previousCounts[sensorKey]!;
      if (currentCount == previousCount) {
        _pendingTaken.remove(sensorKey);
        print('➡️ Değişiklik yok: $sensorId = $currentCount');
        return;
      }

      print('➡️ Değişiklik: $sensorId = $previousCount → $currentCount');

      // Artış = refill (log yok)
      if (currentCount > previousCount) {
        _previousCounts[sensorKey] = currentCount;
        _pendingTaken.remove(sensorKey);
        print('📦 İlaç eklendi: $sensorId (${previousCount} → $currentCount)');
        return;
      }

      // Azalma = aday alım
      final taken = previousCount - currentCount;

      // 1) Anormal büyük azalma (çıkar-koy / sensör hatası)
      if (taken > 50) {
        print('⚠️ Anormal değer değişimi: $taken adet (muhtemelen sensör hatası)');
        _previousCounts[sensorKey] = currentCount;
        _pendingTaken.remove(sensorKey);
        return;
      }

      // 2) Son 5 dakikada 5+ azalma = çıkar-koy olabilir
      final now = DateTime.now();
      final lastLog = _lastLogTime[sensorKey];
      if (lastLog != null) {
        final minutesSinceLastLog = now.difference(lastLog).inMinutes;
        if (minutesSinceLastLog < 5 && taken >= 5) {
          print('⚠️ 5 dakikada $taken pill azalması (çıkar-koy olabilir) - kaydetmiyorum');
          _previousCounts[sensorKey] = currentCount;
          _pendingTaken.remove(sensorKey);
          return;
        }
      }

      // 3) Karar filtresi: aynı azalma 2 kez görülürse logla
      final pending = _pendingTaken[sensorKey];
      if (pending == null || pending != taken) {
        _pendingTaken[sensorKey] = taken;
        _previousCounts[sensorKey] = currentCount;
        print('⏳ Azalma adayı: -$taken (doğrulama için bir sonraki kontrolde tekrar bakılacak)');
        return;
      }

      // doğrulandı
      _pendingTaken.remove(sensorKey);

      // Hangi schedule'a yazacağımızı seç (en yakın zaman + pencere)
      final chosen = _chooseScheduleForNow(schedules, now);
      if (chosen == null) {
        print('⚠️ Uygun schedule bulunamadı (±60dk dışında) - otomatik log atmadım');
        _previousCounts[sensorKey] = currentCount;
        return;
      }

      final expectedDosage = _parseExpectedDosage(chosen.dosage);
      final isOverdose = taken > expectedDosage;
      if (isOverdose) {
        print('⚠️ OVERDOSE: Beklenen $expectedDosage, Alınan $taken');
      }

      print('💊💊💊 İLAÇ ALINDI: ${chosen.medicationName} ($taken adet) 💊💊💊');

      await _logMedicationTaken(chosen, taken);

      _lastLogTime[sensorKey] = now;
      _previousCounts[sensorKey] = currentCount;
    } catch (e) {
      print('❌ Sensör kontrol hatası ($sensorId): $e');
    }
  }

  int _parseExpectedDosage(String dosage) {
    // "2 tablet" -> 2, parse edemezse 1
    final first = dosage.trim().split(RegExp(r'\s+')).first;
    return int.tryParse(first) ?? 1;
  }

  /// Şu ana en uygun schedule'ı seç (±60 dakika pencere)
  Schedule? _chooseScheduleForNow(List<Schedule> schedules, DateTime now) {
    const int windowMinutes = 60;

    Schedule? best;
    int bestDiff = 1 << 30;

    for (final s in schedules) {
      for (final timeStr in s.specificTimes) {
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;

        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;

        final scheduled = DateTime(now.year, now.month, now.day, h, m);
        final diff = now.difference(scheduled).inMinutes.abs();

        if (diff < bestDiff) {
          bestDiff = diff;
          best = s;
        }
      }
    }

    if (best == null) return null;
    if (bestDiff > windowMinutes) return null;
    return best;
  }

  /// İlaç alımını kaydet
  Future<void> _logMedicationTaken(Schedule schedule, int takenCount) async {
    final now = DateTime.now();

    // En yakın zamanı bul
    String? closestTime;
    int minDifference = 1 << 30;

    for (final timeStr in schedule.specificTimes) {
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final scheduleHour = int.tryParse(parts[0]);
      final scheduleMinute = int.tryParse(parts[1]);
      if (scheduleHour == null || scheduleMinute == null) continue;

      final scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        scheduleHour,
        scheduleMinute,
      );

      final difference = now.difference(scheduledDateTime).inMinutes.abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestTime = timeStr;
      }
    }

    if (closestTime == null) return;

    final parts = closestTime.split(':');
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    final expectedDosage = _parseExpectedDosage(schedule.dosage);
    final isOverdose = takenCount > expectedDosage;

    await _adherenceService.logMedicationTaken(
      scheduleId: schedule.id,
      medicationName: schedule.medicationName,
      scheduledTime: scheduledDateTime,
      takenCount: takenCount,
      isOverdose: isOverdose,
    );

    if (isOverdose) {
      print('⚠️ Otomatik log kaydedildi (OVERDOSE): ${schedule.medicationName} x$takenCount');
    } else {
      print('✅ Otomatik log kaydedildi: ${schedule.medicationName} x$takenCount');
    }
  }

  /// Tracking'i durdur
  void stopTracking() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _previousCounts.clear();
    _lastLogTime.clear();
    _pendingTaken.clear();
    print('⏹️ Medication tracker durduruldu');
  }

  /// Tracking'i yenile (schedule'lar değiştiğinde)
  Future<void> refreshTracking() async {
    stopTracking();
    await startTracking();
  }
}
