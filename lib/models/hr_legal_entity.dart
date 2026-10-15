import '../models/enterprise.dart';

class HrLegalEntity {
  final String id;
  final String enterpriseId;

  // ─── 1. Informations légales ─────────────────────────────────────────────
  final String socialReason;
  final String taxId;
  final String vatStatus;
  final String category;
  final String cnssNumber;

  // ─── 2. Paramètres de paie ───────────────────────────────────────────────
  final String collectiveAgreement;
  final bool hasNoCollectiveAgreement;
  final String fiscalYear;
  final String cutoffDay;
  final String paymentDay;
  final String timezone;
  final String activitySector;
  final String employerAtMpRate;
  final String employerTfpRate;

  // ─── 3. Siège social ─────────────────────────────────────────────────────
  final String address;
  final String postalCode;
  final String city;
  final String country;
  final String checkInRadius;
  final double? latitude;
  final double? longitude;
  final bool hasGeozone;

  // ─── 4. Représentant légal ───────────────────────────────────────────────
  final String legalRepName;
  final String legalRepRole;

  // ─── 5. Coordonnées bancaires ────────────────────────────────────────────
  final String bankAccountName;
  final String iban;
  final String bic;
  final String bankAgency;
  final bool transferOrderActive;

  // ─── Timestamps ──────────────────────────────────────────────────────────
  final DateTime createdAt;
  final DateTime updatedAt;

