import 'sensor.dart';

class Device {
  final String id;
  final String deviceName;
  final String status;
  final DateTime lastSeen;
  final List<Sensor> sensors;

  Device({
    required this.id,
    required this.deviceName,
    required this.status,
    required this.lastSeen,
    this.sensors = const [],
  });

  String get name => deviceName;

  bool get online {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    // Sensör verisi varsa ve 5 dk içinde güncellenmişse ONLINE
    if (sensors.isNotEmpty && diff.inMinutes < 5) return true;

    // Son görülme 10 dk'dan eskiyse OFFLINE
    if (diff.inMinutes >= 10) return false;

    // Sensör yoksa ve son görülme taze ise status'e göre karar ver
    return status == 'ONLINE';
  }
}
