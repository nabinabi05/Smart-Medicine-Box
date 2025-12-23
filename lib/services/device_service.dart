import 'package:firebase_database/firebase_database.dart';
import '../models/device.dart';
import '../models/sensor.dart';

// Firestore kaldırıldı, ileride Firebase Realtime Database ile entegre edilecek
// Şu an RealtimeDeviceService kullanılıyor
class DeviceService {
  // Devices
  Stream<List<Device>> watchDevices() {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
    return Stream.value([]);
  }

  Future<List<Device>> fetchDevices() async {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
    return [];
  }

  Future<Device?> fetchDevice(String deviceId) async {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
    return null;
  }

  Future<void> createDevice(Device d) async {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
  }

  Future<void> updateDevice(Device d) async {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
  }

  // Live data
  Stream<List<Sensor>> watchLiveSensors(String deviceId) {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
    return Stream.value([]);
  }

  Future<Sensor?> fetchLiveSensor(String deviceId, String sensorId) async {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
    return null;
  }

  Future<void> patchLiveSensor(
    String deviceId,
    String sensorId, {
    double? rawValue,
    int? currentPillCount,
  }) async {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
  }

  // Config
  Future<void> saveSensorConfig(
    String deviceId,
    String sensorId, {
    required double rawBaseValue,
    required double averagePillRaw,
    double? dosePerPill,
  }) async {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
  }

  Future<Sensor?> fetchConfigMergedSensor(
    String deviceId,
    String sensorId,
  ) async {
    // TODO: Firebase Realtime Database entegrasyonu (RealtimeDeviceService kullanın)
    return null;
  }
}

// Realtime Database ile çalışan servis
class RealtimeDeviceService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Kullanıcının kayıtlı cihazlarını izle (gerçek zamanlı sensör verileri ile)
  Stream<List<Device>> watchUserDevices(String userId) async* {
    // Her 2 saniyede bir güncelle
    await for (var _ in Stream.periodic(const Duration(seconds: 2))) {
      final devices = await fetchUserDevices(userId);
      yield devices;
    }
  }

  // Kullanıcının cihazlarını getir (tek seferlik)
  Future<List<Device>> fetchUserDevices(String userId) async {
    final snapshot = await _db.ref('users/$userId/devices').get();
    
    if (!snapshot.exists) return [];
    
    final devicesData = snapshot.value as Map?;
    if (devicesData == null) return [];

    final devices = <Device>[];
    
    for (var entry in devicesData.entries) {
      final deviceId = entry.key;
      final deviceInfo = Map<String, dynamic>.from(entry.value as Map);
      
      // Cihazın live data'sını ve config'ini çek
      final liveSnapshot = await _db.ref('devices/$deviceId/liveData').get();
      final configSnapshot = await _db.ref('devices/$deviceId/config').get();
      final sensors = <Sensor>[];
      
      if (liveSnapshot.exists) {
        final liveData = liveSnapshot.value as Map?;
        
        if (liveData != null) {
          for (var sensorEntry in liveData.entries) {
            final sensorId = sensorEntry.key.toString();
            final sensorLiveData = Map<String, dynamic>.from(sensorEntry.value as Map);
            
            // Tracker service'in hesaplayıp yazdığı currentPillCount'u kullan
            final currentPillCount = (sensorLiveData['currentPillCount'] as num?)?.toInt() ?? 0;
            
            // Basit sensor objesi - sadece currentPillCount'u override et
            final sensor = Sensor(
              id: sensorId,
              name: 'Bolme ${sensorId.toUpperCase()}',
              rawValue: 0,
              tareValue: 0,
              oneItemWeight: 1,
              overridePillCount: currentPillCount,
            );
            sensors.add(sensor);
          }
        }
      }

      devices.add(Device(
        id: deviceId,
        deviceName: deviceInfo['name'] ?? 'İlaç Kutusu',
        status: deviceInfo['status'] ?? 'OFFLINE',
        lastSeen: deviceInfo['lastSeen'] != null
            ? DateTime.fromMillisecondsSinceEpoch(deviceInfo['lastSeen'])
            : DateTime.now(),
        sensors: sensors,
      ));
    }

    return devices;
  }

  // Yeni cihaz kaydet
  Future<void> registerDevice({
    required String userId,
    required String deviceId,
    required String deviceName,
  }) async {
    await _db.ref('users/$userId/devices/$deviceId').set({
      'name': deviceName,
      'status': 'OFFLINE',
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });

    print('✅ Cihaz kaydedildi: $deviceId');
  }

  // Cihazın durumunu güncelle (ESP8266'dan çağrılacak)
  Future<void> updateDeviceStatus({
    required String deviceId,
    required String status,
  }) async {
    await _db.ref('devices/$deviceId/status').set(status);
    await _db.ref('devices/$deviceId/lastSeen').set(DateTime.now().millisecondsSinceEpoch);
  }
}
