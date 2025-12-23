import 'package:flutter/material.dart';
import '../models/adherence.dart';
import '../services/adherence_service.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final _adherenceService = AdherenceService();
  
  String _selectedPeriod = 'week'; // week, month, today
  
  Future<AdherenceStats> _getStats() {
    switch (_selectedPeriod) {
      case 'today':
        return _adherenceService.getTodayStats();
      case 'month':
        return _adherenceService.getMonthlyStats();
      case 'week':
      default:
        return _adherenceService.getWeeklyStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 İstatistikler'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'today', child: Text('📅 Bugün')),
              const PopupMenuItem(value: 'week', child: Text('📆 Bu Hafta')),
              const PopupMenuItem(value: 'month', child: Text('📊 Bu Ay')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<AdherenceStats>(
        future: _getStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final stats = snapshot.data;
          if (stats == null || stats.totalDoses == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_chart_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz veri yok',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'İlaç alma kayıtlarınız burada görünecek',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Genel performans kartı
                _buildPerformanceCard(stats),
                const SizedBox(height: 16),
                
                // Detaylı istatistikler
                _buildDetailedStats(stats),
                const SizedBox(height: 16),
                
                // İlerleme grafiği
                _buildProgressBar(stats),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerformanceCard(AdherenceStats stats) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              stats.emoji,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              stats.performanceLevel,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '%${stats.adherenceRate.toStringAsFixed(1)} Uyum Oranı',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: stats.adherenceRate / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getColorForRate(stats.adherenceRate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats(AdherenceStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detaylı İstatistikler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildStatRow('Toplam Doz', '${stats.totalDoses}', Icons.medication),
            _buildStatRow('Alınan', '${stats.takenDoses}', Icons.check_circle, Colors.green),
            _buildStatRow('Kaçırılan', '${stats.missedDoses}', Icons.cancel, Colors.red),
            _buildStatRow('Mükemmel Zamanında', '${stats.perfectDoses}', Icons.star, Colors.amber),
            _buildStatRow('Gecikmeli', '${stats.lateDoses}', Icons.schedule, Colors.orange),
            const Divider(),
            _buildStatRow(
              'Ortalama Skor',
              '${stats.averageScore.toStringAsFixed(1)}/100',
              Icons.analytics,
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AdherenceStats stats) {
    final successRate = stats.totalDoses > 0 
        ? stats.takenDoses / stats.totalDoses 
        : 0.0;
    final missRate = stats.totalDoses > 0 
        ? stats.missedDoses / stats.totalDoses 
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dağılım',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    if (stats.perfectDoses > 0)
                      Expanded(
                        flex: stats.perfectDoses,
                        child: Container(
                          color: Colors.green,
                          child: Center(
                            child: Text(
                              '${stats.perfectDoses}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    if (stats.lateDoses > 0)
                      Expanded(
                        flex: stats.lateDoses,
                        child: Container(
                          color: Colors.orange,
                          child: Center(
                            child: Text(
                              '${stats.lateDoses}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    if (stats.missedDoses > 0)
                      Expanded(
                        flex: stats.missedDoses,
                        child: Container(
                          color: Colors.red,
                          child: Center(
                            child: Text(
                              '${stats.missedDoses}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegend('Mükemmel', Colors.green),
                _buildLegend('Gecikmeli', Colors.orange),
                _buildLegend('Kaçırılan', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
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
