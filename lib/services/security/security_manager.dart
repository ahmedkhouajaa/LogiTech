import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'security_config.dart';
import 'secure_storage_service.dart';
import 'license_service.dart';
import 'license_model.dart';
import 'android_security_service.dart';
import 'ssl_pinning_service.dart';

/// Central facade for the LogiTech Pro Security Engine across platforms.
class SecurityManager {
  static final SecurityManager instance = SecurityManager._();
  SecurityManager._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  LicenseVerificationResult? _lastResult;
  LicenseVerificationResult? get lastResult => _lastResult;

  Map<String, dynamic> _deviceSecurityReport = {};
  Map<String, dynamic> get deviceSecurityReport => Map.unmodifiable(_deviceSecurityReport);

  /// Initializes security layers, SSL pinning, and platform-specific checks.
  Future<LicenseVerificationResult> initialize() async {
    if (_initialized && _lastResult != null) return _lastResult!;

    SecurityLogger.info('Initializing Security Engine (DISABLE_SECURITY=${SecurityConfig.isSecurityDisabled})...');

    // 1. Install SSL Pinning protection for network requests
    SslPinningService.initialize();

    // 2. Android Security Protections
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Enable Screenshot and Screen Recording Prevention (FLAG_SECURE)
      await AndroidSecurityService.instance.enableScreenshotProtection();

      // Check Root, Emulator, Debugger, and Frida/Xposed
      _deviceSecurityReport = await AndroidSecurityService.instance.checkDeviceSecurity();
    }

    // 3. Check if security is explicitly bypassed via flag
    if (SecurityConfig.isSecurityDisabled) {
      SecurityLogger.info('Security enforcement bypassed via DISABLE_SECURITY flag.');
      _initialized = true;
      _lastResult = LicenseVerificationResult.success(
        license: LicenseInfo(
          id: 'dev_bypass',
          enterpriseId: 'default',
          plan: 'enterprise',
          isActive: true,
        ),
        bypass: true,
      );
      return _lastResult!;
    }

    // 4. Desktop Windows License & Tamper Check
    if (SecurityConfig.isWindowsDesktop) {
      try {
        await SecureStorageService.instance.read(SecureStorageService.keyLicensePayload);
        final result = await LicenseService.instance.verifyLicense();
        _lastResult = result;
        _initialized = true;

        SecurityLogger.audit(
          action: 'Security Engine Startup Check',
          success: result.isAllowed,
          details: 'Status: ${result.status.name}, Message: ${result.message}',
        );

        return result;
      } catch (e, st) {
        SecurityLogger.error('Security Manager initialization failed on Windows', e, st);
        final failure = LicenseVerificationResult.failure(
          status: LicenseStatus.tampered,
          message: 'Erreur lors de l\'initialisation de sécurité: $e',
          isOnline: false,
        );
        _lastResult = failure;
        _initialized = true;
        return failure;
      }
    }

    // Default success for web and mobile platforms
    _initialized = true;
    _lastResult = LicenseVerificationResult.success(
      license: LicenseInfo(
        id: kIsWeb ? 'web_active' : 'mobile_active',
        enterpriseId: 'default',
        plan: kIsWeb ? 'web' : 'mobile',
        isActive: true,
      ),
      bypass: false,
    );
    return _lastResult!;
  }
}
