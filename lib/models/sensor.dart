class Sensor {
  final String id;
  final String name;
  final double rawValue;
  final double tareValue;
  final double oneItemWeight;
  final int? overridePillCount; // ESP8266'nın hesapladığı değer

  Sensor({
    required this.id,
    required this.name,
    required this.rawValue,
    required this.tareValue,
    required this.oneItemWeight,
    this.overridePillCount,
  });

  int get currentPillCount {
    // ESP'nin hesapladığı değer varsa onu kullan
    if (overridePillCount != null) return overridePillCount!;
    if (oneItemWeight <= 0.001) return 0;
    
    double netWeight = rawValue - tareValue;
    
    // Gürültü filtresi: Net ağırlık birim ağırlığın %40'ından azsa (yarım pilden az) 0 kabul et
    if (netWeight.abs() < oneItemWeight * 0.4) {
      return 0;
    }
    
    double exactCount = netWeight / oneItemWeight;
    
    // Hysteresis (histerezis) mantığı:
    // 0.3 ve 0.7 arasında "belirsiz bölge" oluşturarak titreşimi engelle
    
    int lowerBound = exactCount.floor();
    int upperBound = exactCount.ceil();
    
    // Tam sayıya ne kadar yakın?
    double distanceToLower = exactCount - lowerBound;
    double distanceToUpper = upperBound - exactCount;
    
    int result;
    if (distanceToLower < 0.35) {
      result = lowerBound; // Alt tarafa yakın
    } else if (distanceToUpper < 0.35) {
      result = upperBound; // Üst tarafa yakın
    } else {
      // Belirsiz bölge: En yakına yuvarla
      result = exactCount.round();
    }
    
    return result < 0 ? 0 : result;
  }
}
