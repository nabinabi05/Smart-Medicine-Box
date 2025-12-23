import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/main_navigation_page.dart';
import 'services/notification_service.dart';
import 'services/schedule_checker_service.dart';
import 'services/medication_tracker_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlat
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase başarıyla başlatıldı!');
    
    // FCM'i başlat (kullanıcı giriş yaptıktan sonra token kaydedilecek)
    await NotificationService().initialize();
    print('✅ Bildirim servisi başlatıldı!');
    
    // Kullanıcı auth durumunu dinle ve servisleri başlat/durdur
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // Kullanıcı giriş yaptı - servisleri başlat
        ScheduleCheckerService().start();
        MedicationTrackerService().startTracking();
      } else {
        // Kullanıcı çıkış yaptı - servisleri durdur
        ScheduleCheckerService().stop();
        MedicationTrackerService().stopTracking();
      }
    });
  } catch (e, st) {
    print('❌ Firebase başlatma hatası: $e');
    print(st);
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akıllı İlaç Kutusu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Bağlantı kontrol ediliyor
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // Kullanıcı giriş yapmış mı?
          if (snapshot.hasData) {
            return const MainNavigationPage();
          }
          
          // Giriş yapmamış
          return const LoginPage();
        },
      ),
    );
  }
}