  const HrLegalEntity({
    required this.id,
    required this.enterpriseId,
    this.socialReason = '',
    this.taxId = '',
    this.vatStatus = '-',
    this.category = '-',
    this.cnssNumber = '-',
    this.collectiveAgreement = '-',
    this.hasNoCollectiveAgreement = false,
    this.fiscalYear = 'Janvier → Décembre',
    this.cutoffDay = 'Le 25 du mois',
    this.paymentDay = 'Le 28 du mois',
    this.timezone = 'Africa/Tunis',
    this.activitySector = '-',
    this.employerAtMpRate = '-',
    this.employerTfpRate = '-',
    this.address = '-',
    this.postalCode = '-',
    this.city = '-',
    this.country = 'Tunisie',
    this.checkInRadius = '-',
    this.latitude,
    this.longitude,
    this.hasGeozone = false,
    this.legalRepName = '-',
    this.legalRepRole = '-',
    this.bankAccountName = '-',
    this.iban = '-',
    this.bic = '-',
    this.bankAgency = '-',
    this.transferOrderActive = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory creating an initial entity pre-filled from Enterprise ("Information de la société")
  factory HrLegalEntity.fromEnterprise(Enterprise ent) {
    final now = DateTime.now();
    return HrLegalEntity(
      id: 'default',
      enterpriseId: ent.id,
      socialReason: ent.name.isNotEmpty ? ent.name : 'Mon Entreprise',
      taxId: (ent.taxId != null && ent.taxId!.trim().isNotEmpty) ? ent.taxId!.trim() : '-',
      vatStatus: (ent.taxId != null && ent.taxId!.isNotEmpty) ? 'Assujetti' : '-',
      category: 'Personne morale',
      cnssNumber: '-',
      collectiveAgreement: '-',
      hasNoCollectiveAgreement: false,
      fiscalYear: 'Janvier → Décembre',
      cutoffDay: 'Le 25 du mois',
      paymentDay: 'Le 28 du mois',
      timezone: 'Africa/Tunis',
      activitySector: ent.description?.isNotEmpty == true ? ent.description! : '-',
      employerAtMpRate: '0.4 %',
      employerTfpRate: '1.0 %',
      address: (ent.address != null && ent.address!.trim().isNotEmpty) ? ent.address!.trim() : '-',
      postalCode: '-',
      city: 'Tunis',
      country: 'Tunisie',
      checkInRadius: '100 m',
      hasGeozone: false,
      legalRepName: '-',
      legalRepRole: 'Gérant',
      bankAccountName: ent.name.isNotEmpty ? ent.name : '-',
      iban: (ent.rib != null && ent.rib!.trim().isNotEmpty) ? ent.rib!.trim() : '-',
      bic: '-',
      bankAgency: '-',
      transferOrderActive: false,
      createdAt: ent.createdAt,
      updatedAt: now,
    );
  }

  HrLegalEntity copyWith({
    String? id,
    String? enterpriseId,
    String? socialReason,
    String? taxId,
    String? vatStatus,
    String? category,
    String? cnssNumber,
    String? collectiveAgreement,
    bool? hasNoCollectiveAgreement,
    String? fiscalYear,
    String? cutoffDay,
    String? paymentDay,
    String? timezone,
    String? activitySector,
    String? employerAtMpRate,
    String? employerTfpRate,
    String? address,
    String? postalCode,
    String? city,
    String? country,
    String? checkInRadius,
    double? latitude,
    double? longitude,
    bool? hasGeozone,
    String? legalRepName,
    String? legalRepRole,
    String? bankAccountName,
    String? iban,
    String? bic,
    String? bankAgency,
    bool? transferOrderActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HrLegalEntity(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      socialReason: socialReason ?? this.socialReason,
      taxId: taxId ?? this.taxId,
      vatStatus: vatStatus ?? this.vatStatus,
      category: category ?? this.category,
      cnssNumber: cnssNumber ?? this.cnssNumber,
      collectiveAgreement: collectiveAgreement ?? this.collectiveAgreement,
      hasNoCollectiveAgreement: hasNoCollectiveAgreement ?? this.hasNoCollectiveAgreement,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      cutoffDay: cutoffDay ?? this.cutoffDay,
      paymentDay: paymentDay ?? this.paymentDay,
      timezone: timezone ?? this.timezone,
      activitySector: activitySector ?? this.activitySector,
      employerAtMpRate: employerAtMpRate ?? this.employerAtMpRate,
      employerTfpRate: employerTfpRate ?? this.employerTfpRate,
      address: address ?? this.address,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country ?? this.country,
      checkInRadius: checkInRadius ?? this.checkInRadius,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hasGeozone: hasGeozone ?? this.hasGeozone,
      legalRepName: legalRepName ?? this.legalRepName,
      legalRepRole: legalRepRole ?? this.legalRepRole,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      bankAgency: bankAgency ?? this.bankAgency,
      transferOrderActive: transferOrderActive ?? this.transferOrderActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'socialReason': socialReason,
      'taxId': taxId,
      'vatStatus': vatStatus,
      'category': category,
      'cnssNumber': cnssNumber,
      'collectiveAgreement': collectiveAgreement,
      'hasNoCollectiveAgreement': hasNoCollectiveAgreement,
      'fiscalYear': fiscalYear,
      'cutoffDay': cutoffDay,
      'paymentDay': paymentDay,
      'timezone': timezone,
      'activitySector': activitySector,
      'employerAtMpRate': employerAtMpRate,
      'employerTfpRate': employerTfpRate,
      'address': address,
      'postalCode': postalCode,
      'city': city,
      'country': country,
      'checkInRadius': checkInRadius,
      'latitude': latitude,
      'longitude': longitude,
      'hasGeozone': hasGeozone,
      'legalRepName': legalRepName,
      'legalRepRole': legalRepRole,
      'bankAccountName': bankAccountName,
      'iban': iban,
      'bic': bic,
      'bankAgency': bankAgency,
      'transferOrderActive': transferOrderActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HrLegalEntity.fromMap(Map<String, dynamic> map) {
    return HrLegalEntity(
      id: map['id']?.toString() ?? 'default',
      enterpriseId: map['enterpriseId']?.toString() ?? '',
      socialReason: map['socialReason']?.toString() ?? '',
      taxId: map['taxId']?.toString() ?? '-',
      vatStatus: map['vatStatus']?.toString() ?? '-',
      category: map['category']?.toString() ?? '-',
      cnssNumber: map['cnssNumber']?.toString() ?? '-',
      collectiveAgreement: map['collectiveAgreement']?.toString() ?? '-',
      hasNoCollectiveAgreement: map['hasNoCollectiveAgreement'] == true,
      fiscalYear: map['fiscalYear']?.toString() ?? 'Janvier → Décembre',
      cutoffDay: map['cutoffDay']?.toString() ?? 'Le 25 du mois',
      paymentDay: map['paymentDay']?.toString() ?? 'Le 28 du mois',
      timezone: map['timezone']?.toString() ?? 'Africa/Tunis',
      activitySector: map['activitySector']?.toString() ?? '-',
      employerAtMpRate: map['employerAtMpRate']?.toString() ?? '-',
      employerTfpRate: map['employerTfpRate']?.toString() ?? '-',
      address: map['address']?.toString() ?? '-',
      postalCode: map['postalCode']?.toString() ?? '-',
      city: map['city']?.toString() ?? '-',
      country: map['country']?.toString() ?? 'Tunisie',
      checkInRadius: map['checkInRadius']?.toString() ?? '-',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      hasGeozone: map['hasGeozone'] == true,
      legalRepName: map['legalRepName']?.toString() ?? '-',
      legalRepRole: map['legalRepRole']?.toString() ?? '-',
      bankAccountName: map['bankAccountName']?.toString() ?? '-',
      iban: map['iban']?.toString() ?? '-',
      bic: map['bic']?.toString() ?? '-',
      bankAgency: map['bankAgency']?.toString() ?? '-',
      transferOrderActive: map['transferOrderActive'] == true,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
