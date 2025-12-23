// Firestore kaldırıldı, ileride Firebase Realtime Database ile entegre edilecek
class UserService {
  Stream<List<Map<String, dynamic>>> watchUsers() {
    // TODO: Firebase Realtime Database entegrasyonu
    return Stream.value([]);
  }

  Future<Map<String, dynamic>?> fetchUser(String userId) async {
    // TODO: Firebase Realtime Database entegrasyonu
    return null;
  }

  Future<void> updateUser(String userId, Map<String, dynamic> patch) async {
    // TODO: Firebase Realtime Database entegrasyonu
  }
}
