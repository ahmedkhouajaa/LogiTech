import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/affiliate_model.dart';

class AffiliateService {
  AffiliateService._();
  static final AffiliateService instance = AffiliateService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _profilesRef =>
      _firestore.collection('affiliate_profiles');

  CollectionReference<Map<String, dynamic>> get _codesIndexRef =>
      _firestore.collection('affiliate_codes');

  CollectionReference<Map<String, dynamic>> get _referralsRef =>
      _firestore.collection('affiliate_referrals');

  CollectionReference<Map<String, dynamic>> get _payoutsRef =>
      _firestore.collection('affiliate_payout_requests');

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('app_configuration').doc('affiliate_program');

  // ==========================================
  // CONFIGURATION DU PROGRAMME (SuperAdmin)
  // ==========================================

  Stream<AffiliateConfig> streamConfig() {
    return _configRef.snapshots().map((doc) {
      if (!doc.exists) return const AffiliateConfig();
      return AffiliateConfig.fromMap(doc.data());
    });
  }

  Future<AffiliateConfig> getConfig() async {
    try {
      final doc = await _configRef.get();
      if (!doc.exists) {
        final defaultConfig = const AffiliateConfig();
        await _configRef.set(defaultConfig.toMap());
        return defaultConfig;
      }
      return AffiliateConfig.fromMap(doc.data());
    } catch (e) {
      debugPrint('[AffiliateService] getConfig error: $e');
      return const AffiliateConfig();
    }
  }

  Future<void> updateConfig(AffiliateConfig config) async {
    await _configRef.set(config.toMap(), SetOptions(merge: true));
  }

  // ==========================================
  // GESTION DU PROFIL AFFILIÉ (User X)
  // ==========================================

