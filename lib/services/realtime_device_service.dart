import 'package:firebase_database/firebase_database.dart';
import '../models/device.dart';
import '../models/sensor.dart';

class RealtimeDeviceService {
  final _db = FirebaseDatabase.instance.ref();

  Stream<List<Device>> watchDevices() {
    return _db.child('devices').onValue.map((event) {
      if (event.snapshot.value == null) return <Device>[];
      final devicesMap = event.snapshot.value as Map<dynamic, dynamic>;
      return devicesMap.entries.map((e) {
        final data = Map<String, dynamic>.from(e.value as Map);
        DateTime lastSeen = DateTime.now();
        if (data['lastSeen'] != null) {
          lastSeen = DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] as int);
        }
        return Device(
          id: e.key.toString(),
          deviceName: data['deviceName'] ?? 'Bilinmeyen Cihaz',
          status: data['status'] ?? 'OFFLINE',
          lastSeen: lastSeen,
        );
      }).toList();
    });
  }

  Stream<List<Sensor>> watchDeviceSensors(String deviceId) {
    return _db.child('devices/$deviceId').onValue.map((event) {
      if (event.snapshot.value == null) return <Sensor>[];
      final deviceData = event.snapshot.value as Map<dynamic, dynamic>;
      final liveData = deviceData['liveData'] as Map<dynamic, dynamic>? ?? {};
      final config = deviceData['config'] as Map<dynamic, dynamic>? ?? {};

      final sensors = <Sensor>[];
      liveData.forEach((sensorId, sensorDataRaw) {
        final sId = sensorId.toString();
        final sData = Map<String, dynamic>.from(sensorDataRaw as Map);
        final cData = config[sId] != null
            ? Map<String, dynamic>.from(config[sId] as Map)
            : <String, dynamic>{};

        double raw = 0;
        try {
          if (sData['raw'] != null) {
            raw = (sData['raw'] as num).toDouble();
          } else if (sData['rawValue'] != null) {
            raw = (sData['rawValue'] as num).toDouble();
          }
        } catch (_) {}

        String name = 'Sensor $sId';
        if (cData['name'] != null) {
          name = cData['name'] as String;
        } else if (sData['name'] != null) {
          name = sData['name'] as String;
        } else if (sId == 'sensor1') {
          name = 'Compartment 1';
        }

        sensors.add(Sensor(
          id: sId,
          name: name,
          rawValue: raw,
          tareValue: (cData['tareValue'] as num?)?.toDouble() ?? 0.0,
          oneItemWeight: (cData['oneItemWeight'] as num?)?.toDouble() ?? 1.0,
        ));
      });

      sensors.sort((a, b) => a.id.compareTo(b.id));
      return sensors;
    });
  }

  Future<void> setTareValue({
    required String deviceId,
    required String sensorId,
    required double currentRaw,
  }) async {
    await _db.child('devices/$deviceId/config/$sensorId/tareValue').set(currentRaw);
  }

  Future<void> calibrateSensor({
    required String deviceId,
    required String sensorId,
    required double currentRaw,
    required double tareValue,
    required int knownCount,
  }) async {
    if (knownCount <= 0) return;
    final oneItemWeight = (currentRaw - tareValue) / knownCount;
    await _db.child('devices/$deviceId/config/$sensorId/oneItemWeight').set(oneItemWeight);
  }

  Future<void> addDevice({
    required String deviceId,
    required String deviceName,
  }) async {
    await _db.child('devices/$deviceId').set({
      'deviceName': deviceName,
      'status': 'OFFLINE',
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> registerDevice({
    required String userId,
    required String deviceId,
    required String deviceName,
  }) async {
    await _db.child('users/$userId/devices/$deviceId').set({
      'name': deviceName,
      'status': 'OFFLINE',
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });

    final deviceSnapshot = await _db.child('devices/$deviceId').get();
    if (!deviceSnapshot.exists) {
      await _db.child('devices/$deviceId').set({
        'deviceName': deviceName,
        'status': 'OFFLINE',
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'ownerId': userId,
      });
    }
  }

  Stream<List<Device>> watchUserDevices(String userId) {
    return _db.child('users/$userId/devices').onValue.asyncMap((event) async {
      if (event.snapshot.value == null) return <Device>[];
      final devicesData = event.snapshot.value as Map?;
      if (devicesData == null) return <Device>[];

      final devices = <Device>[];

      for (var entry in devicesData.entries) {
        final deviceId = entry.key;
        final deviceInfo = Map<String, dynamic>.from(entry.value as Map);

        final deviceSnapshot = await _db.child('devices/$deviceId').get();
        final deviceData = deviceSnapshot.exists
            ? Map<String, dynamic>.from(deviceSnapshot.value as Map)
            : <String, dynamic>{};

        final liveSnapshot = await _db.child('devices/$deviceId/liveData').get();
        final sensors = <Sensor>[];

        if (liveSnapshot.exists) {
          final liveData = liveSnapshot.value as Map?;
          if (liveData != null) {
            for (var sensorEntry in liveData.entries) {
              final sId = sensorEntry.key.toString();
              final sensorData = Map<String, dynamic>.from(sensorEntry.value as Map);

              double raw = 0;
              try {
                if (sensorData['raw'] != null) {
                  raw = (sensorData['raw'] as num).toDouble();
                } else if (sensorData['rawValue'] != null) {
                  raw = (sensorData['rawValue'] as num).toDouble();
                }
              } catch (_) {}

              final configSnapshot = await _db.child('devices/$deviceId/config/$sId').get();
              double tareValue = 0;
              double oneItemWeight = 1;
              if (configSnapshot.exists) {
                final configData = Map<String, dynamic>.from(configSnapshot.value as Map);
                tareValue = (configData['tareValue'] as num?)?.toDouble() ?? 0;
                oneItemWeight = (configData['oneItemWeight'] as num?)?.toDouble() ?? 1;
              }

              sensors.add(Sensor(
                id: sId,
                name: 'Bolme ${sId.toUpperCase()}',
                rawValue: raw,
                tareValue: tareValue,
                oneItemWeight: oneItemWeight,
              ));
            }
          }
        }

        DateTime lastSeenTime = DateTime.now();
        if (deviceData['lastSeen'] is int) {
          lastSeenTime = DateTime.fromMillisecondsSinceEpoch(deviceData['lastSeen'] as int);
        } else if (deviceInfo['lastSeen'] != null) {
          lastSeenTime = DateTime.fromMillisecondsSinceEpoch(deviceInfo['lastSeen']);
        }

        String deviceStatus = deviceData['status'] ?? deviceInfo['status'] ?? 'OFFLINE';
        if (deviceStatus.isEmpty) deviceStatus = 'OFFLINE';

        if (sensors.isNotEmpty) {
          deviceStatus = 'ONLINE';
          lastSeenTime = DateTime.now();
          _db.child('users/$userId/devices/$deviceId/lastSeen')
              .set(DateTime.now().millisecondsSinceEpoch);
        }

        devices.add(Device(
          id: deviceId,
          deviceName: deviceInfo['name'] ?? deviceData['deviceName'] ?? 'Ilac Kutusu',
          status: deviceStatus,
          lastSeen: lastSeenTime,
          sensors: sensors,
        ));
      }

      return devices;
    });
  }

  Future<void> deleteDevice({
    required String userId,
    required String deviceId,
  }) async {
    await _db.child('users/$userId/devices/$deviceId').remove();

    final schedulesSnapshot = await _db.child('users/$userId/schedules').get();
    if (schedulesSnapshot.exists) {
      final schedules = schedulesSnapshot.value as Map?;
      if (schedules != null) {
        for (var entry in schedules.entries) {
          final scheduleData = Map<String, dynamic>.from(entry.value as Map);
          if (scheduleData['linkedDeviceId'] == deviceId) {
            await _db.child('users/$userId/schedules/${entry.key}').remove();
          }
        }
      }
    }

    await _db.child('notificationTriggers/$userId').get().then((snapshot) async {
      if (snapshot.exists) {
        final triggers = snapshot.value as Map?;
        if (triggers != null) {
          for (var _ in triggers.entries) {
            // gerekirse temizleme
          }
        }
      }
    });
  }
}
