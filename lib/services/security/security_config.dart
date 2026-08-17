import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// Global security configuration and logging utility.
class SecurityConfig {
  /// Compile-time flag to disable all security checks for testing:
  /// Run with: `flutter run -d windows --dart-define=DISABLE_SECURITY=true`
  static const bool isSecurityDisabled = bool.fromEnvironment(
    'DISABLE_SECURITY',
    defaultValue: false,
  );

  /// True if the current platform is Windows Desktop and security checks apply.
  static bool get isWindowsDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// Whether security checks should actively execute.
  static bool get isSecurityEnforced {
    if (isSecurityDisabled) return false;
    return isWindowsDesktop;
  }
}

/// Structured logger for all security events, checks, and warnings.
class SecurityLogger {
  static const String _tag = '[LogiTech-Security]';

  static void info(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('$_tag [INFO] $message');
    }
  }

  static void warn(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('$_tag [WARN] ⚠️ $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('$_tag [ERROR] 🛑 $message');
      if (error != null) {
        // ignore: avoid_print
        print('$_tag [ERROR DETAIL] $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print(stackTrace);
      }
    }
  }

  static void audit({
    required String action,
    required bool success,
    String? details,
  }) {
    final status = success ? 'SUCCESS' : 'VIOLATION/FAILURE';
    if (kDebugMode) {
      // ignore: avoid_print
      print('$_tag [AUDIT] $action -> $status ${details != null ? "($details)" : ""}');
    }
  }
}
