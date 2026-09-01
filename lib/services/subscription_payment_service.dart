import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_payment.dart';
import 'enterprise_service.dart';

class SubscriptionPaymentService {
  static final SubscriptionPaymentService instance = SubscriptionPaymentService._();
  SubscriptionPaymentService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<SubscriptionPayment> _localPayments = [];
  final StreamController<List<SubscriptionPayment>> _paymentsController =
      StreamController<List<SubscriptionPayment>>.broadcast();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSubscription;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'local_user';
  String get _currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId ?? '';

  /// Stream of subscription payment records synced in real-time across Android, Desktop, and Web
  Stream<List<SubscriptionPayment>> getPaymentsStream() {
    _loadLocalCache();
    _startFirestoreSync();
    return _paymentsController.stream;
  }

  void _startFirestoreSync() {
    _firestoreSubscription?.cancel();

    final uid = _currentUserId;
    final entId = _currentEnterpriseId;

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('subscription_payments');

      // Filter by userId if authenticated, else enterpriseId
      if (uid.isNotEmpty && uid != 'local_user') {
        query = query.where('userId', isEqualTo: uid);
      } else if (entId.isNotEmpty) {
        query = query.where('enterpriseId', isEqualTo: entId);
      }

      // No .orderBy in firestore to avoid composite index requirement
      _firestoreSubscription = query.snapshots().listen(
        (snapshot) {
          final list = snapshot.docs
              .map((doc) => SubscriptionPayment.fromMap(doc.data(), doc.id))
              .toList();

          // In-memory sort by date descending
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _localPayments.clear();
          _localPayments.addAll(list);
          _saveLocalCache(list);
          _paymentsController.add(List.from(list));
        },
        onError: (error) {
          debugPrint('[SubscriptionPaymentService] Error streaming payments from Firestore: $error');
          _paymentsController.add(List.from(_localPayments));
        },
      );
    } catch (e) {
      debugPrint('[SubscriptionPaymentService] Stream init fallback: $e');
      _paymentsController.add(List.from(_localPayments));
    }
  }

  /// Records a payment attempt or request when user clicks "Contacter le support" or selects a payment method.
  /// Reuses existing pending payment for current cycle so only 1 record is created across all devices.
  Future<SubscriptionPayment> recordPaymentRequest({
    required String planName,
    required double amount,
    required String method,
    required int durationDays,
  }) async {
    final now = DateTime.now();
    final uid = _currentUserId;
    final entId = _currentEnterpriseId;

    String docId = '';
    DateTime createdAt = now;

    // 1. Check local cache for existing pending payment
    final existingLocalIndex = _localPayments.indexWhere((p) => p.status == 'pending');
    if (existingLocalIndex != -1) {
      docId = _localPayments[existingLocalIndex].id;
      createdAt = _localPayments[existingLocalIndex].createdAt;
    }

    // 2. Also check Firestore remotely to ensure cross-device consistency
    if (docId.isEmpty && uid.isNotEmpty && uid != 'local_user') {
      try {
        final remotePending = await _firestore
            .collection('subscription_payments')
            .where('userId', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (remotePending.docs.isNotEmpty) {
          final doc = remotePending.docs.first;
          docId = doc.id;
          final parsed = SubscriptionPayment.fromMap(doc.data(), doc.id);
          createdAt = parsed.createdAt;
        }
      } catch (e) {
        debugPrint('[SubscriptionPaymentService] Error checking remote pending payments: $e');
      }
    }

    // 3. If still no pending payment found, create a new document ID
    if (docId.isEmpty) {
      final docRef = _firestore.collection('subscription_payments').doc();
      docId = docRef.id;
      createdAt = now;
    }

    final payment = SubscriptionPayment(
      id: docId,
      enterpriseId: entId,
      userId: uid,
      planName: planName,
      amount: amount,
      method: method,
      status: 'pending',
      createdAt: createdAt,
      durationDays: durationDays,
    );

    // 4. Update in local cache & stream immediately
    final idx = _localPayments.indexWhere((p) => p.id == docId);
    if (idx != -1) {
      _localPayments[idx] = payment;
    } else {
      _localPayments.insert(0, payment);
    }
    _saveLocalCache(_localPayments);
    _paymentsController.add(List.from(_localPayments));

    // 5. Persist to Firestore to sync with Android, Web, and Desktop
    try {
      await _firestore.collection('subscription_payments').doc(docId).set(
            payment.toMap(),
            SetOptions(merge: true),
          );
      debugPrint('[SubscriptionPaymentService] Successfully synced payment $docId to Firestore');
    } catch (e) {
      debugPrint('[SubscriptionPaymentService] Firestore recordPaymentRequest error: $e');
    }

    return payment;
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'sub_payments_${_currentEnterpriseId}_$_currentUserId';
      final jsonStr = prefs.getString(key) ?? prefs.getString('sub_payments_$_currentEnterpriseId');
      if (jsonStr != null) {
        final List decoded = jsonDecode(jsonStr);
        _localPayments.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _localPayments.add(SubscriptionPayment.fromMap(item, item['id']?.toString() ?? ''));
          }
        }
        _paymentsController.add(List.from(_localPayments));
      }
    } catch (e) {
      debugPrint('[SubscriptionPaymentService] Error loading local cache: $e');
    }
  }

  Future<void> _saveLocalCache(List<SubscriptionPayment> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'sub_payments_${_currentEnterpriseId}_$_currentUserId';
      final maps = list.map((p) => p.toMap()..['id'] = p.id).toList();
      final sanitized = maps.map((m) {
        final copy = Map<String, dynamic>.from(m);
        if (copy['createdAt'] is Timestamp) {
          copy['createdAt'] = (copy['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (copy['paidAt'] is Timestamp) {
          copy['paidAt'] = (copy['paidAt'] as Timestamp).toDate().toIso8601String();
        }
        return copy;
      }).toList();
      await prefs.setString(key, jsonEncode(sanitized));
    } catch (e) {
      debugPrint('[SubscriptionPaymentService] Error saving local cache: $e');
    }
  }
}
