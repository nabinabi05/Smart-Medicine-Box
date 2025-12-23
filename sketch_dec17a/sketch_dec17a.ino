/*
 * ESP8266 - 1sn PENCERE ORTALAMASI (V14.5 - Single Sensor)
 * - HX711 read() ile ham okur (Sadece Sensor 1)
 * - Her READ_INTERVAL_MS'de (100ms) bir okur
 * - 1 saniyede bir (SEND_INTERVAL_MS) pencere ortalamasını Firebase'e yazar
 * - EMA yok, sadece window average
 */

#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <HX711.h>
#include <time.h>

// --- AYARLAR ---
const char* WIFI_SSID     = "Galaxy A72D775";
const char* WIFI_PASSWORD = "iyyy4021";
const char* FIREBASE_HOST = "medtrack-4066e-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = "wMwItzBF9NMbWIDMM6TlwDvBhd4PxDFcYTjL6E9j";
const char* DEVICE_ID     = "device001";

// --- PINLER (Sadece Sensor 1) ---
#define S1_DT_PIN   D2
#define S1_SCK_PIN  D1

// --- ZAMANLAR ---
const unsigned long READ_INTERVAL_MS   = 100;    // 0.1 sn'de bir okuma (~10Hz)
const unsigned long SEND_INTERVAL_MS   = 1000;   // 1 sn'de bir gönder
const unsigned long STATUS_INTERVAL_MS = 30000;  // 30 sn status

// --- NESNELER ---
HX711 scale1;

FirebaseData firebaseData;
FirebaseConfig firebaseConfig;
FirebaseAuth firebaseAuth;

// --- PATH'LER ---
String pathStatus;
String pathSensor1Raw;

// --- ZAMAN TAKİBİ ---
unsigned long lastReadTime    = 0;
unsigned long windowStartTime = 0;
unsigned long lastStatusTime  = 0;

// --- PENCERE BİRİKTİRME ---
long long sum1 = 0;
unsigned long cnt1 = 0;

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== 1sn PENCERE ORTALAMASI (V14.5 - SINGLE) ===");

  scale1.begin(S1_DT_PIN, S1_SCK_PIN);

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print(".");
  }
  Serial.println("\n✓ WiFi Baglandi");

  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  while (time(nullptr) < 1000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" Saat OK");

  firebaseConfig.host = FIREBASE_HOST;
  firebaseConfig.signer.tokens.legacy_token = FIREBASE_AUTH;
  firebaseConfig.timeout.wifiReconnect = 5000;
  firebaseConfig.timeout.socketConnection = 5000;

  Firebase.begin(&firebaseConfig, &firebaseAuth);
  Firebase.reconnectWiFi(true);

  firebaseData.setBSSLBufferSize(512, 512);
  firebaseData.setResponseSize(512);

  const String base = String("devices/") + DEVICE_ID;
  pathStatus     = base + "/status";
  pathSensor1Raw = base + "/liveData/sensor1/raw";

  if (Firebase.ready()) Firebase.setString(firebaseData, pathStatus, "ONLINE");

  windowStartTime = millis();
}

void loop() {
  const unsigned long nowMs = millis();

  // 1) Belirli aralıkla oku ve pencereye ekle
  if (nowMs - lastReadTime >= READ_INTERVAL_MS) {
    lastReadTime = nowMs;

    if (scale1.is_ready()) {
      long v1 = scale1.read();   // ham okuma
      sum1 += (long long)v1;
      cnt1++;
    }
  }

  // 2) Süre dolunca pencere ortalamasını gönder
  if (nowMs - windowStartTime >= SEND_INTERVAL_MS) {
    windowStartTime = nowMs;

    long out1 = (cnt1 > 0) ? (long)(sum1 / (long long)cnt1) : 0;

    Serial.print("S1 window_avg="); Serial.print(out1);
    Serial.print(" (n="); Serial.print(cnt1); Serial.println(")");

    if (Firebase.ready()) {
      if (cnt1 > 0) Firebase.setInt(firebaseData, pathSensor1Raw, out1);
    }

    // pencereyi sıfırla
    sum1 = 0;
    cnt1 = 0;
  }

  // 3) Status (30 sn)
  if (nowMs - lastStatusTime >= STATUS_INTERVAL_MS) {
    lastStatusTime = nowMs;
    if (Firebase.ready()) Firebase.setString(firebaseData, pathStatus, "ONLINE");
  }
}