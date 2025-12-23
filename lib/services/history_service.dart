import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/adherence.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // MedicationLog'ları stream olarak dinle
  Stream<List<MedicationLog>> watchMedicationLogs({
    DateTime? start,
    DateTime? end,
  }) {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _db.ref('medicationLogs/$_userId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <MedicationLog>[];
      }

      final logsMap = event.snapshot.value as Map<dynamic, dynamic>;
      final logs = <MedicationLog>[];

      for (final entry in logsMap.entries) {
        try {
          final log = MedicationLog.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
            entry.key as String,
          );

          // Tarih filtresi
          if (start != null && log.takenAt.isBefore(start)) continue;
          if (end != null && log.takenAt.isAfter(end)) continue;

          logs.add(log);
        } catch (e) {
          print('⚠️ Log parse hatası: $e');
        }
      }

      // Tarihe göre sırala (en yeni önce)
      logs.sort((a, b) => b.takenAt.compareTo(a.takenAt));
      return logs;
    });
  }

  // Tüm logları sil (temizlik için)
  Future<void> clearAllLogs() async {
    if (_userId == null) return;
    await _db.ref('medicationLogs/$_userId').remove();
    print('🗑️ Tüm medication logları silindi');
  }
}
