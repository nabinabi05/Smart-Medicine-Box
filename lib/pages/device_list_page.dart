import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device.dart';
import '../services/realtime_device_service.dart';
import 'device_card.dart';
import 'device_detail_page.dart';

class DeviceListPage extends StatefulWidget {
  const DeviceListPage({super.key});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  final _deviceService = RealtimeDeviceService();
  final _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  Future<void> _addDevice() async {
    if (_userId == null) return;

    final deviceIdController = TextEditingController();
    final deviceNameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Cihaz Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deviceIdController,
              decoration: const InputDecoration(
                labelText: 'Cihaz ID',
                hintText: 'demo_device_001',
                helperText: 'ESP8266\'da ayarlanan cihaz ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Cihaz Adı',
                hintText: 'İlaç Kutusu #1',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (result == true && deviceIdController.text.isNotEmpty) {
      try {
        await _deviceService.registerDevice(
          userId: _userId!,
          deviceId: deviceIdController.text.trim(),
          deviceName: deviceNameController.text.trim().isEmpty
              ? 'İlaç Kutusu'
              : deviceNameController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Cihaz kaydedildi!')),
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

    deviceIdController.dispose();
    deviceNameController.dispose();
  }

  Future<void> _deleteDevice(Device device) async {
    if (_userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cihazı Sil'),
        content: Text(
          '${device.deviceName} cihazını silmek istediğinize emin misiniz?\n\n'
          'Bu işlem geri alınamaz ve cihazın tüm ayarları silinecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deviceService.deleteDevice(
          userId: _userId!,
          deviceId: device.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Cihaz silindi')),
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

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Center(child: Text('Kullanıcı girişi gerekli'));
    }

    return Scaffold(
      body: StreamBuilder<List<Device>>(
        // Sadece kullanıcının kayıtlı cihazlarını göster
        stream: _deviceService.watchUserDevices(_userId!),
        builder: (context, snapshot) {
        // Yükleniyor
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Hata
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Hata: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          );
        }

        // Veri yok
        final devices = snapshot.data ?? [];
        if (devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.devices_other, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Henüz cihaz eklenmemiş',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'ESP8266 cihazınızı açın ve bekleyin',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Cihazları listele
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: devices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final device = devices[i];
            return DeviceCard(
              device: device,
              onTap: () => _openDeviceDetail(device),
              onLongPress: () => _deleteDevice(device),
            );
          },
        );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDevice,
        tooltip: 'Cihaz Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openDeviceDetail(Device device) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailPage(device: device),
      ),
    );
  }
}
