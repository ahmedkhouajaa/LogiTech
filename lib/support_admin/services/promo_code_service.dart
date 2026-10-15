import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/promo_code_model.dart';
import '../../../services/affiliate_service.dart';

class PromoCodeValidationResult {
  final bool isValid;
  final bool isPredefinedPromo;
  final String code;
  final String benefitSummary;
  final PromoDiscountType? discountType;
  final double discountValue;
  final String? message;
  final PromoCode? promoCode;

  const PromoCodeValidationResult({
    required this.isValid,
    this.isPredefinedPromo = false,
    this.code = '',
    this.benefitSummary = '',
    this.discountType,
    this.discountValue = 0.0,
    this.message,
    this.promoCode,
  });
}

class PromoCodeService {
  static final PromoCodeService instance = PromoCodeService._();
  PromoCodeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _promoCodesRef =>
      _firestore.collection('promo_codes');

  CollectionReference<Map<String, dynamic>> get _usagesRef =>
      _firestore.collection('promo_code_usages');

  /// Streams all promo codes in real time, ordered by creation date
  Stream<List<PromoCode>> streamPromoCodes() {
    return _promoCodesRef.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PromoCode.fromMap(doc.data(), id: doc.id)).toList();
    });
  }

  /// Streams all client usages in real time
  Stream<List<PromoCodeUsage>> streamAllUsages({int limit = 150}) {
    return _usagesRef.orderBy('usedAt', descending: true).limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PromoCodeUsage.fromMap(doc.data(), id: doc.id)).toList();
    });
  }

  /// Creates a new promo code
  Future<void> createPromoCode(PromoCode promo) async {
    final cleanCode = promo.code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      throw 'Le code promo ne peut pas être vide.';
    }

    final docSnap = await _promoCodesRef.doc(cleanCode).get();
    if (docSnap.exists) {
      throw 'Le code promo "$cleanCode" existe déjà. Veuillez en choisir un autre.';
    }

    final promoToSave = promo.copyWith(
      id: cleanCode,
      code: cleanCode,
      createdAt: DateTime.now(),
      usedCount: 0,
    );

    await _promoCodesRef.doc(cleanCode).set(promoToSave.toMap());
  }

  /// Updates an existing promo code
  Future<void> updatePromoCode(PromoCode promo) async {
    final cleanCode = promo.code.trim().toUpperCase();
    await _promoCodesRef.doc(cleanCode).update(promo.toMap());
  }

  /// Toggles status between active and inactive
  Future<void> togglePromoStatus(String codeId, bool isActive) async {
    await _promoCodesRef.doc(codeId.toUpperCase()).update({'isActive': isActive});
  }

  /// Deletes a promo code
  Future<void> deletePromoCode(String codeId) async {
    await _promoCodesRef.doc(codeId.toUpperCase()).delete();
  }

  /// Validates a code entered by a user during signup or onboarding
  Future<PromoCodeValidationResult> validatePromoCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      return const PromoCodeValidationResult(isValid: false, message: 'Code promo vide');
    }

    try {
      final doc = await _promoCodesRef.doc(code).get();
      if (!doc.exists) {
        // Check if this is an affiliate/referral code
        try {
          final affiliate = await AffiliateService.instance.findAffiliateByCode(code);
          if (affiliate != null) {
            final config = await AffiliateService.instance.getConfig();
            return PromoCodeValidationResult(
              isValid: true,
              isPredefinedPromo: false,
              code: code,
              benefitSummary: '🤝 Parrain ${affiliate.userName} : ${config.referredUserBenefit}',
              discountType: PromoDiscountType.percentage,
              discountValue: config.referredUserDiscount,
            );
          }
        } catch (_) {}

        // Fallback for custom partner code
        return PromoCodeValidationResult(
          isValid: true,
          isPredefinedPromo: false,
          code: code,
          benefitSummary: 'Code promo enregistré',
        );
      }

      final promo = PromoCode.fromMap(doc.data()!, id: doc.id);

      if (!promo.isActive) {
        return PromoCodeValidationResult(
          isValid: false,
          code: code,
          message: 'Ce code promo est inactif ou désactivé.',
        );
      }

      if (promo.isExpired) {
        return PromoCodeValidationResult(
          isValid: false,
          code: code,
          message: 'Ce code promo a expiré.',
        );
      }

      if (promo.isLimitReached) {
        return PromoCodeValidationResult(
          isValid: false,
          code: code,
          message: 'Ce code promo a atteint sa limite maximale d\'utilisations.',
        );
      }

      return PromoCodeValidationResult(
        isValid: true,
        isPredefinedPromo: true,
        promoCode: promo,
        code: code,
        benefitSummary: promo.benefitSummary,
        discountType: promo.discountType,
        discountValue: promo.discountValue,
      );
    } catch (e) {
      debugPrint('[PromoCodeService] Validation error: $e');
      return PromoCodeValidationResult(isValid: false, message: 'Erreur lors de la validation: $e');
    }
  }

  /// Records that user X from enterprise Y used promo code Z with benefit W
  Future<PromoCode?> recordPromoUsage({
    required String code,
    required String userId,
    required String userName,
    required String userEmail,
    required String enterpriseId,
    required String enterpriseName,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    try {
      final doc = await _promoCodesRef.doc(cleanCode).get();
      PromoCode? promo;
      String benefitSummary = 'Code appliqué';
      PromoDiscountType discountType = PromoDiscountType.percentage;
      double discountValue = 0.0;

      if (doc.exists) {
        promo = PromoCode.fromMap(doc.data()!, id: doc.id);
        benefitSummary = promo.benefitSummary;
        discountType = promo.discountType;
        discountValue = promo.discountValue;

        // Atomically increment usage count and append recent usage record
        final usageSummary = {
          'userId': userId,
          'userName': userName,
          'userEmail': userEmail,
          'enterpriseId': enterpriseId,
          'enterpriseName': enterpriseName,
          'benefitSummary': benefitSummary,
          'usedAt': DateTime.now().toIso8601String(),
        };

        await _promoCodesRef.doc(cleanCode).update({
          'usedCount': FieldValue.increment(1),
          'recentUsages': FieldValue.arrayUnion([usageSummary]),
        });
      }

      // Write individual detailed usage record in promo_code_usages collection
      final usageRecord = PromoCodeUsage(
        id: '${cleanCode}_${userId}_${DateTime.now().millisecondsSinceEpoch}',
        promoCodeId: cleanCode,
        code: cleanCode,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        enterpriseId: enterpriseId,
        enterpriseName: enterpriseName,
        discountType: discountType,
        discountValue: discountValue,
        benefitSummary: benefitSummary,
        usedAt: DateTime.now(),
      );

      await _usagesRef.doc(usageRecord.id).set(usageRecord.toMap());

      // Update user & enterprise documents with the applied promo benefit
      await _firestore.collection('users').doc(userId).set({
        'partnerCode': cleanCode,
        'promoBenefit': benefitSummary,
        'hasPartner': true,
        'partnerLinkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (enterpriseId.isNotEmpty) {
        await _firestore.collection('enterprises').doc(enterpriseId).set({
          'partnerCode': cleanCode,
          'promoBenefit': benefitSummary,
          'hasPartner': true,
          'partnerLinkedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Check if this code belongs to an affiliate and grant commission to User X
      try {
        await AffiliateService.instance.handleAffiliateReferral(
          rawCode: cleanCode,
          referredUserId: userId,
          referredUserName: userName,
          referredUserEmail: userEmail,
          referredEnterpriseId: enterpriseId,
          referredEnterpriseName: enterpriseName,
        );
      } catch (e) {
        debugPrint('[PromoCodeService] Error handling affiliate referral: $e');
      }

      return promo;
    } catch (e) {
      debugPrint('[PromoCodeService] recordPromoUsage error: $e');
      return null;
    }
  }
}
