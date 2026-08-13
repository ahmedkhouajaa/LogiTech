import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quote.dart';
import '../models/invoice.dart';
import '../models/customer_order.dart';
import '../models/stock_entry.dart';
import '../models/delivery_note.dart';
import '../models/supplier_order.dart';
import '../models/receiving_voucher.dart';
import '../models/stock_withdrawal.dart';
import '../models/credit_note.dart';
import '../models/supplier_credit_note.dart';
import '../models/return_note.dart';
import '../models/supplier_return.dart';
import '../models/inventory_sheet.dart';
import '../models/stock_transfer.dart';
import '../models/purchase_invoice.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/payment_model.dart';
import '../models/treasury_account.dart';
import '../models/treasury_transaction.dart';
import '../models/retenue_source_vente.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
import 'enterprise_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

Query _applyEnterpriseFilter(Query query) {
  final currentEntId = EnterpriseService.instance.currentEnterpriseId;
  if (currentEntId != null && currentEntId.isNotEmpty) {
    return query.where('enterprise_id', isEqualTo: currentEntId);
  }
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null && uid.isNotEmpty) {
    return query.where('userId', isEqualTo: uid);
  }
  return query;
}

class FirestorePaginationService {
  static final FirestorePaginationService instance =
      FirestorePaginationService._();
  FirestorePaginationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pagination state tracking
  DocumentSnapshot? _lastDevisSnapshot;
  DocumentSnapshot? _lastPurchaseInvoiceSnapshot;
  DocumentSnapshot? _lastCustomerSnapshot;
  DocumentSnapshot? _lastSupplierSnapshot;
  DocumentSnapshot? _lastPaymentSnapshot;
  DocumentSnapshot? _lastTreasuryAccountSnapshot;
  bool _initialized = false;

