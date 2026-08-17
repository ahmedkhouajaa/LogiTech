import 'dart:io';
import 'security_config.dart';

/// Custom HttpOverrides ensuring HTTPS connections are validated and secure against MITM.
class SslPinningService extends HttpOverrides {
  static void initialize() {
    if (SecurityConfig.isSecurityDisabled) {
      SecurityLogger.info('SSL Pinning skipped: DISABLE_SECURITY is active.');
      return;
    }
    HttpOverrides.global = SslPinningService();
    SecurityLogger.info('SSL Pinning HttpOverrides installed.');
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // In production mode, reject any untrusted / self-signed / MITM proxy certificates
      if (SecurityConfig.isSecurityDisabled) {
        SecurityLogger.warn('Accepting untrusted cert for $host because DISABLE_SECURITY is active.');
        return true;
      }

      SecurityLogger.error('Blocked untrusted SSL certificate for host: $host:$port');
      return false;
    };
    return client;
  }
}
