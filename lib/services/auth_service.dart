import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'sync_service.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  String? _currentUserUid;
  bool _offlineMode = false;

  bool get isAuthenticated => _currentUserUid != null || _offlineMode;
  String? get currentUserUid => _currentUserUid;
  bool get isOfflineMode => _offlineMode;

  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    _currentUserUid = user?.uid;
  }

  Future<bool> login(String email, String password) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        _currentUserUid = userCredential.user!.uid;
        _offlineMode = false;
        // Trigger sync immediately after successful login
        unawaited(SyncService.instance.triggerSync());
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'Aucun utilisateur trouvé pour cet email.';
      } else if (e.code == 'wrong-password') {
        throw 'Mot de passe incorrect.';
      } else {
        throw 'Erreur de connexion: ${e.message}';
      }
    } catch (e) {
      throw 'Erreur inattendue: $e';
    }
  }

  Future<void> enableOfflineMode() async {
    _offlineMode = true;
    _currentUserUid = 'local-user';
  }

  Future<void> logout() async {
    _offlineMode = false;
    _currentUserUid = null;
    await FirebaseAuth.instance.signOut();
  }
}
