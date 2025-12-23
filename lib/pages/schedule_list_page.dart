import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import 'schedule_card.dart';
import 'schedule_form_page.dart';

class ScheduleListPage extends StatefulWidget {
  const ScheduleListPage({super.key});

  @override
  State<ScheduleListPage> createState() => _ScheduleListPageState();
}

class _ScheduleListPageState extends State<ScheduleListPage> {
  final _scheduleService = ScheduleService();
  final _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  Future<void> _add() async {
    if (_userId == null) return;

    final result = await Navigator.of(context).push<Schedule>(
      MaterialPageRoute(builder: (_) => const ScheduleFormPage()),
    );
    
    if (result != null) {
      try {
        await _scheduleService.createSchedule(_userId!, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Plan oluşturuldu!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Hata: $e')),
          );
        }
      }
    }
  }

  Future<void> _edit(Schedule schedule) async {
    if (_userId == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScheduleFormPage(initial: schedule)),
    );
    
    if (result == null) {
      // Geri/iptal: hicbir islem yapma
      return;
    }

    if (result is String && result == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Plan Sil'),
          content: Text('${schedule.medicationName} planini silmek istediginize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Iptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _scheduleService.deleteSchedule(_userId!, schedule.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan silindi')),
          );
        }
      }
      return;
    }

    if (result is Schedule) {
      await _scheduleService.updateSchedule(_userId!, result.copyWith(id: schedule.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan guncellendi')),
        );
      }
    }
  }

  Future<void> _toggleActive(Schedule schedule) async {
    if (_userId == null) return;

    final updated = schedule.copyWith(isActive: !schedule.isActive);
    await _scheduleService.updateSchedule(_userId!, updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: Text('Kullanıcı girişi gerekli')),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<Schedule>>(
        stream: _scheduleService.watchUserSchedules(_userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final schedules = snapshot.data ?? [];

          if (schedules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz plan eklenmemiş',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sağ alttaki + butonuna basarak\nilk planınızı ekleyin',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: schedules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = schedules[index];
              return ScheduleCard(
                schedule: s,
                onTap: () => _edit(s),
                onToggle: (v) => _toggleActive(s),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_schedule',
        onPressed: _add,
        tooltip: 'Yeni Plan Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }

}
