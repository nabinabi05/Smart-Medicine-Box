import 'package:flutter/material.dart';
import '../models/sensor.dart';
import '../services/realtime_device_service.dart';

class CalibrationPage extends StatefulWidget {
  final Sensor sensor;
  final String deviceId;
  const CalibrationPage({
    super.key,
    required this.sensor,
    required this.deviceId,
  });

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  final _deviceService = RealtimeDeviceService();
  final _pillCountController = TextEditingController(text: '10');
  bool _loading = false;
  
  double? _emptyReading;
  double? _pillsReading;
  int _pillCount = 10;

  @override
  void dispose() {
    _pillCountController.dispose();
    super.dispose();
  }

  Future<void> _recordEmpty(double raw) async {
    setState(() {
      _emptyReading = raw;
      _pillsReading = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Boş ölçüm kaydedildi')),
    );
  }

  Future<void> _recordPills(double raw) async {
    if (_emptyReading == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Önce boş ölçümü yapın!'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Pill sayısını al
    final count = int.tryParse(_pillCountController.text);
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Geçerli bir ilaç sayısı girin!'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() {
      _pillsReading = raw;
      _pillCount = count;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $_pillCount ilaç ölçümü kaydedildi')),
    );
  }

  Future<void> _finalize() async {
    if (_emptyReading == null || _pillsReading == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Lütfen 2 adımı da tamamlayın!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _deviceService.setTareValue(
        deviceId: widget.deviceId,
        sensorId: widget.sensor.id,
        currentRaw: _emptyReading!,
      );
      
      await _deviceService.calibrateSensor(
        deviceId: widget.deviceId,
        sensorId: widget.sensor.id,
        currentRaw: _pillsReading!,
        tareValue: _emptyReading!,
        knownCount: _pillCount,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Kalibrasyon tamamlandı!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildStep({
    required int number,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback? onPressed,
    required bool isComplete,
    required double? value,
    required Color color,
  }) {
    return Card(
      elevation: isComplete ? 0 : 2,
      color: isComplete ? Colors.green.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isComplete ? Colors.green : color,
                  foregroundColor: Colors.white,
                  child: isComplete ? const Icon(Icons.check) : Text('$number'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            if (!isComplete) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withOpacity(0.1),
                  foregroundColor: color,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(buttonText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.sensor.name} Kalibrasyon')),
      body: StreamBuilder<List<Sensor>>(
        stream: _deviceService.watchDeviceSensors(widget.deviceId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final currentSensor = snapshot.data!.firstWhere(
            (s) => s.id == widget.sensor.id,
            orElse: () => widget.sensor,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStep(
                  number: 1,
                  title: 'BOŞ ÖLÇÜM',
                  description: 'Kutuyu tamamen boşaltın',
                  buttonText: 'BOŞ ÖLÇÜMÜ KAYDET',
                  onPressed: _emptyReading == null ? () => _recordEmpty(currentSensor.rawValue) : null,
                  isComplete: _emptyReading != null,
                  value: _emptyReading,
                  color: Colors.orange,
                ),

                const SizedBox(height: 16),

                Card(
                  elevation: _emptyReading == null ? 0 : 2,
                  color: _emptyReading == null ? Colors.grey.shade100 : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _pillsReading != null ? Colors.green : Colors.purple,
                              foregroundColor: Colors.white,
                              child: _pillsReading != null ? const Icon(Icons.check) : const Text('2'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'İLAÇ ÖLÇÜMÜ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Kutuya belirli sayıda ilaç koyun',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_pillsReading == null) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pillCountController,
                            enabled: _emptyReading != null,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'İlaç Sayısı',
                              hintText: 'Örn: 10',
                              prefixIcon: const Icon(Icons.medication),
                              border: const OutlineInputBorder(),
                              helperText: 'Kutuya koyacağınız ilaç sayısını girin',
                              enabled: _emptyReading != null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _emptyReading != null 
                                ? () => _recordPills(currentSensor.rawValue)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.withOpacity(0.1),
                              foregroundColor: Colors.purple,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            child: const Text('İLAÇ ÖLÇÜMÜNÜ KAYDET'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: _loading || _pillsReading == null ? null : _finalize,
                  icon: const Icon(Icons.check_circle),
                  label: _loading 
                      ? const Text('KAYDEDİLİYOR...') 
                      : const Text('KALİBRASYONU TAMAMLA'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
