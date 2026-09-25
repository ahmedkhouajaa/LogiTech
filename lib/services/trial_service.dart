import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../screens/subscription_screen.dart';

class TrialInfo {
  final DateTime trialStartDate;
  final DateTime trialEndDate;
  final String plan; // 'trial', 'pro', 'enterprise', 'annual', 'monthly'
  final bool isUpgraded;

  TrialInfo({
    required this.trialStartDate,
    required this.trialEndDate,
    this.plan = 'trial',
    this.isUpgraded = false,
  });

  int get daysRemaining {
    final now = DateTime.now();
    if (!now.isBefore(trialEndDate)) return 0;
    final diff = trialEndDate.difference(now);
    final days = (diff.inHours / 24).ceil();
    return days < 0 ? 0 : days;
  }

  bool get isTrial => !isUpgraded || plan == 'trial' || plan == 'free';
  bool get isVip =>
      plan.toLowerCase().trim() == 'vip' ||
      plan.toLowerCase().trim().contains('vip') ||
      daysRemaining >= 3000;

  /// Whether the license or trial is expired (not VIP and trialEndDate has passed)
  bool get isExpired {
    if (isVip) return false;
    return !DateTime.now().isBefore(trialEndDate);
  }

  /// Whether creation of new items is allowed (VIP or days remaining)
  bool get canCreateNewItems => isVip || DateTime.now().isBefore(trialEndDate);

  bool get isTrialExpired => isExpired;
  bool get isTrialActive => isTrial && !isExpired;
  bool get isSubscriptionActive => !isTrial && !isExpired;
  bool get isSubscriptionExpired => !isTrial && isExpired;

  Map<String, dynamic> toMap() => {
        'trialStartDate': Timestamp.fromDate(trialStartDate),
        'trialEndDate': Timestamp.fromDate(trialEndDate),
        'plan': plan,
        'subscriptionPlan': plan,
        'isUpgraded': isUpgraded,
        'isVip': isVip,
      };

  factory TrialInfo.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val != null) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final start = parseDate(map['trialStartDate'] ?? map['createdAt']);
    final end = map['trialEndDate'] != null
        ? parseDate(map['trialEndDate'])
        : start.add(const Duration(days: 7));

    // Check multiple potential keys for plan
    final rawPlan = map['plan'] ??
        map['subscriptionPlan'] ??
        map['subscriptionTier'] ??
        (map['isVip'] == true ? 'vip' : 'trial');
    final planStr = rawPlan.toString().toLowerCase().trim();

    final isVipFlag = map['isVip'] == true ||
        planStr == 'vip' ||
        planStr.contains('vip') ||
        end.difference(DateTime.now()).inDays >= 3000;

    final resolvedPlan = isVipFlag ? 'vip' : planStr;

    final isUpgraded = isVipFlag ||
        map['isUpgraded'] == true ||
        (resolvedPlan != 'trial' && resolvedPlan != 'free' && resolvedPlan.isNotEmpty);

    return TrialInfo(
      trialStartDate: start,
      trialEndDate: end,
      plan: resolvedPlan,
      isUpgraded: isUpgraded,
    );
  }
}

/// Service to handle 7-Day Free Trial, Countdown, and Action Restrictions
class TrialService {
  static final TrialService instance = TrialService._();
  TrialService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValueNotifier<TrialInfo?> trialNotifier = ValueNotifier<TrialInfo?>(null);
  StreamSubscription<DocumentSnapshot>? _trialDocSub;
  StreamSubscription<String?>? _entSub;

  TrialInfo? _currentTrial;
  TrialInfo? get currentTrial => _currentTrial ?? trialNotifier.value;

  /// Check if the trial or subscription is expired
  bool get isExpired => currentTrial?.isExpired ?? false;

  /// Backward compatible alias
  bool get isTrialExpired => isExpired;

  /// Check if plan is upgraded
  bool get isPlanUpgraded => currentTrial?.isUpgraded ?? false;

  /// Check if user has active trial, subscription, or VIP access to create new items
  bool get canCreateItems => currentTrial?.canCreateNewItems ?? (!isExpired);

  /// Days remaining in trial or subscription
  int get daysRemaining => currentTrial?.daysRemaining ?? (isExpired ? 0 : 7);

  /// Initialize trial status for current user / enterprise
  Future<void> initTrial() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final entId = EnterpriseService.instance.currentEnterpriseId;
      final prefs = await SharedPreferences.getInstance();

