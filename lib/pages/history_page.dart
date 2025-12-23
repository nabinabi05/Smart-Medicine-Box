import 'package:flutter/material.dart';
import '../models/adherence.dart';
import '../services/history_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _historyService = HistoryService();
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final initial = _range ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      initialDateRange: initial,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _clearAllLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Geçmişi Sil'),
        content: const Text(
          'Tüm ilaç alım kayıtları silinecek. Bu işlem geri alınamaz!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _historyService.clearAllLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tüm kayıtlar silindi')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _range == null
        ? 'Tüm Kayıtlar'
        : '${_range!.start.day}.${_range!.start.month}.${_range!.start.year} - ${_range!.end.day}.${_range!.end.month}.${_range!.end.year}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(rangeLabel),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Tüm Geçmişi Sil',
                onPressed: _clearAllLogs,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MedicationLog>>(
            stream: _historyService.watchMedicationLogs(
              start: _range?.start,
              end: _range?.end,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Hata: ${snapshot.error}'));
              }

              final logs = snapshot.data ?? [];

              if (logs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Henüz kayıt yok',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _buildLogItem(logs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(MedicationLog log) {
    final isOnTime = log.adherenceScore >= 75;
    final isMissed = log.adherenceScore == 0;
    
    IconData icon;
    Color color;
    String statusText;

    if (isMissed) {
      icon = Icons.cancel;
      color = Colors.red;
      statusText = 'Kaçırıldı';
    } else if (log.isOverdose) {
      icon = Icons.warning;
      color = Colors.orange;
      statusText = 'Overdose (${log.takenCount} adet)';
    } else if (isOnTime) {
      icon = Icons.check_circle;
      color = Colors.green;
      statusText = 'Zamanında';
    } else {
      icon = Icons.access_time;
      color = Colors.orange;
      statusText = 'Geç (${log.delayMinutes} dk)';
    }

    return ListTile(
      leading: Icon(icon, color: color, size: 32),
      title: Text(
        log.medicationName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planlanan: ${_formatTime(log.scheduledTime)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Alınan: ${_formatTime(log.takenAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (log.takenCount > 1)
            Text(
              'Miktar: ${log.takenCount} adet',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            'Skor: ${log.adherenceScore}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
