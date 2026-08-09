import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'enterprise_service.dart';
import '../models/quote.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../models/customer_order.dart';
import '../models/delivery_note.dart';
import '../models/receiving_voucher.dart';
import '../models/stock_withdrawal.dart';
import '../models/stock_transfer.dart';
import '../models/credit_note.dart';
import '../models/supplier_credit_note.dart';
import '../models/return_note.dart';
import '../models/supplier_return.dart';
import '../models/inventory_sheet.dart';
import '../models/stock_movement.dart';
import '../models/treasury_account.dart';
import '../models/treasury_transaction.dart';
import '../models/payment_model.dart';
import '../models/check_traite.dart';
import '../models/project.dart';

class FirestoreRepository {
  static final FirestoreRepository instance = FirestoreRepository._();
  FirestoreRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId;

  Map<String, dynamic> _withMetadata(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final uid = currentUid;
    final entId = currentEnterpriseId;

    if (uid != null && uid.isNotEmpty) {
      map['userId'] = uid;
      map['firebase_uid'] = uid;
    }
    if (entId != null && entId.isNotEmpty) {
      map['enterprise_id'] = entId;
    }
    map['updated_at'] = DateTime.now().toIso8601String();
    return map;
  }

  Future<void> saveDocument(String collection, String id, Map<String, dynamic> data) async {
    final payload = _withMetadata(data);
    if (!payload.containsKey('created_at') || payload['created_at'] == null) {
      payload['created_at'] = DateTime.now().toIso8601String();
    }
    await _firestore.collection(collection).doc(id).set(payload, SetOptions(merge: true));
  }

  Future<void> updateDocument(String collection, String id, Map<String, dynamic> data) async {
    final payload = _withMetadata(data);
    await _firestore.collection(collection).doc(id).update(payload);
  }

  Future<void> softDeleteDocument(String collection, String id) async {
    await _firestore.collection(collection).doc(id).update({
      'is_deleted': 1,
      'updated_at': DateTime.now().toIso8601String(),
      if (currentUid != null) 'userId': currentUid,
    });
  }

  Future<void> deleteDocument(String collection, String id) async {
    await _firestore.collection(collection).doc(id).delete();
  }

  // Helper Entity Persistence
  Future<void> saveQuote(Quote quote) async {
    final map = quote.toMap();
    await saveDocument('quotes', quote.id, map);
  }

  Future<void> saveInvoice(Invoice invoice) async {
    final map = invoice.toMap();
    await saveDocument('invoices', invoice.id, map);
  }

  Future<void> saveCustomer(Customer customer) async {
    final map = customer.toMap();
    await saveDocument('clients', customer.id, map);
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final map = supplier.toMap();
    await saveDocument('fournisseurs', supplier.id, map);
  }

  Future<void> saveProduct(Product product) async {
    final map = product.toMap();
    await saveDocument('articles', product.id, map);
  }

  Future<void> saveCustomerOrder(CustomerOrder order) async {
    final map = order.toMap();
    await saveDocument('customer_orders', order.id, map);
  }

  Future<void> saveDeliveryNote(DeliveryNote note) async {
    final map = note.toMap();
    await saveDocument('delivery_notes', note.id, map);
  }
}
