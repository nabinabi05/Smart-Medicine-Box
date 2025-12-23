class Schedule {
  final String id;
  String medicationName;
  String dosage; // e.g., "1 Tablet"
  List<String> specificTimes; // e.g., ["08:00", "20:00"]
  int pillsPerDose; // Her doz için kaç ilaç (örn: sabah 2, öğle 1, akşam 2)
  bool isActive;
  String? linkedDeviceId;
  String? linkedSensorId;
  int? totalPillsInBox; // Kutudaki toplam ilaç adedi
  DateTime? startDate; // İlaç kullanımına başlama tarihi

  Schedule({
    this.id = '',
    required this.medicationName,
    required this.dosage,
    required this.specificTimes,
    this.pillsPerDose = 1, // Varsayılan: her doz için 1 ilaç
    this.isActive = true,
    this.linkedDeviceId,
    this.linkedSensorId,
    this.totalPillsInBox,
    this.startDate,
  });
  
  // Günlük kaç ilaç alınacak (zamanlama sayısı × her dozda kaç ilaç)
  int get dailyDosageCount => specificTimes.length * pillsPerDose;
  
  // Tahmini bitiş tarihi hesapla
  DateTime? get estimatedDepletionDate {
    if (totalPillsInBox == null || totalPillsInBox! <= 0) return null;
    if (dailyDosageCount == 0) return null;
    
    final daysRemaining = (totalPillsInBox! / dailyDosageCount).ceil();
    return DateTime.now().add(Duration(days: daysRemaining));
  }
  
  // Kalan gün sayısı
  int? get daysUntilDepletion {
    final depletionDate = estimatedDepletionDate;
    if (depletionDate == null) return null;
    
    return depletionDate.difference(DateTime.now()).inDays;
  }
  
  // Stok durumu (kritik/normal/bol)
  String get stockStatus {
    final days = daysUntilDepletion;
    if (days == null) return 'unknown';
    if (days <= 3) return 'critical'; // 3 gün veya daha az
    if (days <= 7) return 'low'; // 7 gün veya daha az
    return 'normal'; // 7 günden fazla
  }

  Schedule copyWith({
    String? id,
    String? medicationName,
    String? dosage,
    List<String>? specificTimes,
    int? pillsPerDose,
    bool? isActive,
    String? linkedDeviceId,
    String? linkedSensorId,
    int? totalPillsInBox,
    DateTime? startDate,
  }) {
    return Schedule(
      id: id ?? this.id,
      medicationName: medicationName ?? this.medicationName,
      dosage: dosage ?? this.dosage,
      specificTimes: specificTimes ?? List.of(this.specificTimes),
      pillsPerDose: pillsPerDose ?? this.pillsPerDose,
      isActive: isActive ?? this.isActive,
      linkedDeviceId: linkedDeviceId ?? this.linkedDeviceId,
      linkedSensorId: linkedSensorId ?? this.linkedSensorId,
      totalPillsInBox: totalPillsInBox ?? this.totalPillsInBox,
      startDate: startDate ?? this.startDate,
    );
  }

  factory Schedule.fromMap(Map<String, dynamic> data, String id) {
    return Schedule(
      id: id,
      medicationName: data['medicationName'] ?? 'Unknown',
      dosage: data['dosage'] ?? '',
      specificTimes:
          (data['specificTimes'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      pillsPerDose: data['pillsPerDose'] as int? ?? 1,
      isActive: data['isActive'] ?? true,
      linkedDeviceId: data['linkedDeviceId'] as String?,
      linkedSensorId: data['linkedSensorId'] as String?,
      totalPillsInBox: data['totalPillsInBox'] as int?,
      startDate: data['startDate'] != null 
          ? DateTime.parse(data['startDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'medicationName': medicationName,
    'dosage': dosage,
    'specificTimes': specificTimes,
    'pillsPerDose': pillsPerDose,
    'isActive': isActive,
    'linkedDeviceId': linkedDeviceId,
    'linkedSensorId': linkedSensorId,
    'totalPillsInBox': totalPillsInBox,
    'startDate': startDate?.toIso8601String(),
  };
}
