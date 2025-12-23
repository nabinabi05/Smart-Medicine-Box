import 'package:flutter/material.dart';
import '../models/adherence.dart';
import '../services/adherence_service.dart';

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  final _adherenceService = AdherenceService();
  PerformanceAnalysis? _analysis;
  bool _isLoading = true;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() => _isLoading = true);
    final analysis = await _adherenceService.getPerformanceAnalysis(days: _selectedDays);
    setState(() {
      _analysis = analysis;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performans Analizi'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _selectedDays,
            onSelected: (days) {
              setState(() => _selectedDays = days);
              _loadAnalysis();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('Son 7 Gün')),
              const PopupMenuItem(value: 14, child: Text('Son 14 Gün')),
              const PopupMenuItem(value: 30, child: Text('Son 30 Gün')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analysis == null
              ? const Center(child: Text('Veri yok'))
              : RefreshIndicator(
                  onRefresh: _loadAnalysis,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildRiskCard(),
                      const SizedBox(height: 16),
                      _buildStatsCard(),
                      const SizedBox(height: 16),
                      _buildStreakCard(),
                      const SizedBox(height: 16),
                      if (_analysis!.warnings.isNotEmpty) ...[
                        _buildWarningsCard(),
                        const SizedBox(height: 16),
                      ],
                      if (_analysis!.achievements.isNotEmpty) ...[
                        _buildAchievementsCard(),
                        const SizedBox(height: 16),
                      ],
                      _buildMedicationBreakdown(),
                      if (_analysis!.overdoseByMedication.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildOverdoseBreakdown(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildRiskCard() {
    final analysis = _analysis!;
    return Card(
      color: _getRiskColor(analysis.riskScore),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  analysis.riskEmoji,
                  style: const TextStyle(fontSize: 48),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      analysis.riskLevel,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Risk Skoru: ${analysis.riskScore}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: analysis.riskScore / 100,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _analysis!.stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  stats.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.performanceLevel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Uyum Oranı: %${stats.adherenceRate.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Toplam', stats.totalDoses.toString(), Icons.medication),
                _buildStatItem('Alınan', stats.takenDoses.toString(), Icons.check_circle, Colors.green),
                _buildStatItem('Kaçırılan', stats.missedDoses.toString(), Icons.cancel, Colors.red),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Mükemmel', stats.perfectDoses.toString(), Icons.star, Colors.amber),
                _buildStatItem('Geç', stats.lateDoses.toString(), Icons.access_time, Colors.orange),
                _buildStatItem('Ort. Skor', stats.averageScore.toStringAsFixed(0), Icons.analytics, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey[600], size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    final analysis = _analysis!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seriler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (analysis.perfectStreak > 0)
              ListTile(
                leading: const Icon(Icons.local_fire_department, color: Colors.orange),
                title: Text('Mükemmel Seri: ${analysis.perfectStreak} gün'),
                subtitle: const Text('Tüm ilaçlar zamanında alındı'),
              ),
            if (analysis.missedStreak > 0)
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text('Kaçırma Serisi: ${analysis.missedStreak} gün'),
                subtitle: const Text('İlaçlar kaçırılıyor'),
              ),
            if (analysis.overdoseCount > 0)
              ListTile(
                leading: const Icon(Icons.medication, color: Colors.red),
                title: Text('Overdose: ${analysis.overdoseCount} kez'),
                subtitle: const Text('Fazla doz alımı tespit edildi'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningsCard() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Uyarılar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._analysis!.warnings.map((warning) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(warning)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsCard() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Başarılar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._analysis!.achievements.map((achievement) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    achievement,
                    style: const TextStyle(fontSize: 16),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationBreakdown() {
    final breakdown = _analysis!.medicationBreakdown;
    if (breakdown.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İlaç Bazında Alım',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...breakdown.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.medication, size: 20),
                          const SizedBox(width: 8),
                          Text(entry.key),
                        ],
                      ),
                      Text(
                        '${entry.value} adet',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdoseBreakdown() {
    final overdose = _analysis!.overdoseByMedication;
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Overdose Dağılımı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...overdose.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(
                        '${entry.value} kez',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(int riskScore) {
    if (riskScore >= 70) return Colors.red[700]!;
    if (riskScore >= 40) return Colors.orange[700]!;
    if (riskScore >= 20) return Colors.yellow[700]!;
    return Colors.green[700]!;
  }
}
