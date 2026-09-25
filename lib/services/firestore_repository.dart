import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'enterprise_service.dart';
import '../database/database_helper.dart';
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
import '../models/supplier_order.dart';
import '../models/purchase_invoice.dart';
import '../models/supplier_return.dart';
import '../models/inventory_sheet.dart';
import '../models/payment_model.dart';
import '../models/stock_entry.dart';
import 'trash_service.dart';

import 'user_tracking_service.dart';

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
    final isNew = !data.containsKey('created_at') || data['created_at'] == null;
    final payload = _withMetadata(data);
    if (isNew) {
      payload['created_at'] = DateTime.now().toIso8601String();
    }
    await _firestore.collection(collection).doc(id).set(payload, SetOptions(merge: true));

    // Audit log
    unawaited(UserTrackingService.instance.logActivity(
      action: isNew ? 'create' : 'update',
      collection: collection,
      documentId: id,
      docData: data,
    ));
  }

  Future<void> updateDocument(String collection, String id, Map<String, dynamic> data) async {
    final payload = _withMetadata(data);
    await _firestore.collection(collection).doc(id).update(payload);

    // Audit log
    unawaited(UserTrackingService.instance.logActivity(
      action: 'update',
      collection: collection,
      documentId: id,
      docData: data,
    ));
  }

  Future<void> softDeleteDocument(String collection, String id) async {
    try {
      await TrashService.instance.moveToTrash(collection, id);
    } catch (e) {
      if (e.toString().contains('permission-denied') || e.toString().contains('not-found')) {
        // If the document is already deleted on the server, update() might throw permission-denied or not-found.
        // We call delete() to forcefully wipe it from the local Firestore cache.
        await _firestore.collection(collection).doc(id).delete();
      } else {
        rethrow;
      }
    }

    try {
      await DatabaseHelper.instance.resetDocSequenceIfEmpty(collection);
    } catch (_) {}
  }

  Future<void> deleteDocument(String collection, String id) async {
    await _firestore.collection(collection).doc(id).delete();
    try {
      await DatabaseHelper.instance.resetDocSequenceIfEmpty(collection);
    } catch (_) {}
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

  Future<void> saveStockWithdrawal(StockWithdrawal withdrawal) async {
    final map = withdrawal.toMap();
    final collection = withdrawal.number.startsWith('BP-') ? 'bons_prelevement' : 'bons_sortie';
    await saveDocument(collection, withdrawal.id, map);
  }

  Future<void> saveStockTransfer(StockTransfer transfer) async {
    final map = transfer.toMap();
    await saveDocument('stock_transfers', transfer.id, map);
  }

  Future<void> saveInventorySheet(InventorySheet sheet) async {
    final map = sheet.toMap();
    await saveDocument('inventory_sheets', sheet.id, map);
  }

  Future<void> saveCreditNote(CreditNote creditNote) async {
    final map = creditNote.toMap();
    await saveDocument('credit_notes', creditNote.id, map);
  }

  Future<void> saveReturnNote(ReturnNote returnNote) async {
    final map = returnNote.toMap();
    await saveDocument('return_notes', returnNote.id, map);
  }

  Future<void> saveSupplierOrder(SupplierOrder order) async {
    final map = order.toMap();
    await saveDocument('supplier_orders', order.id, map);
  }

  Future<void> saveReceivingVoucher(ReceivingVoucher voucher) async {
    final map = voucher.toMap();
    await saveDocument('receiving_vouchers', voucher.id, map);
  }

  Future<void> savePurchaseInvoice(PurchaseInvoice invoice) async {
    final map = invoice.toMap();
    await saveDocument('purchase_invoices', invoice.id, map);
  }

  Future<void> saveSupplierCreditNote(SupplierCreditNote note) async {
    final map = note.toMap();
    await saveDocument('supplier_credit_notes', note.id, map);
  }

  Future<void> saveSupplierReturn(SupplierReturn item) async {
    final map = item.toMap();
    await saveDocument('supplier_returns', item.id, map);
  }

  Future<void> savePayment(Payment payment) async {
    final map = payment.toMap();
    await saveDocument('paiements', payment.id, map);
  }

  Future<void> saveStockEntry(StockEntry entry) async {
    final map = entry.toMap();
    await saveDocument('stock_entries', entry.id, map);
  }
}
