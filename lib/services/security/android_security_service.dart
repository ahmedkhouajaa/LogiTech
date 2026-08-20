import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'security_config.dart';

/// Service interfacing with native Android security features via MethodChannel.
class AndroidSecurityService {
  static final AndroidSecurityService instance = AndroidSecurityService._();
  AndroidSecurityService._();

  static const MethodChannel _channel = MethodChannel('com.logitech.security');

  /// Enables Android FLAG_SECURE to prevent screenshots, screen recording,
  /// and recent app switcher previews.
  Future<bool> enableScreenshotProtection() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    if (SecurityConfig.isSecurityDisabled) {
      SecurityLogger.info('Screenshot protection skipped: DISABLE_SECURITY is active.');
      return true;
    }

    try {
      final res = await _channel.invokeMethod<bool>('enableScreenshotProtection');
      SecurityLogger.info('Screenshot protection (FLAG_SECURE) enabled.');
      return res ?? true;
    } catch (e, st) {
      SecurityLogger.error('Failed to enable screenshot protection', e, st);
      return false;
    }
  }

  /// Disables Android FLAG_SECURE.
  Future<bool> disableScreenshotProtection() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;

    try {
      final res = await _channel.invokeMethod<bool>('disableScreenshotProtection');
      SecurityLogger.info('Screenshot protection (FLAG_SECURE) disabled.');
      return res ?? true;
    } catch (e, st) {
      SecurityLogger.error('Failed to disable screenshot protection', e, st);
      return false;
    }
  }

  /// Performs native Android security checks: Root, Emulator, Debugger, Frida/Xposed hooks.
  Future<Map<String, dynamic>> checkDeviceSecurity() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {'isSecure': true, 'platform': 'non-android'};
    }

    if (SecurityConfig.isSecurityDisabled) {
      SecurityLogger.info('Device security check bypassed via DISABLE_SECURITY flag.');
      return {
        'isRooted': false,
        'isEmulator': false,
        'isDebuggerConnected': false,
        'isFridaDetected': false,
        'isSecure': true,
        'bypassed': true,
      };
    }

    try {
      final rawReport = await _channel.invokeMapMethod<String, dynamic>('checkDeviceSecurity');
      final report = rawReport ?? {};

      final isRooted = report['isRooted'] == true;
      final isDebugger = report['isDebuggerConnected'] == true;
      final isFrida = report['isFridaDetected'] == true;
      final isEmulator = report['isEmulator'] == true;
      final isSecure = report['isSecure'] == true;

      SecurityLogger.audit(
        action: 'Android Device Security Check',
        success: isSecure,
        details: 'Root: $isRooted, Debugger: $isDebugger, Frida: $isFrida, Emulator: $isEmulator',
      );

      return report;
    } catch (e, st) {
      SecurityLogger.error('Failed to perform native Android security check', e, st);
      return {
        'isSecure': false,
        'error': e.toString(),
      };
    }
  }
}
