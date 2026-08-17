import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'secure_storage_service.dart';
import 'security_config.dart';

/// Service managing biometric authentication (Fingerprint, Face Unlock) on Android.
class BiometricAuthService {
  static final BiometricAuthService instance = BiometricAuthService._();
  BiometricAuthService._();

  static const MethodChannel _channel = MethodChannel('com.logitech.security');
  static const String _keyBiometricEnabled = 'sec_biometric_enabled_v1';

  /// Checks if hardware and device support biometrics and have enrolled credentials.
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final available = await _channel.invokeMethod<bool>('isBiometricAvailable');
      return available ?? false;
    } catch (e, st) {
      SecurityLogger.error('Failed to check biometric availability', e, st);
      return false;
    }
  }

  /// Prompts the native Android BiometricPrompt for authentication.
  Future<bool> authenticate({
    String title = 'Authentification LogiTech Pro',
    String subtitle = 'Veuillez vous authentifier',
    String cancelText = 'Annuler',
    String? reason,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    if (SecurityConfig.isSecurityDisabled) {
      SecurityLogger.info('Biometric auth bypassed via DISABLE_SECURITY flag.');
      return true;
    }

    try {
      final available = await isBiometricAvailable();
      if (!available) {
        SecurityLogger.warn('Biometric hardware not available or enrolled.');
        return false;
      }

      final effectiveSubtitle = reason ?? subtitle;

      final authenticated = await _channel.invokeMethod<bool>(
        'authenticateBiometrics',
        {
          'title': title,
          'subtitle': effectiveSubtitle,
          'cancelText': cancelText,
        },
      );

      final isSuccess = authenticated ?? false;
      SecurityLogger.audit(
        action: 'Biometric Authentication',
        success: isSuccess,
      );

      return isSuccess;
    } on PlatformException catch (e) {
      SecurityLogger.error('Biometric platform error: ${e.code}', e);
      return false;
    } catch (e, st) {
      SecurityLogger.error('Biometric authentication failed', e, st);
      return false;
    }
  }

  /// Checks if user has opted in to biometric login.
  Future<bool> isBiometricEnabled() async {
    final val = await SecureStorageService.instance.read(_keyBiometricEnabled);
    return val == 'true';
  }

  /// Enables or disables biometric login preference in secure storage.
  Future<void> setBiometricEnabled(bool enabled) async {
    await SecureStorageService.instance.write(
      _keyBiometricEnabled,
      enabled ? 'true' : 'false',
    );
  }
}
