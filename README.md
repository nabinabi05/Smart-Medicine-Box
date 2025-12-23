# Smart Medicine Box (Akıllı İlaç Kutusu)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

IoT tabanlı akıllı ilaç kutusu uygulaması. Load cell sensörleri kullanarak ilaç stokunu gerçek zamanlı takip eder, kullanıcıya hatırlatmalar gönderir ve uyum istatistikleri sağlar.

## ✨ Özellikler

- 🔐 **Kullanıcı Yönetimi**: Firebase Authentication ile güvenli giriş/kayıt
- 📱 **Gerçek Zamanlı Takip**: Firebase Realtime Database ile canlı sensör verileri
- 🔔 **Akıllı Bildirimler**: FCM push bildirimleri ve yerel hatırlatmalar
- ⚖️ **Sensör Kalibrasyonu**: Hassas ağırlık ölçümü ve otomatik ilaç sayımı
- 📅 **İlaç Programları**: Zamanlanmış dozaj takibi ve hatırlatmalar
- 📊 **Uyum İstatistikleri**: İlaç alım oranları ve performans analizi
- 🔄 **Çoklu Platform**: Android, iOS, Web ve Windows desteği
- 🌐 **IoT Entegrasyonu**: ESP32/ESP8266 cihazlarıyla uyumlu

## 📋 Gereksinimler

- **Flutter**: 3.0.0 veya üzeri
- **Dart**: 3.0.0 veya üzeri
- **Android**: compileSdk 35, minSdk 23, desugar_jdk_libs 2.1.4
- **Firebase Proje**: Realtime Database, Authentication, Cloud Messaging
- **IoT Donanım** (opsiyonel): ESP32 + HX711 + Load Cell

## 🚀 Kurulum

### 1. Flutter Bağımlılıklarını Yükleyin

```bash
flutter pub get
```

### 2. Firebase Yapılandırması

#### FlutterFire CLI ile (Önerilen):

```bash
# FlutterFire CLI'yi yükleyin
dart pub global activate flutterfire_cli

# Firebase projesini yapılandırın
flutterfire configure
```

Bu komut otomatik olarak:
- `lib/firebase_options.dart` dosyasını oluşturur
- Platform-specific konfigürasyon dosyalarını ekler
- Firebase seçeneklerini ayarlar

#### Manuel Yapılandırma:

