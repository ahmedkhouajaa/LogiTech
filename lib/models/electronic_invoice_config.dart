import 'package:flutter/foundation.dart';

/// Configuration and adhesion status for Tunisian Electronic Invoicing (El Fatoora / TTN).
@immutable
class ElectronicInvoiceConfig {
  final bool isEnabled;
  final String adhesionStatus; // 'not_started', 'pending_ttn', 'active'
  final String ttnMemberCode;
  final String matriculeFiscal;
  final String taxCode;
  final String environment; // 'sandbox' (Test), 'production'
  final String signatureType; // 'digigo' (Tuntrust), 'token_usb' (ANCE Token), 'software'
  final bool autoGenerateXml;
  final bool showQrCode;
  final bool autoSendEmail;
  final DateTime? activatedAt;
  final DateTime? ttnCertificateExpiry;

  const ElectronicInvoiceConfig({
    this.isEnabled = false,
    this.adhesionStatus = 'not_started',
    this.ttnMemberCode = '',
    this.matriculeFiscal = '',
    this.taxCode = '',
    this.environment = 'sandbox',
    this.signatureType = 'digigo',
    this.autoGenerateXml = true,
    this.showQrCode = true,
    this.autoSendEmail = true,
    this.activatedAt,
    this.ttnCertificateExpiry,
  });

  bool get isConfigured => ttnMemberCode.isNotEmpty && matriculeFiscal.isNotEmpty;
  bool get isProduction => environment == 'production';
  bool get isActive => isEnabled && adhesionStatus == 'active';

  ElectronicInvoiceConfig copyWith({
    bool? isEnabled,
    String? adhesionStatus,
    String? ttnMemberCode,
    String? matriculeFiscal,
    String? taxCode,
    String? environment,
    String? signatureType,
    bool? autoGenerateXml,
    bool? showQrCode,
    bool? autoSendEmail,
    DateTime? activatedAt,
    DateTime? ttnCertificateExpiry,
  }) {
    return ElectronicInvoiceConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      adhesionStatus: adhesionStatus ?? this.adhesionStatus,
      ttnMemberCode: ttnMemberCode ?? this.ttnMemberCode,
      matriculeFiscal: matriculeFiscal ?? this.matriculeFiscal,
      taxCode: taxCode ?? this.taxCode,
      environment: environment ?? this.environment,
      signatureType: signatureType ?? this.signatureType,
      autoGenerateXml: autoGenerateXml ?? this.autoGenerateXml,
      showQrCode: showQrCode ?? this.showQrCode,
      autoSendEmail: autoSendEmail ?? this.autoSendEmail,
      activatedAt: activatedAt ?? this.activatedAt,
      ttnCertificateExpiry: ttnCertificateExpiry ?? this.ttnCertificateExpiry,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'adhesionStatus': adhesionStatus,
      'ttnMemberCode': ttnMemberCode,
      'matriculeFiscal': matriculeFiscal,
      'taxCode': taxCode,
      'environment': environment,
      'signatureType': signatureType,
      'autoGenerateXml': autoGenerateXml,
      'showQrCode': showQrCode,
      'autoSendEmail': autoSendEmail,
      'activatedAt': activatedAt?.toIso8601String(),
      'ttnCertificateExpiry': ttnCertificateExpiry?.toIso8601String(),
    };
  }

  factory ElectronicInvoiceConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ElectronicInvoiceConfig();
    return ElectronicInvoiceConfig(
      isEnabled: map['isEnabled'] as bool? ?? false,
      adhesionStatus: map['adhesionStatus'] as String? ?? 'not_started',
      ttnMemberCode: map['ttnMemberCode'] as String? ?? '',
      matriculeFiscal: map['matriculeFiscal'] as String? ?? '',
      taxCode: map['taxCode'] as String? ?? '',
      environment: map['environment'] as String? ?? 'sandbox',
      signatureType: map['signatureType'] as String? ?? 'digigo',
      autoGenerateXml: map['autoGenerateXml'] as bool? ?? true,
      showQrCode: map['showQrCode'] as bool? ?? true,
      autoSendEmail: map['autoSendEmail'] as bool? ?? true,
      activatedAt: map['activatedAt'] != null ? DateTime.tryParse(map['activatedAt'].toString()) : null,
      ttnCertificateExpiry: map['ttnCertificateExpiry'] != null ? DateTime.tryParse(map['ttnCertificateExpiry'].toString()) : null,
    );
  }
}
