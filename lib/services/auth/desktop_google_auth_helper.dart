import 'package:firebase_auth/firebase_auth.dart';
import 'desktop_google_auth_stub.dart'
    if (dart.library.io) 'desktop_google_auth_io.dart';

class DesktopGoogleAuthHelper {
  static Future<UserCredential> signIn() {
    return signInWithDesktopGoogleAuthImpl();
  }
}
