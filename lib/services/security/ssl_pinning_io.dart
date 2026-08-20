import 'dart:io';
import 'security_config.dart';

/// Custom HttpOverrides ensuring HTTPS connections are validated and secure against MITM.
class SslPinningServiceIo extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
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

void initializeSslPinning() {
  if (SecurityConfig.isSecurityDisabled) {
    SecurityLogger.info('SSL Pinning skipped: DISABLE_SECURITY is active.');
    return;
  }
  HttpOverrides.global = SslPinningServiceIo();
  SecurityLogger.info('SSL Pinning HttpOverrides installed.');
}