  void enablePersistence() {
    if (_initialized) return;
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100000000,
      );
      _initialized = true;
    } catch (_) {}
  }

  // ─── DEVIS (QUOTES) PAGINATION ──────────────────────────────────
  Future<List<Quote>> getFirstDevis({
    int pageSize = 10,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetDevisPagination();

    try {
      Query baseQuery = _applyEnterpriseFilter(_firestore.collection('quotes'))
          .where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        baseQuery = baseQuery
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        final orderedQuery = baseQuery.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await orderedQuery.get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDevisSnapshot = snapshot.docs.last;
      }

      final quotes = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return Quote.fromMap(data);
      }).toList();

      quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return quotes.take(pageSize).toList();
    } catch (e) {
      try {
        return await DatabaseHelper.instance.getQuotesPaginated(
          limit: pageSize,
          offset: 0,
          searchQuery: searchQuery,
          customerId: customerId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
        );
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<Quote>> getNextDevis({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('quotes'))
          .where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastDevisSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDevisSnapshot = snapshot.docs.last;
      }

      return snapshot.docs
          .map((doc) => Quote.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  void resetDevisPagination() {
    _lastDevisSnapshot = null;
  }

  Future<int> getDevisCount({
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('quotes'))
          .where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── INVOICES (FACTURES) PAGINATION ─────────────────────────────
  DocumentSnapshot? _lastInvoiceSnapshot;

  Future<List<Invoice>> getFirstInvoices({
    int pageSize = 10,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetInvoicesPagination();

    try {
      Query baseQuery = _applyEnterpriseFilter(_firestore.collection('invoices'))
          .where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        baseQuery = baseQuery
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        final orderedQuery = baseQuery.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await orderedQuery.get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastInvoiceSnapshot = snapshot.docs.last;
      }

      final invoices = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return Invoice.fromMap(data);
      }).toList();

      invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invoices.take(pageSize).toList();
    } catch (_) {
      try {
        return await DatabaseHelper.instance.getInvoicesPaginated(
          limit: pageSize,
          offset: 0,
          searchQuery: searchQuery,
          customerId: customerId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
        );
      } catch (e) {
        return [];
      }
    }
  }

  Future<List<Invoice>> getNextInvoices({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query baseQuery = _applyEnterpriseFilter(_firestore.collection('invoices'))
          .where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        baseQuery = baseQuery
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        Query query = baseQuery;
        if (_lastInvoiceSnapshot != null) {
          query = query.startAfterDocument(_lastInvoiceSnapshot!);
        }
        query = query.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await baseQuery.limit(pageSize * 10).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastInvoiceSnapshot = snapshot.docs.last;
      }

      final invoices = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return Invoice.fromMap(data);
      }).toList();

      invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invoices.skip(currentOffset).take(pageSize).toList();
    } catch (_) {
      try {
        return await DatabaseHelper.instance.getInvoicesPaginated(
          limit: pageSize,
          offset: currentOffset,
          searchQuery: searchQuery,
          customerId: customerId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
        );
      } catch (e) {
        return [];
      }
    }
  }

  void resetInvoicesPagination() {
    _lastInvoiceSnapshot = null;
  }

  Future<int> getInvoicesCount({
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('invoices'))
          .where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── PURCHASE INVOICES (FACTURES D'ACHAT) PAGINATION ─────────────
  Future<List<PurchaseInvoice>> getFirstPurchaseInvoices({
    int pageSize = 10,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetPurchaseInvoicesPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('purchase_invoices'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastPurchaseInvoiceSnapshot = snapshot.docs.last;
      }

      List<PurchaseInvoice> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return PurchaseInvoice.fromMap(data);
      }).where((inv) => !inv.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<PurchaseInvoice>> getNextPurchaseInvoices({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('purchase_invoices'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastPurchaseInvoiceSnapshot != null) {
        query = query.startAfterDocument(_lastPurchaseInvoiceSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastPurchaseInvoiceSnapshot = snapshot.docs.last;
      }

      List<PurchaseInvoice> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return PurchaseInvoice.fromMap(data);
      }).where((inv) => !inv.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetPurchaseInvoicesPagination() {
    _lastPurchaseInvoiceSnapshot = null;
  }

  Future<int> getPurchaseInvoicesCount({
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('purchase_invoices'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return PurchaseInvoice.fromMap(data);
      }).where((inv) => !inv.isDeleted);

      return items.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── CLIENTS (CUSTOMERS) PAGINATION ──────────────────────────────
  Future<List<Customer>> getFirstCustomers({
    int pageSize = 10,
    String? searchQuery,
  }) async {
    resetCustomersPagination();

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('clients'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff')
            .orderBy('name', descending: false);
      } else {
        query = query.orderBy('code', descending: false);
      }

      query = query.limit(pageSize);

      // Always fetch from server for cross-device sync
      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        // Fallback to cache if server is unreachable
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCustomerSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (!mappedData.containsKey('code') &&
            mappedData.containsKey('clientCode')) {
          mappedData['code'] = mappedData['clientCode'];
        }
        if (!mappedData.containsKey('customer_type') &&
            mappedData.containsKey('type')) {
          mappedData['customer_type'] = mappedData['type'];
        }
        mappedData['created_at'] =
            mappedData['created_at'] ?? DateTime.now().toIso8601String();
        mappedData['updated_at'] =
            mappedData['updated_at'] ?? DateTime.now().toIso8601String();
        return Customer.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Customer>> getNextCustomers({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('clients'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff')
            .orderBy('name', descending: false);
      } else {
        query = query.orderBy('code', descending: false);
      }

      query = query.startAfterDocument(_lastCustomerSnapshot!).limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastCustomerSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (!mappedData.containsKey('code') &&
            mappedData.containsKey('clientCode')) {
          mappedData['code'] = mappedData['clientCode'];
        }
        if (!mappedData.containsKey('customer_type') &&
            mappedData.containsKey('type')) {
          mappedData['customer_type'] = mappedData['type'];
        }
        mappedData['created_at'] =
            mappedData['created_at'] ?? DateTime.now().toIso8601String();
        mappedData['updated_at'] =
            mappedData['updated_at'] ?? DateTime.now().toIso8601String();
        return Customer.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  void resetCustomersPagination() {
    _lastCustomerSnapshot = null;
  }

  Future<int> getCustomersCount({String? searchQuery}) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('clients'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── SUPPLIERS (FOURNISSEURS) PAGINATION ──────────────────────────
  Future<List<Supplier>> getFirstSuppliers({
    int pageSize = 10,
    String? searchQuery,
  }) async {
    resetSuppliersPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('fournisseurs'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff')
            .orderBy('name', descending: false);
      } else {
        query = query.orderBy('code', descending: false);
      }

      query = query.limit(pageSize);

      // Always fetch from server for cross-device sync
      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        // Fallback to cache if server is unreachable
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (!mappedData.containsKey('code') &&
            mappedData.containsKey('supplierCode')) {
          mappedData['code'] = mappedData['supplierCode'];
        }
        if (!mappedData.containsKey('supplier_type') &&
            mappedData.containsKey('type')) {
          mappedData['supplier_type'] = mappedData['type'];
        }
        mappedData['created_at'] =
            mappedData['created_at'] ?? DateTime.now().toIso8601String();
        mappedData['updated_at'] =
            mappedData['updated_at'] ?? DateTime.now().toIso8601String();
        return Supplier.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Supplier>> getNextSuppliers({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('fournisseurs'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff')
            .orderBy('name', descending: false);
      } else {
        query = query.orderBy('code', descending: false);
      }

      query = query.startAfterDocument(_lastSupplierSnapshot!).limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastSupplierSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (!mappedData.containsKey('code') &&
            mappedData.containsKey('supplierCode')) {
          mappedData['code'] = mappedData['supplierCode'];
        }
        if (!mappedData.containsKey('supplier_type') &&
            mappedData.containsKey('type')) {
          mappedData['supplier_type'] = mappedData['type'];
        }
        mappedData['created_at'] =
            mappedData['created_at'] ?? DateTime.now().toIso8601String();
        mappedData['updated_at'] =
            mappedData['updated_at'] ?? DateTime.now().toIso8601String();
        return Supplier.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  void resetSuppliersPagination() {
    _lastSupplierSnapshot = null;
  }

  Future<int> getSuppliersCount({String? searchQuery}) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('fournisseurs'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── PAYMENTS (PAIEMENTS) PAGINATION ──────────────────────────────
  Future<List<Payment>> getFirstPayments({
    int pageSize = 10,
    String? searchQuery,
    String? status,
    String? contactId,
    String? direction,
  }) async {
    resetPaymentsPagination();

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'));

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (contactId != null && contactId.isNotEmpty) {
        query = query.where('contact_id', isEqualTo: contactId);
      }

      if (direction != null && direction != 'Tous' && direction.isNotEmpty) {
        query = query.where('direction', isEqualTo: direction.toLowerCase());
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('payment_number', isGreaterThanOrEqualTo: q)
            .where('payment_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastPaymentSnapshot = snapshot.docs.last;
      }

      List<Payment> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        if (data['payment_date'] == null) {
          data['payment_date'] = data['date'] ?? DateTime.now().millisecondsSinceEpoch;
        }
        return Payment.fromMap(data);
      }).where((p) => !p.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<Payment>> getNextPayments({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? status,
    String? contactId,
    String? direction,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'));

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (contactId != null && contactId.isNotEmpty) {
        query = query.where('contact_id', isEqualTo: contactId);
      }

      if (direction != null && direction != 'Tous' && direction.isNotEmpty) {
        query = query.where('direction', isEqualTo: direction.toLowerCase());
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('payment_number', isGreaterThanOrEqualTo: q)
            .where('payment_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (_lastPaymentSnapshot != null) {
        query = query.startAfterDocument(_lastPaymentSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastPaymentSnapshot = snapshot.docs.last;
      }

      List<Payment> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        if (data['payment_date'] == null) {
          data['payment_date'] = data['date'] ?? DateTime.now().millisecondsSinceEpoch;
        }
        return Payment.fromMap(data);
      }).where((p) => !p.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetPaymentsPagination() {
    _lastPaymentSnapshot = null;
  }

  Future<int> getPaymentsCount({
    String? searchQuery,
    String? status,
    String? contactId,
    String? direction,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'));

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (contactId != null && contactId.isNotEmpty) {
        query = query.where('contact_id', isEqualTo: contactId);
      }

      if (direction != null && direction != 'Tous' && direction.isNotEmpty) {
        query = query.where('direction', isEqualTo: direction.toLowerCase());
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('payment_number', isGreaterThanOrEqualTo: q)
            .where('payment_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return Payment.fromMap(data);
      }).where((p) => !p.isDeleted);

      return items.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── CUSTOMER ORDERS (COMMANDES CLIENT) PAGINATION ─────────────
  DocumentSnapshot? _lastCustomerOrderSnapshot;

  Future<List<CustomerOrder>> getFirstCustomerOrders({
    int pageSize = 10,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetCustomerOrdersPagination();

    try {
      Query baseQuery = _applyEnterpriseFilter(
        _firestore.collection('customer_orders'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        baseQuery = baseQuery
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        final orderedQuery = baseQuery.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await orderedQuery.get(const GetOptions(source: Source.server));
      } catch (e) {
        try {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCustomerOrderSnapshot = snapshot.docs.last;
      }

      final orders = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return CustomerOrder.fromMap(data);
      }).toList();

      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders.take(pageSize).toList();
    } catch (_) {
      // ── Fallback to local SQLite ──
      try {
        return await DatabaseHelper.instance.getCustomerOrdersPaginated(
          limit: pageSize,
          offset: 0,
          searchQuery: searchQuery,
          customerId: customerId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
        );
      } catch (e) {
        return [];
      }
    }
  }

  Future<List<CustomerOrder>> getNextCustomerOrders({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query baseQuery = _applyEnterpriseFilter(
        _firestore.collection('customer_orders'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        baseQuery = baseQuery
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        Query query = baseQuery;
        if (_lastCustomerOrderSnapshot != null) {
          query = query.startAfterDocument(_lastCustomerOrderSnapshot!);
        }
        query = query.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await baseQuery.limit(pageSize * 10).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCustomerOrderSnapshot = snapshot.docs.last;
      }

      final orders = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return CustomerOrder.fromMap(data);
      }).toList();

      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (orders.isNotEmpty) {
        return orders.skip(currentOffset).take(pageSize).toList();
      }
    } catch (_) {}

    // ── Fallback to local SQLite ──
    try {
      return await DatabaseHelper.instance.getCustomerOrdersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
    } catch (e) {
      return [];
    }
  }

  void resetCustomerOrdersPagination() {
    _lastCustomerOrderSnapshot = null;
  }

  Future<int> getCustomerOrdersCount({
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('customer_orders'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      final count = aggregateSnapshot.count;
      if (count != null) return count;
    } catch (_) {}

    // ── Fallback to local SQLite ──
    try {
      return await DatabaseHelper.instance.getCustomerOrdersCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
    } catch (e) {
      return 0;
    }
  }

  // ─── STOCK ENTRIES (BONS D'ENTRÉE) PAGINATION ──────────────────
  DocumentSnapshot? _lastStockEntrySnapshot;

  Future<List<StockEntry>> getFirstStockEntries({
    int pageSize = 10,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetStockEntriesPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('stock_entries'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastStockEntrySnapshot = snapshot.docs.last;
      }

      List<StockEntry> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return StockEntry.fromMap(data);
      }).where((e) => !e.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<StockEntry>> getNextStockEntries({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('stock_entries'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastStockEntrySnapshot != null) {
        query = query.startAfterDocument(_lastStockEntrySnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastStockEntrySnapshot = snapshot.docs.last;
      }

      List<StockEntry> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return StockEntry.fromMap(data);
      }).where((e) => !e.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetStockEntriesPagination() {
    _lastStockEntrySnapshot = null;
  }

  Future<int> getStockEntriesCount({
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('stock_entries'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return StockEntry.fromMap(data);
      }).where((e) => !e.isDeleted);

      return items.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── DELIVERY NOTES (BONS DE LIVRAISON) PAGINATION ──────────────
  DocumentSnapshot? _lastDeliveryNoteSnapshot;

  Future<List<DeliveryNote>> getFirstDeliveryNotes({
    int pageSize = 10,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetDeliveryNotesPagination();

    try {
      Query baseQuery = _applyEnterpriseFilter(
        _firestore.collection('delivery_notes'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        baseQuery = baseQuery
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        final orderedQuery = baseQuery.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await orderedQuery.get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDeliveryNoteSnapshot = snapshot.docs.last;
      }

      final notes = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return DeliveryNote.fromMap(data);
      }).toList();

      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notes.take(pageSize).toList();
    } catch (_) {
      try {
        return await DatabaseHelper.instance.getDeliveryNotesPaginated(
          limit: pageSize,
          offset: 0,
          searchQuery: searchQuery,
          customerId: customerId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
        );
      } catch (e) {
        return [];
      }
    }
  }

  Future<List<DeliveryNote>> getNextDeliveryNotes({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query baseQuery = _applyEnterpriseFilter(
        _firestore.collection('delivery_notes'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        baseQuery = baseQuery
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        Query query = baseQuery;
        if (_lastDeliveryNoteSnapshot != null) {
          query = query.startAfterDocument(_lastDeliveryNoteSnapshot!);
        }
        query = query.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await baseQuery.limit(pageSize * 10).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDeliveryNoteSnapshot = snapshot.docs.last;
      }

      final notes = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return DeliveryNote.fromMap(data);
      }).toList();

      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notes.skip(currentOffset).take(pageSize).toList();
    } catch (_) {
      try {
        return await DatabaseHelper.instance.getDeliveryNotesPaginated(
          limit: pageSize,
          offset: currentOffset,
          searchQuery: searchQuery,
          customerId: customerId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
        );
      } catch (e) {
        return [];
      }
    }
  }

  void resetDeliveryNotesPagination() {
    _lastDeliveryNoteSnapshot = null;
  }

  Future<int> getDeliveryNotesCount({
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('delivery_notes'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── SUPPLIER ORDERS (COMMANDES FOURNISSEUR) PAGINATION ──────────
  DocumentSnapshot? _lastSupplierOrderSnapshot;

  Future<List<SupplierOrder>> getFirstSupplierOrders({
    int pageSize = 10,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetSupplierOrdersPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_orders'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierOrderSnapshot = snapshot.docs.last;
      }

      List<SupplierOrder> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return SupplierOrder.fromMap(data);
      }).where((o) => !o.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<SupplierOrder>> getNextSupplierOrders({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_orders'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastSupplierOrderSnapshot != null) {
        query = query.startAfterDocument(_lastSupplierOrderSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierOrderSnapshot = snapshot.docs.last;
      }

      List<SupplierOrder> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return SupplierOrder.fromMap(data);
      }).where((o) => !o.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetSupplierOrdersPagination() {
    _lastSupplierOrderSnapshot = null;
  }

  Future<int> getSupplierOrdersCount({
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_orders'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return SupplierOrder.fromMap(data);
      }).where((o) => !o.isDeleted);

      return items.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── RECEIVING VOUCHERS (BONS DE RÉCEPTION) PAGINATION ────────────
  DocumentSnapshot? _lastReceivingVoucherSnapshot;

  Future<List<ReceivingVoucher>> getFirstReceivingVouchers({
    int pageSize = 10,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetReceivingVouchersPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('receiving_vouchers'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastReceivingVoucherSnapshot = snapshot.docs.last;
      }

      List<ReceivingVoucher> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return ReceivingVoucher.fromMap(data);
      }).where((v) => !v.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<ReceivingVoucher>> getNextReceivingVouchers({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('receiving_vouchers'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastReceivingVoucherSnapshot != null) {
        query = query.startAfterDocument(_lastReceivingVoucherSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastReceivingVoucherSnapshot = snapshot.docs.last;
      }

      List<ReceivingVoucher> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return ReceivingVoucher.fromMap(data);
      }).where((v) => !v.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetReceivingVouchersPagination() {
    _lastReceivingVoucherSnapshot = null;
  }

  Future<int> getReceivingVouchersCount({
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('receiving_vouchers'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return ReceivingVoucher.fromMap(data);
      }).where((v) => !v.isDeleted);

      return items.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── STOCK WITHDRAWALS (BONS DE SORTIE) PAGINATION ──────────────
  // ─── BONS DE SORTIE (EXIT VOUCHERS) PAGINATION ──────────────────
  DocumentSnapshot? _lastExitVoucherSnapshot;

  Future<List<StockWithdrawal>> getFirstExitVouchers({
    int pageSize = 10,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetExitVouchersPagination();

    try {
      Query baseQuery = _applyEnterpriseFilter(_firestore.collection('bons_sortie'))
          .where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim().toUpperCase();
        final q = search.startsWith('BS-') ? search : 'BS-$search';
        baseQuery = baseQuery
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        final orderedQuery = baseQuery.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await orderedQuery.get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await baseQuery.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          // 100% Firebase mode (offline cache fallback disabled)
          rethrow;
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastExitVoucherSnapshot = snapshot.docs.last;
      }

      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return StockWithdrawal.fromMap(data);
      }).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.take(pageSize).toList();
    } catch (_) {
      try {
        return await DatabaseHelper.instance.getStockWithdrawalsPaginated(
          limit: pageSize,
          offset: 0,
          searchQuery: searchQuery,
          customerId: customerId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
        );
      } catch (e) {
        return [];
      }
    }
  }

  Future<List<StockWithdrawal>> getNextExitVouchers({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query baseQuery = _applyEnterpriseFilter(_firestore.collection('bons_sortie'))
          .where('is_deleted', isEqualTo: 0);

      String q = 'BS-';
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim().toUpperCase();
        q = search.startsWith('BS-') ? search : 'BS-$search';
      }
      baseQuery = baseQuery
          .where('number', isGreaterThanOrEqualTo: q)
          .where('number', isLessThanOrEqualTo: '$q\uf8ff');

      if (customerId != null && customerId.isNotEmpty) {
        baseQuery = baseQuery.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        baseQuery = baseQuery.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        Query query = baseQuery;
        if (_lastExitVoucherSnapshot != null) {
          query = query.startAfterDocument(_lastExitVoucherSnapshot!);
        }
        query = query.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await baseQuery.limit(pageSize * 10).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastExitVoucherSnapshot = snapshot.docs.last;
      }

      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return StockWithdrawal.fromMap(data);
      }).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.skip(currentOffset).take(pageSize).toList();
    } catch (_) {
      try {
        return await DatabaseHelper.instance.getStockWithdrawalsPaginated(
          limit: pageSize,
          offset: currentOffset,
          searchQuery: searchQuery,
          customerId: customerId,
          dateFrom: dateFrom,
          dateTo: dateTo,
          status: status,
        );
      } catch (e) {
        return [];
      }
    }
  }

  void resetExitVouchersPagination() {
    _lastExitVoucherSnapshot = null;
  }

  Future<int> getExitVouchersCount({
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('bons_sortie'))
          .where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim().toUpperCase();
        final q = search.startsWith('BS-') ? search : 'BS-$search';
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── STOCK WITHDRAWALS (BONS DE PRÉLÈVEMENT) PAGINATION ───────
  DocumentSnapshot? _lastStockWithdrawalSnapshot;

  Future<List<StockWithdrawal>> getFirstStockWithdrawals({
    int pageSize = 10,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetStockWithdrawalsPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('bons_prelevement'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim().toUpperCase();
        final q = search.startsWith('BP-') ? search : 'BP-$search';
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        final ordered = query.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await ordered.get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          // 100% Firebase mode (offline cache fallback disabled)
          rethrow;
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastStockWithdrawalSnapshot = snapshot.docs.last;
      }

      final items = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] = doc.id;
            return StockWithdrawal.fromMap(data);
          })
          .where((w) => !w.isDeleted)
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.take(pageSize).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<StockWithdrawal>> getNextStockWithdrawals({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('bons_prelevement'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim().toUpperCase();
        final q = search.startsWith('BP-') ? search : 'BP-$search';
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastStockWithdrawalSnapshot != null) {
        query = query
            .orderBy('created_at', descending: true)
            .startAfterDocument(_lastStockWithdrawalSnapshot!)
            .limit(pageSize);
      } else {
        query = query.orderBy('created_at', descending: true).limit(pageSize);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastStockWithdrawalSnapshot = snapshot.docs.last;
      }

      final items = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] = doc.id;
            return StockWithdrawal.fromMap(data);
          })
          .where((w) => !w.isDeleted)
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetStockWithdrawalsPagination() {
    _lastStockWithdrawalSnapshot = null;
  }

  Future<int> getStockWithdrawalsCount({
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('bons_prelevement'),
      );

      String q = 'BP-';
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim().toUpperCase();
        q = search.startsWith('BP-') ? search : 'BP-$search';
      }
      query = query
          .where('number', isGreaterThanOrEqualTo: q)
          .where('number', isLessThanOrEqualTo: '$q\uf8ff');

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      final count = aggregateSnapshot.count;
      if (count != null && count > 0) return count;
    } catch (_) {}

    return 0;
  }

  // ─── CREDIT NOTES (AVOIRS CLIENT) PAGINATION ──────────────────
  DocumentSnapshot? _lastCreditNoteSnapshot;

  Future<List<CreditNote>> getFirstCreditNotes({
    int pageSize = 10,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetCreditNotesPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('credit_notes'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCreditNoteSnapshot = snapshot.docs.last;
      }

      List<CreditNote> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return CreditNote.fromMap(data);
      }).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<CreditNote>> getNextCreditNotes({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('credit_notes'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastCreditNoteSnapshot != null) {
        query = query.startAfterDocument(_lastCreditNoteSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize).get();
      } catch (_) {
        snapshot = await query.limit(pageSize).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCreditNoteSnapshot = snapshot.docs.last;
      }

      List<CreditNote> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return CreditNote.fromMap(data);
      }).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetCreditNotesPagination() {
    _lastCreditNoteSnapshot = null;
  }

  Future<int> getCreditNotesCount({
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('credit_notes'),
      ).where('is_deleted', isEqualTo: 0);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── SUPPLIER CREDIT NOTES (AVOIRS FOURNISSEUR) PAGINATION ──────
  DocumentSnapshot? _lastSupplierCreditNoteSnapshot;

  Future<List<SupplierCreditNote>> getFirstSupplierCreditNotes({
    int pageSize = 10,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetSupplierCreditNotesPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_credit_notes'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierCreditNoteSnapshot = snapshot.docs.last;
      }

      List<SupplierCreditNote> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return SupplierCreditNote.fromMap(data);
      }).where((n) => !n.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<SupplierCreditNote>> getNextSupplierCreditNotes({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_credit_notes'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastSupplierCreditNoteSnapshot != null) {
        query = query.startAfterDocument(_lastSupplierCreditNoteSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierCreditNoteSnapshot = snapshot.docs.last;
      }

      List<SupplierCreditNote> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return SupplierCreditNote.fromMap(data);
      }).where((n) => !n.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetSupplierCreditNotesPagination() {
    _lastSupplierCreditNoteSnapshot = null;
  }

  Future<int> getSupplierCreditNotesCount({
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_credit_notes'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return SupplierCreditNote.fromMap(data);
      }).where((n) => !n.isDeleted);

      return items.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── RETURN NOTES (BONS DE RETOUR CLIENT) PAGINATION ───────────
  DocumentSnapshot? _lastReturnNoteSnapshot;

  Future<List<ReturnNote>> getFirstReturnNotes({
    int pageSize = 10,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetReturnNotesPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('return_notes'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('return_number', isGreaterThanOrEqualTo: q)
            .where('return_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastReturnNoteSnapshot = snapshot.docs.last;
      }

      List<ReturnNote> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return ReturnNote.fromMap(data);
      }).where((note) => !note.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<ReturnNote>> getNextReturnNotes({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('return_notes'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('return_number', isGreaterThanOrEqualTo: q)
            .where('return_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastReturnNoteSnapshot != null) {
        query = query.startAfterDocument(_lastReturnNoteSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastReturnNoteSnapshot = snapshot.docs.last;
      }

      List<ReturnNote> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return ReturnNote.fromMap(data);
      }).where((note) => !note.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetReturnNotesPagination() {
    _lastReturnNoteSnapshot = null;
  }

  Future<int> getReturnNotesCount({
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('return_notes'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('return_number', isGreaterThanOrEqualTo: q)
            .where('return_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return ReturnNote.fromMap(data);
      }).where((n) => !n.isDeleted);

      return items.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── SUPPLIER RETURNS (RETOURS FOURNISSEUR) PAGINATION ──────────
  DocumentSnapshot? _lastSupplierReturnSnapshot;

  Future<List<SupplierReturn>> getFirstSupplierReturns({
    int pageSize = 10,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetSupplierReturnsPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_returns'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierReturnSnapshot = snapshot.docs.last;
      }

      List<SupplierReturn> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return SupplierReturn.fromMap(data);
      }).where((r) => !r.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<SupplierReturn>> getNextSupplierReturns({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_returns'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastSupplierReturnSnapshot != null) {
        query = query.startAfterDocument(_lastSupplierReturnSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierReturnSnapshot = snapshot.docs.last;
      }

      List<SupplierReturn> items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return SupplierReturn.fromMap(data);
      }).where((r) => !r.isDeleted).toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetSupplierReturnsPagination() {
    _lastSupplierReturnSnapshot = null;
  }

  Future<int> getSupplierReturnsCount({
    String? searchQuery,
    String? supplierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('supplier_returns'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('supplier_id', isEqualTo: supplierId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        return SupplierReturn.fromMap(data);
      }).where((r) => !r.isDeleted);

      return items.length;
    } catch (e) {
      return 0;
    }
  }

  // ─── INVENTORY SHEETS (FICHES D'INVENTAIRE) PAGINATION ─────────
  DocumentSnapshot? _lastInventorySheetSnapshot;

  Future<List<InventorySheet>> getFirstInventorySheets({
    int pageSize = 10,
    String? searchQuery,
    String? warehouseId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetInventorySheetsPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('inventory_sheets'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (warehouseId != null && warehouseId.isNotEmpty) {
        query = query.where('emplacement_id', isEqualTo: warehouseId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastInventorySheetSnapshot = snapshot.docs.last;
      }

      List<InventorySheet> items = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] = doc.id;
            return InventorySheet.fromMap(data);
          })
          .where((s) => !s.isDeleted)
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<InventorySheet>> getNextInventorySheets({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? warehouseId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('inventory_sheets'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (warehouseId != null && warehouseId.isNotEmpty) {
        query = query.where('emplacement_id', isEqualTo: warehouseId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastInventorySheetSnapshot != null) {
        query = query.startAfterDocument(_lastInventorySheetSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastInventorySheetSnapshot = snapshot.docs.last;
      }

      List<InventorySheet> items = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] = doc.id;
            return InventorySheet.fromMap(data);
          })
          .where((s) => !s.isDeleted)
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetInventorySheetsPagination() {
    _lastInventorySheetSnapshot = null;
  }

  Future<int> getInventorySheetsCount({
    String? searchQuery,
    String? warehouseId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('inventory_sheets'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (warehouseId != null && warehouseId.isNotEmpty) {
        query = query.where('emplacement_id', isEqualTo: warehouseId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── STOCK TRANSFERS (BONS DE TRANSFERT) PAGINATION ───────────
  DocumentSnapshot? _lastStockTransferSnapshot;

  Future<List<StockTransfer>> getFirstStockTransfers({
    int pageSize = 10,
    String? searchQuery,
    String? sourceWarehouseId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    resetStockTransfersPagination();

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('stock_transfers'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (sourceWarehouseId != null && sourceWarehouseId.isNotEmpty) {
        query = query.where(
          'source_warehouse_id',
          isEqualTo: sourceWarehouseId,
        );
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastStockTransferSnapshot = snapshot.docs.last;
      }

      List<StockTransfer> items = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] = doc.id;
            return StockTransfer.fromMap(data);
          })
          .where((t) => !t.isDeleted)
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > pageSize) {
        items = items.sublist(0, pageSize);
      }

      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<StockTransfer>> getNextStockTransfers({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? sourceWarehouseId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('stock_transfers'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (sourceWarehouseId != null && sourceWarehouseId.isNotEmpty) {
        query = query.where(
          'source_warehouse_id',
          isEqualTo: sourceWarehouseId,
        );
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      if (_lastStockTransferSnapshot != null) {
        query = query.startAfterDocument(_lastStockTransferSnapshot!);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query.orderBy('created_at', descending: true).limit(pageSize * 5).get();
      } catch (_) {
        snapshot = await query.limit(pageSize * 5).get();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastStockTransferSnapshot = snapshot.docs.last;
      }

      List<StockTransfer> items = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] = doc.id;
            return StockTransfer.fromMap(data);
          })
          .where((t) => !t.isDeleted)
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  void resetStockTransfersPagination() {
    _lastStockTransferSnapshot = null;
  }

  Future<int> getStockTransfersCount({
    String? searchQuery,
    String? sourceWarehouseId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('stock_transfers'),
      );

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (sourceWarehouseId != null && sourceWarehouseId.isNotEmpty) {
        query = query.where(
          'source_warehouse_id',
          isEqualTo: sourceWarehouseId,
        );
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── TREASURY ACCOUNTS PAGINATION ──────────────────────────────────
  void resetTreasuryAccountsPagination() {
    _lastTreasuryAccountSnapshot = null;
  }

  Future<List<TreasuryAccount>> getFirstTreasuryAccounts({
    int pageSize = 10,
    String? searchQuery,
  }) async {
    resetTreasuryAccountsPagination();
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('treasury_accounts'),
      );
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }
      query = query.orderBy('name', descending: false);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastTreasuryAccountSnapshot = snapshot.docs.last;
      }
      return snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['is_deleted'] != 1 && data['is_deleted'] != true && data['is_deleted'] != '1';
          })
          .map(
            (doc) =>
                TreasuryAccount.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      final localData = await DatabaseHelper.instance
          .getTreasuryAccountsPaginated(
            limit: pageSize,
            offset: 0,
            searchQuery: searchQuery,
          );
      return localData.map((e) => TreasuryAccount.fromMap(e)).toList();
    }
  }

  Future<List<TreasuryAccount>> getNextTreasuryAccounts({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('treasury_accounts'),
      );
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }
      query = query
          .orderBy('name', descending: false)
          .startAfterDocument(_lastTreasuryAccountSnapshot!);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastTreasuryAccountSnapshot = snapshot.docs.last;
      }
      return snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['is_deleted'] != 1 && data['is_deleted'] != true && data['is_deleted'] != '1';
          })
          .map(
            (doc) =>
                TreasuryAccount.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      final localData = await DatabaseHelper.instance
          .getTreasuryAccountsPaginated(
            limit: pageSize,
            offset: currentOffset,
            searchQuery: searchQuery,
          );
      return localData.map((e) => TreasuryAccount.fromMap(e)).toList();
    }
  }

  Future<int> getTreasuryAccountsCount({String? searchQuery}) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('treasury_accounts'),
      );
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }
      final QuerySnapshot snapshot = await query.get();
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['is_deleted'] != 1 && data['is_deleted'] != true && data['is_deleted'] != '1';
      }).length;
    } catch (e) {
      return await DatabaseHelper.instance.getTreasuryAccountsCount(
        searchQuery: searchQuery,
      );
    }
  }

  // Treasury Transactions Pagination
  DocumentSnapshot? _lastTreasuryTransactionSnapshot;

  void resetTreasuryTransactionsPagination() {
    _lastTreasuryTransactionSnapshot = null;
  }

  Future<List<TreasuryTransaction>> getFirstTreasuryTransactions({
    int pageSize = 10,
    String? searchQuery,
    String typeFilter = 'Tous',
  }) async {
    resetTreasuryTransactionsPagination();
    try {

      Query query = _applyEnterpriseFilter(
        _firestore.collection('treasury_transactions'),
      );

      if (typeFilter != 'Tous') {
        query = query.where(
          'type',
          isEqualTo: typeFilter == 'Entrée' ? 'income' : 'expense',
        );
      }

      QuerySnapshot snapshot;
      try {
        final orderedQuery = query.orderBy('created_at', descending: true).limit(pageSize);
        snapshot = await orderedQuery.get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastTreasuryTransactionSnapshot = snapshot.docs.last;
      }

      var results = snapshot.docs
          .map(
            (doc) =>
                TreasuryTransaction.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        results = results
            .where(
              (t) =>
                  (t.transactionNumber.toLowerCase().contains(q)) ||
                  (t.accountName?.toLowerCase().contains(q) ?? false) ||
                  (t.description?.toLowerCase().contains(q) ?? false),
            )
            .toList();
      }
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results.take(pageSize).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TreasuryTransaction>> getNextTreasuryTransactions({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String typeFilter = 'Tous',
  }) async {
    try {
      final localData = await DatabaseHelper.instance
          .getTreasuryTransactionsPaginated(
            pageSize,
            currentOffset,
            searchQuery ?? '',
            typeFilter,
          );
      if (localData.isNotEmpty) {
        return localData.map((e) => TreasuryTransaction.fromMap(e)).toList();
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('treasury_transactions'),
      );

      if (typeFilter != 'Tous') {
        query = query.where(
          'type',
          isEqualTo: typeFilter == 'Entrée' ? 'income' : 'expense',
        );
      }

      QuerySnapshot snapshot;
      try {
        final orderedQuery = query.orderBy('created_at', descending: true)
            .startAfterDocument(_lastTreasuryTransactionSnapshot!)
            .limit(pageSize);
        snapshot = await orderedQuery.get(const GetOptions(source: Source.server));
      } catch (_) {
        try {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.server));
        } catch (_) {
          snapshot = await query.limit(pageSize * 10).get(const GetOptions(source: Source.cache));
        }
      }

      if (snapshot.docs.isNotEmpty) {
        _lastTreasuryTransactionSnapshot = snapshot.docs.last;
      }

      var results = snapshot.docs
          .map(
            (doc) =>
                TreasuryTransaction.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        results = results
            .where(
              (t) =>
                  (t.transactionNumber.toLowerCase().contains(q)) ||
                  (t.accountName?.toLowerCase().contains(q) ?? false) ||
                  (t.description?.toLowerCase().contains(q) ?? false),
            )
            .toList();
      }
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results.take(pageSize).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> getTreasuryTransactionsCount({
    String? searchQuery,
    String typeFilter = 'Tous',
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('treasury_transactions'),
      );

      if (typeFilter != 'Tous') {
        query = query.where(
          'type',
          isEqualTo: typeFilter == 'Entrée' ? 'income' : 'expense',
        );
      }

      final AggregateQuerySnapshot snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Retenue a la Source Vente Pagination
  DocumentSnapshot? _lastRetenueSourceVenteSnapshot;

  void resetRetenueSourceVentesPagination() {
    _lastRetenueSourceVenteSnapshot = null;
  }

  Future<List<RetenueSourceVente>> _getRetenueSourceFromLocalDb({
    required bool isSales,
    String? searchQuery,
    String statusFilter = 'Tous',
  }) async {
    try {
      final payments = await DatabaseHelper.instance.getPayments();
      final filtered = payments.where((p) {
        if (p.method != 'retenue_source') return false;
        if (isSales && p.direction != 'encaissement') return false;
        if (!isSales && p.direction != 'decaissement') return false;

        if (statusFilter != 'Tous') {
          String dbStatus = statusFilter == 'Payé'
              ? 'paid'
              : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
          if (p.status != dbStatus) return false;
        }

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.trim().toLowerCase();
          final ref = p.reference?.toLowerCase() ?? '';
          final num = p.paymentNumber.toLowerCase();
          final contact = p.contactName?.toLowerCase() ?? '';
          if (!ref.contains(q) && !num.contains(q) && !contact.contains(q))
            return false;
        }

        return true;
      }).toList();

      return filtered
          .map(
            (p) => RetenueSourceVente(
              id: p.id,
              invoiceReference: (p.reference != null && p.reference!.isNotEmpty)
                  ? p.reference!
                  : p.paymentNumber,
              clientName: p.contactName ?? 'Inconnu',
              date: p.paymentDate,
              amount: p.amount,
              status: (p.status == 'paid' || p.status == 'payee')
                  ? 'Payé'
                  : (p.status == 'cancelled' ? 'Annulé' : 'En attente'),
            ),
          )
          .toList();
    } catch (e) {
      print("Error reading local payments DB: $e");
    }

    return [];
  }

  Future<List<RetenueSourceVente>> getFirstRetenueSourceVentes({
    int pageSize = 10,
    String? searchQuery,
    String statusFilter = 'Tous',
    bool isSales = true,
  }) async {
    resetRetenueSourceVentesPagination();
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'))
          .where('method', isEqualTo: 'retenue_source')
          .where(
            'direction',
            isEqualTo: isSales ? 'encaissement' : 'decaissement',
          )
          .orderBy('payment_date', descending: true);

      if (statusFilter != 'Tous') {
        String dbStatus = statusFilter == 'Payé'
            ? 'paid'
            : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
        query = query.where('status', isEqualTo: dbStatus);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('reference', isGreaterThanOrEqualTo: q)
            .where('reference', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final snapshot = await query.limit(pageSize).get();

      if (snapshot.docs.isNotEmpty) {
        _lastRetenueSourceVenteSnapshot = snapshot.docs.last;
        var results = snapshot.docs
            .map(
              (doc) => RetenueSourceVente.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();
        results.sort((a, b) => b.date.compareTo(a.date));
        return results;
      }
    } catch (e) {
      print("Error getting retenue source ventes from Firebase: $e");
      // Fallback query: mimic desktop app behavior by fetching payments and filtering locally
      try {
        final allPayments = await getFirstPayments(pageSize: pageSize * 5);
        
        var filtered = allPayments.where((p) {
          if (p.method != 'retenue_source') return false;
          if (isSales && p.direction != 'encaissement') return false;
          if (!isSales && p.direction != 'decaissement') return false;
          
          if (statusFilter != 'Tous') {
            String dbStatus = statusFilter == 'Payé'
                ? 'paid'
                : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
            if (p.status != dbStatus) return false;
          }
          
          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim().toLowerCase();
            return (p.reference?.toLowerCase().contains(q) ?? false) ||
                   p.paymentNumber.toLowerCase().contains(q) ||
                   (p.contactName?.toLowerCase().contains(q) ?? false);
          }
          return true;
        }).toList();

        var results = filtered.map((p) => RetenueSourceVente(
          id: p.id,
          invoiceReference: p.reference ?? p.paymentNumber,
          clientName: p.contactName ?? '',
          date: p.paymentDate,
          amount: p.amount,
          status: p.status == 'paid' || p.status == 'payee' ? 'Payé' : (p.status == 'cancelled' ? 'Annulé' : 'En attente'),
        )).toList();
        
        results.sort((a, b) => b.date.compareTo(a.date));
        return results.take(pageSize).toList();
      } catch (fallbackErr) {
         print("Fallback fetching all payments failed: $fallbackErr");
      }
    }

    final localResults = await _getRetenueSourceFromLocalDb(
      isSales: isSales,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
    );
    localResults.sort((a, b) => b.date.compareTo(a.date));
    return localResults.take(pageSize).toList();
  }

  Future<List<RetenueSourceVente>> getNextRetenueSourceVentes({
    int pageSize = 10,
    String? searchQuery,
    String statusFilter = 'Tous',
    bool isSales = true,
  }) async {
    if (_lastRetenueSourceVenteSnapshot == null) {
      return getFirstRetenueSourceVentes(
        pageSize: pageSize,
        searchQuery: searchQuery,
        statusFilter: statusFilter,
        isSales: isSales,
      );
    }

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'))
          .where('method', isEqualTo: 'retenue_source')
          .where(
            'direction',
            isEqualTo: isSales ? 'encaissement' : 'decaissement',
          )
          .orderBy('payment_date', descending: true);

      if (statusFilter != 'Tous') {
        String dbStatus = statusFilter == 'Payé'
            ? 'paid'
            : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
        query = query.where('status', isEqualTo: dbStatus);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('reference', isGreaterThanOrEqualTo: q)
            .where('reference', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query
          .startAfterDocument(_lastRetenueSourceVenteSnapshot!)
          .limit(pageSize);
      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastRetenueSourceVenteSnapshot = snapshot.docs.last;
        var results = snapshot.docs
            .map(
              (doc) => RetenueSourceVente.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();
        results.sort((a, b) => b.date.compareTo(a.date));
        return results;
      }
    } catch (e) {
      print("Error getting next retenue source ventes from Firebase: $e");
      // Fallback query: mimic desktop app behavior by fetching payments and filtering locally
      try {
        final allPayments = await getNextPayments(pageSize: pageSize * 5, currentOffset: 0); 
        
        var filtered = allPayments.where((p) {
          if (p.method != 'retenue_source') return false;
          if (isSales && p.direction != 'encaissement') return false;
          if (!isSales && p.direction != 'decaissement') return false;
          
          if (statusFilter != 'Tous') {
            String dbStatus = statusFilter == 'Payé'
                ? 'paid'
                : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
            if (p.status != dbStatus) return false;
          }
          
          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim().toLowerCase();
            return (p.reference?.toLowerCase().contains(q) ?? false) ||
                   p.paymentNumber.toLowerCase().contains(q) ||
                   (p.contactName?.toLowerCase().contains(q) ?? false);
          }
          return true;
        }).toList();

        var results = filtered.map((p) => RetenueSourceVente(
          id: p.id,
          invoiceReference: p.reference ?? p.paymentNumber,
          clientName: p.contactName ?? '',
          date: p.paymentDate,
          amount: p.amount,
          status: p.status == 'paid' || p.status == 'payee' ? 'Payé' : (p.status == 'cancelled' ? 'Annulé' : 'En attente'),
        )).toList();
        
        results.sort((a, b) => b.date.compareTo(a.date));
        return results;
      } catch (fallbackErr) {
         print("Fallback next Firebase query also failed: $fallbackErr");
      }
    }

    final localResults = await _getRetenueSourceFromLocalDb(
      isSales: isSales,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
    );
    localResults.sort((a, b) => b.date.compareTo(a.date));
    return localResults;
  }

  Future<int> getRetenueSourceVentesCount({
    String? searchQuery,
    String statusFilter = 'Tous',
    bool isSales = true,
  }) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'))
          .where('method', isEqualTo: 'retenue_source')
          .where(
            'direction',
            isEqualTo: isSales ? 'encaissement' : 'decaissement',
          );

      if (statusFilter != 'Tous') {
        String dbStatus = statusFilter == 'Payé'
            ? 'paid'
            : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
        query = query.where('status', isEqualTo: dbStatus);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('reference', isGreaterThanOrEqualTo: q)
            .where('reference', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final AggregateQuerySnapshot snapshot = await query.count().get();
      int count = snapshot.count ?? 0;
      if (count > 0) return count;
    } catch (e) {
      print("Error getting count from Firebase: $e");
    }

    final localResults = await _getRetenueSourceFromLocalDb(
      isSales: isSales,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
    );
    return localResults.length;
  }

  // --- Products Pagination ---
  DocumentSnapshot? _lastProductSnapshot;

  void resetProductsPagination() {
    _lastProductSnapshot = null;
  }

  Future<List<Product>> _getProductsFromLocalDb({
    String? searchQuery,
    String stockFilter = 'Tous',
  }) async {
    try {
      final products = await DatabaseHelper.instance.getProducts();
      final filtered = products.where((p) {
        if (p.isDeleted) return false;

        if (stockFilter == 'En stock' && p.stockQty <= 0) return false;
        if (stockFilter == 'Rupture' && p.stockQty > 0) return false;

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.trim().toLowerCase();
          final name = p.name.toLowerCase();
          final code = p.code.toLowerCase();
          final ref = p.reference?.toLowerCase() ?? '';
          if (!name.contains(q) && !code.contains(q) && !ref.contains(q))
            return false;
        }

        return true;
      }).toList();

      return filtered;
    } catch (e) {
      print("Error reading local products DB: $e");
    }

    return [];
  }

  Future<List<Product>> getFirstProducts({
    int pageSize = 10,
    String? searchQuery,
    String stockFilter = 'Tous',
  }) async {
    resetProductsPagination();
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('articles'),
      );
      print("DEBUG: getFirstProducts query created.");

      if (stockFilter == 'En stock') {
        query = query.where('stock_qty', isGreaterThan: 0);
      } else if (stockFilter == 'Rupture') {
        query = query.where('stock_qty', isEqualTo: 0);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final snapshot = await query.limit(pageSize).get();
      print("DEBUG: getFirstProducts Firebase snapshot length: ${snapshot.docs.length}");

      if (snapshot.docs.isNotEmpty) {
        _lastProductSnapshot = snapshot.docs.last;
        try {
          var results = snapshot.docs
              .map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>))
              .toList();
          print("DEBUG: getFirstProducts mapped ${results.length} products successfully.");
          return results;
        } catch (e) {
          print("DEBUG: Product.fromMap CRASHED! Error: $e");
          for (var doc in snapshot.docs) {
            try {
              Product.fromMap(doc.data() as Map<String, dynamic>);
            } catch (e2) {
              print("DEBUG: Crashed on document ${doc.id}: $e2\nData: ${doc.data()}");
            }
          }
        }
      }
    } catch (e) {
      print("Error getting first products from Firebase: $e");
    }

    final localResults = await _getProductsFromLocalDb(
      searchQuery: searchQuery,
      stockFilter: stockFilter,
    );
    return localResults.take(pageSize).toList();
  }

  Future<List<Product>> getNextProducts({
    int pageSize = 10,
    String? searchQuery,
    String stockFilter = 'Tous',
  }) async {
    if (_lastProductSnapshot == null) {
      return getFirstProducts(
        pageSize: pageSize,
        searchQuery: searchQuery,
        stockFilter: stockFilter,
      );
    }

    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('articles'),
      );

      if (stockFilter == 'En stock') {
        query = query.where('stock_qty', isGreaterThan: 0);
      } else if (stockFilter == 'Rupture') {
        query = query.where('stock_qty', isEqualTo: 0);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query.startAfterDocument(_lastProductSnapshot!).limit(pageSize);
      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastProductSnapshot = snapshot.docs.last;
        var results = snapshot.docs
            .map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        return results;
      }
    } catch (e) {
      print("Error getting next products from Firebase: $e");
    }

    final localResults = await _getProductsFromLocalDb(
      searchQuery: searchQuery,
      stockFilter: stockFilter,
    );
    return localResults;
  }

  Future<int> getProductsCount({
    String? searchQuery,
    String stockFilter = 'Tous',
  }) async {
    try {
      Query query = _applyEnterpriseFilter(
        _firestore.collection('articles'),
      );

      if (stockFilter == 'En stock') {
        query = query.where('stock_qty', isGreaterThan: 0);
      } else if (stockFilter == 'Rupture') {
        query = query.where('stock_qty', isEqualTo: 0);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final AggregateQuerySnapshot snapshot = await query.count().get();
      int count = snapshot.count ?? 0;
      if (count > 0) return count;
    } catch (e) {
      print("Error getting products count from Firebase: $e");
    }

    final localResults = await _getProductsFromLocalDb(
      searchQuery: searchQuery,
      stockFilter: stockFilter,
    );
    return localResults.length;
  }
}
