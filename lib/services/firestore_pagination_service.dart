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

Query _applyEnterpriseFilter(Query query) {
  final currentEntId = EnterpriseService.instance.currentEnterpriseId;
  if (currentEntId != null && currentEntId.isNotEmpty) {
    return query.where('enterprise_id', isEqualTo: currentEntId);
  }
  return query;
}

class FirestorePaginationService {
  static final FirestorePaginationService instance = FirestorePaginationService._();
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
      final localQuotes = await DatabaseHelper.instance.getQuotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localQuotes.isNotEmpty) {
        return localQuotes;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('quotes'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDevisSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => Quote.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getQuotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localQuotes = await DatabaseHelper.instance.getQuotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localQuotes.isNotEmpty) {
        return localQuotes;
      }
    } catch (_) {}

    try {
      if (_lastDevisSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('quotes'));

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

      return snapshot.docs.map((doc) => Quote.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getQuotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getQuotesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('quotes'));

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
      return DatabaseHelper.instance.getQuotesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getInvoicesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('invoices'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastInvoiceSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => Invoice.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getInvoicesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getInvoicesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastInvoiceSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('invoices'));

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
          .startAfterDocument(_lastInvoiceSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastInvoiceSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => Invoice.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getInvoicesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getInvoicesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('invoices'));

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
      return DatabaseHelper.instance.getInvoicesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getPurchaseInvoicesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('purchase_invoices'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastPurchaseInvoiceSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => PurchaseInvoice.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getPurchaseInvoicesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getPurchaseInvoicesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastPurchaseInvoiceSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('purchase_invoices'));

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

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastPurchaseInvoiceSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastPurchaseInvoiceSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => PurchaseInvoice.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getPurchaseInvoicesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getPurchaseInvoicesCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('purchase_invoices'));

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

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getPurchaseInvoicesCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
    }
  }

  // ─── CLIENTS (CUSTOMERS) PAGINATION ──────────────────────────────
  Future<List<Customer>> getFirstCustomers({
    int pageSize = 10,
    String? searchQuery,
  }) async {
    resetCustomersPagination();
    try {
      final local = await DatabaseHelper.instance.getCustomersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('clients'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query.orderBy('name', descending: false).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCustomerSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (!mappedData.containsKey('code') && mappedData.containsKey('clientCode')) {
          mappedData['code'] = mappedData['clientCode'];
        }
        if (!mappedData.containsKey('customer_type') && mappedData.containsKey('type')) {
          mappedData['customer_type'] = mappedData['type'];
        }
        mappedData['created_at'] = mappedData['created_at'] ?? DateTime.now().toIso8601String();
        mappedData['updated_at'] = mappedData['updated_at'] ?? DateTime.now().toIso8601String();
        return Customer.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return DatabaseHelper.instance.getCustomersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
      );
    }
  }

  Future<List<Customer>> getNextCustomers({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
  }) async {
    try {
      final local = await DatabaseHelper.instance.getCustomersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastCustomerSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('clients'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query
          .orderBy('name', descending: false)
          .startAfterDocument(_lastCustomerSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastCustomerSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (!mappedData.containsKey('code') && mappedData.containsKey('clientCode')) {
          mappedData['code'] = mappedData['clientCode'];
        }
        if (!mappedData.containsKey('customer_type') && mappedData.containsKey('type')) {
          mappedData['customer_type'] = mappedData['type'];
        }
        mappedData['created_at'] = mappedData['created_at'] ?? DateTime.now().toIso8601String();
        mappedData['updated_at'] = mappedData['updated_at'] ?? DateTime.now().toIso8601String();
        return Customer.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return DatabaseHelper.instance.getCustomersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
      );
    }
  }

  void resetCustomersPagination() {
    _lastCustomerSnapshot = null;
  }

  Future<int> getCustomersCount({
    String? searchQuery,
  }) async {
    try {
      final localCount = await DatabaseHelper.instance.getCustomersCount(
        searchQuery: searchQuery,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

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
      return DatabaseHelper.instance.getCustomersCount(
        searchQuery: searchQuery,
      );
    }
  }

  // ─── SUPPLIERS (FOURNISSEURS) PAGINATION ──────────────────────────
  Future<List<Supplier>> getFirstSuppliers({
    int pageSize = 10,
    String? searchQuery,
  }) async {
    resetSuppliersPagination();
    try {
      final local = await DatabaseHelper.instance.getSuppliersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('fournisseurs'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query.orderBy('name', descending: false).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (!mappedData.containsKey('code') && mappedData.containsKey('supplierCode')) {
          mappedData['code'] = mappedData['supplierCode'];
        }
        if (!mappedData.containsKey('supplier_type') && mappedData.containsKey('type')) {
          mappedData['supplier_type'] = mappedData['type'];
        }
        mappedData['created_at'] = mappedData['created_at'] ?? DateTime.now().toIso8601String();
        mappedData['updated_at'] = mappedData['updated_at'] ?? DateTime.now().toIso8601String();
        return Supplier.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return DatabaseHelper.instance.getSuppliersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
      );
    }
  }

  Future<List<Supplier>> getNextSuppliers({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
  }) async {
    try {
      final local = await DatabaseHelper.instance.getSuppliersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastSupplierSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('fournisseurs'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query
          .orderBy('name', descending: false)
          .startAfterDocument(_lastSupplierSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastSupplierSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (!mappedData.containsKey('code') && mappedData.containsKey('supplierCode')) {
          mappedData['code'] = mappedData['supplierCode'];
        }
        if (!mappedData.containsKey('supplier_type') && mappedData.containsKey('type')) {
          mappedData['supplier_type'] = mappedData['type'];
        }
        mappedData['created_at'] = mappedData['created_at'] ?? DateTime.now().toIso8601String();
        mappedData['updated_at'] = mappedData['updated_at'] ?? DateTime.now().toIso8601String();
        return Supplier.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return DatabaseHelper.instance.getSuppliersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
      );
    }
  }

  void resetSuppliersPagination() {
    _lastSupplierSnapshot = null;
  }

  Future<int> getSuppliersCount({
    String? searchQuery,
  }) async {
    try {
      final localCount = await DatabaseHelper.instance.getSuppliersCount(
        searchQuery: searchQuery,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('fournisseurs'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getSuppliersCount(
        searchQuery: searchQuery,
      );
    }
  }

  // ─── PAYMENTS (PAIEMENTS) PAGINATION ──────────────────────────────
  Future<List<Payment>> getFirstPayments({
    int pageSize = 10,
    String? searchQuery,
    String? status,
  }) async {
    resetPaymentsPagination();
    try {
      final local = await DatabaseHelper.instance.getPaymentsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'));

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('payment_number', isGreaterThanOrEqualTo: q)
            .where('payment_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastPaymentSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (mappedData['payment_date'] == null) {
          mappedData['payment_date'] = mappedData['date'] ?? DateTime.now().millisecondsSinceEpoch;
        }
        return Payment.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return DatabaseHelper.instance.getPaymentsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        status: status,
      );
    }
  }

  Future<List<Payment>> getNextPayments({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? status,
  }) async {
    try {
      final local = await DatabaseHelper.instance.getPaymentsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastPaymentSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'));

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('payment_number', isGreaterThanOrEqualTo: q)
            .where('payment_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastPaymentSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastPaymentSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final mappedData = Map<String, dynamic>.from(data);
        mappedData['id'] = doc.id;
        if (mappedData['payment_date'] == null) {
          mappedData['payment_date'] = mappedData['date'] ?? DateTime.now().millisecondsSinceEpoch;
        }
        return Payment.fromMap(mappedData);
      }).toList();
    } catch (e) {
      return DatabaseHelper.instance.getPaymentsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        status: status,
      );
    }
  }

  void resetPaymentsPagination() {
    _lastPaymentSnapshot = null;
  }

  Future<int> getPaymentsCount({
    String? searchQuery,
    String? status,
  }) async {
    try {
      final localCount = await DatabaseHelper.instance.getPaymentsCount(
        searchQuery: searchQuery,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('paiements'));

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('payment_number', isGreaterThanOrEqualTo: q)
            .where('payment_number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getPaymentsCount(
        searchQuery: searchQuery,
        status: status,
      );
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

    // ── Try Firestore first (always up-to-date) ──
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('customer_orders'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'CC-')
            .where('number', isLessThanOrEqualTo: 'CC-\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      final snapshot = await query.get(const GetOptions(source: Source.server));

      if (snapshot.docs.isNotEmpty) {
        _lastCustomerOrderSnapshot = snapshot.docs.last;
        return snapshot.docs.map((doc) => CustomerOrder.fromMap(doc.data() as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

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

  Future<List<CustomerOrder>> getNextCustomerOrders({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String? customerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
  }) async {
    // ── Try Firestore first with cursor ──
    try {
      if (_lastCustomerOrderSnapshot == null) {
        throw Exception('No pagination cursor');
      }

      Query query = _applyEnterpriseFilter(_firestore.collection('customer_orders'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'CC-')
            .where('number', isLessThanOrEqualTo: 'CC-\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastCustomerOrderSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get(const GetOptions(source: Source.server));
      if (snapshot.docs.isNotEmpty) {
        _lastCustomerOrderSnapshot = snapshot.docs.last;
        return snapshot.docs.map((doc) => CustomerOrder.fromMap(doc.data() as Map<String, dynamic>)).toList();
      }
      return [];
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
    // ── Try Firestore count().get() (1 read only) ──
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('customer_orders'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'CC-')
            .where('number', isLessThanOrEqualTo: 'CC-\uf8ff');
      }

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
      final local = await DatabaseHelper.instance.getStockEntriesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('stock_entries'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastStockEntrySnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => StockEntry.fromMap(doc.data() as Map<String, dynamic>, [])).toList();
    } catch (e) {
      return DatabaseHelper.instance.getStockEntriesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getStockEntriesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastStockEntrySnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('stock_entries'));

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

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastStockEntrySnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastStockEntrySnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => StockEntry.fromMap(doc.data() as Map<String, dynamic>, [])).toList();
    } catch (e) {
      return DatabaseHelper.instance.getStockEntriesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getStockEntriesCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('stock_entries'));

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

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getStockEntriesCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getDeliveryNotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('delivery_notes'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDeliveryNoteSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => DeliveryNote.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getDeliveryNotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getDeliveryNotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastDeliveryNoteSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('delivery_notes'));

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
          .startAfterDocument(_lastDeliveryNoteSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDeliveryNoteSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => DeliveryNote.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getDeliveryNotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getDeliveryNotesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('delivery_notes'));

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
      return DatabaseHelper.instance.getDeliveryNotesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getSupplierOrdersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_orders'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierOrderSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => SupplierOrder.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getSupplierOrdersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getSupplierOrdersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastSupplierOrderSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_orders'));

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

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastSupplierOrderSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastSupplierOrderSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => SupplierOrder.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getSupplierOrdersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getSupplierOrdersCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_orders'));

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

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getSupplierOrdersCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getReceivingVouchersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('receiving_vouchers'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastReceivingVoucherSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => ReceivingVoucher.fromMap(doc.data() as Map<String, dynamic>, [])).toList();
    } catch (e) {
      return DatabaseHelper.instance.getReceivingVouchersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getReceivingVouchersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastReceivingVoucherSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('receiving_vouchers'));

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

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastReceivingVoucherSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastReceivingVoucherSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => ReceivingVoucher.fromMap(doc.data() as Map<String, dynamic>, [])).toList();
    } catch (e) {
      return DatabaseHelper.instance.getReceivingVouchersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getReceivingVouchersCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('receiving_vouchers'));

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

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getReceivingVouchersCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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

    // ── Try Firestore first (primary source, always up-to-date) ──
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('bons_sortie'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'BS-')
            .where('number', isLessThanOrEqualTo: 'BS-\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      // Always fetch from server to get the latest data
      final snapshot = await query.get(const GetOptions(source: Source.server));

      if (snapshot.docs.isNotEmpty) {
        _lastExitVoucherSnapshot = snapshot.docs.last;
        return snapshot.docs.map((doc) => StockWithdrawal.fromMap(doc.data() as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // ── Fallback to local SQLite ──
    try {
      return await DatabaseHelper.instance.getStockWithdrawalsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        numberPrefix: 'BS-',
      );
    } catch (e) {
      return [];
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
    // ── Try Firestore first (pagination with cursor) ──
    try {
      if (_lastExitVoucherSnapshot == null) {
        // No cursor — fall through to local
        throw Exception('No pagination cursor');
      }

      Query query = _applyEnterpriseFilter(_firestore.collection('bons_sortie'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'BS-')
            .where('number', isLessThanOrEqualTo: 'BS-\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastExitVoucherSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get(const GetOptions(source: Source.server));
      if (snapshot.docs.isNotEmpty) {
        _lastExitVoucherSnapshot = snapshot.docs.last;
        return snapshot.docs.map((doc) => StockWithdrawal.fromMap(doc.data() as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {}

    // ── Fallback to local SQLite ──
    try {
      return await DatabaseHelper.instance.getStockWithdrawalsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        numberPrefix: 'BS-',
      );
    } catch (e) {
      return [];
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
      Query query = _applyEnterpriseFilter(_firestore.collection('bons_sortie'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'BS-')
            .where('number', isLessThanOrEqualTo: 'BS-\uf8ff');
      }

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

    try {
      final localCount = await DatabaseHelper.instance.getStockWithdrawalsCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        numberPrefix: 'BS-',
      );
      return localCount;
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
      final local = await DatabaseHelper.instance.getStockWithdrawalsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        numberPrefix: 'BP-',
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('bons_sortie'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'BP-')
            .where('number', isLessThanOrEqualTo: 'BP-\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastStockWithdrawalSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => StockWithdrawal.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getStockWithdrawalsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        numberPrefix: 'BP-',
      );
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
      final local = await DatabaseHelper.instance.getStockWithdrawalsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        numberPrefix: 'BP-',
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastStockWithdrawalSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('bons_sortie'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'BP-')
            .where('number', isLessThanOrEqualTo: 'BP-\uf8ff');
      }

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customer_id', isEqualTo: customerId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastStockWithdrawalSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastStockWithdrawalSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => StockWithdrawal.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getStockWithdrawalsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        numberPrefix: 'BP-',
      );
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
      Query query = _applyEnterpriseFilter(_firestore.collection('bons_sortie'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      } else {
        query = query
            .where('number', isGreaterThanOrEqualTo: 'BP-')
            .where('number', isLessThanOrEqualTo: 'BP-\uf8ff');
      }

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

    try {
      final localCount = await DatabaseHelper.instance.getStockWithdrawalsCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
        numberPrefix: 'BP-',
      );
      return localCount;
    } catch (e) {
      return 0;
    }
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
      final local = await DatabaseHelper.instance.getCreditNotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('credit_notes'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCreditNoteSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => CreditNote.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getCreditNotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getCreditNotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastCreditNoteSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('credit_notes'));

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
          .startAfterDocument(_lastCreditNoteSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastCreditNoteSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => CreditNote.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getCreditNotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getCreditNotesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('credit_notes'));

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
      return DatabaseHelper.instance.getCreditNotesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getSupplierCreditNotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_credit_notes'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierCreditNoteSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => SupplierCreditNote.fromMap(doc.data() as Map<String, dynamic>, [])).toList();
    } catch (e) {
      return DatabaseHelper.instance.getSupplierCreditNotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getSupplierCreditNotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastSupplierCreditNoteSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_credit_notes'));

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

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastSupplierCreditNoteSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastSupplierCreditNoteSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => SupplierCreditNote.fromMap(doc.data() as Map<String, dynamic>, [])).toList();
    } catch (e) {
      return DatabaseHelper.instance.getSupplierCreditNotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getSupplierCreditNotesCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_credit_notes'));

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

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getSupplierCreditNotesCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getReturnNotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('return_notes'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastReturnNoteSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => ReturnNote.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getReturnNotesPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getReturnNotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastReturnNoteSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('return_notes'));

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
          .startAfterDocument(_lastReturnNoteSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastReturnNoteSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => ReturnNote.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getReturnNotesPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getReturnNotesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('return_notes'));

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
      return DatabaseHelper.instance.getReturnNotesCount(
        searchQuery: searchQuery,
        customerId: customerId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getSupplierReturnsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_returns'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastSupplierReturnSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => SupplierReturn.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getSupplierReturnsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getSupplierReturnsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastSupplierReturnSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_returns'));

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

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastSupplierReturnSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastSupplierReturnSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => SupplierReturn.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getSupplierReturnsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getSupplierReturnsCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('supplier_returns'));

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

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getSupplierReturnsCount(
        searchQuery: searchQuery,
        supplierId: supplierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getInventorySheetsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        warehouseId: warehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('inventory_sheets'));

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

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastInventorySheetSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => InventorySheet.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getInventorySheetsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        warehouseId: warehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getInventorySheetsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        warehouseId: warehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastInventorySheetSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('inventory_sheets'));

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

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastInventorySheetSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastInventorySheetSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => InventorySheet.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getInventorySheetsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        warehouseId: warehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getInventorySheetsCount(
        searchQuery: searchQuery,
        warehouseId: warehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('inventory_sheets'));

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
      return DatabaseHelper.instance.getInventorySheetsCount(
        searchQuery: searchQuery,
        warehouseId: warehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getStockTransfersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        sourceWarehouseId: sourceWarehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('stock_transfers'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (sourceWarehouseId != null && sourceWarehouseId.isNotEmpty) {
        query = query.where('source_warehouse_id', isEqualTo: sourceWarehouseId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastStockTransferSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => StockTransfer.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getStockTransfersPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
        sourceWarehouseId: sourceWarehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final local = await DatabaseHelper.instance.getStockTransfersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        sourceWarehouseId: sourceWarehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (local.isNotEmpty) {
        return local;
      }
    } catch (_) {}

    try {
      if (_lastStockTransferSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('stock_transfers'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (sourceWarehouseId != null && sourceWarehouseId.isNotEmpty) {
        query = query.where('source_warehouse_id', isEqualTo: sourceWarehouseId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastStockTransferSnapshot!)
          .limit(pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastStockTransferSnapshot = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) => StockTransfer.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      return DatabaseHelper.instance.getStockTransfersPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
        sourceWarehouseId: sourceWarehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localCount = await DatabaseHelper.instance.getStockTransfersCount(
        searchQuery: searchQuery,
        sourceWarehouseId: sourceWarehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('stock_transfers'));

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('number', isGreaterThanOrEqualTo: q)
            .where('number', isLessThanOrEqualTo: '$q\uf8ff');
      }

      if (sourceWarehouseId != null && sourceWarehouseId.isNotEmpty) {
        query = query.where('source_warehouse_id', isEqualTo: sourceWarehouseId);
      }

      if (status != null && status != 'Tous' && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status.toLowerCase());
      }

      final aggregateSnapshot = await query.count().get();
      return aggregateSnapshot.count ?? 0;
    } catch (e) {
      return DatabaseHelper.instance.getStockTransfersCount(
        searchQuery: searchQuery,
        sourceWarehouseId: sourceWarehouseId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: status,
      );
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
      final localAccounts = await DatabaseHelper.instance.getTreasuryAccountsPaginated(
        limit: pageSize,
        offset: 0,
        searchQuery: searchQuery,
      );
      if (localAccounts.isNotEmpty) {
        return localAccounts.map((e) => TreasuryAccount.fromMap(e)).toList();
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('treasury_accounts'));
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }
      query = query.orderBy('name', descending: false).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastTreasuryAccountSnapshot = snapshot.docs.last;
      }
      return snapshot.docs.map((doc) => TreasuryAccount.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      final localData = await DatabaseHelper.instance.getTreasuryAccountsPaginated(
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
      final localAccounts = await DatabaseHelper.instance.getTreasuryAccountsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
      );
      if (localAccounts.isNotEmpty) {
        return localAccounts.map((e) => TreasuryAccount.fromMap(e)).toList();
      }
    } catch (_) {}

    try {
      if (_lastTreasuryAccountSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('treasury_accounts'));
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }
      query = query.orderBy('name', descending: false).startAfterDocument(_lastTreasuryAccountSnapshot!).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastTreasuryAccountSnapshot = snapshot.docs.last;
      }
      return snapshot.docs.map((doc) => TreasuryAccount.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      final localData = await DatabaseHelper.instance.getTreasuryAccountsPaginated(
        limit: pageSize,
        offset: currentOffset,
        searchQuery: searchQuery,
      );
      return localData.map((e) => TreasuryAccount.fromMap(e)).toList();
    }
  }

  Future<int> getTreasuryAccountsCount({String? searchQuery}) async {
    try {
      final localCount = await DatabaseHelper.instance.getTreasuryAccountsCount(searchQuery: searchQuery);
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('treasury_accounts'));
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThanOrEqualTo: '$q\uf8ff');
      }
      final AggregateQuerySnapshot snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return await DatabaseHelper.instance.getTreasuryAccountsCount(searchQuery: searchQuery);
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
      final localData = await DatabaseHelper.instance.getTreasuryTransactionsPaginated(
        pageSize,
        0,
        searchQuery ?? '',
        typeFilter,
      );
      if (localData.isNotEmpty) {
        return localData.map((e) => TreasuryTransaction.fromMap(e)).toList();
      }
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('treasury_transactions'));
      
      if (typeFilter != 'Tous') {
        query = query.where('type', isEqualTo: typeFilter == 'Entrée' ? 'income' : 'expense');
      }

      // No range query on reference for transactions to allow ordering by date
      // We will sort by created_at DESC as required
      query = query.orderBy('created_at', descending: true).limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastTreasuryTransactionSnapshot = snapshot.docs.last;
      }
      
      var results = snapshot.docs.map((doc) => TreasuryTransaction.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        results = results.where((t) => 
          (t.transactionNumber.toLowerCase().contains(q)) || 
          (t.accountName?.toLowerCase().contains(q) ?? false) ||
          (t.description?.toLowerCase().contains(q) ?? false)
        ).toList();
      }
      
      return results;
    } catch (e) {
      final localData = await DatabaseHelper.instance.getTreasuryTransactionsPaginated(
        pageSize,
        0,
        searchQuery ?? '',
        typeFilter,
      );
      return localData.map((e) => TreasuryTransaction.fromMap(e)).toList();
    }
  }

  Future<List<TreasuryTransaction>> getNextTreasuryTransactions({
    int pageSize = 10,
    int currentOffset = 0,
    String? searchQuery,
    String typeFilter = 'Tous',
  }) async {
    try {
      final localData = await DatabaseHelper.instance.getTreasuryTransactionsPaginated(
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
      if (_lastTreasuryTransactionSnapshot == null) return [];

      Query query = _applyEnterpriseFilter(_firestore.collection('treasury_transactions'));
      
      if (typeFilter != 'Tous') {
        query = query.where('type', isEqualTo: typeFilter == 'Entrée' ? 'income' : 'expense');
      }

      query = query
          .orderBy('created_at', descending: true)
          .startAfterDocument(_lastTreasuryTransactionSnapshot!)
          .limit(pageSize);

      QuerySnapshot snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get(const GetOptions(source: Source.server));
        }
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.server));
      }

      if (snapshot.docs.isNotEmpty) {
        _lastTreasuryTransactionSnapshot = snapshot.docs.last;
      }
      
      var results = snapshot.docs.map((doc) => TreasuryTransaction.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        results = results.where((t) => 
          (t.transactionNumber.toLowerCase().contains(q)) || 
          (t.accountName?.toLowerCase().contains(q) ?? false) ||
          (t.description?.toLowerCase().contains(q) ?? false)
        ).toList();
      }
      
      return results;
    } catch (e) {
      final localData = await DatabaseHelper.instance.getTreasuryTransactionsPaginated(
        pageSize,
        currentOffset,
        searchQuery ?? '',
        typeFilter,
      );
      return localData.map((e) => TreasuryTransaction.fromMap(e)).toList();
    }
  }

  Future<int> getTreasuryTransactionsCount({String? searchQuery, String typeFilter = 'Tous'}) async {
    try {
      final localCount = await DatabaseHelper.instance.getTreasuryTransactionsCount(searchQuery ?? '', typeFilter);
      if (localCount > 0) return localCount;
    } catch (_) {}

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('treasury_transactions'));
      
      if (typeFilter != 'Tous') {
        query = query.where('type', isEqualTo: typeFilter == 'Entrée' ? 'income' : 'expense');
      }
      
      final AggregateQuerySnapshot snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return await DatabaseHelper.instance.getTreasuryTransactionsCount(searchQuery ?? '', typeFilter);
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
          String dbStatus = statusFilter == 'Payé' ? 'paid' : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
          if (p.status != dbStatus) return false;
        }

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.trim().toLowerCase();
          final ref = p.reference?.toLowerCase() ?? '';
          final num = p.paymentNumber.toLowerCase();
          final contact = p.contactName?.toLowerCase() ?? '';
          if (!ref.contains(q) && !num.contains(q) && !contact.contains(q)) return false;
        }

        return true;
      }).toList();

      return filtered.map((p) => RetenueSourceVente(
        id: p.id,
        invoiceReference: (p.reference != null && p.reference!.isNotEmpty) ? p.reference! : p.paymentNumber,
        clientName: p.contactName ?? 'Inconnu',
        date: p.paymentDate,
        amount: p.amount,
        status: (p.status == 'paid' || p.status == 'payee') ? 'Payé' : (p.status == 'cancelled' ? 'Annulé' : 'En attente'),
      )).toList();
    } catch (e) {
      print("Error reading local payments DB: $e");
      return [];
    }
  }

  Future<List<RetenueSourceVente>> getFirstRetenueSourceVentes({
    int pageSize = 10,
    String? searchQuery,
    String statusFilter = 'Tous',
    bool isSales = true,
  }) async {
    resetRetenueSourceVentesPagination();
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('payments'))
        .where('method', isEqualTo: 'retenue_source')
        .where('direction', isEqualTo: isSales ? 'encaissement' : 'decaissement')
        .orderBy('payment_date', descending: true);
      
      if (statusFilter != 'Tous') {
        String dbStatus = statusFilter == 'Payé' ? 'paid' : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
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
        var results = snapshot.docs.map((doc) => RetenueSourceVente.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
        results.sort((a, b) => b.date.compareTo(a.date));
        return results;
      }
    } catch (e) {
      print("Error getting retenue source ventes from Firebase: $e");
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
      return getFirstRetenueSourceVentes(pageSize: pageSize, searchQuery: searchQuery, statusFilter: statusFilter, isSales: isSales);
    }

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('payments'))
        .where('method', isEqualTo: 'retenue_source')
        .where('direction', isEqualTo: isSales ? 'encaissement' : 'decaissement')
        .orderBy('payment_date', descending: true);
      
      if (statusFilter != 'Tous') {
        String dbStatus = statusFilter == 'Payé' ? 'paid' : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
        query = query.where('status', isEqualTo: dbStatus);
      }
      
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query
            .where('reference', isGreaterThanOrEqualTo: q)
            .where('reference', isLessThanOrEqualTo: '$q\uf8ff');
      }

      query = query.startAfterDocument(_lastRetenueSourceVenteSnapshot!).limit(pageSize);
      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastRetenueSourceVenteSnapshot = snapshot.docs.last;
        var results = snapshot.docs.map((doc) => RetenueSourceVente.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
        results.sort((a, b) => b.date.compareTo(a.date));
        return results;
      }
    } catch (e) {
      print("Error getting next retenue source ventes from Firebase: $e");
    }

    final localResults = await _getRetenueSourceFromLocalDb(
      isSales: isSales,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
    );
    localResults.sort((a, b) => b.date.compareTo(a.date));
    return localResults;
  }

  Future<int> getRetenueSourceVentesCount({String? searchQuery, String statusFilter = 'Tous', bool isSales = true}) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('payments'))
        .where('method', isEqualTo: 'retenue_source')
        .where('direction', isEqualTo: isSales ? 'encaissement' : 'decaissement');
      
      if (statusFilter != 'Tous') {
        String dbStatus = statusFilter == 'Payé' ? 'paid' : (statusFilter == 'Annulé' ? 'cancelled' : 'pending');
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
          if (!name.contains(q) && !code.contains(q) && !ref.contains(q)) return false;
        }

        return true;
      }).toList();

      return filtered;
    } catch (e) {
      print("Error reading local products DB: $e");
      return [];
    }
  }

  Future<List<Product>> getFirstProducts({
    int pageSize = 10,
    String? searchQuery,
    String stockFilter = 'Tous',
  }) async {
    resetProductsPagination();
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('products')).where('is_deleted', isEqualTo: false);

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

      if (snapshot.docs.isNotEmpty) {
        _lastProductSnapshot = snapshot.docs.last;
        var results = snapshot.docs.map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>)).toList();
        return results;
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
      return getFirstProducts(pageSize: pageSize, searchQuery: searchQuery, stockFilter: stockFilter);
    }

    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('products')).where('is_deleted', isEqualTo: false);

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
        var results = snapshot.docs.map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>)).toList();
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

  Future<int> getProductsCount({String? searchQuery, String stockFilter = 'Tous'}) async {
    try {
      Query query = _applyEnterpriseFilter(_firestore.collection('products')).where('is_deleted', isEqualTo: false);

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

