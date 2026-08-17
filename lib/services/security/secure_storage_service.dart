import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'security_config.dart';

/// Secure key-value storage backed by Windows DPAPI / Windows Credential Manager.
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._();
  SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  // ── Keys ────────────────────────────────────────────────────────
  static const String keyLicensePayload = 'sec_license_payload_v1';
  static const String keyLicenseSignature = 'sec_license_signature_v1';
  static const String keyLastVerifiedTime = 'sec_last_verified_time_v1';
  static const String keyLastTrustedTime = 'sec_last_trusted_time_v1';
  static const String keyDeviceFingerprint = 'sec_device_fingerprint_v1';
  static const String keyIntegrityHash = 'sec_integrity_hash_v1';
  static const String keyAuthToken = 'sec_auth_token_v1';

  /// Writes an encrypted value to secure storage.
  Future<bool> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      SecurityLogger.info('Secure write success for key: $key');
      return true;
    } catch (e, st) {
      SecurityLogger.error('Failed to write to secure storage: $key', e, st);
      return false;
    }
  }

  /// Reads a decrypted value from secure storage.
  Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value;
    } catch (e, st) {
      SecurityLogger.error('Failed to read from secure storage: $key', e, st);
      return null;
    }
  }

  /// Deletes a specific key from secure storage.
  Future<bool> delete(String key) async {
    try {
      await _storage.delete(key: key);
      SecurityLogger.info('Secure delete success for key: $key');
      return true;
    } catch (e, st) {
      SecurityLogger.error('Failed to delete key: $key', e, st);
      return false;
    }
  }

  /// Clears all stored secure credentials and cached license data.
  Future<bool> clearAll() async {
    try {
      await _storage.deleteAll();
      SecurityLogger.info('Secure storage cleared completely.');
      return true;
    } catch (e, st) {
      SecurityLogger.error('Failed to clear secure storage', e, st);
      return false;
    }
  }
}