      // 1. Try local cache first for immediate UI responsiveness
      final cachedEndStr = prefs.getString('trial_end_date_$entId');
      final cachedUpgraded = prefs.getBool('trial_upgraded_$entId') ?? false;
      final cachedPlan = prefs.getString('trial_plan_$entId') ?? (cachedUpgraded ? 'annual' : 'trial');

      if (cachedEndStr != null) {
        final cachedEnd = DateTime.tryParse(cachedEndStr) ?? DateTime.now().add(const Duration(days: 7));
        _currentTrial = TrialInfo(
          trialStartDate: cachedEnd.subtract(const Duration(days: 7)),
          trialEndDate: cachedEnd,
          plan: cachedPlan,
          isUpgraded: cachedUpgraded || cachedPlan == 'vip',
        );
        trialNotifier.value = _currentTrial;
      }

      // 2. Fetch from Firestore (Enterprise doc or User doc)
      if (entId != null && entId.isNotEmpty) {
        _startRealtimeTrialListener(entId);

        _entSub?.cancel();
        _entSub = EnterpriseService.instance.enterpriseStream.listen((newEntId) {
          _startRealtimeTrialListener(newEntId);
        });

        final entDoc = await _firestore.collection('enterprises').doc(entId).get();
        if (entDoc.exists && entDoc.data() != null) {
          final data = entDoc.data()!;
          if (data['trialEndDate'] != null || data['plan'] != null) {
            _updateFromMap(data, entId);
            return;
          }
        }

        // Initialize 7-day trial in Firestore if doc missing trialEndDate
        final now = DateTime.now();
        final trialEnd = now.add(const Duration(days: 7));
        final newTrialMap = {
          'trialStartDate': Timestamp.fromDate(now),
          'trialEndDate': Timestamp.fromDate(trialEnd),
          'plan': 'trial',
          'isUpgraded': false,
        };

        await _firestore.collection('enterprises').doc(entId).set(newTrialMap, SetOptions(merge: true));
        _updateFromMap(newTrialMap, entId);
        return;
      }

      // Fallback for user level if no enterprise ID yet
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          _updateFromMap(userDoc.data()!, user.uid);
          return;
        }
      }

      // Final default: 7-day trial from now
      final now = DateTime.now();
      _currentTrial = TrialInfo(
        trialStartDate: now,
        trialEndDate: now.add(const Duration(days: 7)),
      );
      trialNotifier.value = _currentTrial;
    } catch (e) {
      debugPrint('[TrialService] Error initializing trial: $e');
      if (_currentTrial == null) {
        final now = DateTime.now();
        _currentTrial = TrialInfo(
          trialStartDate: now,
          trialEndDate: now.add(const Duration(days: 7)),
        );
        trialNotifier.value = _currentTrial;
      }
    }
  }

  void _startRealtimeTrialListener(String? entId) {
    _trialDocSub?.cancel();
    _trialDocSub = null;
    if (entId == null || entId.isEmpty) return;

    _trialDocSub = _firestore.collection('enterprises').doc(entId).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        _updateFromMap(snap.data()!, entId);
      }
    }, onError: (e) {
      debugPrint('[TrialService] Error in realtime trial listener: $e');
    });
  }

  void _updateFromMap(Map<String, dynamic> map, String keyId) async {
    final info = TrialInfo.fromMap(map);
    _currentTrial = info;
    trialNotifier.value = info;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trial_end_date_$keyId', info.trialEndDate.toIso8601String());
    await prefs.setBool('trial_upgraded_$keyId', info.isUpgraded);
    await prefs.setString('trial_plan_$keyId', info.plan);
  }

  /// Check if creating an item is allowed.
  /// Returns true if VIP or trial/subscription active with days remaining.
  /// If expired, displays upgrade modal and returns false.
  bool checkCanCreate(BuildContext context) {
    if (canCreateItems) return true;
    showTrialExpiredModal(context);
    return false;
  }

  /// Backward compatible alias for action checking
  bool checkActionAllowed(BuildContext context) => checkCanCreate(context);

  /// Show the Trial/Subscription Expired upgrade modal / dialog
  void showTrialExpiredModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Abonnement requis',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
              onPressed: () => Navigator.pop(ctx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Text(
            'Votre période d\'essai ou abonnement est arrivé à expiration. Veuillez renouveler votre offre pour continuer à créer de nouveaux éléments.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Renouveler l\'abonnement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
