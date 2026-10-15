import 'package:cloud_firestore/cloud_firestore.dart';

/// Statut d'une demande de retrait
enum PayoutStatus {
  pending,  // En attente de validation
  approved, // Approuvé
  paid,     // Payé / Virement effectué
  rejected, // Rejeté
}

extension PayoutStatusExt on PayoutStatus {
  String get label {
    switch (this) {
      case PayoutStatus.pending:
        return 'En attente';
      case PayoutStatus.approved:
        return 'Validé';
      case PayoutStatus.paid:
        return 'Payé';
      case PayoutStatus.rejected:
        return 'Rejeté';
    }
  }

  String get id {
    switch (this) {
      case PayoutStatus.pending:
        return 'pending';
      case PayoutStatus.approved:
        return 'approved';
      case PayoutStatus.paid:
        return 'paid';
      case PayoutStatus.rejected:
        return 'rejected';
    }
  }

  static PayoutStatus fromString(String? val) {
    switch (val) {
      case 'approved':
        return PayoutStatus.approved;
      case 'paid':
        return PayoutStatus.paid;
      case 'rejected':
        return PayoutStatus.rejected;
      case 'pending':
      default:
        return PayoutStatus.pending;
    }
  }
}

/// Profil d'un affilié / parrain (User X)
class AffiliateProfile {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String affiliateCode;
  final double balanceCash;      // Solde disponible pour virement en DT
  final double balanceDiscount;  // Crédit utilisable en remise abonnement en DT
  final double totalEarned;      // Gains cumulés depuis le début en DT
  final int totalReferrals;      // Nombre total de filleuls parrainés
  final String? preferredPayoutMethod; // 'bank_transfer', 'flouci', 'd17'
  final Map<String, dynamic> payoutDetails; // IBAN, titulaire, tél
  final DateTime createdAt;
  final DateTime updatedAt;

