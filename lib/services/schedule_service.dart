import 'package:firebase_database/firebase_database.dart';
import '../models/schedule.dart';

class ScheduleService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Kullanıcının tüm programlarını izle
  Stream<List<Schedule>> watchUserSchedules(String userId) {
    return _db
        .ref('users/$userId/schedules')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <Schedule>[];
      
      final data = event.snapshot.value as Map?;
      if (data == null) return <Schedule>[];

      return data.entries
          .map((e) => Schedule.fromMap(
              Map<String, dynamic>.from(e.value as Map),
              e.key,
            ))
          .toList()
        ..sort((a, b) {
          // En yakın saati en üste
          final now = TimeOfDay.now();
          final aNext = _getNextTimeIndex(a.specificTimes, now);
          final bNext = _getNextTimeIndex(b.specificTimes, now);
          return aNext.compareTo(bNext);
        });
    });
  }

  // Kullanıcının programlarını getir (tek seferlik)
  Future<List<Schedule>> fetchUserSchedules(String userId) async {
    final snapshot = await _db.ref('users/$userId/schedules').get();
    
    if (!snapshot.exists) return [];
    
    final data = snapshot.value as Map?;
    if (data == null) return [];

    return data.entries
        .map((e) => Schedule.fromMap(
            Map<String, dynamic>.from(e.value as Map),
            e.key,
          ))
        .toList();
  }

  // Yeni program oluştur
  Future<String> createSchedule(String userId, Schedule schedule) async {
    final ref = _db.ref('users/$userId/schedules').push();
    await ref.set(schedule.toMap());
    
    print('📅 Program oluşturuldu: ${schedule.medicationName}');
    
    // Bildirim trigger'ı ayarla (Cloud Functions için)
    await _scheduleNotificationTriggers(userId, ref.key!, schedule);
    
    return ref.key!;
  }

  // Programı güncelle
  Future<void> updateSchedule(String userId, Schedule schedule) async {
    await _db.ref('users/$userId/schedules/${schedule.id}').update(schedule.toMap());
    
    print('📅 Program güncellendi: ${schedule.medicationName}');
    
    // Bildirimleri yeniden ayarla
    await _scheduleNotificationTriggers(userId, schedule.id, schedule);
  }

  // Programı sil
  Future<void> deleteSchedule(String userId, String scheduleId) async {
    await _db.ref('users/$userId/schedules/$scheduleId').remove();
    
    // Bildirim trigger'larını sil
    await _db.ref('notificationTriggers/$userId/$scheduleId').remove();
    
    print('📅 Program silindi');
  }

  // Bildirim trigger'larını Firebase'e kaydet
  // Cloud Functions bunları okuyup zamanı gelince bildirim gönderecek
  Future<void> _scheduleNotificationTriggers(
    String userId,
    String scheduleId,
    Schedule schedule,
  ) async {
    if (!schedule.isActive) return;

    final triggersRef = _db.ref('notificationTriggers/$userId/$scheduleId');
    
    // Her saat için bir trigger
    final triggers = <String, dynamic>{};
    for (var time in schedule.specificTimes) {
      triggers[time.replaceAll(':', '_')] = {
        'time': time,
        'medicationName': schedule.medicationName,
        'dosage': schedule.dosage,
        'enabled': true,
      };
    }
    
    await triggersRef.set(triggers);
  }

  // En yakın ilaç saatinin index'ini bul (sıralama için)
  int _getNextTimeIndex(List<String> times, TimeOfDay now) {
    final nowMinutes = now.hour * 60 + now.minute;
    
    for (int i = 0; i < times.length; i++) {
      final parts = times[i].split(':');
      final timeMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      
      if (timeMinutes >= nowMinutes) return timeMinutes;
    }
    
    // Hepsi geçmişse, yarının ilk saati
    final parts = times.first.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]) + 1440; // +24 saat
  }
}

class TimeOfDay {
  final int hour;
  final int minute;

  TimeOfDay(this.hour, this.minute);

  factory TimeOfDay.now() {
    final now = DateTime.now();
    return TimeOfDay(now.hour, now.minute);
  }
}
