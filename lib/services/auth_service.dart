import 'dart:async';
import 'dart:io' show Platform, File, FileMode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'sync_service.dart';
import 'enterprise_service.dart';
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
        throw 'Aucun utilisateur trouve pour cet email.';
      } else if (e.code == 'wrong-password') {
        throw 'Mot de passe incorrect.';
      } else {
        throw 'Erreur de connexion: ${e.message}';
      }
    } catch (e) {
      throw 'Erreur inattendue: $e';
    }
  }

  Future<bool> signUpWithEmail(String email, String password, String name) async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        _currentUserUid = userCredential.user!.uid;
        _offlineMode = false;
        await _createUserProfileAndEnterprise(userCredential.user!, name: name);
        unawaited(SyncService.instance.triggerSync());
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw 'Le mot de passe est trop faible.';
      } else if (e.code == 'email-already-in-use') {
        throw 'Un compte existe déjà pour cet email.';
      } else if (e.code == 'invalid-email') {
        throw 'L\'adresse email est invalide.';
      } else {
        throw 'Erreur d\'inscription: ${e.message}';
      }
    } catch (e) {
      throw 'Erreur inattendue: $e';
    }
  }

  Future<bool> signInWithGoogle() async {
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
            scopes: ['email', 'profile'],
            port: 43210,
            urlLancher: urlLauncher
        );
        
        var credentials = await authenticator.authorize();
        var tokenResponse = await credentials.getTokenResponse();
        
        final idToken = tokenResponse.idToken.toCompactSerialization();
        final accessToken = tokenResponse.accessToken;
        
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        // Android / Native Flow using google_sign_in v7 API
        try {
          await GoogleSignIn.instance.initialize();
        } catch (_) {
          // Ignore if already initialized
        }
        
        final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
        if (googleUser == null) {
          // User canceled the sign-in flow
          throw 'Connexion Google annulée.';
        }
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final GoogleSignInClientAuthorization? authz = await googleUser.authorizationClient.authorizationForScopes([]);
        
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authz?.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      if (userCredential.user != null) {
        _currentUserUid = userCredential.user!.uid;
        _offlineMode = false;

        // Check if user is new, if so create profile and enterprise
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserUid).get();
        if (!userDoc.exists) {
          await _createUserProfileAndEnterprise(userCredential.user!);
        }

        unawaited(SyncService.instance.triggerSync());
        return true;
      }
      return false;
    } catch (e, stack) {
      File('d:/LogiTech/google_auth_error.txt').writeAsStringSync('Error: $e\nStack: $stack\n', mode: FileMode.append);
      throw 'Erreur lors de la connexion Google: $e';
    }
  }

  Future<void> _createUserProfileAndEnterprise(User user, {String? name}) async {
    final uid = user.uid;
    final displayName = name ?? user.displayName ?? 'Utilisateur';
    final email = user.email ?? '';

    // Create the default enterprise first
    final enterprise = await EnterpriseService.instance.createEnterprise('Mon Entreprise');

    // The enterprise service automatically creates the user doc, but we should make sure 
    // the name and email are explicitly set correctly, so we merge the update.
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'name': displayName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> enableOfflineMode() async {
    _offlineMode = true;
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> logout() async {
    _offlineMode = false;
    _currentUserUid = null;
    await FirebaseAuth.instance.signOut();
  }
}
