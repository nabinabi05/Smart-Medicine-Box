import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/schedule.dart';
import '../models/adherence.dart';
import '../models/device.dart';
import '../models/sensor.dart';
import '../services/schedule_service.dart';
import '../services/adherence_service.dart';
import '../services/device_service.dart';
import 'statistics_page.dart';
import 'performance_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _scheduleService = ScheduleService();
  final _adherenceService = AdherenceService();
  final _deviceService = RealtimeDeviceService();
  final _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Center(child: Text('Kullanıcı girişi gerekli'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hoşgeldin mesajı
            _buildWelcomeCard(),
            const SizedBox(height: 16),
            
            // Bugünkü performans
            _buildTodayPerformance(),
            const SizedBox(height: 16),
            
            // Schedule'ların durumu
            _buildSchedulesStatus(),
            const SizedBox(height: 16),
            
            // Hızlı erişim butonları
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final hour = DateTime.now().hour;
    String greeting = 'Merhaba';
    String emoji = '👋';
    
    if (hour < 12) {
      greeting = 'Günaydın';
      emoji = '🌅';
    } else if (hour < 18) {
      greeting = 'İyi günler';
      emoji = '☀️';
    } else {
      greeting = 'İyi akşamlar';
      emoji = '🌙';
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'İlaç takibinizi kontrol edin',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayPerformance() {
    return FutureBuilder<AdherenceStats>(
      future: _adherenceService.getTodayStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final stats = snapshot.data!;
        
        if (stats.totalDoses == 0) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('Bugün için veri yok'),
              subtitle: const Text('İlaç aldığınızda burası güncellenecek'),
            ),
          );
        }

        return Card(
          elevation: 3,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📊 Bugünkü Performans',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stats.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: stats.adherenceRate / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getColorForRate(stats.adherenceRate),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatChip(
                        '${stats.takenDoses}/${stats.totalDoses}',
                        'Alınan',
                        Colors.green,
                      ),
                      _buildStatChip(
                        '%${stats.adherenceRate.toStringAsFixed(0)}',
                        'Uyum',
                        Colors.blue,
                      ),
                      _buildStatChip(
                        '${stats.missedDoses}',
                        'Kaçırılan',
                        Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSchedulesStatus() {
    return StreamBuilder<List<Schedule>>(
      stream: _scheduleService.watchUserSchedules(_userId!),
      builder: (context, scheduleSnapshot) {
        if (!scheduleSnapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final schedules = scheduleSnapshot.data!;
        
        if (schedules.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.add_alert, color: Colors.orange),
              title: const Text('Henüz plan yok'),
              subtitle: const Text('İlaç planı eklemek için Planlar sekmesini kullanın'),
            ),
          );
        }

        // Device'ları da çek (gerçek zamanlı)
        return StreamBuilder<List<Device>>(
          stream: _deviceService.watchUserDevices(_userId!),
          builder: (context, deviceSnapshot) {
            final devices = deviceSnapshot.data ?? [];
            
            // Kritik stokları filtrele (sensör verisine göre)
            final criticalSchedules = <Schedule>[];
            for (var schedule in schedules) {
              if (schedule.linkedDeviceId != null && schedule.linkedSensorId != null) {
                final device = devices.firstWhere(
                  (d) => d.id == schedule.linkedDeviceId,
                  orElse: () => Device(id: '', deviceName: '', status: 'OFFLINE', lastSeen: DateTime.now(), sensors: []),
                );
                final Sensor? sensor = device.sensors.cast<Sensor?>().firstWhere(
                  (s) => s?.id == schedule.linkedSensorId,
                  orElse: () => null,
                );
                if (sensor != null) {
                  final days = _calculateDaysRemaining(sensor.currentPillCount, schedule.dailyDosageCount);
                  if (days != null && days <= 3) {
                    criticalSchedules.add(schedule);
                  }
                }
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '💊 İlaç Durumu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (criticalSchedules.isNotEmpty)
                  ...criticalSchedules.map((s) => _buildCriticalStockWarning(s, devices)),
                _buildSchedulesSummary(schedules, devices),
              ],
            );
          },
        );
      },
    );
  }

  int? _calculateDaysRemaining(int currentPillCount, int dailyUsage) {
    if (currentPillCount <= 0 || dailyUsage <= 0) return null;
    return (currentPillCount / dailyUsage).ceil();
  }

  Widget _buildCriticalStockWarning(Schedule schedule, List<Device> devices) {
    // Sensörden gerçek ilaç sayısını al
    int? currentCount;
    int? daysRemaining;
    
    if (schedule.linkedDeviceId != null && schedule.linkedSensorId != null) {
      final device = devices.firstWhere(
        (d) => d.id == schedule.linkedDeviceId,
        orElse: () => Device(id: '', deviceName: '', status: 'OFFLINE', lastSeen: DateTime.now(), sensors: []),
      );
      final Sensor? sensor = device.sensors.cast<Sensor?>().firstWhere(
        (s) => s?.id == schedule.linkedSensorId,
        orElse: () => null,
      );
      if (sensor != null) {
        currentCount = sensor.currentPillCount;
        daysRemaining = _calculateDaysRemaining(currentCount, schedule.dailyDosageCount);
      }
    }
    
    return Card(
      color: Colors.red[50],
      child: ListTile(
        leading: const Icon(Icons.warning, color: Colors.red),
        title: Text(schedule.medicationName),
        subtitle: Text(
          daysRemaining != null
              ? '⚠️ $daysRemaining gün sonra bitecek! (${currentCount ?? 0} adet kaldı)'
              : '⚠️ İlaç bitmek üzere!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: daysRemaining != null
            ? Text(
                '${DateTime.now().add(Duration(days: daysRemaining)).day}/${DateTime.now().add(Duration(days: daysRemaining)).month}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            : null,
      ),
    );
  }

  Widget _buildSchedulesSummary(List<Schedule> schedules, List<Device> devices) {
    // Sadece cihaza bağlı olan ilaçları göster
    final schedulesWithDevice = schedules.where((s) => 
      s.linkedDeviceId != null && s.linkedSensorId != null
    ).toList();
    
    if (schedulesWithDevice.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'İlaç Stok Durumu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Cihaza bağlı ilaç yok',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plan eklerken cihaz ve bölme seçin',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'İlaç Stok Durumu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${schedulesWithDevice.length} ilaç',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...schedulesWithDevice.map((schedule) => _buildScheduleStockItem(schedule, devices)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleStockItem(Schedule schedule, List<Device> devices) {
    // Sensörden gerçek ilaç sayısını al
    int? currentCount;
    int? daysRemaining;
    
    if (schedule.linkedDeviceId != null && schedule.linkedSensorId != null) {
      final device = devices.firstWhere(
        (d) => d.id == schedule.linkedDeviceId,
        orElse: () => Device(id: '', deviceName: '', status: 'OFFLINE', lastSeen: DateTime.now(), sensors: []),
      );
      final Sensor? sensor = device.sensors.cast<Sensor?>().firstWhere(
        (s) => s?.id == schedule.linkedSensorId,
        orElse: () => null,
      );
      if (sensor != null) {
        currentCount = sensor.currentPillCount;
        daysRemaining = _calculateDaysRemaining(currentCount, schedule.dailyDosageCount);
      }
    }
    
    // Durum belirleme
    Color statusColor;
    String statusEmoji;
    String statusText;
    
    if (daysRemaining == null || currentCount == null) {
      statusColor = Colors.grey;
      statusEmoji = '⚪';
      statusText = 'Bekleniyor';
    } else if (daysRemaining <= 3) {
      statusColor = Colors.red;
      statusEmoji = '🔴';
      statusText = 'Kritik';
    } else if (daysRemaining <= 7) {
      statusColor = Colors.orange;
      statusEmoji = '🟡';
      statusText = 'Düşük';
    } else {
      statusColor = Colors.green;
      statusEmoji = '🟢';
      statusText = 'Normal';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.medicationName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (currentCount != null) ...[
                      Text(
                        '$currentCount adet',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                    ],
                    if (daysRemaining != null) ...[
                      Text(
                        '$daysRemaining gün',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                    ],
                    Text(
                      'Günlük: ${schedule.dailyDosageCount} adet',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              '$statusEmoji $statusText',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '⚡ Hızlı Erişim',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Card(
                color: Colors.orange[50],
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PerformancePage()),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.analytics, size: 48, color: Colors.orange),
                        SizedBox(height: 8),
                        Text(
                          'Performans',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                color: Colors.blue[50],
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StatisticsPage()),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.bar_chart, size: 48, color: Colors.blue),
                        SizedBox(height: 8),
                        Text(
                          'İstatistikler',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Card(
                color: Colors.purple[50],
                child: InkWell(
                  onTap: () {
                    // History sayfasına git
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 48, color: Colors.purple),
                        SizedBox(height: 8),
                        Text(
                          'Geçmiş',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Color _getColorForRate(double rate) {
    if (rate >= 95) return Colors.green;
    if (rate >= 85) return Colors.lightGreen;
    if (rate >= 70) return Colors.orange;
    if (rate >= 50) return Colors.deepOrange;
    return Colors.red;
  }
}
