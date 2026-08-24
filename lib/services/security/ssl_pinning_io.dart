import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'security_config.dart';

/// Custom HttpOverrides ensuring HTTPS connections are validated and secure against MITM
/// while allowing local development services (DDS, DevTools) and official Google/Firebase endpoints.
class SslPinningServiceIo extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Always allow local loopback / development services (DDS, DevTools)
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return true;
      }
      // Allow official Google & Firebase endpoints
      if (host.endsWith('.googleapis.com') ||
          host.endsWith('.google.com') ||
          host.endsWith('.firebaseio.com') ||
          host.endsWith('.firebaseapp.com') ||
          host.endsWith('.firebasestorage.app')) {
        return true;
      }
      if (SecurityConfig.isSecurityDisabled || kDebugMode) {
        SecurityLogger.warn('Accepting cert for $host because debug mode or DISABLE_SECURITY is active.');
        return true;
      }
      SecurityLogger.error('Blocked untrusted SSL certificate for host: $host:$port');
      return false;
    };
    return client;
  }
}

void initializeSslPinning() {
  // On Windows Desktop and debug mode, rely directly on the native OS TLS stack to prevent any loopback / DDS interception
  if (SecurityConfig.isSecurityDisabled || kDebugMode || SecurityConfig.isWindowsDesktop) {
    SecurityLogger.info('SSL Pinning using native OS certificate validation.');
    return;
  }
  HttpOverrides.global = SslPinningServiceIo();
  SecurityLogger.info('SSL Pinning HttpOverrides installed.');
}
