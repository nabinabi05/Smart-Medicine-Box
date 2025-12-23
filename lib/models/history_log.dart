enum HistoryStatus { taken, missed, skipped }

class HistoryLog {
  final String id;
  final String userId;
  final String scheduleId;
  final String medicationName;
  final DateTime scheduledTime;
  final HistoryStatus status;
  final DateTime? actualTakenTime;
  final String? notes;

  HistoryLog({
    required this.id,
    required this.userId,
    required this.scheduleId,
    required this.medicationName,
    required this.scheduledTime,
    required this.status,
    this.actualTakenTime,
    this.notes,
  });

  factory HistoryLog.fromMap(Map<String, dynamic> data, String id) {
    return HistoryLog(
      id: id,
      userId: data['userId'] ?? '',
      scheduleId: data['scheduleId'] ?? '',
      medicationName: data['medicationName'] ?? '',
      scheduledTime: data['scheduledTime'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['scheduledTime'])
          : DateTime.fromMillisecondsSinceEpoch(0),
      status: _statusFromStr(data['status'] ?? 'MISSED'),
      actualTakenTime: data['actualTakenTime'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['actualTakenTime'])
          : null,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'scheduleId': scheduleId,
    'medicationName': medicationName,
    'scheduledTime': scheduledTime.millisecondsSinceEpoch,
    'status': status.name.toUpperCase(),
    'actualTakenTime': actualTakenTime?.millisecondsSinceEpoch,
    'notes': notes,
  }..removeWhere((key, value) => value == null);

  static HistoryStatus _statusFromStr(String s) {
    switch (s) {
      case 'TAKEN':
        return HistoryStatus.taken;
      case 'SKIPPED':
        return HistoryStatus.skipped;
      default:
        return HistoryStatus.missed;
    }
  }
}
