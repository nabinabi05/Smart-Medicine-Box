import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Başarılı giriş kaydı
      await _logAuthAttempt(
        userId: cred.user?.uid,
        email: email,
        action: 'LOGIN',
        success: true,
      );
      
      return cred.user;
    } catch (e) {
      // Başarısız giriş kaydı
      await _logAuthAttempt(
        userId: null,
        email: email,
        action: 'LOGIN',
        success: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Başarılı kayıt kaydı
      await _logAuthAttempt(
        userId: cred.user?.uid,
        email: email,
        action: 'REGISTER',
        success: true,
      );
      
      return cred.user;
    } catch (e) {
      // Başarısız kayıt kaydı
      await _logAuthAttempt(
        userId: null,
        email: email,
        action: 'REGISTER',
        success: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    final userId = _auth.currentUser?.uid;
    await _auth.signOut();
    
    if (userId != null) {
      await _logAuthAttempt(
        userId: userId,
        email: _auth.currentUser?.email,
        action: 'LOGOUT',
        success: true,
      );
    }
  }

  Future<void> _logAuthAttempt({
    String? userId,
    String? email,
    required String action,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      // Sadece console'a yazdır (Firebase'e yazma devre dışı)
      print('📝 Auth Log: $action - ${success ? "SUCCESS" : "FAILED"} - $email');
      if (errorMessage != null) {
        print('   Error: $errorMessage');
      }
      
      // Firebase'e yazma şimdilik kapalı (izin sorunu çözülünce açılabilir)
      /*
      final logRef = _db.child('authLogs').push();
      await logRef.set({
        'userId': userId,
        'email': email,
        'action': action,
        'success': success,
        'timestamp': ServerValue.timestamp,
        'errorMessage': errorMessage,
      });
      */
    } catch (e) {
      // Log kaydı başarısız olsa bile uygulamayı etkilemesin
      print('Auth log kayıt hatası: $e');
    }
  }
}
