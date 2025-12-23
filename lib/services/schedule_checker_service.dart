import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'notification_service.dart';

class ScheduleCheckerService {
  static final ScheduleCheckerService _instance = ScheduleCheckerService._internal();
  factory ScheduleCheckerService() => _instance;
  ScheduleCheckerService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  Timer? _timer;
  final Set<String> _notifiedToday = {}; // Bugün gönderilmiş bildirimler

  // Schedule kontrol sistemini başlat
  void start() {
    stop(); // Önce eski timer'ı durdur
    
    // Her dakika kontrol et
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkSchedules();
    });
    
    // İlk kontrolü hemen yap
    _checkSchedules();
    
    print('✅ Schedule checker başlatıldı (1 dakikada bir)');
  }

  // Timer'ı durdur
  void stop() {
    _timer?.cancel();
    _timer = null;
    print('⏹️ Schedule checker durduruldu');
  }

  // Tüm schedule'ları kontrol et
  Future<void> _checkSchedules() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('⚠️ User ID null, schedule kontrolü yapılamıyor');
      return;
    }

    try {
      final now = DateTime.now();
      final currentTime = '${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}';
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      print('🔍 Schedule kontrolü: $currentTime');
      
      // Gece yarısı geçtiğinde cache'i temizle
      if (now.hour == 0 && now.minute == 0) {
        _notifiedToday.clear();
      }

      // notificationTriggers/{userId} altındaki tüm schedule'ları oku
      final snapshot = await _db.ref('notificationTriggers/$userId').get();
      
      if (!snapshot.exists) {
        print('📭 Hiç trigger bulunamadı');
        return;
      }

      final triggers = snapshot.value as Map<dynamic, dynamic>?;
      if (triggers == null) {
        print('📭 Triggers null');
        return;
      }
      
      print('📋 ${triggers.length} schedule bulundu');

      // Her schedule için kontrol et
      for (final scheduleEntry in triggers.entries) {
        final scheduleId = scheduleEntry.key as String;
        final scheduleTimes = scheduleEntry.value as Map<dynamic, dynamic>?;
        
        if (scheduleTimes == null) continue;

        // Bu schedule'ın şu anki saatine bak
        final timeEntry = scheduleTimes[currentTime];
        if (timeEntry == null) {
          print('⏰ $scheduleId için $currentTime trigger bulunamadı');
          continue;
        }

        final timeData = timeEntry as Map<dynamic, dynamic>;
        final enabled = timeData['enabled'] as bool? ?? true;
        
        if (!enabled) {
          print('🚫 $scheduleId trigger disabled');
          continue;
        }

        // Bugün bu bildirim zaten gönderildi mi?
        final notificationKey = '$scheduleId-$currentTime-$today';
        if (_notifiedToday.contains(notificationKey)) {
          print('✓ $scheduleId için bugün zaten bildirim gönderildi (cache)');
          continue; // Zaten gönderilmiş
        }

        // Bildirim gönder
        final medicationName = timeData['medicationName'] as String? ?? 'İlaç';
        final time = timeData['time'] as String? ?? currentTime.replaceAll('_', ':');
        
        print('🔔 Bildirim gönderiliyor: $medicationName - $time');
        
        try {
          await _notificationService.showLocalNotification(
            id: notificationKey.hashCode,
            title: '💊 İlaç Zamanı!',
            body: '$medicationName almanız gerekiyor. Saat: $time',
            payload: scheduleId,
          );
          
          // Kaydet ki tekrar göndermeyelim
          _notifiedToday.add(notificationKey);
          
          print('✅ Bildirim başarıyla gönderildi: $medicationName - $time');
        } catch (e) {
          print('❌ Bildirim gönderilemedi: $e');
        }
      }
    } catch (e) {
      print('❌ Schedule kontrol hatası: $e');
    }
  }

  // Manuel kontrol (test için)
  Future<void> checkNow() async {
    print('🔍 Manuel schedule kontrolü...');
    await _checkSchedules();
  }
}
