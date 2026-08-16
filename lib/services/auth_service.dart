import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'enterprise_service.dart';
import '../models/user_management_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:openid_client/openid_client_io.dart';
import '../secrets.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  String? _currentUserUid;
  bool _offlineMode = false;

  bool get isAuthenticated => _currentUserUid != null || _offlineMode;
  String? get currentUserUid => _currentUserUid;
  bool get isOfflineMode => _offlineMode;
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Stream<User?> get authStateChanges => FirebaseAuth.instance.authStateChanges();
  Stream<User?> get idTokenChanges => FirebaseAuth.instance.idTokenChanges();

  /// Initialize and verify session validity on app startup.
  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Validate session token on startup
      try {
        final token = await user.getIdToken(false);
        if (token != null && token.isNotEmpty) {
          _currentUserUid = user.uid;
        } else {
          _currentUserUid = null;
          await FirebaseAuth.instance.signOut();
        }
      } catch (e) {
        // If token refresh fails due to revocation / expiration, sign out
        if (e is FirebaseAuthException && (e.code == 'user-disabled' || e.code == 'user-token-expired')) {
          _currentUserUid = null;
          await FirebaseAuth.instance.signOut();
        } else {
          // Might be offline - allow local session
          _currentUserUid = user.uid;
        }
      }
    } else {
      _currentUserUid = null;
    }
  }

  /// Validates the current token before critical operations (Scenario 20).
  Future<bool> validateSession({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _currentUserUid = null;
      return false;
    }
    try {
      final token = await user.getIdToken(forceRefresh);
      return token != null && token.isNotEmpty;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-disabled' || e.code == 'user-token-expired' || e.code == 'invalid-user-token') {
        await logout();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    // Check connectivity first
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      throw 'Aucune connexion Internet. Veuillez vérifier votre connexion et réessayer.';
    }

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        _currentUserUid = userCredential.user!.uid;
        _offlineMode = false;

        // Verify account is active
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data['isActive'] == false) {
            await logout();
            throw FirebaseAuthException(
              code: 'user-disabled',
              message: 'Ce compte utilisateur a été désactivé.',
            );
          }
          final Map<String, dynamic> updates = {
            'lastLoginAt': FieldValue.serverTimestamp(),
          };
          // Auto-upgrade if permissions/role are missing and not an explicitly restricted collaborator
          if (data?['role'] == null || (data?['role'] == 'admin' && data?['permissions'] == null)) {
            final adminPerms = UserPermissionResources.getAdminDefaultPermissions()
                .map((k, v) => MapEntry(k, v.toMap()));
            updates['role'] = 'admin';
            updates['isOwner'] = true;
            updates['permissions'] = adminPerms;
          }
          await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).set(
            updates,
            SetOptions(merge: true),
          );
        } else if (userCredential.user != null) {
          await _createUserProfile(userCredential.user!);
        }

        // Trigger sync immediately after successful login
        unawaited(SyncService.instance.triggerSync());
        return true;
      }
      return false;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw 'Erreur inattendue: $e';
    }
  }

  Future<bool> signUpWithEmail(String email, String password, String name) async {
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      throw 'Aucune connexion Internet. Veuillez vérifier votre connexion et réessayer.';
    }

    UserCredential? userCredential;
    try {
      userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _currentUserUid = userCredential.user!.uid;
        _offlineMode = false;

        // Create user profile in Firestore (without auto-creating enterprise)
        try {
          await _createUserProfile(userCredential.user!, name: name);
        } catch (firestoreError) {
          // Rollback on Firestore failure
          try {
            await userCredential.user?.delete();
          } catch (_) {}
          await FirebaseAuth.instance.signOut();
          _currentUserUid = null;
          throw 'Échec de la création du profil utilisateur. L\'inscription a été annulée. Veuillez réessayer.';
        }

        unawaited(SyncService.instance.triggerSync());
        return true;
      }
      return false;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw 'Erreur inattendue: $e';
    }
  }

  Future<bool> signInWithGoogle() async {
    // 1. Connectivity Check (Scenario 4)
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      throw 'Aucune connexion Internet. Veuillez vérifier votre connexion et réessayer.';
    }

    try {
      UserCredential userCredential;

      if (!kIsWeb && Platform.isWindows) {
        // Desktop Flow using manual loopback via openid_client
        final clientId = Secrets.googleClientId;
        final clientSecret = Secrets.googleClientSecret;
        var issuer = await Issuer.discover(Issuer.google);
        var client = Client(issuer, clientId, clientSecret: clientSecret);

        Future<void> urlLauncher(String url) async {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
          } else {
            throw 'Impossible de lancer le navigateur web.';
          }
        }

        var authenticator = Authenticator(
          client,
          scopes: ['email', 'profile', 'openid'],
          port: 43210,
          urlLancher: urlLauncher,
        );

        Credential credentials;
        try {
          credentials = await authenticator.authorize();
        } catch (e) {
          // Scenario 5: User cancelled or closed browser
          throw 'Connexion Google annulée.';
        }

        var tokenResponse = await credentials.getTokenResponse();
        final idToken = tokenResponse.idToken.toCompactSerialization();
        final accessToken = tokenResponse.accessToken;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        // Android / Mobile Flow using google_sign_in
        debugPrint('[GoogleAuth] Step 1: Setting up GoogleSignIn');
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );

        try {
          await googleSignIn.disconnect();
        } catch (_) {}

        debugPrint('[GoogleAuth] Step 2: Calling googleSignIn.signIn()...');
        GoogleSignInAccount? googleUser;
        try {
          googleUser = await googleSignIn.signIn();
        } catch (e, stack) {
          debugPrint('[GoogleAuth] GoogleSignIn.signIn error: $e\n$stack');
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('sign_in_canceled') ||
              errStr.contains('canceled') ||
              errStr.contains('cancelled') ||
              errStr.contains('user_cancelled')) {
            throw 'Connexion Google annulée.';
          }
          throw 'Erreur Google Sign-In: $e';
        }

        if (googleUser == null) {
          // User dismissed the account picker without selecting
          throw 'Connexion Google annulée.';
        }

        debugPrint('[GoogleAuth] Step 3: Account selected: ${googleUser.email}');
        GoogleSignInAuthentication googleAuth;
        try {
          googleAuth = await googleUser.authentication;
        } catch (e) {
          debugPrint('[GoogleAuth] authentication error: $e');
          throw 'Échec de l\'authentification Google: $e';
        }

        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;
        debugPrint('[GoogleAuth] Step 4: idToken=${idToken != null ? "PRESENT" : "NULL"}, accessToken=${accessToken != null ? "PRESENT" : "NULL"}');

        if (idToken == null && accessToken == null) {
          throw 'Identifiants Google manquants. Vérifiez la configuration Firebase (SHA-1 enregistré ?).';
        }

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );
        debugPrint('[GoogleAuth] Step 5: Signing in to Firebase...');
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        debugPrint('[GoogleAuth] Step 6: Firebase OK! uid=${userCredential.user?.uid}');
      }

      // Scenario 14: Required permissions validation
      final authUser = userCredential.user;
      if (authUser == null || (authUser.email?.isEmpty ?? true)) {
        await FirebaseAuth.instance.signOut();
        throw 'Autorisations insuffisantes. Veuillez autoriser l\'accès à votre profil et votre adresse email.';
      }

      _currentUserUid = userCredential.user!.uid;
      _offlineMode = false;

      // Check if user profile already exists in Firestore (Scenario 1 & 2)
      debugPrint('[GoogleAuth] Step 7: Checking Firestore user profile for $_currentUserUid...');
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();

      if (!userDoc.exists) {
        debugPrint('[GoogleAuth] Step 8: Creating new user profile in Firestore...');
        try {
          await _createUserProfile(userCredential.user!);
        } catch (firestoreError) {
          debugPrint('[GoogleAuth] Firestore profile creation failed: $firestoreError');
          try {
            await userCredential.user?.delete();
          } catch (_) {}
          await FirebaseAuth.instance.signOut();
          _currentUserUid = null;
          throw 'Échec de l\'enregistrement du profil utilisateur : $firestoreError';
        }
      } else {
        debugPrint('[GoogleAuth] Step 8: Existing user profile found, updating lastLoginAt...');
        final data = userDoc.data();
        if (data != null && data['isActive'] == false) {
          await logout();
          throw FirebaseAuthException(
            code: 'user-disabled',
            message: 'Ce compte utilisateur a été désactivé.',
          );
        }

        final Map<String, dynamic> updates = {
          'lastLoginAt': FieldValue.serverTimestamp(),
        };
        if (data?['role'] == null || (data?['role'] == 'admin' && data?['permissions'] == null)) {
          final adminPerms = UserPermissionResources.getAdminDefaultPermissions()
              .map((k, v) => MapEntry(k, v.toMap()));
          updates['role'] = 'admin';
          updates['isOwner'] = true;
          updates['permissions'] = adminPerms;
        }

        await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).set(
          updates,
          SetOptions(merge: true),
        );
      }

      debugPrint('[GoogleAuth] Step 9: Sync triggered, sign in complete!');
      unawaited(SyncService.instance.triggerSync());
      return true;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[GoogleAuth] Unexpected error: $e');
      rethrow;
    }
  }

  /// Creates a clean user profile in Firestore without auto-creating a default enterprise.
  /// Self-registered users are assigned the admin role and full permissions for all resources.
  Future<void> _createUserProfile(User user, {String? name}) async {
    final uid = user.uid;
    final displayName = name ?? user.displayName ?? (user.email?.split('@').first ?? 'Utilisateur');
    final email = user.email ?? '';
    final adminPerms = UserPermissionResources.getAdminDefaultPermissions()
        .map((k, v) => MapEntry(k, v.toMap()));

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'name': displayName,
      'email': email,
      'role': 'admin',
      'isOwner': true,
      'permissions': adminPerms,
      'enterprises': [],
      'currentEnterpriseId': null,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> enableOfflineMode() async {
    _offlineMode = true;
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  }

  /// Sends a password reset email to the provided address.
  Future<void> sendPasswordResetEmail(String email) async {
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      throw 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.';
    }

    try {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email.trim(),
          actionCodeSettings: ActionCodeSettings(
            url: 'https://logitech-37369.web.app',
            handleCodeInApp: true,
            androidPackageName: 'com.logitech.pro',
            androidInstallApp: false,
          ),
        );
      } catch (_) {
        // Fallback to standard email if ActionCodeSettings encounters domain config requirements
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw 'Une erreur inattendue s\'est produite. Veuillez réessayer.';
    }
  }

  /// Confirms password reset with an out-of-band action code.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      throw 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.';
    }

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: code.trim(),
        newPassword: newPassword,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw 'Une erreur inattendue s\'est produite. Veuillez réessayer.';
    }
  }

  /// Verifies a password reset code and returns the associated email address.
  Future<String> verifyPasswordResetCode(String code) async {
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      throw 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.';
    }

    try {
      return await FirebaseAuth.instance.verifyPasswordResetCode(code.trim());
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw 'Le lien de réinitialisation est invalide ou a expiré.';
    }
  }

  /// Scenario 10: Clean logout for both Firebase and Google Sign In
  Future<void> logout() async {
    _offlineMode = false;
    _currentUserUid = null;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await EnterpriseService.instance.clearCache();
  }
}
