# Smart Medicine Box (Flutter + Firebase IoT)

Akilli ilac kutusu demosu: agirlik sensori ile stok takibi, planlara gore hatirlatma, kalibrasyon ve performans ekranlari.

## Gereksinimler
- Flutter 3.x, Dart 3.x
- Android: compileSdk 35, minSdk 23, desugar_jdk_libs 2.1.4
- Firebase projesi (Realtime Database, Auth, Cloud Messaging)
- Google Play hizmetleri olan emulator/cihaz (FCM icin)

## Kurulum
```bash
flutter pub get
flutterfire configure   # Firebase ayari (lib/firebase_options.dart olusur)
flutter run             # Firebase ile
# Firebase devre disi test: flutter run --dart-define=ENABLE_FIREBASE=false
```

## Ozellikler
- Firebase Auth ile giris/kayit
- Cihaz ve sensörleri RTDB uzerinden izleme, pill count gosterimi
- Sensör kalibrasyonu (tare + oneItemWeight yazma)
- Ilac planlari: olusturma/düzenleme/silme, cihaz/bölme baglama, aktif/pasif
- Bildirimler: FCM token kaydi, plan tetikleyicisi, local bildirim
- Gecmis ve uyum istatistik ekranlari

## Ana dosyalar
- `lib/main.dart`: Firebase init, auth routing, bildirim/tracker servis baslatma
- Modeller: `lib/models/` (`device.dart`, `sensor.dart`, `schedule.dart`, `history_log.dart`, `adherence.dart`)
- Servisler:
  - `auth_service.dart` (Auth)
  - `realtime_device_service.dart` (RTDB cihaz/sensör stream, kalibrasyon)
  - `device_service.dart` (polling cihazlar)
  - `schedule_service.dart` (plan CRUD)
  - `schedule_checker_service.dart`, `medication_tracker_service.dart` (plan/sensör takibi, bildirim)
  - `notification_service.dart` (FCM init/token kaydi, local notification)
  - `history_service.dart`, `adherence_service.dart`
  - `firestore_paths.dart` (yol yardimcilari)
- Sayfalar:
  - Auth: `login_page`, `register_page`, `main_navigation_page`
  - Dashboard: `dashboard_page`
  - Cihazlar: `device_list_page`, `device_detail_page`, `device_card`
  - Kalibrasyon: `calibration_page`
  - Planlar: `schedule_list_page`, `schedule_form_page`, `schedule_card`
  - Gecmis/istatistik: `history_page`, `history_log_item`, `statistics_page`, `performance_page`
- Test/örn: `firebase_initial_data.json`; istege bagli `send_test_notification.py` (harici FCM testi)

## RTDB semasi (ozet)
```
devices/{deviceId}
  deviceName, status, lastSeen
  liveData/{sensorId}: raw/rawValue/currentPillCount/...
  config/{sensorId}: tareValue, oneItemWeight, name (ops)
users/{userId}
  devices/{deviceId}: name/status/lastSeen/addedAt
  schedules/{scheduleId}: medicationName, specificTimes[], isActive,
    linkedDeviceId, linkedSensorId, pillsPerDose, startDate
doseHistory/{historyId}: userId, scheduleId, medicationName,
  scheduledTime, status, actualTakenTime, notes
notificationTriggers/{userId}/{scheduleId}/{HH_mm}: time, medicationName, enabled
```

## IoT akis (ESP8266/ESP32 + HX711 + load cell)
1) Ham sensor degerini oku (`raw`).
2) RTDB `config/{sensorId}` altindan `tareValue` ve `oneItemWeight` cek.
3) `(raw - tareValue) / oneItemWeight` ile pil sayisini hesapla.
4) `devices/{deviceId}/liveData/{sensorId}` altina periyodik yaz.
5) Durum/lastSeen icin `devices/{deviceId}/status` ve `devices/{deviceId}/lastSeen` alanlarini guncelleyin (uygulama bu alanlari okur).

## Online/Offline mantigi
- Sensör verisi 5 dk icinde geldiyse ONLINE.
- Son görülme 10 dk’dan eskiyse OFFLINE.
- Aradaki durumda cihaz `status` alanina bakilir.

## Test ipuclari
- `flutter analyze`, `flutter test`
- Cihaz/sensör stream + plan olustur/guncelle/sil + bildirim tetiklerini emulator/cihazda dogrula.
- RTDB’de `devices/{deviceId}/status/lastSeen` ve `users/{uid}/fcmToken` alanlarini kontrol et.
- Kalibrasyon sonrası sayim guncelleniyor mu bak.