  const AffiliateProfile({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.affiliateCode,
    this.balanceCash = 0.0,
    this.balanceDiscount = 0.0,
    this.totalEarned = 0.0,
    this.totalReferrals = 0,
    this.preferredPayoutMethod,
    this.payoutDetails = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory AffiliateProfile.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return AffiliateProfile(
      id: id ?? data['id'] ?? data['userId'] ?? '',
      userId: data['userId'] ?? id ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? 'Utilisateur',
      affiliateCode: (data['affiliateCode'] ?? '').toString().toUpperCase(),
      balanceCash: (data['balanceCash'] as num?)?.toDouble() ?? 0.0,
      balanceDiscount: (data['balanceDiscount'] as num?)?.toDouble() ?? 0.0,
      totalEarned: (data['totalEarned'] as num?)?.toDouble() ?? 0.0,
      totalReferrals: (data['totalReferrals'] as num?)?.toInt() ?? 0,
      preferredPayoutMethod: data['preferredPayoutMethod'],
      payoutDetails: Map<String, dynamic>.from(data['payoutDetails'] ?? {}),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'affiliateCode': affiliateCode.toUpperCase(),
      'balanceCash': balanceCash,
      'balanceDiscount': balanceDiscount,
      'totalEarned': totalEarned,
      'totalReferrals': totalReferrals,
      'preferredPayoutMethod': preferredPayoutMethod,
      'payoutDetails': payoutDetails,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Enregistrement d'un filleul parrainé
class AffiliateReferral {
  final String id;
  final String referrerId;        // UID de User X
  final String referrerCode;      // Code affilié utilisé
  final String referredUserId;    // UID de User Y
  final String referredUserName;
  final String referredUserEmail;
  final String referredEnterpriseId;
  final String referredEnterpriseName;
  final double commissionAmount;  // Montant gagné en DT (ex: 20 DT)
  final String commissionType;    // 'cash', 'discount'
  final String status;            // 'confirmed', 'pending'
  final String benefitAwarded;    // Ce que le filleul a reçu (ex: 10% remise)
  final DateTime createdAt;

  const AffiliateReferral({
    required this.id,
    required this.referrerId,
    required this.referrerCode,
    required this.referredUserId,
    required this.referredUserName,
    required this.referredUserEmail,
    required this.referredEnterpriseId,
    required this.referredEnterpriseName,
    this.commissionAmount = 20.0,
    this.commissionType = 'cash',
    this.status = 'confirmed',
    this.benefitAwarded = '10% de remise bienvenue',
    required this.createdAt,
  });

  factory AffiliateReferral.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return AffiliateReferral(
      id: id ?? data['id'] ?? '',
      referrerId: data['referrerId'] ?? '',
      referrerCode: (data['referrerCode'] ?? '').toString().toUpperCase(),
      referredUserId: data['referredUserId'] ?? '',
      referredUserName: data['referredUserName'] ?? 'Nouveau client',
      referredUserEmail: data['referredUserEmail'] ?? '',
      referredEnterpriseId: data['referredEnterpriseId'] ?? '',
      referredEnterpriseName: data['referredEnterpriseName'] ?? '',
      commissionAmount: (data['commissionAmount'] as num?)?.toDouble() ?? 20.0,
      commissionType: data['commissionType'] ?? 'cash',
      status: data['status'] ?? 'confirmed',
      benefitAwarded: data['benefitAwarded'] ?? '10% de remise bienvenue',
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'referrerId': referrerId,
      'referrerCode': referrerCode.toUpperCase(),
      'referredUserId': referredUserId,
      'referredUserName': referredUserName,
      'referredUserEmail': referredUserEmail,
      'referredEnterpriseId': referredEnterpriseId,
      'referredEnterpriseName': referredEnterpriseName,
      'commissionAmount': commissionAmount,
      'commissionType': commissionType,
      'status': status,
      'benefitAwarded': benefitAwarded,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Demande de retrait effectuée par un affilié
class AffiliatePayoutRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final double amount;
  final String payoutMethod; // 'bank_transfer', 'flouci', 'd17', 'mandat'
  final Map<String, dynamic> payoutDetails; // RIB, numéro de téléphone, etc.
  final PayoutStatus status;
  final String? adminNotes;
  final String? transactionReference; // Référence du virement
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;

  const AffiliatePayoutRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.amount,
    required this.payoutMethod,
    required this.payoutDetails,
    this.status = PayoutStatus.pending,
    this.adminNotes,
    this.transactionReference,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
  });

  factory AffiliatePayoutRequest.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return AffiliatePayoutRequest(
      id: id ?? data['id'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Utilisateur',
      userEmail: data['userEmail'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      payoutMethod: data['payoutMethod'] ?? 'bank_transfer',
      payoutDetails: Map<String, dynamic>.from(data['payoutDetails'] ?? {}),
      status: PayoutStatusExt.fromString(data['status']),
      adminNotes: data['adminNotes'],
      transactionReference: data['transactionReference'],
      requestedAt: parseDate(data['requestedAt']),
      processedAt: data['processedAt'] != null ? parseDate(data['processedAt']) : null,
      processedBy: data['processedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'amount': amount,
      'payoutMethod': payoutMethod,
      'payoutDetails': payoutDetails,
      'status': status.id,
      'adminNotes': adminNotes,
      'transactionReference': transactionReference,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'processedBy': processedBy,
    };
  }
}

/// Configuration globale du programme d'affiliation (SuperAdmin)
class AffiliateConfig {
  final bool isEnabled;
  final double fixedRewardAmount;      // Gain en DT par filleul (ex: 20 DT)
  final double percentageReward;       // % si basé sur les abonnements (ex: 20%)
  final double minPayoutAmount;        // Montant minimum de retrait en DT (ex: 50 DT)
  final String referredUserBenefit;    // Description du bénéfice du filleul
  final double referredUserDiscount;   // Remise accordée au filleul (ex: 10%)
  final int referredUserFreeDays;      // Jours supplémentaires offerts (ex: 14)

  const AffiliateConfig({
    this.isEnabled = true,
    this.fixedRewardAmount = 20.0,
    this.percentageReward = 15.0,
    this.minPayoutAmount = 50.0,
    this.referredUserBenefit = '10% de remise immédiate sur votre abonnement',
    this.referredUserDiscount = 10.0,
    this.referredUserFreeDays = 14,
  });

  factory AffiliateConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AffiliateConfig();
    return AffiliateConfig(
      isEnabled: data['isEnabled'] as bool? ?? true,
      fixedRewardAmount: (data['fixedRewardAmount'] as num?)?.toDouble() ?? 20.0,
      percentageReward: (data['percentageReward'] as num?)?.toDouble() ?? 15.0,
      minPayoutAmount: (data['minPayoutAmount'] as num?)?.toDouble() ?? 50.0,
      referredUserBenefit: data['referredUserBenefit'] ?? '10% de remise immédiate sur votre abonnement',
      referredUserDiscount: (data['referredUserDiscount'] as num?)?.toDouble() ?? 10.0,
      referredUserFreeDays: (data['referredUserFreeDays'] as num?)?.toInt() ?? 14,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'fixedRewardAmount': fixedRewardAmount,
      'percentageReward': percentageReward,
      'minPayoutAmount': minPayoutAmount,
      'referredUserBenefit': referredUserBenefit,
      'referredUserDiscount': referredUserDiscount,
      'referredUserFreeDays': referredUserFreeDays,
    };
  }
}
