import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/adherence.dart';
import '../models/schedule.dart';

class AdherenceService {
  static final AdherenceService _instance = AdherenceService._internal();
  factory AdherenceService() => _instance;
  AdherenceService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // İlaç alındığında kaydet
  Future<void> logMedicationTaken({
    required String scheduleId,
    required String medicationName,
    required DateTime scheduledTime,
    int takenCount = 1,
    bool isOverdose = false,
  }) async {
    if (_userId == null) return;

    final takenAt = DateTime.now();
    final score = MedicationLog.calculateScore(scheduledTime, takenAt);
    final wasOnTime = score >= 75; // 75+ puan = zamanında

    final log = MedicationLog(
      scheduleId: scheduleId,
      medicationName: medicationName,
      takenAt: takenAt,
      scheduledTime: scheduledTime,
      wasOnTime: wasOnTime,
      adherenceScore: score,
      takenCount: takenCount,
      isOverdose: isOverdose,
    );

    // medicationLogs/{userId}/{logId} altına kaydet
    final ref = _db.ref('medicationLogs/$_userId').push();
    await ref.set(log.toMap());

    if (isOverdose) {
      print('⚠️ İlaç alım kaydedildi (OVERDOSE): $medicationName x$takenCount (Skor: $score)');
    } else {
      print('✅ İlaç alım kaydedildi: $medicationName x$takenCount (Skor: $score)');
    }
  }

  // Kaçırılan ilaç kaydet
  Future<void> logMissedDose({
    required String scheduleId,
    required String medicationName,
    required DateTime scheduledTime,
  }) async {
    if (_userId == null) return;

    final log = MedicationLog(
      scheduleId: scheduleId,
      medicationName: medicationName,
      takenAt: DateTime.now(), // Kontrol zamanı
      scheduledTime: scheduledTime,
      wasOnTime: false,
      adherenceScore: 0, // Kaçırılan = 0 puan
    );

    final ref = _db.ref('medicationLogs/$_userId').push();
    await ref.set(log.toMap());

    print('⚠️ Kaçırılan ilaç kaydedildi: $medicationName');
  }

  // Belirli tarih aralığındaki logları al
  Future<List<MedicationLog>> getLogsBetween(DateTime start, DateTime end) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _db.ref('medicationLogs/$_userId').get();
      
      if (!snapshot.exists) {
        print('📭 Hiç medication log yok');
        return [];
      }

      final logsMap = snapshot.value as Map<dynamic, dynamic>;
      final logs = <MedicationLog>[];

      print('📊 Firebase\'de ${logsMap.length} log bulundu');

