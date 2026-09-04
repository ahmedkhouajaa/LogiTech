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
    if (now.isAfter(trialEndDate)) return 0;
    final diffDays = trialEndDate.difference(now).inDays;
    return diffDays < 0 ? 0 : diffDays;
  }

  bool get isTrial => !isUpgraded || plan == 'trial' || plan == 'free';
  bool get isVip =>
      plan.toLowerCase().trim() == 'vip' ||
      plan.toLowerCase().trim().contains('vip') ||
      daysRemaining >= 3000;
  bool get isTrialExpired => isTrial && daysRemaining <= 0;
  bool get isTrialActive => isTrial && daysRemaining > 0;
  bool get isSubscriptionActive => !isTrial && (isVip || daysRemaining > 0);
  bool get isSubscriptionExpired => !isTrial && !isVip && daysRemaining <= 0;

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

  /// Check if trial is expired
  bool get isTrialExpired => currentTrial?.isTrialExpired ?? false;

  /// Check if plan is upgraded
  bool get isPlanUpgraded => currentTrial?.isUpgraded ?? false;

  /// Days remaining in trial or subscription
  int get daysRemaining => currentTrial?.daysRemaining ?? 7;

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

  /// Check if an action (create, update, delete) is allowed.
  /// Returns true if trial is active or plan is upgraded.
  /// If trial is expired, displays upgrade modal and returns false.
  bool checkActionAllowed(BuildContext context) {
    if (!isTrialExpired) return true;
    showTrialExpiredModal(context);
    return false;
  }

  /// Show the Trial Expired upgrade modal / dialog
  void showTrialExpiredModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFFDEDEC),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFE74C3C), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Période d\'essai expirée',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre période d\'essai gratuite de 7 jours est terminée.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Pour continuer à ajouter, modifier ou supprimer des données, veuillez mettre à niveau votre plan. Vous pouvez toujours consulter vos données existantes.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer (Mode lecture)'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // Open Support / Upgrade ticket
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Mettre à niveau mon plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      ),
    );
  }
}
