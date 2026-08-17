import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'security_config.dart';
import 'secure_storage_service.dart';
import 'license_model.dart';
import '../enterprise_service.dart';

/// Service responsible for Firebase license verification, subscription caching,
/// and offline grace-period enforcement.
class LicenseService {
  static final LicenseService instance = LicenseService._();
  LicenseService._();

  // Internal secret salt used to sign the cached license payload against tampering
  static const String _signatureSalt = 'LogiTech_Sec_License_Sign_2026_Salt_#992!';

  final _statusController = StreamController<LicenseStatus>.broadcast();
  Stream<LicenseStatus> get statusStream => _statusController.stream;

  LicenseInfo? _currentLicense;
  LicenseInfo? get currentLicense => _currentLicense;

  /// Verifies license status with Firebase or encrypted local storage.
  Future<LicenseVerificationResult> verifyLicense({
    String? enterpriseId,
    bool forceOnline = false,
  }) async {
    // 1. Bypass check if security is explicitly disabled or not on Windows Desktop
    if (!SecurityConfig.isSecurityEnforced) {
      SecurityLogger.info('Security check skipped: DISABLE_SECURITY is active or platform is not Windows Desktop.');
      final mockLicense = LicenseInfo(
        id: 'bypassed',
        enterpriseId: enterpriseId ?? 'default',
        plan: 'enterprise',
        isActive: true,
      );
      _currentLicense = mockLicense;
      _statusController.add(LicenseStatus.bypassed);
      return LicenseVerificationResult.success(license: mockLicense, bypass: true);
    }

    final targetId = enterpriseId ??
        EnterpriseService.instance.currentEnterpriseId ??
        FirebaseAuth.instance.currentUser?.uid;

    if (targetId == null || targetId.isEmpty) {
      SecurityLogger.warn('No active enterprise or user context found for license check.');
      return const LicenseVerificationResult(
        status: LicenseStatus.unlicensed,
        message: 'Aucune licence associée à ce compte.',
        isAllowed: false,
        isOnline: false,
      );
    }

    // 2. Check network connectivity
    final isOnline = await _isNetworkAvailable();
    final lastVerifiedStr = await SecureStorageService.instance.read(
      SecureStorageService.keyLastVerifiedTime,
    );
    final lastVerifiedTime = lastVerifiedStr != null
        ? DateTime.tryParse(lastVerifiedStr) ?? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);

    final hoursSinceLastCheck = DateTime.now().difference(lastVerifiedTime).inHours;

    // 3. Online Check (if online and (forced OR 24 hours elapsed OR no cache))
    if (isOnline && (forceOnline || hoursSinceLastCheck >= 24 || _currentLicense == null)) {
      try {
        final onlineResult = await _verifyWithFirestore(targetId);
        _currentLicense = onlineResult.license;
        _statusController.add(onlineResult.status);
        SecurityLogger.audit(
          action: 'Online License Verification',
          success: onlineResult.isAllowed,
          details: 'Status: ${onlineResult.status.name}, Plan: ${onlineResult.license?.plan}',
        );
        return onlineResult;
      } catch (e, st) {
        SecurityLogger.warn('Online license check failed with error: $e. Falling back to secure cache.');
        SecurityLogger.error('Online license check error details', e, st);
      }
    }