      for (final entry in logsMap.entries) {
        try {
          final log = MedicationLog.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
            entry.key as String,
          );
          
          // Tarih aralığında mı?
          if (log.takenAt.isAfter(start) && log.takenAt.isBefore(end)) {
            logs.add(log);
            print('✅ Log: ${log.medicationName} - ${log.takenAt} (${log.takenCount} adet, overdose: ${log.isOverdose})');
          } else {
            print('⏭️ Tarih dışı: ${log.medicationName} - ${log.takenAt}');
          }
        } catch (e) {
          print('⚠️ Log parse hatası: $e');
        }
      }

      print('📋 Tarih aralığında ${logs.length} log bulundu (${start.day}/${start.month} - ${end.day}/${end.month})');
      return logs;
    } catch (e) {
      print('❌ Log okuma hatası: $e');
      return [];
    }
  }

  // Haftalık istatistik hesapla
  Future<AdherenceStats> getWeeklyStats() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: 7));
    
    return _calculateStats(weekStart, now);
  }

  // Aylık istatistik hesapla
  Future<AdherenceStats> getMonthlyStats() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    return _calculateStats(monthStart, now);
  }

  // Bugünkü istatistik
  Future<AdherenceStats> getTodayStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    return _calculateStats(todayStart, now);
  }

  // İstatistik hesaplama
  Future<AdherenceStats> _calculateStats(DateTime start, DateTime end) async {
    final logs = await getLogsBetween(start, end);
    
    if (logs.isEmpty) {
      return AdherenceStats(
        totalDoses: 0,
        takenDoses: 0,
        missedDoses: 0,
        adherenceRate: 0,
        averageScore: 0,
        perfectDoses: 0,
        lateDoses: 0,
      );
    }

    final takenDoses = logs.where((l) => l.adherenceScore > 0).length;
    final missedDoses = logs.where((l) => l.adherenceScore == 0).length;
    final perfectDoses = logs.where((l) => l.adherenceScore == 100).length;
    final lateDoses = logs.where((l) => l.adherenceScore > 0 && l.adherenceScore < 100).length;
    
    final totalDoses = logs.length;
    final adherenceRate = totalDoses > 0 
        ? (takenDoses / totalDoses) * 100 
        : 0.0;
    
    final averageScore = totalDoses > 0
        ? logs.map((l) => l.adherenceScore).reduce((a, b) => a + b) / totalDoses
        : 0.0;

    return AdherenceStats(
      totalDoses: totalDoses,
      takenDoses: takenDoses,
      missedDoses: missedDoses,
      adherenceRate: adherenceRate,
      averageScore: averageScore,
      perfectDoses: perfectDoses,
      lateDoses: lateDoses,
    );
  }

  // Detaylı performans analizi
  Future<PerformanceAnalysis> getPerformanceAnalysis({int days = 7}) async {
    if (_userId == null) {
      return PerformanceAnalysis(
        stats: AdherenceStats(
          totalDoses: 0, takenDoses: 0, missedDoses: 0,
          adherenceRate: 0, averageScore: 0, perfectDoses: 0, lateDoses: 0,
        ),
        overdoseCount: 0, missedStreak: 0, perfectStreak: 0,
        medicationBreakdown: {}, overdoseByMedication: {},
        warnings: [], achievements: [],
      );
    }

    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final logs = await getLogsBetween(start, now);
    
    // Sırala (en yeniden eskiye)
    logs.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    
    // Stats hesapla
    final stats = await _calculateStats(start, now);
    
    // Overdose sayısı
    final overdoseCount = logs.where((l) => l.isOverdose).length;
    
    // İlaç bazında breakdown
    final medicationBreakdown = <String, int>{};
    final overdoseByMedication = <String, int>{};
    
    for (final log in logs) {
      medicationBreakdown[log.medicationName] = 
        (medicationBreakdown[log.medicationName] ?? 0) + log.takenCount;
      
      if (log.isOverdose) {
        overdoseByMedication[log.medicationName] = 
          (overdoseByMedication[log.medicationName] ?? 0) + 1;
      }
    }
    
    // Mükemmel seri (ardışık zamanında alım)
    int perfectStreak = 0;
    for (final log in logs) {
      if (log.adherenceScore == 100) {
        perfectStreak++;
      } else {
        break;
      }
    }
    
    // Kaçırma serisi (ardışık kaçırma)
    int missedStreak = 0;
    for (final log in logs) {
      if (log.adherenceScore == 0) {
        missedStreak++;
      } else {
        break;
      }
    }
    
    // Uyarılar oluştur
    final warnings = <String>[];
    if (overdoseCount > 0) {
      warnings.add('$overdoseCount kez fazla doz alındı');
    }
    if (missedStreak >= 3) {
      warnings.add('$missedStreak gündür ilaç kaçırılıyor');
    }
    if (stats.adherenceRate < 70) {
      warnings.add('Uyum oranı düşük: %${stats.adherenceRate.toStringAsFixed(0)}');
    }
    if (stats.lateDoses > stats.takenDoses * 0.5) {
      warnings.add('İlaçların %${((stats.lateDoses / stats.takenDoses) * 100).toStringAsFixed(0)}\'si geç alınıyor');
    }
    
    // Başarılar
    final achievements = <String>[];
    if (perfectStreak >= 7) {
      achievements.add('🏆 7 gün mükemmel uyum!');
    } else if (perfectStreak >= 3) {
      achievements.add('⭐ $perfectStreak gün mükemmel uyum!');
    }
    if (stats.adherenceRate >= 95) {
      achievements.add('🎯 Mükemmel uyum oranı!');
    }
    if (overdoseCount == 0 && stats.takenDoses > 10) {
      achievements.add('✅ Hiç overdose yok');
    }
    if (missedStreak == 0 && stats.takenDoses > 5) {
      achievements.add('💪 Süreklilik korunuyor');
    }
    
    return PerformanceAnalysis(
      stats: stats,
      overdoseCount: overdoseCount,
      missedStreak: missedStreak,
      perfectStreak: perfectStreak,
      medicationBreakdown: medicationBreakdown,
      overdoseByMedication: overdoseByMedication,
      warnings: warnings,
      achievements: achievements,
    );
  }

  // Schedule için bugünkü performansı hesapla
  Future<double> getScheduleAdherenceRate(String scheduleId, {int days = 7}) async {
    if (_userId == null) return 0;

    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final logs = await getLogsBetween(start, now);
    
    // Bu schedule'a ait loglar
    final scheduleLogs = logs.where((l) => l.scheduleId == scheduleId).toList();
    
    if (scheduleLogs.isEmpty) return 0;
    
    final takenCount = scheduleLogs.where((l) => l.adherenceScore > 0).length;
    return (takenCount / scheduleLogs.length) * 100;
  }
}
