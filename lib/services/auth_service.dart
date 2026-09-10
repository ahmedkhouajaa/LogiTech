import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'enterprise_service.dart';
import '../models/user_management_model.dart';
import '../utils/platform_utils.dart';
import '../utils/firestore_safe_helper.dart';
import '../utils/anti_spam_guard.dart';
import 'auth/desktop_google_auth_helper.dart';

class AuthService with WidgetsBindingObserver {
  static final AuthService instance = AuthService._();
  AuthService._();

  bool _observerRegistered = false;

  /// Registers the WidgetsBindingObserver safely after Flutter binding initialization.
  void initLifecycleObserver() {
    if (_observerRegistered) return;
    try {
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
      debugPrint('[AuthService] WidgetsBindingObserver registered successfully.');
    } catch (e) {
      debugPrint('[AuthService] Could not register lifecycle observer yet: $e');
    }
  }

  static const _prefKeyDeactivated = 'isAccountDeactivated';
  static const _prefKeyDeactivatedReason = 'accountDeactivatedReason';

  String? _currentUserUid;
  bool _offlineMode = false;
  bool _isDeactivated = false;
  String? _deactivationReason;
  final _accountDeactivatedController = StreamController<String>.broadcast();
  StreamSubscription<DocumentSnapshot>? _userStatusSubscription;
  Timer? _presenceHeartbeatTimer;
  Timer? _presenceOfflineDebounceTimer;

  bool get isAuthenticated => !_isDeactivated && (_currentUserUid != null || _offlineMode);
  bool get isDeactivated => _isDeactivated;
  String? get deactivationReason => _deactivationReason;
  String? get currentUserUid => _currentUserUid;
  bool get isOfflineMode => _offlineMode;
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Stream<User?> get authStateChanges => FirebaseAuth.instance.authStateChanges();
  Stream<User?> get idTokenChanges => FirebaseAuth.instance.idTokenChanges();
  Stream<String> get onAccountDeactivated => _accountDeactivatedController.stream;

