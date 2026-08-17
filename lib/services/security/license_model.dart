import 'dart:convert';

/// Status of the software license.
enum LicenseStatus {
  active,
  trial,
  gracePeriod,
  expired,
  deviceMismatch,
  unlicensed,
  tampered,
  bypassed,
}

/// Software license metadata and subscription state.
class LicenseInfo {
  final String id;
  final String enterpriseId;
  final String? licenseKey;
  final String plan;
  final bool isActive;
  final DateTime? subscriptionEnd;
  final String? boundDeviceId;
  final int maxDevices;
  final DateTime lastVerifiedAt;
  final int gracePeriodDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  LicenseInfo({
    required this.id,
    required this.enterpriseId,
    this.licenseKey,
    this.plan = 'pro',
    this.isActive = true,
    this.subscriptionEnd,
    this.boundDeviceId,
    this.maxDevices = 1,
    DateTime? lastVerifiedAt,
    this.gracePeriodDays = 7,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : lastVerifiedAt = lastVerifiedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isExpired {
    if (subscriptionEnd == null) return false;
    return DateTime.now().isAfter(subscriptionEnd!);
  }

  bool get isValid => isActive && !isExpired;

  int get daysRemaining {
    if (subscriptionEnd == null) return 9999;
    final diff = subscriptionEnd!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'enterprise_id': enterpriseId,
        'license_key': licenseKey,
        'plan': plan,
        'is_active': isActive,
        'subscription_end': subscriptionEnd?.toIso8601String(),
        'bound_device_id': boundDeviceId,
        'max_devices': maxDevices,
        'last_verified_at': lastVerifiedAt.toIso8601String(),
        'grace_period_days': gracePeriodDays,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory LicenseInfo.fromMap(Map<String, dynamic> map) {
    return LicenseInfo(
      id: map['id']?.toString() ?? '',
      enterpriseId: map['enterprise_id']?.toString() ?? map['enterpriseId']?.toString() ?? '',
      licenseKey: map['license_key']?.toString() ?? map['licenseKey']?.toString(),
      plan: map['plan']?.toString() ?? 'pro',
      isActive: map['is_active'] == true || map['isActive'] == true,
      subscriptionEnd: map['subscription_end'] != null || map['subscriptionEnd'] != null
          ? DateTime.tryParse((map['subscription_end'] ?? map['subscriptionEnd']).toString())
          : null,
      boundDeviceId: map['bound_device_id']?.toString() ?? map['boundDeviceId']?.toString(),
      maxDevices: int.tryParse(map['max_devices']?.toString() ?? map['maxDevices']?.toString() ?? '1') ?? 1,
      lastVerifiedAt: map['last_verified_at'] != null || map['lastVerifiedAt'] != null
          ? DateTime.tryParse((map['last_verified_at'] ?? map['lastVerifiedAt']).toString()) ?? DateTime.now()
          : DateTime.now(),
      gracePeriodDays: int.tryParse(map['grace_period_days']?.toString() ?? map['gracePeriodDays']?.toString() ?? '7') ?? 7,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LicenseInfo.fromJson(String source) =>
      LicenseInfo.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Result returned after verifying a license.
class LicenseVerificationResult {
  final LicenseStatus status;
  final LicenseInfo? license;
  final String message;
  final bool isAllowed;
  final bool isOnline;

  const LicenseVerificationResult({
    required this.status,
    this.license,
    required this.message,
    required this.isAllowed,
    required this.isOnline,
  });

  factory LicenseVerificationResult.success({
    required LicenseInfo license,
    bool isOnline = true,
    bool bypass = false,
  }) {
    return LicenseVerificationResult(
      status: bypass ? LicenseStatus.bypassed : (license.isExpired ? LicenseStatus.expired : LicenseStatus.active),
      license: license,
      message: bypass ? 'Security checks bypassed by flag' : 'License verified successfully',
      isAllowed: true,
      isOnline: isOnline,
    );
  }

  factory LicenseVerificationResult.failure({
    required LicenseStatus status,
    LicenseInfo? license,
    required String message,
    bool isOnline = true,
  }) {
    return LicenseVerificationResult(
      status: status,
      license: license,
      message: message,
      isAllowed: false,
      isOnline: isOnline,
    );
  }
}
