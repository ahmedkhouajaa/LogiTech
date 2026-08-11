import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/enterprise_service.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/purchase_invoice.dart';
import '../models/quote.dart';
import '../models/customer_order.dart';
import '../models/delivery_note.dart';
import '../models/supplier_order.dart';
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
import '../models/project.dart';
import '../models/check_traite.dart';
import '../models/project.dart';
import '../models/document_template.dart';
import '../models/product_family.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId;

  String get newId => _firestore.collection('tmp').doc().id;

  // Database stubs
  Future<dynamic> get database async => null;
  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async => [];
  Future<int> insert(String table, Map<String, dynamic> data, {dynamic conflictAlgorithm}) async => 1;
  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async => 1;
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async => 1;
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async => [];
  Future<void> softDelete(String table, String id) async {}
  Future<void> addToSyncQueue(String table, String id, String op, Map<String, dynamic> data) async {}
  Future<dynamic> getById(String table, String id) async => null;

  // Quotes
  Future<List<Quote>> getQuotes() async => [];
  Future<List<Quote>> getQuotesPaginated({int limit = 10, int offset = 0, String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status}) async => [];
  Future<int> getQuotesCount({String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status}) async => 0;
  Future<void> insertQuote(dynamic quote) async {}
  Future<void> updateQuote(dynamic quote) async {}
  Future<int> getNextQuoteSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'quotes');

  // Invoices
  Future<List<Invoice>> getInvoices() async => [];
  Future<List<Invoice>> getInvoicesPaginated({int limit = 10, int offset = 0, String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status}) async => [];
  Future<int> getInvoicesCount({String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status}) async => 0;
  Future<void> insertInvoice(dynamic invoice) async {}
  Future<void> updateInvoice(dynamic invoice) async {}
  Future<void> deleteInvoice(String id) async {}
  Future<Invoice?> getInvoice(String id) async => null;
  Future<dynamic> convertInvoiceToCreditNote(dynamic inv, [dynamic arg2]) async => null;
  Future<int> getNextInvoiceSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'invoices');
  Future<int> getNextCreditNoteSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'credit_notes');

  // Purchase Invoices
  Future<List<PurchaseInvoice>> getPurchaseInvoices() async => [];
  Future<List<PurchaseInvoice>> getPurchaseInvoicesPaginated({int limit = 10, int offset = 0, String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status}) async => [];
  Future<int> getPurchaseInvoicesCount({String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status}) async => 0;
  Future<void> insertPurchaseInvoice(dynamic invoice) async {}
  Future<void> updatePurchaseInvoice(dynamic invoice) async {}
  Future<void> deletePurchaseInvoice(String id) async {}
  Future<PurchaseInvoice?> getPurchaseInvoice(String id) async => null;
  Future<dynamic> convertPurchaseInvoiceToCreditNote(dynamic inv, [dynamic arg2]) async => null;
  Future<int> getNextPurchaseInvoiceSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'purchase_invoices');

  // Customer orders
  Future<List<CustomerOrder>> getCustomerOrders({String? status, String? customerId, DateTime? startDate, DateTime? endDate}) async => [];
  Future<List<CustomerOrder>> getCustomerOrdersPaginated({int limit = 10, int offset = 0, String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => [];
  Future<int> getCustomerOrdersCount({String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => 0;
  Future<CustomerOrder?> getCustomerOrder(String id) async => null;
  Future<void> insertCustomerOrder(dynamic item) async {}
  Future<void> updateCustomerOrder(dynamic item) async {}
  Future<int> getNextCustomerOrderSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'customer_orders');

  // Delivery Notes
  Future<List<DeliveryNote>> getDeliveryNotes({String? status, String? customerId, DateTime? startDate, DateTime? endDate}) async => [];
  Future<List<DeliveryNote>> getDeliveryNotesPaginated({int limit = 10, int offset = 0, String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => [];
  Future<int> getDeliveryNotesCount({String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => 0;
  Future<DeliveryNote?> getDeliveryNote(String id) async => null;
  Future<void> insertDeliveryNote(dynamic item) async {}
  Future<void> updateDeliveryNote(dynamic item) async {}
  Future<int> getTotalDeliveryNotes() async => 0;
  Future<int> getNextDeliveryNoteSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'delivery_notes');

  // Supplier Orders
  Future<List<SupplierOrder>> getSupplierOrders({String? status, String? supplierId, DateTime? startDate, DateTime? endDate}) async => [];
  Future<List<SupplierOrder>> getSupplierOrdersPaginated({int limit = 10, int offset = 0, String? searchQuery, String? supplierId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => [];
  Future<int> getSupplierOrdersCount({String? searchQuery, String? supplierId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => 0;
  Future<SupplierOrder?> getSupplierOrderById(String id) async => null;
  Future<void> insertSupplierOrder(dynamic item) async {}
  Future<void> updateSupplierOrder(dynamic item) async {}
  Future<int> getNextSupplierOrderSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'supplier_orders');

  // Receiving Vouchers
  Future<List<ReceivingVoucher>> getReceivingVouchers() async => [];
  Future<List<dynamic>> getReceivingVouchersPaginated({int limit = 10, int offset = 0, String? searchQuery, String? supplierId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => [];
  Future<int> getReceivingVouchersCount({String? searchQuery, String? supplierId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => 0;
  Future<dynamic> getReceivingVoucher(String id) async => null;
  Future<void> insertReceivingVoucher(dynamic item, [dynamic arg2]) async {}
  Future<void> updateReceivingVoucher(dynamic item, [dynamic arg2]) async {}
  Future<int> getNextReceivingVoucherSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'receiving_vouchers');

  // Stock Withdrawals
  Future<List<StockWithdrawal>> getStockWithdrawals({String? status, DateTime? startDate, DateTime? endDate}) async => [];
  Future<List<StockWithdrawal>> getStockWithdrawalsPaginated({int limit = 10, int offset = 0, String? searchQuery, DateTime? dateFrom, DateTime? dateTo, String? status, String? customerId, String? numberPrefix, DateTime? startDate, DateTime? endDate}) async => [];
  Future<int> getStockWithdrawalsCount({String? searchQuery, DateTime? dateFrom, DateTime? dateTo, String? status, String? customerId, String? numberPrefix, DateTime? startDate, DateTime? endDate}) async => 0;
  Future<StockWithdrawal?> getStockWithdrawal(String id) async => null;
  Future<int> getNextStockWithdrawalSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'bons_prelevement');
  Future<int> getNextExitVoucherSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'bons_sortie');

  // Credit Notes & Return Notes
  Future<List<CreditNote>> getCreditNotes() async => [];
  Future<List<CreditNote>> getCreditNotesPaginated({int limit = 10, int offset = 0, String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status, String? numberPrefix}) async => [];
  Future<int> getCreditNotesCount({String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status, String? numberPrefix}) async => 0;
  Future<CreditNote?> getCreditNote(String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('credit_notes').doc(id).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = doc.id;
        return CreditNote.fromMap(data);
      }
    } catch (_) {}
    return null;
  }
  Future<void> insertCreditNote(dynamic item) async {}
  Future<void> updateCreditNote(dynamic item) async {}

  Future<List<SupplierCreditNote>> getSupplierCreditNotes() async => [];
  Future<List<SupplierCreditNote>> getSupplierCreditNotesPaginated({int limit = 10, int offset = 0, String? searchQuery, String? supplierId, DateTime? dateFrom, DateTime? dateTo, String? status, String? numberPrefix}) async => [];
  Future<int> getSupplierCreditNotesCount({String? searchQuery, String? supplierId, DateTime? dateFrom, DateTime? dateTo, String? status, String? numberPrefix}) async => 0;
  Future<SupplierCreditNote?> getSupplierCreditNoteById(String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('supplier_credit_notes').doc(id).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = doc.id;
        return SupplierCreditNote.fromMap(data);
      }
    } catch (_) {}
    return null;
  }
  Future<void> insertSupplierCreditNote(dynamic item) async {}
  Future<void> updateSupplierCreditNote(dynamic item) async {}
  Future<void> deleteSupplierCreditNote(String id) async {}
  Future<int> getNextSupplierCreditNoteSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'supplier_credit_notes');

  Future<List<ReturnNote>> getReturnNotes({String? status, String? customerId, DateTime? startDate, DateTime? endDate}) async => [];
  Future<List<ReturnNote>> getReturnNotesPaginated({int limit = 10, int offset = 0, String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => [];
  Future<int> getReturnNotesCount({String? searchQuery, String? customerId, DateTime? dateFrom, DateTime? dateTo, String? status, DateTime? startDate, DateTime? endDate}) async => 0;
  Future<ReturnNote?> getReturnNote(String id) async => null;
  Future<void> insertReturnNote(dynamic item) async {}
  Future<void> updateReturnNote(dynamic item) async {}
  Future<void> deleteReturnNote(String id) async {}
  Future<int> getNextReturnNoteSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'return_notes');

  Future<List<SupplierReturn>> getSupplierReturns() async => [];
  Future<List<SupplierReturn>> getSupplierReturnsPaginated({int limit = 10, int offset = 0, String? searchQuery, String? supplierId, DateTime? dateFrom, DateTime? dateTo, String? status}) async => [];
  Future<int> getSupplierReturnsCount({String? searchQuery, String? supplierId, DateTime? dateFrom, DateTime? dateTo, String? status}) async => 0;
  Future<SupplierReturn?> getSupplierReturn(String id) async => null;
  Future<void> insertSupplierReturn(dynamic item) async {}
  Future<void> updateSupplierReturn(dynamic item) async {}
  Future<void> deleteSupplierReturn(String id) async {}
  Future<int> getNextSupplierReturnSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'supplier_returns');

  // Inventory & Transfers
  Future<List<InventorySheet>> getInventorySheets() async => [];
  Future<List<InventorySheet>> getInventorySheetsPaginated({int limit = 10, int offset = 0, String? searchQuery, DateTime? dateFrom, DateTime? dateTo, String? status}) async => [];
  Future<int> getInventorySheetsCount({String? searchQuery, DateTime? dateFrom, DateTime? dateTo, String? status}) async => 0;
  Future<void> insertInventorySheet(dynamic item) async {}
  Future<void> updateInventorySheet(dynamic item) async {}
  Future<void> deleteInventorySheet(String id) async {}

  Future<List<StockTransfer>> getStockTransfers() async => [];
  Future<List<StockTransfer>> getStockTransfersPaginated({int limit = 10, int offset = 0, String? searchQuery, DateTime? dateFrom, DateTime? dateTo, String? status}) async => [];
  Future<int> getStockTransfersCount({String? searchQuery, DateTime? dateFrom, DateTime? dateTo, String? status}) async => 0;
  Future<void> insertStockTransfer(dynamic item) async {}
  Future<void> updateStockTransfer(dynamic item) async {}
  Future<void> deleteStockTransfer(String id) async {}

  // Treasury & Categories
  Future<List<dynamic>> getTreasuryAccountsPaginated({int limit = 10, int offset = 0, String? searchQuery}) async => [];
  Future<int> getTreasuryAccountsCount({String? searchQuery}) async => 0;
  Future<void> createTreasuryAccount(dynamic item, [dynamic arg2]) async {}
  Future<void> updateTreasuryAccount(dynamic item, [dynamic arg2]) async {}
  Future<void> deleteTreasuryAccount(String id) async {}

  Future<List<dynamic>> getTreasuryTransactions() async => [];
  Future<List<dynamic>> getTreasuryTransactionsPaginated(dynamic a1, [dynamic a2, dynamic a3, dynamic a4]) async => [];
  Future<int> getTreasuryTransactionsCount(dynamic a1, [dynamic a2]) async => 0;
  Future<void> createTreasuryTransaction(dynamic item, [dynamic arg2]) async {}
  Future<void> deleteTreasuryTransaction(String id) async {}

  Future<List<dynamic>> getTransactionCategories() async => [];
  Future<void> createTransactionCategory(dynamic item) async {}
  Future<void> deleteTransactionCategory(String id) async {}

  // Customers & Suppliers & Products
  Future<List<Customer>> getCustomers() async => [];
  Future<List<Customer>> getCustomersPaginated({int limit = 10, int offset = 0, String? searchQuery, String? category, String? city}) async => [];
  Future<int> getCustomersCount({String? searchQuery, String? category, String? city}) async => 0;
  Future<Customer?> getCustomer(String id) async => null;
  Future<void> insertCustomer(dynamic customer) async {}
  Future<void> updateCustomer(dynamic customer) async {}
  Future<void> deleteCustomer(String id) async {}
  Future<String> getNextCustomerSequence() async {
    final uid = currentUid;
    final currentEntId = currentEnterpriseId;
    Query query = _firestore.collection('clients');
    if (uid != null && uid.isNotEmpty) {
      query = query.where('userId', isEqualTo: uid);
    }
    if (currentEntId != null && currentEntId.isNotEmpty) {
      query = query.where('enterprise_id', isEqualTo: currentEntId);
    }
    query = query.where('is_deleted', isEqualTo: 0);

    try {
      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      int maxNum = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final code = (data['code'] ?? data['clientCode'] ?? '').toString();
        final match = RegExp(r'(?:CL|CLI)-?(\d+)', caseSensitive: false).firstMatch(code) ?? RegExp(r'(\d+)').firstMatch(code);
        if (match != null) {
          final num = int.tryParse(match.group(1)!) ?? 0;
          if (num > maxNum && num < 100000) maxNum = num;
        }
      }
      final nextNum = maxNum == 0 ? 1 : maxNum + 1;
      return 'CL-${nextNum.toString().padLeft(3, '0')}';
    } catch (e) {
      return 'CL-001';
    }
  }

  Future<int> generateNextDocSequenceAtomic(String? currentEntId, String docCollection) async {
    String entId = currentEntId ?? currentEnterpriseId ?? 'default';
    if (entId.isEmpty) entId = 'default';
    final counterRef = _firestore.collection('enterprises').doc(entId).collection('counters').doc(docCollection);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);
        int currentCount = 0;

        if (snapshot.exists && snapshot.data() != null && snapshot.data()!['count'] != null) {
          currentCount = (snapshot.data()!['count'] as num).toInt();
        } else {
          // Counter document does not exist yet. Initialize from existing records if any
          final querySnap = await _firestore
              .collection(docCollection)
              .where('enterprise_id', isEqualTo: entId)
              .get(const GetOptions(source: Source.server));

          for (var doc in querySnap.docs) {
            final data = doc.data();
            final number = (data['number'] ?? data['transaction_number'] ?? data['transactionNumber'] ?? '').toString();
            final parts = number.split('-');
            if (parts.length >= 3) {
              final numVal = int.tryParse(parts.last) ?? 0;
              if (numVal > currentCount && numVal < 100000) {
                currentCount = numVal;
              }
            }
          }
        }

        final nextCount = currentCount + 1;
        transaction.set(counterRef, {'count': nextCount}, SetOptions(merge: true));
        return nextCount;
      });
    } catch (e) {
      print('❌ [DEBUG] generateNextDocSequenceAtomic failed for $docCollection: $e');
      return DateTime.now().millisecondsSinceEpoch % 1000000;
    }
  }

  Future<String> generateNextCustomerSequenceAtomic(String? currentEntId) async {
    String entId = currentEntId ?? currentEnterpriseId ?? 'default';
    if (entId.isEmpty) entId = 'default';
    final counterRef = _firestore.collection('enterprises').doc(entId).collection('counters').doc('clients');
    
    try {
      // 1. Ensure counter is initialized if it doesn't exist
      final counterSnap = await counterRef.get(const GetOptions(source: Source.server));
      if (!counterSnap.exists) {
        // Find current max to initialize
        int maxNum = 0;
        final querySnap = await _firestore.collection('clients')
            .where('enterprise_id', isEqualTo: entId)
            .get(const GetOptions(source: Source.server));
            
        for (var doc in querySnap.docs) {
          final data = doc.data();
          final code = (data['code'] ?? data['clientCode'] ?? '').toString();
          final match = RegExp(r'(?:CL|CLI)-?(\d+)', caseSensitive: false).firstMatch(code) ?? RegExp(r'(\d+)').firstMatch(code);
          if (match != null) {
            final num = int.tryParse(match.group(1)!) ?? 0;
            if (num > maxNum && num < 100000) maxNum = num;
          }
        }
        await counterRef.set({'count': maxNum}, SetOptions(merge: true));
      }

      // 2. Atomically increment and get the exact unique code
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);
        int currentCount = 0;
        if (snapshot.exists && snapshot.data() != null) {
          currentCount = (snapshot.data()!['count'] as int?) ?? 0;
        }
        
        int newCount = currentCount + 1;
        transaction.set(counterRef, {'count': newCount}, SetOptions(merge: true));
        return 'CL-${newCount.toString().padLeft(3, '0')}';
      });
    } catch (e) {
      // Fallback in case of offline or permissions issue
      return getNextCustomerSequence();
    }
  }

  Future<String> generateNextWarehouseSequenceAtomic(String? currentEntId) async {
    String entId = currentEntId ?? currentEnterpriseId ?? 'default';
    if (entId.isEmpty) entId = 'default';
    final counterRef = _firestore.collection('enterprises').doc(entId).collection('counters').doc('warehouses');
    
    try {
      // 1. Ensure counter is initialized if it doesn't exist
      final counterSnap = await counterRef.get(const GetOptions(source: Source.server));
      if (!counterSnap.exists) {
        // Find current max to initialize
        int maxNum = 0;
        final querySnap = await _firestore.collection('warehouses')
            .where('enterprise_id', isEqualTo: entId)
            .get(const GetOptions(source: Source.server));
            
        for (var doc in querySnap.docs) {
          final data = doc.data();
          final code = (data['reference'] ?? '').toString();
          final match = RegExp(r'(?:WH)-?(\d+)', caseSensitive: false).firstMatch(code) ?? RegExp(r'(\d+)').firstMatch(code);
          if (match != null) {
            final num = int.tryParse(match.group(1)!) ?? 0;
            if (num > maxNum && num < 100000) maxNum = num;
          }
        }
        await counterRef.set({'count': maxNum}, SetOptions(merge: true));
      }

      // 2. Atomically increment and get the exact unique code
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);
        int currentCount = 0;
        if (snapshot.exists && snapshot.data() != null) {
          currentCount = (snapshot.data()!['count'] as int?) ?? 0;
        }
        
        int newCount = currentCount + 1;
        transaction.set(counterRef, {'count': newCount}, SetOptions(merge: true));
        return 'WH-${newCount.toString().padLeft(3, '0')}';
      });
    } catch (e) {
      print('❌ [DEBUG] generateNextWarehouseSequenceAtomic failed: $e');
      // Fallback in case of offline or permissions issue
      return 'WH-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
  }

  Future<List<Supplier>> getSuppliers() async => [];
  Future<List<Supplier>> getSuppliersPaginated({int limit = 10, int offset = 0, String? searchQuery, String? category, String? city}) async => [];
  Future<int> getSuppliersCount({String? searchQuery, String? category, String? city}) async => 0;
  Future<Supplier?> getSupplier(String id) async => null;
  Future<void> insertSupplier(dynamic supplier) async {}
  Future<void> updateSupplier(dynamic supplier) async {}
  Future<void> deleteSupplier(String id) async {}
  Future<String> getNextSupplierSequence() async {
    final uid = currentUid;
    final currentEntId = currentEnterpriseId;
    Query query = _firestore.collection('fournisseurs');
    if (uid != null && uid.isNotEmpty) {
      query = query.where('userId', isEqualTo: uid);
    }
    if (currentEntId != null && currentEntId.isNotEmpty) {
      query = query.where('enterprise_id', isEqualTo: currentEntId);
    }
    query = query.where('is_deleted', isEqualTo: 0);

    try {
      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      int maxNum = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final code = (data['code'] ?? data['supplierCode'] ?? '').toString();
        final match = RegExp(r'(?:FR|FOU)-?(\d+)', caseSensitive: false).firstMatch(code) ?? RegExp(r'(\d+)').firstMatch(code);
        if (match != null) {
          final num = int.tryParse(match.group(1)!) ?? 0;
          if (num > maxNum && num < 100000) maxNum = num;
        }
      }
      final nextNum = maxNum == 0 ? 1 : maxNum + 1;
      return 'FR-${nextNum.toString().padLeft(3, '0')}';
    } catch (e) {
      return 'FR-001';
    }
  }

  Future<String> generateNextSupplierSequenceAtomic(String? currentEntId) async {
    String entId = currentEntId ?? currentEnterpriseId ?? 'default';
    if (entId.isEmpty) entId = 'default';
    final counterRef = _firestore.collection('enterprises').doc(entId).collection('counters').doc('fournisseurs');
    
    try {
      // 1. Ensure counter is initialized if it doesn't exist
      final counterSnap = await counterRef.get(const GetOptions(source: Source.server));
      if (!counterSnap.exists) {
        // Find current max to initialize
        int maxNum = 0;
        final querySnap = await _firestore.collection('fournisseurs')
            .where('enterprise_id', isEqualTo: entId)
            .get(const GetOptions(source: Source.server));
            
        for (var doc in querySnap.docs) {
          final data = doc.data();
          final code = (data['code'] ?? data['supplierCode'] ?? '').toString();
          final match = RegExp(r'(?:FR|FOU)-?(\d+)', caseSensitive: false).firstMatch(code) ?? RegExp(r'(\d+)').firstMatch(code);
          if (match != null) {
            final num = int.tryParse(match.group(1)!) ?? 0;
            if (num > maxNum && num < 100000) maxNum = num;
          }
        }
        await counterRef.set({'count': maxNum}, SetOptions(merge: true));
      }

      // 2. Atomically increment and get the exact unique code
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);
        int currentCount = 0;
        if (snapshot.exists && snapshot.data() != null) {
          currentCount = (snapshot.data()!['count'] as int?) ?? 0;
        }
        
        int newCount = currentCount + 1;
        transaction.set(counterRef, {'count': newCount}, SetOptions(merge: true));
        return 'FR-${newCount.toString().padLeft(3, '0')}';
      });
    } catch (e) {
      // Fallback in case of offline or permissions issue
      return getNextSupplierSequence();
    }
  }

  Future<List<Product>> getProducts() async => [];
  Future<List<Product>> getLowStockProducts() async => [];
  Future<Product?> getProduct(String id) async => null;
  Future<void> insertProduct(dynamic item) async {}
  Future<void> updateProduct(dynamic item) async {}
  Future<void> deleteProduct(String id) async {}

  Future<List<ProductFamily>> getProductFamilies() async => [];
  Future<void> insertProductFamily(dynamic item) async {}
  Future<void> updateProductFamily(dynamic item) async {}
  Future<void> deleteProductFamily(String id) async {}

  // Payments & Accounts
  Future<List<Payment>> getPayments() async => [];
  Future<List<Payment>> getPaymentsPaginated({int limit = 10, int offset = 0, String? searchQuery, String? entityType, String? paymentMethod}) async => [];
  Future<int> getPaymentsCount({String? searchQuery, String? entityType, String? paymentMethod}) async => 0;
  Future<void> insertPayment(dynamic item) async {}
  Future<void> updatePayment(dynamic item) async {}
  Future<void> softDeletePayment(String id) async {}
  Future<List<PaymentAccount>> getPaymentAccounts() async => [];
  Future<void> insertPaymentAccount(dynamic item) async {}
  Future<int> getNextPaymentSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'paiements');
  Future<int> getNextTreasuryTransactionSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'treasury_transactions');
  Future<int> getNextStockEntrySequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'stock_entries');
  Future<int> getNextStockTransferSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'stock_transfers');
  Future<int> getNextInventorySheetSequence() async => await generateNextDocSequenceAtomic(currentEnterpriseId, 'inventory_sheets');

  // Stock Movements & Warehouses
  Future<List<StockMovement>> getStockMovements() async => [];
  Future<double> getTotalStockValue() async => 0.0;
  Future<void> insertStockMovement(dynamic item) async {}
  Future<List<Warehouse>> getWarehouses() async => [];
  Future<void> insertWarehouse(dynamic item) async {}
  Future<void> updateWarehouse(dynamic item) async {}
  Future<void> deleteWarehouse(String id) async {}

  // Checks & Traites
  Future<List<CheckTraite>> getChecksTraites() async => [];
  Future<List<CheckTraite>> getUpcomingChecksTraites() async => [];
  Future<void> insertCheckTraite(dynamic item) async {}
  Future<void> updateCheckTraiteStatus(String id, String status, {String? paymentId}) async {}
  Future<void> deleteCheckTraite(String id) async {}

  // Projects & Documents & Reports
  Future<List<Project>> getProjects() async => [];
  Future<void> insertProject(dynamic item) async {}
  Future<void> updateProject(dynamic item) async {}
  Future<List<Account>> getAccounts() async => [];
  Future<void> insertTransaction(dynamic item) async {}
  Future<void> insertAccount(dynamic item) async {}
  Future<List<TransactionModel>> getTransactions() async => [];

  Future<List<DocumentTemplate>> getDocumentTemplates() async => [];
  Future<void> insertDocumentTemplate(dynamic item) async {}
  Future<void> updateDocumentTemplate(dynamic item) async {}
  Future<void> deleteDocumentTemplate(String id) async {}
  Future<void> setDefaultTemplate(String type, String id) async {}

  // Dashboard Stats
  Future<double> getTotalInvoiced() async => 0.0;
  Future<double> getTotalPaid() async => 0.0;
  Future<double> getTotalTvaCollected() async => 0.0;
  Future<double> getTotalTvaDeductible() async => 0.0;
  Future<Map<String, double>> getInvoiceStatusBreakdown() async => {};
  Future<List<Invoice>> getRecentInvoices({int? limit}) async => [];

  Future<List<dynamic>> getTreasuryAccounts() async => [];
  Future<CompanySettings> getCompanySettings() async {
    try {
      final currentEnt = EnterpriseService.instance.currentEnterprise;
      if (currentEnt != null) {
        return CompanySettings(
          id: currentEnt.id,
          name: currentEnt.name,
          phone: currentEnt.phone,
          email: currentEnt.email,
          website: currentEnt.website,
          taxId: currentEnt.taxId,
          rcNumber: currentEnt.rcNumber,
          address: currentEnt.address,
          rib: currentEnt.rib,
        );
      }
    } catch (_) {}
    return CompanySettings();
  }
  Future<void> updateCompanySettings(dynamic settings) async {}
  Future<dynamic> getDefaultTemplate(String type) async => null;
  Future<List<dynamic>> getPendingSyncItems() async => [];
  Future<void> markSynced(int id) async {}
  Future<void> markSyncError(int id, String error) async {}
  Future<void> forceSyncAllExistingDataWithItems() async {}
}
