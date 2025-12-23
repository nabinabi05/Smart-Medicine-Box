import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background Message: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Local Notifications
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    // 0. Local Notifications Initialize
    await _initializeLocalNotifications();

    // 1. İzin iste
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('⚠️ Bildirim izni verilmedi');
      return;
    }

    print('✅ Bildirim izni alındı');

    // 2. FCM Token al ve kaydet
    _fcmToken = await _fcm.getToken();
    if (_fcmToken != null) {
      print('📱 FCM Token: $_fcmToken');
      await _saveFcmToken(_fcmToken!);
    }

    // Token yenilendiğinde güncelle
    _fcm.onTokenRefresh.listen(_saveFcmToken);

    // 3. Message Handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Uygulama kapalıyken gelen bildirimleri kontrol et
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // FCM Token'ı Firebase'e kaydet
  Future<void> _saveFcmToken(String token) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _db.ref('users/$userId/fcmToken').set(token);
      print('✅ FCM Token kaydedildi');
    } catch (e) {
      print('❌ Token kaydetme hatası: $e');
    }
  }

  // Foreground'da gelen mesajları göster
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 Foreground Message: ${message.notification?.title}');
    // FCM otomatik olarak bildirimi gösterir
  }

  // Bildirim açılarak uygulamaya dönüldü
  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Bildirim açıldı: ${message.data}');
    // TODO: İlgili programa yönlendir
  }

  // Local Notifications Initialize
  Future<void> _initializeLocalNotifications() async {
    // Timezone'ları yükle
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('🔔 Local bildirim tıklandı: ${details.payload}');
      },
    );
    
    print('✅ Local notifications initialized');
  }

  // Local bildirim göster (hemen)
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      print('🔔 Bildirim oluşturuluyor - ID: $id, Title: $title');
      
      const androidDetails = AndroidNotificationDetails(
        'medication_reminders',
        'İlaç Hatırlatıcıları',
        channelDescription: 'İlaç alma zamanı hatırlatmaları',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        ticker: 'İlaç Zamanı',
        showWhen: true,
        when: null,
        usesChronometer: false,
        channelShowBadge: true,
        onlyAlertOnce: false, // Her seferinde ses çıkar
        autoCancel: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(id, title, body, details, payload: payload);
      print('✅ Bildirim başarıyla gösterildi: $title (ID: $id)');
    } catch (e) {
      print('❌ Bildirim gösterme hatası: $e');
      rethrow;
    }
  }

  // Test bildirimi - FCM üzerinden gönderilmeli
  Future<void> showTestNotification() async {
    await showLocalNotification(
      id: 999,
      title: '💊 Test Bildirimi',
      body: 'Local notification sistemi çalışıyor!',
    );
  }
}
