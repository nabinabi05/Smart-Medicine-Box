import 'package:flutter/material.dart';
import '../models/history_log.dart';

class HistoryLogItem extends StatelessWidget {
  final HistoryLog log;
  const HistoryLogItem({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _visualForStatus(
      log.status,
      Theme.of(context),
    );
    final scheduled = _hhmm(log.scheduledTime);
    final taken =
        log.actualTakenTime != null ? _hhmm(log.actualTakenTime!) : null;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        log.medicationName,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Planlanan: $scheduled'),
          if (log.status == HistoryStatus.taken && taken != null)
            Text("$taken'te alındı"),
        ],
      ),
      trailing: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }

  (IconData, Color, String) _visualForStatus(HistoryStatus s, ThemeData theme) {
    switch (s) {
      case HistoryStatus.taken:
        return (Icons.check_circle, Colors.green, 'TAKEN');
      case HistoryStatus.missed:
        return (Icons.cancel, Colors.red, 'MISSED');
      case HistoryStatus.skipped:
        return (Icons.remove_circle_outline, Colors.grey, 'SKIPPED');
    }
  }

  String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
