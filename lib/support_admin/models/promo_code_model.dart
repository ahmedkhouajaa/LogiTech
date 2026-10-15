import 'package:cloud_firestore/cloud_firestore.dart';

enum PromoDiscountType {
  percentage,  // Remise en %
  fixedAmount, // Réduction en DT / TND
  gift,        // Cadeau / Avantage spécifique
  freeDays,    // Jours supplémentaires d'abonnement offerts
}

extension PromoDiscountTypeExt on PromoDiscountType {
  String get label {
    switch (this) {
      case PromoDiscountType.percentage:
        return 'Pourcentage (%)';
      case PromoDiscountType.fixedAmount:
        return 'Montant fixe (DT)';
      case PromoDiscountType.gift:
        return 'Cadeau / Avantage';
      case PromoDiscountType.freeDays:
        return 'Jours offerts';
    }
  }

  String get id {
    switch (this) {
      case PromoDiscountType.percentage:
        return 'percentage';
      case PromoDiscountType.fixedAmount:
        return 'fixed_amount';
      case PromoDiscountType.gift:
        return 'gift';
      case PromoDiscountType.freeDays:
        return 'free_days';
    }
  }

  static PromoDiscountType fromString(String? val) {
    switch (val) {
      case 'fixed_amount':
      case 'fixedAmount':
        return PromoDiscountType.fixedAmount;
      case 'gift':
        return PromoDiscountType.gift;
      case 'free_days':
      case 'freeDays':
        return PromoDiscountType.freeDays;
      case 'percentage':
      default:
        return PromoDiscountType.percentage;
    }
  }
}

class PromoCode {
  final String id;
  final String code;
  final String description;
  final PromoDiscountType discountType;
  final double discountValue; // % or DT or days
  final String giftDetails;   // e.g. "1 mois offert", "Module Stock VIP"
  final bool isActive;
  final int? maxUses;         // null = unlimited
  final int usedCount;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String createdBy;
  final List<Map<String, dynamic>> recentUsages;

  const PromoCode({
    required this.id,
    required this.code,
    required this.description,
    required this.discountType,
    this.discountValue = 0.0,
    this.giftDetails = '',
    this.isActive = true,
    this.maxUses,
    this.usedCount = 0,
    this.expiresAt,
    required this.createdAt,
    this.createdBy = 'Support Admin',
    this.recentUsages = const [],
  });

  String get benefitSummary {
    switch (discountType) {
      case PromoDiscountType.percentage:
        return '${discountValue.toInt()}% de remise';
      case PromoDiscountType.fixedAmount:
        return '${discountValue.toStringAsFixed(0)} DT de réduction';
      case PromoDiscountType.gift:
        return giftDetails.isNotEmpty ? 'Cadeau : $giftDetails' : 'Avantage VIP offert';
      case PromoDiscountType.freeDays:
        return '+${discountValue.toInt()} jours offerts';
    }
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get isLimitReached {
    if (maxUses == null) return false;
    return usedCount >= maxUses!;
  }

  bool get isUsable => isActive && !isExpired && !isLimitReached;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.toUpperCase(),
      'description': description,
      'discountType': discountType.id,
      'discountValue': discountValue,
      'giftDetails': giftDetails,
      'benefitSummary': benefitSummary,
      'isActive': isActive,
      'maxUses': maxUses,
      'usedCount': usedCount,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'recentUsages': recentUsages,
    };
  }

  factory PromoCode.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? exp;
    if (map['expiresAt'] is Timestamp) {
      exp = (map['expiresAt'] as Timestamp).toDate();
    } else if (map['expiresAt'] is String) {
      exp = DateTime.tryParse(map['expiresAt']);
    }

    DateTime created = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      created = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      created = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    }

    final rawUsages = map['recentUsages'];
    List<Map<String, dynamic>> usages = [];
    if (rawUsages is List) {
      usages = rawUsages.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return PromoCode(
      id: id ?? map['id']?.toString() ?? map['code']?.toString() ?? '',
      code: (map['code'] ?? '').toString().toUpperCase(),
      description: (map['description'] ?? '').toString(),
      discountType: PromoDiscountTypeExt.fromString(map['discountType']?.toString()),
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0.0,
      giftDetails: (map['giftDetails'] ?? '').toString(),
      isActive: map['isActive'] == true,
      maxUses: map['maxUses'] is int ? map['maxUses'] as int : (map['maxUses'] as num?)?.toInt(),
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      expiresAt: exp,
      createdAt: created,
      createdBy: (map['createdBy'] ?? 'Support Admin').toString(),
      recentUsages: usages,
    );
  }

  PromoCode copyWith({
    String? id,
    String? code,
    String? description,
    PromoDiscountType? discountType,
    double? discountValue,
    String? giftDetails,
    bool? isActive,
    int? maxUses,
    int? usedCount,
    DateTime? expiresAt,
    DateTime? createdAt,
    String? createdBy,
    List<Map<String, dynamic>>? recentUsages,
  }) {
    return PromoCode(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      giftDetails: giftDetails ?? this.giftDetails,
      isActive: isActive ?? this.isActive,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      recentUsages: recentUsages ?? this.recentUsages,
    );
  }
}

class PromoCodeUsage {
  final String id;
  final String promoCodeId;
  final String code;
  final String userId;
  final String userName;
  final String userEmail;
  final String enterpriseId;
  final String enterpriseName;
  final PromoDiscountType discountType;
  final double discountValue;
  final String benefitSummary;
  final DateTime usedAt;

  const PromoCodeUsage({
    required this.id,
    required this.promoCodeId,
    required this.code,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.enterpriseId,
    required this.enterpriseName,
    required this.discountType,
    required this.discountValue,
    required this.benefitSummary,
    required this.usedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'promoCodeId': promoCodeId,
      'code': code.toUpperCase(),
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'enterpriseId': enterpriseId,
      'enterpriseName': enterpriseName,
      'discountType': discountType.id,
      'discountValue': discountValue,
      'benefitSummary': benefitSummary,
      'usedAt': Timestamp.fromDate(usedAt),
    };
  }

  factory PromoCodeUsage.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime used = DateTime.now();
    if (map['usedAt'] is Timestamp) {
      used = (map['usedAt'] as Timestamp).toDate();
    } else if (map['usedAt'] is String) {
      used = DateTime.tryParse(map['usedAt']) ?? DateTime.now();
    }

    return PromoCodeUsage(
      id: id ?? map['id']?.toString() ?? '',
      promoCodeId: (map['promoCodeId'] ?? '').toString(),
      code: (map['code'] ?? '').toString().toUpperCase(),
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? 'Client').toString(),
      userEmail: (map['userEmail'] ?? '').toString(),
      enterpriseId: (map['enterpriseId'] ?? '').toString(),
      enterpriseName: (map['enterpriseName'] ?? 'Entreprise').toString(),
      discountType: PromoDiscountTypeExt.fromString(map['discountType']?.toString()),
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0.0,
      benefitSummary: (map['benefitSummary'] ?? '').toString(),
      usedAt: used,
    );
  }
}
