import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../services/adherence_service.dart';

class ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  const ScheduleCard({
    super.key,
    required this.schedule,
    this.onTap,
    this.onToggle,
  });

  Future<void> _manualLog(BuildContext context) async {
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // En yakın schedule time'ı bul
    String? closestTime;
    int minDifference = 999999;
    
    for (final timeStr in schedule.specificTimes) {
      final parts = timeStr.split(':');
      final scheduleHour = int.parse(parts[0]);
      final scheduleMinute = int.parse(parts[1]);
      
      final scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        scheduleHour,
        scheduleMinute,
      );
      
      final difference = now.difference(scheduledDateTime).inMinutes.abs();
      
      if (difference < minDifference) {
        minDifference = difference;
        closestTime = timeStr;
      }
    }
    
    if (closestTime == null) return;
    
    // Scheduled time'ı oluştur
    final parts = closestTime.split(':');
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    
    try {
      await AdherenceService().logMedicationTaken(
        scheduleId: schedule.id,
        medicationName: schedule.medicationName,
        scheduledTime: scheduledDateTime,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${schedule.medicationName} kaydedildi!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final times = schedule.specificTimes.join(', ');
    
    // Stok durumunu kontrol et
    final stockStatus = schedule.stockStatus;
    Color? borderColor;
    if (stockStatus == 'critical') {
      borderColor = Colors.red;
    } else if (stockStatus == 'low') {
      borderColor = Colors.orange;
    }
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: borderColor != null 
          ? BorderSide(color: borderColor, width: 2)
          : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.medicationName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${schedule.dosage} - $times',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (schedule.daysUntilDepletion != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📦 ${schedule.daysUntilDepletion} gün kaldı',
                            style: TextStyle(
                              fontSize: 12,
                              color: stockStatus == 'critical' 
                                ? Colors.red
                                : stockStatus == 'low'
                                  ? Colors.orange
                                  : Colors.grey[600],
                              fontWeight: stockStatus == 'critical' || stockStatus == 'low'
                                ? FontWeight.bold
                                : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch(value: schedule.isActive, onChanged: onToggle),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }
}
