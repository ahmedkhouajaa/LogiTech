import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'enterprise_service.dart';

/// One-time migration service to ensure all legacy documents in Firestore
/// have both `userId` and `enterprise_id` assigned to the user's default workspace.
class MigrationService {
  static final MigrationService instance = MigrationService._();
  MigrationService._();

  static const List<String> erpCollections = [
    'quotes',
    'invoices',
    'customer_orders',
    'delivery_notes',
    'clients',
    'fournisseurs',
    'articles',
    'payments',
    'treasury_accounts',
    'treasury_transactions',
    'warehouses',
    'projects',
    'stock_entries',
    'stock_movements',
    'stock_withdrawals',
    'stock_transfers',
    'receiving_vouchers',
    'purchase_invoices',
    'supplier_orders',
    'credit_notes',
    'supplier_credit_notes',
    'return_notes',
    'supplier_returns',
    'inventory_sheets',
    'company_settings',
  ];

  Future<void> runEnterpriseMigration() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    if (currentEntId == null || currentEntId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;

    for (final col in erpCollections) {
      try {
        final snap = await firestore.collection(col).where('userId', isEqualTo: uid).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final bool needsUserId = !data.containsKey('userId') || data['userId'] == null || data['userId'].toString().isEmpty;
          final bool needsEnterpriseId = !data.containsKey('enterprise_id') || data['enterprise_id'] == null || data['enterprise_id'].toString().isEmpty;

          if (needsUserId || needsEnterpriseId) {
            final Map<String, dynamic> updates = {};
            if (needsUserId) {
              updates['userId'] = uid;
              updates['firebase_uid'] = uid;
            }
            if (needsEnterpriseId) {
              updates['enterprise_id'] = currentEntId;
            }
            updates['updated_at'] = DateTime.now().toIso8601String();

            await firestore.collection(col).doc(doc.id).set(updates, SetOptions(merge: true));
          }
        }
      } catch (e) {
        print('MigrationService warning for collection $col: $e');
      }
    }
  }
}
