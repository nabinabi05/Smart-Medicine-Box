// İlaç alım kaydı
class MedicationLog {
  final String id;
  final String scheduleId;
  final String medicationName;
  final DateTime takenAt; // Gerçekten alındığı zaman
  final DateTime scheduledTime; // Alınması gereken zaman
  final bool wasOnTime;
  final int adherenceScore; // 0-100 arası puan
  final int takenCount; // Kaç adet alındı
  final bool isOverdose; // Fazla alım var mı
  
  MedicationLog({
    this.id = '',
    required this.scheduleId,
    required this.medicationName,
    required this.takenAt,
    required this.scheduledTime,
    required this.wasOnTime,
    required this.adherenceScore,
    this.takenCount = 1,
    this.isOverdose = false,
  });
  
  // Gecikme süresi (dakika)
  int get delayMinutes {
    final diff = takenAt.difference(scheduledTime).inMinutes.abs();
    return diff;
  }
  
  // Skor hesaplama
  static int calculateScore(DateTime scheduled, DateTime taken) {
    final diffMinutes = taken.difference(scheduled).inMinutes.abs();
    
    if (diffMinutes < 15) return 100; // Mükemmel: ±15 dakika
    if (diffMinutes < 30) return 90;  // Çok iyi: ±30 dakika
    if (diffMinutes < 60) return 75;  // İyi: ±1 saat
    if (diffMinutes < 120) return 50; // Gecikmiş: ±2 saat
    return 25; // Çok gecikmiş
  }
  
  factory MedicationLog.fromMap(Map<String, dynamic> data, String id) {
    return MedicationLog(
      id: id,
      scheduleId: data['scheduleId'] ?? '',
      medicationName: data['medicationName'] ?? '',
      takenAt: DateTime.parse(data['takenAt'] as String),
      scheduledTime: DateTime.parse(data['scheduledTime'] as String),
      wasOnTime: data['wasOnTime'] ?? false,
      adherenceScore: data['adherenceScore'] ?? 0,
      takenCount: data['takenCount'] ?? 1,
      isOverdose: data['isOverdose'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() => {
    'scheduleId': scheduleId,
    'medicationName': medicationName,
    'takenAt': takenAt.toIso8601String(),
    'scheduledTime': scheduledTime.toIso8601String(),
    'wasOnTime': wasOnTime,
    'adherenceScore': adherenceScore,
    'takenCount': takenCount,
    'isOverdose': isOverdose,
  };
}

// Uyum istatistikleri
class AdherenceStats {
  final int totalDoses; // Toplam alınması gereken ilaç sayısı
  final int takenDoses; // Alınan ilaç sayısı
  final int missedDoses; // Kaçırılan ilaç sayısı
  final double adherenceRate; // Uyum oranı (%)
  final double averageScore; // Ortalama skor
  final int perfectDoses; // Mükemmel zamanında alınan (±15 dk)
  final int lateDoses; // Geç alınan
  
  AdherenceStats({
    required this.totalDoses,
    required this.takenDoses,
    required this.missedDoses,
    required this.adherenceRate,
    required this.averageScore,
    required this.perfectDoses,
    required this.lateDoses,
  });
  
  // Performans seviyesi
  String get performanceLevel {
    if (adherenceRate >= 95) return 'Mükemmel'; // 🏆
    if (adherenceRate >= 85) return 'Çok İyi'; // ⭐
    if (adherenceRate >= 70) return 'İyi'; // 👍
    if (adherenceRate >= 50) return 'Orta'; // 😐
    return 'Dikkat'; // ⚠️
  }
  
  String get emoji {
    if (adherenceRate >= 95) return '🏆';
    if (adherenceRate >= 85) return '⭐';
    if (adherenceRate >= 70) return '👍';
    if (adherenceRate >= 50) return '😐';
    return '⚠️';
  }
}

// Detaylı performans analizi
class PerformanceAnalysis {
  final AdherenceStats stats;
  final int overdoseCount; // Overdose sayısı
  final int missedStreak; // Kaçırma serisi (ardışık kaç kez kaçırıldı)
  final int perfectStreak; // Mükemmel seri (ardışık kaç kez zamanında alındı)
  final Map<String, int> medicationBreakdown; // İlaç bazında alım sayısı
  final Map<String, int> overdoseByMedication; // İlaç bazında overdose
  final List<String> warnings; // Uyarı mesajları
  final List<String> achievements; // Başarılar
  
  PerformanceAnalysis({
    required this.stats,
    required this.overdoseCount,
    required this.missedStreak,
    required this.perfectStreak,
    required this.medicationBreakdown,
    required this.overdoseByMedication,
    required this.warnings,
    required this.achievements,
  });
  
  // Risk seviyesi (0-100)
  int get riskScore {
    int risk = 0;
    
    // Overdose riski
    if (overdoseCount > 0) risk += overdoseCount * 15;
    
    // Kaçırma riski
    if (stats.missedDoses > 5) risk += 20;
    if (missedStreak > 3) risk += 15;
    
    // Düşük adherence
    if (stats.adherenceRate < 50) risk += 30;
    else if (stats.adherenceRate < 70) risk += 15;
    
    // Geç alma sıklığı
    if (stats.lateDoses > stats.takenDoses * 0.3) risk += 10;
    
    return risk > 100 ? 100 : risk;
  }
  
  String get riskLevel {
    if (riskScore >= 70) return 'Yüksek Risk';
    if (riskScore >= 40) return 'Orta Risk';
    if (riskScore >= 20) return 'Düşük Risk';
    return 'Risk Yok';
  }
  
  String get riskEmoji {
    if (riskScore >= 70) return '🚨';
    if (riskScore >= 40) return '⚠️';
    if (riskScore >= 20) return '⚡';
    return '✅';
  }
}