  /// Start real-time Firestore listener to detect if the account or enterprise is deactivated remotely.
  void _startUserStatusListener(String uid) {
    _userStatusSubscription?.cancel();
    startUserPresenceHeartbeat(uid);
    try {
      _userStatusSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists) {
          final data = snapshot.data();
          final isUserBanned = data?['isActive'] == false ||
              data?['isDisabled'] == true ||
              data?['isBanned'] == true ||
              data?['status'] == 'disabled' ||
              data?['status'] == 'banned' ||
              data?['status'] == 'blocked';

          if (isUserBanned) {
            debugPrint('[AuthService] User account $uid is deactivated in Firestore! Forcing lockout.');
            await triggerDeactivation(data?['banReason'] ?? "Votre compte a été désactivé par l'administrateur.");
            return;
          }

          // Check all user's enterprises
          final entIds = <String>{};
          final curEnt = data?['currentEnterpriseId'] ?? data?['enterpriseId'];
          if (curEnt != null && curEnt.toString().isNotEmpty) entIds.add(curEnt.toString());
          final entList = data?['enterprises'];
          if (entList is List) {
            for (final e in entList) {
              if (e != null && e.toString().isNotEmpty) entIds.add(e.toString());
            }
          }

          for (final eid in entIds) {
            try {
              final entDoc = await FirebaseFirestore.instance.collection('enterprises').doc(eid).get();
              if (entDoc.exists) {
                final entData = entDoc.data() ?? {};
                if (entData['isBanned'] == true || entData['status'] == 'banned' || entData['status'] == 'disabled') {
                  final entName = entData['name'] ?? 'Entreprise';
                  final reason = entData['banReason'] ?? 'Suspension administrative';
                  await triggerDeactivation('L\'accès de votre entreprise "$entName" a été suspendu par le SuperAdmin.\nMotif : $reason');
                  return;
                }
              }
            } catch (_) {}
          }
        }
      }, onError: (e) async {
        debugPrint('[AuthService] User status listener error: $e');
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.reload();
          }
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'user-disabled' || authErr.code == 'user-not-found') {
            await triggerDeactivation("Votre compte a été désactivé.");
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[AuthService] Error starting user status listener: $e');
    }
  }

  /// Triggers immediate full session lockout when account is disabled
  Future<void> triggerDeactivation([String reason = "Votre compte a été désactivé. Contactez l'administrateur."]) async {
    _isDeactivated = true;
    _deactivationReason = reason;
    stopUserPresenceHeartbeat();
    _userStatusSubscription?.cancel();
    _userStatusSubscription = null;
    _currentUserUid = null;
    _offlineMode = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyDeactivated, true);
      await prefs.setString(_prefKeyDeactivatedReason, reason);
    } catch (_) {}
    try {
      if (PlatformUtils.isAndroid) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await EnterpriseService.instance.clearCache();
    _accountDeactivatedController.add(reason);
  }

  /// Checks if the user or their associated enterprise has been banned or deactivated.
  /// Throws a descriptive FirebaseAuthException if banned and terminates the session.
  Future<void> _verifyUserAndEnterpriseActive(String uid) async {
    try {
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get().timeout(const Duration(seconds: 4));
      if (!userSnap.exists) return;

      final data = userSnap.data() ?? {};

      // 1. Direct User Level Ban / Deactivation
      final isUserBanned = data['isActive'] == false ||
          data['isDisabled'] == true ||
          data['isBanned'] == true ||
          data['status'] == 'disabled' ||
          data['status'] == 'banned' ||
          data['status'] == 'blocked';

      if (isUserBanned) {
        final reason = data['banReason'] ?? 'Ce compte utilisateur a été désactivé ou suspendu par le SuperAdmin.';
        await triggerDeactivation(reason);
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: reason,
        );
      }

      // 2. Enterprise Level Ban (Check all user's enterprises)
      final entIds = <String>{};
      final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
      if (curEnt != null && curEnt.toString().isNotEmpty) entIds.add(curEnt.toString());
      final entList = data['enterprises'];
      if (entList is List) {
        for (final e in entList) {
          if (e != null && e.toString().isNotEmpty) entIds.add(e.toString());
        }
      }

      for (final entId in entIds) {
        final entSnap = await FirebaseFirestore.instance.collection('enterprises').doc(entId).get().timeout(const Duration(seconds: 4));
        if (entSnap.exists) {
          final entData = entSnap.data() ?? {};
          final isEntBanned = entData['isBanned'] == true ||
              entData['status'] == 'banned' ||
              entData['status'] == 'disabled';

          if (isEntBanned) {
            final entName = entData['name'] ?? 'Entreprise';
            final reason = entData['banReason'] ?? 'Non-respect des conditions d\'utilisation / Suspension administrative';
            final fullMsg = 'L\'accès de votre entreprise "$entName" a été suspendu par le SuperAdmin.\nMotif : $reason';
            await triggerDeactivation(fullMsg);
            throw FirebaseAuthException(
              code: 'user-disabled',
              message: fullMsg,
            );
          }
        }
      }
    } on FirebaseAuthException {
      rethrow;
    } on FirebaseException catch (fe) {
      if (fe.code == 'permission-denied' || (fe.message != null && fe.message!.contains('permission-denied'))) {
        const msg = "Accès refusé. Ce compte ou votre entreprise a été suspendu par l'administrateur.";
        await triggerDeactivation(msg);
        throw FirebaseAuthException(code: 'user-disabled', message: msg);
      }
    } catch (_) {}
  }

  /// Initialize and verify session validity on app startup.
  Future<void> initialize() async {
    try {
      // 1. Check local persistent lockout flag first
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKeyDeactivated) == true) {
        final reason = prefs.getString(_prefKeyDeactivatedReason) ?? "Votre compte a été désactivé par l'administrateur.";
        _isDeactivated = true;
        _deactivationReason = reason;
        _currentUserUid = null;
        _offlineMode = false;
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        await EnterpriseService.instance.clearCache();
        _accountDeactivatedController.add(reason);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Validate session token on startup
        try {
          await user.reload().timeout(const Duration(seconds: 3));
          final token = await user.getIdToken(false).timeout(const Duration(seconds: 3));
          if (token != null && token.isNotEmpty) {
            _currentUserUid = user.uid;

            // Strict user & enterprise check on startup
            await _verifyUserAndEnterpriseActive(user.uid);

            if (!_isDeactivated) {
              _startUserStatusListener(user.uid);
              startUserPresenceHeartbeat(user.uid);
            }
          } else {
            _currentUserUid = null;
            await FirebaseAuth.instance.signOut();
          }
        } catch (e) {
          if (e is FirebaseAuthException && e.code == 'user-disabled') {
            await triggerDeactivation(e.message ?? "Votre compte a été désactivé.");
          } else if (e is FirebaseAuthException &&
              (e.code == 'user-token-expired' || e.code == 'user-not-found')) {
            await triggerDeactivation("Votre session a expiré.");
          } else {
            if (!_isDeactivated) {
              _currentUserUid = user.uid;
            }
          }
        }
      } else {
        _currentUserUid = null;
      }
    } catch (_) {
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
    // 1. Anti-Brute Force / Rate Limit Check
    final spamCheck = AntiSpamGuard.instance.checkLoginAllowed(email: email);
    if (!spamCheck.isAllowed) {
      throw spamCheck.message;
    }

    // Check connectivity first
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline) {
      throw 'Aucune connexion Internet. Veuillez vérifier votre connexion et réessayer.';
    }

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 8));
      if (userCredential.user != null) {
        // Record successful login (clears lockout and reset counter)
        AntiSpamGuard.instance.recordLoginResult(email: email, success: true);

        _currentUserUid = userCredential.user!.uid;
        _offlineMode = false;

        // Synchronously verify user and enterprise active status before allowing access
        await _verifyUserAndEnterpriseActive(_currentUserUid!);

        // Update profile / lastLoginAt
        try {
          final data = await FirestoreSafeHelper.getDocData(
            FirebaseFirestore.instance.collection('users'),
            _currentUserUid!,
          ).timeout(const Duration(seconds: 3));
          if (data != null) {
            final Map<String, dynamic> updates = {
              'isOnline': true,
              'lastLoginAt': FieldValue.serverTimestamp(),
              'lastHeartbeat': FieldValue.serverTimestamp(),
            };
            if (data['role'] == null || (data['role'] == 'admin' && data['permissions'] == null)) {
              final adminPerms = UserPermissionResources.getAdminDefaultPermissions()
                  .map((k, v) => MapEntry(k, v.toMap()));
              updates['role'] = 'admin';
              updates['isOwner'] = true;
              updates['permissions'] = adminPerms;
            }
            await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).set(
              updates,
              SetOptions(merge: true),
            ).timeout(const Duration(seconds: 3));
          } else if (userCredential.user != null) {
            await _createUserProfile(userCredential.user!);
          }
        } catch (_) {}

        _startUserStatusListener(_currentUserUid!);

        // Trigger sync immediately after successful login
        unawaited(SyncService.instance.triggerSync());
        return true;
      }
      AntiSpamGuard.instance.recordLoginResult(email: email, success: false);
      return false;
    } on FirebaseAuthException {
      AntiSpamGuard.instance.recordLoginResult(email: email, success: false);
      rethrow;
    } catch (e) {
      AntiSpamGuard.instance.recordLoginResult(email: email, success: false);
      throw 'Erreur inattendue: $e';
    }
  }

  Future<bool> signUpWithEmail(String email, String password, String name) async {
    // 1. Anti-Spam / Rate Limit Check
    final spamCheck = AntiSpamGuard.instance.checkSignUpAllowed();
    if (!spamCheck.isAllowed) {
      throw spamCheck.message;
    }

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
        AntiSpamGuard.instance.recordSignUpResult(success: true);

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

        // Explicitly sign out so user is redirected to the login interface
        await FirebaseAuth.instance.signOut();
        _currentUserUid = null;
        _offlineMode = false;
        return true;
      }
      AntiSpamGuard.instance.recordSignUpResult(success: false);
      return false;
    } on FirebaseAuthException {
      AntiSpamGuard.instance.recordSignUpResult(success: false);
      rethrow;
    } catch (e) {
      AntiSpamGuard.instance.recordSignUpResult(success: false);
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

      if (kIsWeb) {
        // Web Flow using Firebase Auth Popup
        debugPrint('[GoogleAuth] Step 1: Web signInWithPopup starting...');
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        debugPrint('[GoogleAuth] Step 2: Web signInWithPopup success: uid=${userCredential.user?.uid}');
      } else if (PlatformUtils.isWindows) {
        // Desktop Flow using manual loopback via DesktopGoogleAuthHelper
        userCredential = await DesktopGoogleAuthHelper.signIn();
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
      final userData = await FirestoreSafeHelper.getDocData(
        FirebaseFirestore.instance.collection('users'),
        _currentUserUid!,
      );

      if (userData == null) {
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
        if (userData['isActive'] == false) {
          await logout();
          throw FirebaseAuthException(
            code: 'user-disabled',
            message: 'Ce compte utilisateur a été désactivé.',
          );
        }

        final Map<String, dynamic> updates = {
          'lastLoginAt': FieldValue.serverTimestamp(),
        };
        if (userData['role'] == null || (userData['role'] == 'admin' && userData['permissions'] == null)) {
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

      _startUserStatusListener(_currentUserUid!);
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
    stopUserPresenceHeartbeat();
    _userStatusSubscription?.cancel();
    _userStatusSubscription = null;
    _isDeactivated = false;
    _deactivationReason = null;
    _offlineMode = false;
    _currentUserUid = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyDeactivated);
      await prefs.remove(_prefKeyDeactivatedReason);
    } catch (_) {}
    try {
      if (PlatformUtils.isAndroid) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await EnterpriseService.instance.clearCache();
  }

  /// Starts a 25-second heartbeat for the logged-in user to maintain real-time online status.
  /// Also cancels any pending offline debounce (user is back online).
  void startUserPresenceHeartbeat(String uid) {
    if (uid.isEmpty) return;
    // Cancel any pending offline grace timer — user is active again
    _presenceOfflineDebounceTimer?.cancel();
    _presenceOfflineDebounceTimer = null;

    _presenceHeartbeatTimer?.cancel();
    // Immediately mark online
    _updateUserPresence(uid, true);

    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _updateUserPresence(uid, true);
    });
  }

  /// Stops user presence heartbeat and schedules an offline mark after a
  /// 35-second grace period. If the user resumes before the timer fires,
  /// the offline mark is cancelled — preventing false offline flips.
  void stopUserPresenceHeartbeat([String? uid]) {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;

    final targetUid = uid ?? _currentUserUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) return;

    // Cancel any existing debounce before starting a new one
    _presenceOfflineDebounceTimer?.cancel();
    // Wait 35 seconds before marking offline — if user comes back, this is cancelled
    _presenceOfflineDebounceTimer = Timer(const Duration(seconds: 35), () {
      _updateUserPresence(targetUid, false);
      _presenceOfflineDebounceTimer = null;
    });
  }

  Future<void> _updateUserPresence(String uid, bool isOnline) async {
    if (uid.isEmpty) return;
    try {
      final Map<String, dynamic> updates = {
        'isOnline': isOnline,
        'lastHeartbeat': FieldValue.serverTimestamp(),
      };
      if (isOnline) {
        updates['lastLoginAt'] = FieldValue.serverTimestamp();
      } else {
        updates['lastConnectedAt'] = FieldValue.serverTimestamp();
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        updates,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[AuthService] Error updating user presence: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final uid = _currentUserUid ?? FirebaseAuth.instance.currentUser?.uid;
    debugPrint('[AuthService] AppLifecycleState changed to: $state for user: $uid');
    if (uid == null || uid.isEmpty) return;

    if (state == AppLifecycleState.resumed) {
      // User returned to the app — immediately mark online and restart heartbeat
      debugPrint('[AuthService] App resumed -> cancelling offline timer, marking ONLINE for $uid');
      startUserPresenceHeartbeat(uid);
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.detached ||
               state == AppLifecycleState.hidden) {
      // Only schedule offline on true background/close — NOT on 'inactive'
      // 'inactive' fires briefly during app-switching and should NOT mark offline
      debugPrint('[AuthService] App backgrounded ($state) -> scheduling offline in 35s for $uid');
      stopUserPresenceHeartbeat(uid);
    }
    // AppLifecycleState.inactive is intentionally ignored:
    // it fires transiently during multitasking, notification pulls, etc.
  }
}



