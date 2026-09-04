import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Billing & Subscription Validation Service for SuperAdmin and Support Leads
class AdminBillingService {
  static final AdminBillingService instance = AdminBillingService._();
  AdminBillingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _currentAgentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _currentAgentEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  /// Validates a payment request (e.g. Bank Transfer) and immediately extends the enterprise license
  Future<void> validatePaymentAndExtendLicense({
    required String paymentId,
    required String enterpriseId,
    required int durationDays,
    required String reason,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final newEndDate = now.add(Duration(days: durationDays));

    // 1. Mark payment record as 'paid'
    final paymentRef = _firestore.collection('subscription_payments').doc(paymentId);
    batch.update(paymentRef, {
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'validatedBy': _currentAgentEmail,
      'validationReason': reason,
    });

    // 2. Extend Enterprise license/subscription
    final enterpriseRef = _firestore.collection('enterprises').doc(enterpriseId);
    batch.update(enterpriseRef, {
      'trialEndDate': Timestamp.fromDate(newEndDate),
      'isUpgraded': true,
      'plan': durationDays >= 365 ? 'annual' : 'monthly',
      'lastPaymentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. Append to Audit Logs
    final auditRef = _firestore.collection('audit_logs').doc();
    batch.set(auditRef, {
      'agentId': _currentAgentUid,
      'agentEmail': _currentAgentEmail,
      'targetEnterpriseId': enterpriseId,
      'paymentId': paymentId,
      'action': 'VALIDATE_PAYMENT',
      'durationDays': durationDays,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('[AdminBillingService] Successfully validated payment $paymentId for enterprise $enterpriseId');
  }

  /// Rejects or cancels a payment attempt
  Future<void> rejectPayment({
    required String paymentId,
    required String reason,
  }) async {
    await _firestore.collection('subscription_payments').doc(paymentId).update({
      'status': 'failed',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': _currentAgentEmail,
      'rejectionReason': reason,
    });
  }
}
