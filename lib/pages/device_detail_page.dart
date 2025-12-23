import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device.dart';
import '../models/sensor.dart';
import '../models/schedule.dart';
import '../services/realtime_device_service.dart';
import '../services/schedule_service.dart';
import 'calibration_page.dart';

class DeviceDetailPage extends StatefulWidget {
  final Device device;
  const DeviceDetailPage({super.key, required this.device});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final _deviceService = RealtimeDeviceService();
  final _scheduleService = ScheduleService();
  final Map<String, List<int>> _sensorHistory = {};
  final Map<String, int> _stableCount = {};
  List<Schedule> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final schedules = await _scheduleService.fetchUserSchedules(userId);
    setState(() => _schedules = schedules);
  }

  Schedule? _getScheduleForSensor(String sensorId) {
    try {
      return _schedules.firstWhere((s) => s.linkedSensorId == sensorId);
    } catch (_) {
      return null;
    }
  }

  int _getStableCount(String sensorId, int currentCount) {
    if (!_sensorHistory.containsKey(sensorId)) {
      _sensorHistory[sensorId] = [currentCount];
      _stableCount[sensorId] = currentCount;
      return currentCount;
    }
    _sensorHistory[sensorId]!.add(currentCount);
    if (_sensorHistory[sensorId]!.length > 5) {
      _sensorHistory[sensorId]!.removeAt(0);
    }
    final frequency = <int, int>{};
    for (var v in _sensorHistory[sensorId]!) {
      frequency[v] = (frequency[v] ?? 0) + 1;
    }
    int mostFrequent = _stableCount[sensorId]!;
    int maxFreq = 0;
    frequency.forEach((value, count) {
      if (count > maxFreq) {
        maxFreq = count;
        mostFrequent = value;
      }
    });
    if (maxFreq >= 3) {
      _stableCount[sensorId] = mostFrequent;
    }
    return _stableCount[sensorId]!;
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return StreamBuilder<List<Sensor>>(
      stream: _deviceService.watchDeviceSensors(device.id),
      builder: (context, snapshot) {
        final sensors = snapshot.data ?? [];

        // Canli online hesaplama: sensör varsa ONLINE, yoksa status/lastSeen'den türet.
        bool online = sensors.isNotEmpty;
        if (!online) {
          if (device.status == 'ONLINE') {
            online = true;
          } else {
            final diff = DateTime.now().difference(device.lastSeen);
            online = diff.inMinutes < 10;
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: _buildAppBar(device.deviceName, online),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: _buildAppBar(device.deviceName, online),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          );
        }

        if (sensors.isEmpty) {
          return Scaffold(
            appBar: _buildAppBar(device.deviceName, online),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sensors_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Bu cihazda sensör bulunamadı', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(device.deviceName, online),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Cihaz Bölmeleri / Sensörler', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              ...sensors.map((s) => _buildSensorCard(context, s, device.id)),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(String title, bool online) {
    return AppBar(
      title: Text(title),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Icon(Icons.circle, size: 12, color: online ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(
                online ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(fontSize: 12, color: online ? Colors.green : Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorCard(BuildContext context, Sensor sensor, String deviceId) {
    int rawCount = sensor.currentPillCount;
    int stableCount = _getStableCount(sensor.id, rawCount);
    final schedule = _getScheduleForSensor(sensor.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sensor.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('ID: ${sensor.id}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '$stableCount Adet',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ],
            ),
            if (schedule != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medication, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(schedule.medicationName,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                          const SizedBox(height: 2),
                          Text(
                            'Doz: ${schedule.dosage} | ${schedule.specificTimes.join(", ")}',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Bu bölmeye henüz ilaç atanmamış',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CalibrationPage(sensor: sensor, deviceId: deviceId),
                    ),
                  );
                },
                icon: const Icon(Icons.tune),
                label: const Text('Kalibrasyon Ayarları'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