    // 4. Offline / Cached verification
    final cachedResult = await _verifyFromSecureCache(targetId);
    _currentLicense = cachedResult.license;
    _statusController.add(cachedResult.status);
    SecurityLogger.audit(
      action: 'Cached License Verification',
      success: cachedResult.isAllowed,
      details: 'Status: ${cachedResult.status.name}',
    );
    return cachedResult;
  }

  /// Verifies directly from Firestore `/licenses/{enterpriseId}`.
  Future<LicenseVerificationResult> _verifyWithFirestore(String enterpriseId) async {
    final docRef = FirebaseFirestore.instance.collection('licenses').doc(enterpriseId);
    final snapshot = await docRef.get();

    LicenseInfo license;
    if (!snapshot.exists || snapshot.data() == null) {
      // Auto-provision a default 30-day trial or active standard license for existing valid enterprises
      license = LicenseInfo(
        id: enterpriseId,
        enterpriseId: enterpriseId,
        plan: 'trial',
        isActive: true,
        subscriptionEnd: DateTime.now().add(const Duration(days: 30)),
        lastVerifiedAt: DateTime.now(),
        gracePeriodDays: 7,
      );

      try {
        await docRef.set(license.toMap(), SetOptions(merge: true));
        SecurityLogger.info('Auto-provisioned initial license for enterprise: $enterpriseId');
      } catch (e) {
        SecurityLogger.warn('Could not write initial license to Firestore: $e');
      }
    } else {
      license = LicenseInfo.fromMap(snapshot.data()!);
    }

    // Check if deactivated by admin
    if (!license.isActive) {
      return LicenseVerificationResult.failure(
        status: LicenseStatus.unlicensed,
        license: license,
        message: 'Cette licence a été désactivée par un administrateur.',
        isOnline: true,
      );
    }

    // Check if expired
    if (license.isExpired) {
      return LicenseVerificationResult.failure(
        status: LicenseStatus.expired,
        license: license,
        message: 'Votre abonnement LogiTech Pro a expiré le ${_formatDate(license.subscriptionEnd)}.',
        isOnline: true,
      );
    }

    // Save to DPAPI Secure Storage with HMAC signature
    await _saveToSecureCache(license);

    return LicenseVerificationResult.success(
      license: license,
      isOnline: true,
    );
  }

  /// Verifies the encrypted and signed license payload from local secure storage.
  Future<LicenseVerificationResult> _verifyFromSecureCache(String enterpriseId) async {
    final payloadJson = await SecureStorageService.instance.read(
      SecureStorageService.keyLicensePayload,
    );
    final storedSignature = await SecureStorageService.instance.read(
      SecureStorageService.keyLicenseSignature,
    );

    if (payloadJson == null || storedSignature == null) {
      return LicenseVerificationResult.failure(
        status: LicenseStatus.unlicensed,
        message: 'Aucune licence valide enregistrée sur cet appareil. Une connexion Internet est requise.',
        isOnline: false,
      );
    }

    // Verify HMAC-SHA256 signature to prevent manual tampering
    final expectedSignature = _generateSignature(payloadJson);
    if (storedSignature != expectedSignature) {
      SecurityLogger.error('Tampered license payload detected! Checksum mismatch.');
      return LicenseVerificationResult.failure(
        status: LicenseStatus.tampered,
        message: 'Erreur d\'intégrité de la licence. Veuillez vous reconnecter à Internet.',
        isOnline: false,
      );
    }

    final license = LicenseInfo.fromJson(payloadJson);

    // Check if license is active in cache
    if (!license.isActive) {
      return LicenseVerificationResult.failure(
        status: LicenseStatus.unlicensed,
        license: license,
        message: 'Licence désactivée.',
        isOnline: false,
      );
    }

    // Check expiration date
    if (license.isExpired) {
      return LicenseVerificationResult.failure(
        status: LicenseStatus.expired,
        license: license,
        message: 'Votre abonnement a expiré.',
        isOnline: false,
      );
    }

    // Check offline grace period
    final daysSinceLastOnlineCheck = DateTime.now().difference(license.lastVerifiedAt).inDays;
    if (daysSinceLastOnlineCheck > license.gracePeriodDays) {
      return LicenseVerificationResult.failure(
        status: LicenseStatus.gracePeriod,
        license: license,
        message: 'Période d\'utilisation hors-ligne expirée ($daysSinceLastOnlineCheck jours). Veuillez vous connecter à Internet pour renouveler l\'autorisation.',
        isOnline: false,
      );
    }

    return LicenseVerificationResult.success(
      license: license,
      isOnline: false,
    );
  }

  /// Saves the license into DPAPI Secure Storage with an HMAC-SHA256 signature.
  Future<void> _saveToSecureCache(LicenseInfo license) async {
    final nowIso = DateTime.now().toIso8601String();
    final updatedLicense = LicenseInfo(
      id: license.id,
      enterpriseId: license.enterpriseId,
      licenseKey: license.licenseKey,
      plan: license.plan,
      isActive: license.isActive,
      subscriptionEnd: license.subscriptionEnd,
      boundDeviceId: license.boundDeviceId,
      maxDevices: license.maxDevices,
      lastVerifiedAt: DateTime.now(),
      gracePeriodDays: license.gracePeriodDays,
      createdAt: license.createdAt,
      updatedAt: license.updatedAt,
    );

    final jsonStr = updatedLicense.toJson();
    final signature = _generateSignature(jsonStr);

    await SecureStorageService.instance.write(SecureStorageService.keyLicensePayload, jsonStr);
    await SecureStorageService.instance.write(SecureStorageService.keyLicenseSignature, signature);
    await SecureStorageService.instance.write(SecureStorageService.keyLastVerifiedTime, nowIso);
    SecurityLogger.info('License cache securely updated and signed with HMAC-SHA256.');
  }

  String _generateSignature(String payload) {
    final hmac = Hmac(sha256, utf8.encode(_signatureSalt));
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString();
  }

  Future<bool> _isNetworkAvailable() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      return connectivity.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