  /// Récupère ou crée automatiquement le profil affilié et le code unique
  Future<AffiliateProfile> getOrCreateAffiliateProfile(
    String userId, {
    String? userName,
    String? userEmail,
  }) async {
    try {
      final doc = await _profilesRef.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return AffiliateProfile.fromMap(doc.data()!, id: doc.id);
      }

      // Générer un code unique (ex: LOGI-9A4F ou basé sur le nom)
      final generatedCode = await _generateUniqueAffiliateCode(userName);

      final newProfile = AffiliateProfile(
        id: userId,
        userId: userId,
        userEmail: userEmail ?? '',
        userName: (userName?.trim().isNotEmpty == true) ? userName! : 'Utilisateur',
        affiliateCode: generatedCode,
        balanceCash: 0.0,
        balanceDiscount: 0.0,
        totalEarned: 0.0,
        totalReferrals: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Enregistrer le profil et l'index de recherche rapide
      final batch = _firestore.batch();
      batch.set(_profilesRef.doc(userId), newProfile.toMap());
      batch.set(_codesIndexRef.doc(generatedCode), {
        'userId': userId,
        'affiliateCode': generatedCode,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await batch.commit();

      return newProfile;
    } catch (e) {
      debugPrint('[AffiliateService] getOrCreateAffiliateProfile error: $e');
      // Retourne un profil temporaire par sécurité
      return AffiliateProfile(
        id: userId,
        userId: userId,
        userEmail: userEmail ?? '',
        userName: userName ?? 'Utilisateur',
        affiliateCode: 'LOGI-${userId.substring(0, min(6, userId.length)).toUpperCase()}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Écoute en temps réel les changements du profil affilié
  Stream<AffiliateProfile?> streamAffiliateProfile(String userId) {
    return _profilesRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AffiliateProfile.fromMap(doc.data()!, id: doc.id);
    });
  }

  /// Liste des filleuls parrainés par User X
  Stream<List<AffiliateReferral>> streamUserReferrals(String userId) {
    return _referralsRef
        .where('referrerId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => AffiliateReferral.fromMap(d.data(), id: d.id)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Liste des demandes de retrait de User X
  Stream<List<AffiliatePayoutRequest>> streamUserPayoutRequests(String userId) {
    return _payoutsRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => AffiliatePayoutRequest.fromMap(d.data(), id: d.id)).toList();
          list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
          return list;
        });
  }

  // ==========================================
  // DEMANDES DE RETRAIT & CONVERSION
  // ==========================================

  /// Soumet une demande de retrait en déduisant le solde disponible
  Future<bool> requestPayout({
    required String userId,
    required String userName,
    required String userEmail,
    required double amount,
    required String payoutMethod,
    required Map<String, dynamic> payoutDetails,
  }) async {
    final profileDoc = await _profilesRef.doc(userId).get();
    if (!profileDoc.exists) return false;

    final profile = AffiliateProfile.fromMap(profileDoc.data()!, id: profileDoc.id);
    final config = await getConfig();

    if (amount < config.minPayoutAmount) {
      throw Exception('Le montant minimum de retrait est de ${config.minPayoutAmount.toStringAsFixed(0)} DT.');
    }

    if (profile.balanceCash < amount) {
      throw Exception('Solde insuffisant. Votre solde disponible est de ${profile.balanceCash.toStringAsFixed(3)} DT.');
    }

    final requestId = 'payout_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final request = AffiliatePayoutRequest(
      id: requestId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      amount: amount,
      payoutMethod: payoutMethod,
      payoutDetails: payoutDetails,
      status: PayoutStatus.pending,
      requestedAt: DateTime.now(),
    );

    // Déduction atomique du solde disponible et création de la demande
    final batch = _firestore.batch();
    batch.update(_profilesRef.doc(userId), {
      'balanceCash': FieldValue.increment(-amount),
      'preferredPayoutMethod': payoutMethod,
      'payoutDetails': payoutDetails,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    batch.set(_payoutsRef.doc(requestId), request.toMap());

    await batch.commit();
    return true;
  }

  /// Convertit une portion du cash disponible en crédit de remise d'abonnement
  Future<bool> convertCashToDiscount(String userId, double amount) async {
    final profileDoc = await _profilesRef.doc(userId).get();
    if (!profileDoc.exists) return false;

    final profile = AffiliateProfile.fromMap(profileDoc.data()!, id: profileDoc.id);
    if (profile.balanceCash < amount || amount <= 0) return false;

    await _profilesRef.doc(userId).update({
      'balanceCash': FieldValue.increment(-amount),
      'balanceDiscount': FieldValue.increment(amount),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return true;
  }

  // ==========================================
  // TRAITEMENT D'UN CODE AFFILIÉ LORS DU SIGNUP
  // ==========================================

  /// Vérifie si un code donné correspond à un affilié
  Future<AffiliateProfile?> findAffiliateByCode(String rawCode) async {
    final cleanCode = rawCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    try {
      // 1. Recherche par index rapide
      final indexDoc = await _codesIndexRef.doc(cleanCode).get();
      if (indexDoc.exists) {
        final userId = indexDoc.data()?['userId'];
        if (userId != null) {
          final profileDoc = await _profilesRef.doc(userId).get();
          if (profileDoc.exists) {
            return AffiliateProfile.fromMap(profileDoc.data()!, id: profileDoc.id);
          }
        }
      }

      // 2. Recherche directe dans affiliate_profiles en cas de tolérance
      final query = await _profilesRef.where('affiliateCode', isEqualTo: cleanCode).limit(1).get();
      if (query.docs.isNotEmpty) {
        return AffiliateProfile.fromMap(query.docs.first.data(), id: query.docs.first.id);
      }
    } catch (e) {
      debugPrint('[AffiliateService] findAffiliateByCode error: $e');
    }
    return null;
  }

  /// Exécuté lorsqu'un filleul s'inscrit ou crée son entreprise avec le code de User X
  Future<bool> handleAffiliateReferral({
    required String rawCode,
    required String referredUserId,
    required String referredUserName,
    required String referredUserEmail,
    required String referredEnterpriseId,
    required String referredEnterpriseName,
  }) async {
    final cleanCode = rawCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    try {
      final referrer = await findAffiliateByCode(cleanCode);
      if (referrer == null) return false;

      // Empêcher l'auto-parrainage (User X ne peut pas utiliser son propre code)
      if (referrer.userId == referredUserId) {
        debugPrint('[AffiliateService] Self-referral prevented for UID: $referredUserId');
        return false;
      }

      // Vérifier si cette attribution a déjà été enregistrée pour cet utilisateur
      final existingReferral = await _referralsRef
          .where('referrerId', isEqualTo: referrer.userId)
          .where('referredUserId', isEqualTo: referredUserId)
          .limit(1)
          .get();

      if (existingReferral.docs.isNotEmpty) {
        debugPrint('[AffiliateService] Referral already recorded for user $referredUserId');
        return true;
      }

      final config = await getConfig();
      final commissionAmount = config.fixedRewardAmount;

      final referralId = 'ref_${referrer.userId}_${referredUserId}_${DateTime.now().millisecondsSinceEpoch}';
      final referral = AffiliateReferral(
        id: referralId,
        referrerId: referrer.userId,
        referrerCode: cleanCode,
        referredUserId: referredUserId,
        referredUserName: referredUserName,
        referredUserEmail: referredUserEmail,
        referredEnterpriseId: referredEnterpriseId,
        referredEnterpriseName: referredEnterpriseName,
        commissionAmount: commissionAmount,
        commissionType: 'cash',
        status: 'confirmed',
        benefitAwarded: config.referredUserBenefit,
        createdAt: DateTime.now(),
      );

      final batch = _firestore.batch();

      // 1. Enregistrer le parrainage
      batch.set(_referralsRef.doc(referralId), referral.toMap());

      // 2. Créditer atomiquement le portefeuille du parrain
      batch.update(_profilesRef.doc(referrer.userId), {
        'balanceCash': FieldValue.increment(commissionAmount),
        'totalEarned': FieldValue.increment(commissionAmount),
        'totalReferrals': FieldValue.increment(1),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // 3. Marquer le profil utilisateur et l'entreprise avec le parrain
      batch.update(_firestore.collection('users').doc(referredUserId), {
        'referredByUserId': referrer.userId,
        'affiliateCodeUsed': cleanCode,
        'affiliateBenefit': config.referredUserBenefit,
      });

      if (referredEnterpriseId.isNotEmpty) {
        batch.update(_firestore.collection('enterprises').doc(referredEnterpriseId), {
          'referredByUserId': referrer.userId,
          'affiliateCodeUsed': cleanCode,
        });
      }

      await batch.commit();
      debugPrint('[AffiliateService] Successfully rewarded referrer ${referrer.userName} with $commissionAmount DT');
      return true;
    } catch (e) {
      debugPrint('[AffiliateService] handleAffiliateReferral error: $e');
      return false;
    }
  }

  // ==========================================
  // SUPERADMIN MANAGEMENT
  // ==========================================

  /// Tous les affiliés avec leurs performances
  Stream<List<AffiliateProfile>> streamAllAffiliates() {
    return _profilesRef.snapshots().map((snap) {
      final list = snap.docs.map((d) => AffiliateProfile.fromMap(d.data(), id: d.id)).toList();
      list.sort((a, b) => b.totalEarned.compareTo(a.totalEarned));
      return list;
    });
  }

  /// Toutes les demandes de retrait pour le SuperAdmin
  Stream<List<AffiliatePayoutRequest>> streamAllPayoutRequests({PayoutStatus? statusFilter}) {
    return _payoutsRef.snapshots().map((snap) {
      var list = snap.docs.map((d) => AffiliatePayoutRequest.fromMap(d.data(), id: d.id)).toList();
      if (statusFilter != null) {
        list = list.where((p) => p.status == statusFilter).toList();
      }
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  /// Tous les événements de parrainage de la plateforme
  Stream<List<AffiliateReferral>> streamAllReferrals() {
    return _referralsRef.snapshots().map((snap) {
      final list = snap.docs.map((d) => AffiliateReferral.fromMap(d.data(), id: d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Traitement d'une demande de retrait par le SuperAdmin (Validation / Paiement / Rejet)
  Future<void> processPayoutRequest(
    String requestId, {
    required PayoutStatus status,
    String? adminNotes,
    String? transactionRef,
    String? processedBy,
  }) async {
    final doc = await _payoutsRef.doc(requestId).get();
    if (!doc.exists) return;

    final request = AffiliatePayoutRequest.fromMap(doc.data()!, id: doc.id);

    // Si rejeté, recréditer automatiquement le solde cash de l'affilié
    if (status == PayoutStatus.rejected && request.status != PayoutStatus.rejected) {
      await _profilesRef.doc(request.userId).update({
        'balanceCash': FieldValue.increment(request.amount),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }

    await _payoutsRef.doc(requestId).update({
      'status': status.id,
      'adminNotes': adminNotes,
      'transactionReference': transactionRef,
      'processedAt': DateTime.now().toIso8601String(),
      'processedBy': processedBy ?? 'Support SuperAdmin',
    });
  }

  // ==========================================
  // HELPERS PRIVÉS
  // ==========================================

  Future<String> _generateUniqueAffiliateCode(String? name) async {
    final random = Random();
    String base;
    if (name != null && name.trim().isNotEmpty) {
      base = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      if (base.length > 5) base = base.substring(0, 5);
      if (base.isEmpty) base = 'LOGI';
    } else {
      base = 'LOGI';
    }

    for (int i = 0; i < 10; i++) {
      final suffix = random.nextInt(9000) + 1000; // 4 chiffres
      final candidate = '$base$suffix';

      final exists = await _codesIndexRef.doc(candidate).get();
      if (!exists.exists) {
        return candidate;
      }
    }

    // Fallback avec timestamp
    return '$base${DateTime.now().millisecondsSinceEpoch % 10000}';
  }
}