1. [Firebase Console](https://console.firebase.google.com/)'da yeni proje oluşturun
2. Authentication, Realtime Database ve Cloud Messaging'i etkinleştirin
3. Android/iOS/Web uygulamalarını ekleyin
4. İndirdiğiniz konfigürasyon dosyalarını projeye ekleyin:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `web/firebase-config.js` (varsa)

### 3. Uygulamayı Çalıştırın

```bash
# Firebase ile
flutter run

# Firebase olmadan test modu
flutter run --dart-define=ENABLE_FIREBASE=false
```

## 📱 Kullanım

### Temel Akış:

1. **Kayıt/Giriş**: Uygulamaya giriş yapın
2. **Cihaz Ekleme**: IoT cihazınızı sisteme kaydedin
3. **Kalibrasyon**: Her sensör bölmesi için boş ölçüm ve örnek ilaç ölçümü yapın
4. **İlaç Programı**: İlaçlarınızı zamanlayın ve cihaz bölmelerine bağlayın
5. **Takip**: Otomatik hatırlatmalar ve stok takibi başlayacak

### IoT Cihaz Kurulumu:

ESP32/ESP8266 cihazınız için:
- HX711 amplifikatör ile load cell bağlayın
- WiFi bağlantısı sağlayın
- Firebase Realtime Database'e veri gönderin

## 🏗️ Proje Yapısı

```
lib/
├── main.dart                          # Uygulama giriş noktası
├── firebase_options.dart              # Firebase konfigürasyonu
├── models/                            # Veri modelleri
│   ├── device.dart                    # Cihaz modeli
│   ├── sensor.dart                    # Sensör modeli (ağırlık hesaplamaları)
│   ├── schedule.dart                  # İlaç programı modeli
│   ├── history_log.dart               # Geçmiş log modeli
│   └── adherence.dart                 # Uyum istatistikleri modeli
├── pages/                             # UI sayfaları
│   ├── login_page.dart                # Giriş sayfası
│   ├── register_page.dart             # Kayıt sayfası
│   ├── main_navigation_page.dart      # Ana navigasyon
│   ├── dashboard_page.dart            # Kontrol paneli
│   ├── device_list_page.dart          # Cihaz listesi
│   ├── device_detail_page.dart        # Cihaz detayları
│   ├── calibration_page.dart          # Sensör kalibrasyonu
│   ├── schedule_list_page.dart        # Program listesi
│   ├── schedule_form_page.dart        # Program oluşturma/düzenleme
│   ├── history_page.dart              # Geçmiş kayıtlar
│   ├── statistics_page.dart           # İstatistikler
│   ├── performance_page.dart          # Performans analizi
│   ├── device_card.dart               # Cihaz kartı bileşeni
│   ├── schedule_card.dart             # Program kartı bileşeni
│   └── history_log_item.dart          # Geçmiş öğesi bileşeni
└── services/                          # İş mantığı servisleri
    ├── auth_service.dart              # Kimlik doğrulama
    ├── device_service.dart            # Cihaz yönetimi
    ├── realtime_device_service.dart   # Gerçek zamanlı sensör verileri
    ├── schedule_service.dart          # Program yönetimi
    ├── medication_tracker_service.dart # İlaç takip algoritması
    ├── schedule_checker_service.dart  # Zamanlama kontrolü
    ├── notification_service.dart      # Bildirim yönetimi
    ├── history_service.dart           # Geçmiş veri yönetimi
    ├── adherence_service.dart         # Uyum hesaplamaları
    └── firestore_paths.dart           # Veritabanı yolları
```

### Ana Bileşenler Açıklaması:

#### Models (Veri Modelleri):
- **Sensor**: Ham ağırlık değerlerinden ilaç sayısını hesaplar (histerezis ve gürültü filtresi ile)
- **Device**: Cihaz bilgilerini ve bağlı sensörleri yönetir
- **Schedule**: İlaç programlarını ve zamanlamalarını tanımlar
- **Adherence**: Kullanıcı uyumunu puanlar ve istatistikler sağlar

#### Services (Servisler):
- **RealtimeDeviceService**: Firebase RTDB ile canlı veri akışı
- **MedicationTrackerService**: Sensör değişikliklerini izleyip otomatik kayıt
- **ScheduleCheckerService**: Zamanlanmış hatırlatmalar
- **NotificationService**: FCM ve yerel bildirimler

#### Pages (UI Sayfaları):
- Auth sayfaları: Giriş/kayıt akışı
- Device sayfaları: Cihaz yönetimi ve kalibrasyon
- Schedule sayfaları: İlaç programları
- Analytics sayfaları: Geçmiş ve istatistikler

## 🗄️ Firebase Veri Modeli

### Realtime Database Şeması:

```
devices/{deviceId}/
├── deviceName: string
├── status: "ONLINE" | "OFFLINE"
├── lastSeen: timestamp
├── liveData/{sensorId}/
│   ├── raw: number              # Ham sensör değeri
│   ├── rawValue: number         # İşlenmiş değer
│   └── currentPillCount: number # Hesaplanan ilaç sayısı
└── config/{sensorId}/
    ├── tareValue: number        # Boş bölme değeri
    ├── oneItemWeight: number    # Birim ilaç ağırlığı
    └── name: string             # Bölme adı

users/{userId}/
├── fcmToken: string             # Push token
├── devices/{deviceId}/
│   ├── name: string
│   ├── status: string
│   ├── lastSeen: timestamp
│   └── addedAt: timestamp
└── schedules/{scheduleId}/
    ├── medicationName: string
    ├── dosage: string           # "2 tablet"
    ├── specificTimes: string[]  # ["08:00", "20:00"]
    ├── pillsPerDose: number     # Doz başına ilaç sayısı
    ├── isActive: boolean
    ├── linkedDeviceId: string
    ├── linkedSensorId: string
    ├── totalPillsInBox: number  # Başlangıç stoku
    └── startDate: timestamp     # Başlangıç tarihi

doseHistory/{historyId}/
├── userId: string
├── scheduleId: string
├── medicationName: string
├── scheduledTime: timestamp
├── status: "TAKEN" | "MISSED" | "SKIPPED"
├── actualTakenTime: timestamp
├── takenCount: number          # Alınan ilaç sayısı
├── isOverdose: boolean
├── adherenceScore: number      # 0-100 arası puan
└── notes: string

notificationTriggers/{userId}/{scheduleId}/{time}/
├── time: string                # "HH:MM"
├── medicationName: string
├── enabled: boolean
└── lastTriggered: timestamp
```

## 🔧 IoT Backend (ESP32/ESP8266)

### Donanım Gereksinimleri:
- ESP32 veya ESP8266 mikrodenetleyici
- HX711 ADC amplifikatörü
- Load Cell (ağırlık sensörü)
- WiFi bağlantısı

### Yazılım Akışı:

```cpp
// Basit ESP32 kodu örneği
#include <WiFi.h>
#include <FirebaseESP32.h>

// 1. Sensör değerini oku
float rawValue = readHX711();

// 2. Firebase'den konfigürasyon al
float tareValue = getFromFirebase("config/sensor1/tareValue");
float oneItemWeight = getFromFirebase("config/sensor1/oneItemWeight");

// 3. İlaç sayısını hesapla
int pillCount = (rawValue - tareValue) / oneItemWeight;

// 4. Firebase'e gönder
sendToFirebase("liveData/sensor1", {
  "raw": rawValue,
  "currentPillCount": pillCount
});
```

### Örnek ESP Kodu:
Proje içinde `send_test_notification.py` dosyasına benzer şekilde ESP kodu eklenmeli.

## 🧪 Test

### Otomatik Testler:
```bash
flutter test
```

### Manuel Test Senaryoları:
- [ ] Kullanıcı kayıt/giriş
- [ ] Cihaz ekleme ve sensör kalibrasyonu
- [ ] İlaç programı oluşturma ve düzenleme
- [ ] Gerçek zamanlı sensör veri akışı
- [ ] Bildirim tetikleme (saat ve sensör değişikliği)
- [ ] Geçmiş kayıtları ve istatistikler
- [ ] Çoklu cihaz desteği

### Firebase Test Verisi:
`firebase_initial_data.json` dosyasını kullanarak test verisi yükleyebilirsiniz.

## 📊 API Referansı

### Ana Servis Sınıfları:

#### AuthService
```dart
Future<User?> signIn(String email, String password)
Future<User?> signUp(String email, String password)
Future<void> signOut()
Stream<User?> authStateChanges()
```

#### RealtimeDeviceService
```dart
Stream<List<Device>> watchDevices()
Stream<List<Sensor>> watchDeviceSensors(String deviceId)
Future<void> setTareValue(String deviceId, String sensorId, double raw)
Future<void> calibrateSensor(String deviceId, String sensorId, double currentRaw, double tareValue, int knownCount)
```

#### MedicationTrackerService
```dart
void startTracking()
void stopTracking()
Future<void> checkAllDevices()
```

## 🤝 Katkıda Bulunma

1. Fork edin
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit edin (`git commit -m 'Add amazing feature'`)
4. Push edin (`git push origin feature/amazing-feature`)
5. Pull Request açın

### Geliştirme Standartları:
- Flutter analyze hatasız olmalı
- Test coverage %80+ olmalı
- Commit mesajları açıklayıcı olmalı
- Kod yorumları İngilizce

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.

## 🙏 Teşekkürler

- Flutter ekibi
- Firebase ekibi
- Açık kaynak topluluğu

---

**Son Güncelleme**: Aralık 2025
**Versiyon**: 1.0.0
