import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/schedule.dart';
import '../models/device.dart';
import '../services/device_service.dart';

class ScheduleFormPage extends StatefulWidget {
  final Schedule? initial;
  const ScheduleFormPage({super.key, this.initial});

  @override
  State<ScheduleFormPage> createState() => _ScheduleFormPageState();
}

class _ScheduleFormPageState extends State<ScheduleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _deviceService = RealtimeDeviceService();
  final _auth = FirebaseAuth.instance;

  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  String? _selectedDevice;
  String? _selectedSensor;
  final List<String> _times = [];
  late DateTime _startDate;
  late bool _isActive;
  List<Device> _devices = [];

  bool get _isEdit => widget.initial != null;
  String? get _userId => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.medicationName ?? '');
    _dosageController = TextEditingController(text: widget.initial?.pillsPerDose.toString() ?? '1');
    _selectedDevice = widget.initial?.linkedDeviceId;
    _selectedSensor = widget.initial?.linkedSensorId;
    _times.addAll(widget.initial?.specificTimes ?? []);
    _startDate = widget.initial?.startDate ?? DateTime.now();
    _isActive = widget.initial?.isActive ?? true;

    if (_userId != null) {
      _loadDevices();
    }
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _deviceService.fetchUserDevices(_userId!);
      if (mounted) {
        setState(() => _devices = devices);
      }
    } catch (e) {
      debugPrint('Cihaz yükleme hatası: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => _times.add(formatted));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir saat ekleyin')));
      return;
    }

    final pillsPerDose = int.tryParse(_dosageController.text) ?? 1;

    final schedule = Schedule(
      medicationName: _nameController.text.trim(),
      dosage: '$pillsPerDose Adet',
      specificTimes: List.of(_times),
      linkedDeviceId: _selectedDevice,
      linkedSensorId: _selectedSensor,
      totalPillsInBox: widget.initial?.totalPillsInBox,
      pillsPerDose: pillsPerDose,
      startDate: _startDate,
      isActive: _isActive,
    );
    Navigator.of(context).pop(schedule);
  }

  void _delete() {
    Navigator.of(context).pop('delete');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Planı Düzenle' : 'Yeni Plan'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Sil',
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'İlaç Adı',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Her Dozda Kaç İlaç',
                    hintText: '1',
                    border: OutlineInputBorder(),
                    filled: true,
                    helperText: 'Her zamanlama için alınacak ilaç sayısı',
                    suffixIcon: const Icon(Icons.medication),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Gerekli';
                    final num = int.tryParse(v);
                    if (num == null || num < 1) return 'En az 1 olmalı';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedDevice,
                  decoration: const InputDecoration(
                    labelText: 'Cihaz Seç (Opsiyonel)',
                    border: OutlineInputBorder(),
                    filled: true,
                    helperText: 'İlaç kutusunun hangi bölmesinde olduğunu belirtin',
                  ),
                  items: _devices.map((device) {
                    return DropdownMenuItem(
                      value: device.id,
                      child: Text(device.deviceName),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _selectedDevice = v;
                    _selectedSensor = null;
                  }),
                ),
                const SizedBox(height: 12),
                if (_selectedDevice != null)
                  DropdownButtonFormField<String>(
                    value: _selectedSensor,
                    decoration: const InputDecoration(
                      labelText: 'Bölme Seç',
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    items: () {
                      final device = _devices.firstWhere(
                        (d) => d.id == _selectedDevice,
                        orElse: () => Device(
                          id: '',
                          deviceName: '',
                          status: 'OFFLINE',
                          lastSeen: DateTime.now(),
                          sensors: const [],
                        ),
                      );
                      return device.sensors.map((sensor) {
                        return DropdownMenuItem(
                          value: sensor.id,
                          child: Text('Bölme ${sensor.id.toUpperCase()} (${sensor.currentPillCount} adet)'),
                        );
                      }).toList();
                    }(),
                    onChanged: (v) => setState(() => _selectedSensor = v),
                  ),
                if (_selectedDevice != null) const SizedBox(height: 12),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Saatler', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addTime,
                      icon: const Icon(Icons.add),
                      label: const Text('Saat Ekle'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var t in _times)
                      Chip(
                        label: Text(t),
                        onDeleted: () => setState(() => _times.remove(t)),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
