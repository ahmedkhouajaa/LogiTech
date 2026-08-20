import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:openid_client/openid_client_io.dart';
import '../../secrets.dart';

Future<UserCredential> signInWithDesktopGoogleAuthImpl() async {
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
    throw 'Connexion Google annulée.';
  }

  var tokenResponse = await credentials.getTokenResponse();
  final idToken = tokenResponse.idToken.toCompactSerialization();
  final accessToken = tokenResponse.accessToken;

  final AuthCredential credential = GoogleAuthProvider.credential(
    accessToken: accessToken,
    idToken: idToken,
  );
  return await FirebaseAuth.instance.signInWithCredential(credential);
}
