import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/error_handler.dart';
import '../../services/enterprise_service.dart';
import '../../services/offline_document_service.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../models/check_traite.dart';

// Events
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class DashboardRefreshRequested extends DashboardEvent {}

// States
abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}
class DashboardLoaded extends DashboardState {
  final double totalInvoiced;
  final double totalPaid;
  final double totalDeliveryNotes;
  final double totalTvaCollected;
  final double totalTvaDeductible;
  final Map<String, double> invoiceStatusBreakdown;
  final List<Invoice> recentInvoices;
  final List<Product> lowStockProducts;
  final List<CheckTraite> upcomingChecks;

  const DashboardLoaded({
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalDeliveryNotes,
    required this.totalTvaCollected,
    required this.totalTvaDeductible,
    required this.invoiceStatusBreakdown,
    required this.recentInvoices,
    required this.lowStockProducts,
    required this.upcomingChecks,
  });

  @override
  List<Object?> get props => [
        totalInvoiced, totalPaid, totalDeliveryNotes, totalTvaCollected,
        totalTvaDeductible, invoiceStatusBreakdown, recentInvoices,
        lowStockProducts, upcomingChecks
      ];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  static const String _cacheKeyPrefix = 'cached_dashboard_metrics_v2_';

  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _saveToLocalCache(String entId, DashboardLoaded state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'totalInvoiced': state.totalInvoiced,
        'totalPaid': state.totalPaid,
        'totalDeliveryNotes': state.totalDeliveryNotes,
        'totalTvaCollected': state.totalTvaCollected,
        'totalTvaDeductible': state.totalTvaDeductible,
        'invoiceStatusBreakdown': state.invoiceStatusBreakdown,
        'recentInvoices': state.recentInvoices.map((i) => i.toMap()).toList(),
        'lowStockProducts': state.lowStockProducts.map((p) => p.toMap()).toList(),
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString('$_cacheKeyPrefix$entId', jsonEncode(map));
      debugPrint('[DashboardBloc] Cached dashboard metrics locally for enterprise $entId');
    } catch (e) {
      debugPrint('[DashboardBloc] Error saving dashboard metrics to cache: $e');
    }
  }

  Future<DashboardLoaded?> _loadFromLocalCache(String entId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_cacheKeyPrefix$entId');
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final rawBreakdown = map['invoiceStatusBreakdown'] as Map<String, dynamic>? ?? {};
      final breakdown = <String, double>{};
      rawBreakdown.forEach((k, v) {
        breakdown[k] = (v as num).toDouble();
      });

      final rawInvoices = map['recentInvoices'] as List<dynamic>? ?? [];
      final recentInvoices = <Invoice>[];
      for (final item in rawInvoices) {
        try {
          recentInvoices.add(Invoice.fromMap(Map<String, dynamic>.from(item as Map)));
        } catch (_) {}
      }

      final rawProducts = map['lowStockProducts'] as List<dynamic>? ?? [];
      final lowStockProducts = <Product>[];
      for (final item in rawProducts) {
        try {
          lowStockProducts.add(Product.fromMap(Map<String, dynamic>.from(item as Map)));
        } catch (_) {}
      }

      return DashboardLoaded(
        totalInvoiced: (map['totalInvoiced'] as num?)?.toDouble() ?? 0.0,
        totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
        totalDeliveryNotes: (map['totalDeliveryNotes'] as num?)?.toDouble() ?? 0.0,
        totalTvaCollected: (map['totalTvaCollected'] as num?)?.toDouble() ?? 0.0,
        totalTvaDeductible: (map['totalTvaDeductible'] as num?)?.toDouble() ?? 0.0,
        invoiceStatusBreakdown: breakdown,
        recentInvoices: recentInvoices,
        lowStockProducts: lowStockProducts,
        upcomingChecks: const [],
      );
    } catch (e) {
      debugPrint('[DashboardBloc] Error loading dashboard metrics from cache: $e');
      return null;
    }
  }

  DashboardLoaded _computeState({
    required List<QueryDocumentSnapshot<Object?>> invoicesDocs,
    required List<QueryDocumentSnapshot<Object?>> paymentsDocs,
    required double deliveryNotesCount,
    required List<QueryDocumentSnapshot<Object?>> purchaseInvoicesDocs,
    required List<QueryDocumentSnapshot<Object?>> productsDocs,
    List<Map<String, dynamic>> pendingInvoices = const [],
  }) {
    double totalInvoiced = 0.0;
    double totalTvaCollected = 0.0;
    Map<String, double> statusBreakdown = {
      'paye': 0.0,
      'brouillon': 0.0,
      'confirme': 0.0,
      'annule': 0.0,
    };
    List<Invoice> recentInvoices = [];

    // 1. Process invoices from Firestore
    for (var doc in invoicesDocs) {
      final data = doc.data() as Map<String, dynamic>;
      double totalTtc = (data['total_ttc'] as num?)?.toDouble() ?? 0.0;
      double totalTva = (data['total_tva'] as num?)?.toDouble() ?? 0.0;
      String status = data['status'] ?? 'brouillon';
      if (status == 'paid') status = 'paye';
      if (status == 'confirmed') status = 'confirme';
      if (status == 'cancelled') status = 'annule';
      if (status == 'pending') status = 'brouillon';

      totalInvoiced += totalTtc;
      totalTvaCollected += totalTva;

      if (statusBreakdown.containsKey(status)) {
        statusBreakdown[status] = statusBreakdown[status]! + 1;
      } else {
        statusBreakdown[status] = 1;
      }

      final invoiceMap = Map<String, dynamic>.from(data);
      invoiceMap['id'] = doc.id;
      try {
        recentInvoices.add(Invoice.fromMap(invoiceMap));
      } catch (_) {}
    }

    // 2. Include any offline pending invoices not yet synced
    final existingIds = recentInvoices.map((i) => i.id).toSet();
    for (var pMap in pendingInvoices) {
      final id = pMap['id']?.toString() ?? '';
      if (existingIds.contains(id)) continue;

      double totalTtc = (pMap['total_ttc'] as num?)?.toDouble() ?? 0.0;
      double totalTva = (pMap['total_tva'] as num?)?.toDouble() ?? 0.0;
      String status = pMap['status'] ?? 'brouillon';
      if (status == 'paid') status = 'paye';
      if (status == 'confirmed') status = 'confirme';
      if (status == 'cancelled') status = 'annule';
      if (status == 'pending') status = 'brouillon';

      totalInvoiced += totalTtc;
      totalTvaCollected += totalTva;
      statusBreakdown[status] = (statusBreakdown[status] ?? 0.0) + 1;

      try {
        recentInvoices.add(Invoice.fromMap(pMap));
      } catch (_) {}
    }

    recentInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    recentInvoices = recentInvoices.take(5).toList();

    // 3. Payments
    double totalPaid = 0.0;
    for (var doc in paymentsDocs) {
      final data = doc.data() as Map<String, dynamic>;
      bool isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['is_deleted'] == '1';
      if (!isDeleted) {
        totalPaid += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // 4. Purchase invoices
    double totalTvaDeductible = 0.0;
    for (var doc in purchaseInvoicesDocs) {
      final data = doc.data() as Map<String, dynamic>;
      totalTvaDeductible += (data['total_tva'] as num?)?.toDouble() ?? 0.0;
    }

    // 5. Products
    List<Product> lowStockProducts = [];
    for (var doc in productsDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final prodMap = Map<String, dynamic>.from(data);
      prodMap['id'] = doc.id;
      try {
        final p = Product.fromMap(prodMap);
        if (p.stockQty <= p.lowStockThreshold && p.productType != 'service') {
          lowStockProducts.add(p);
        }
      } catch (_) {}
    }
    lowStockProducts = lowStockProducts.take(10).toList();

    return DashboardLoaded(
      totalInvoiced: totalInvoiced,
      totalPaid: totalPaid,
      totalDeliveryNotes: deliveryNotesCount,
      totalTvaCollected: totalTvaCollected,
      totalTvaDeductible: totalTvaDeductible,
      invoiceStatusBreakdown: statusBreakdown,
      recentInvoices: recentInvoices,
      lowStockProducts: lowStockProducts,
      upcomingChecks: const [],
    );
  }

  Future<QuerySnapshot<Object?>?> _safeGet(
    Query query, {
    Source source = Source.serverAndCache,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      if (source == Source.cache) {
        return await query.get(const GetOptions(source: Source.cache));
      } else {
        return await query.get().timeout(timeout);
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _onRefreshRequested(
    DashboardRefreshRequested event,
    Emitter<DashboardState> emit,
  ) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    if (currentEntId == null || currentEntId.isEmpty) {
      emit(const DashboardLoaded(
        totalInvoiced: 0.0,
        totalPaid: 0.0,
        totalDeliveryNotes: 0.0,
        totalTvaCollected: 0.0,
        totalTvaDeductible: 0.0,
        invoiceStatusBreakdown: {'paye': 0.0, 'brouillon': 0.0, 'confirme': 0.0, 'annule': 0.0},
        recentInvoices: [],
        lowStockProducts: [],
        upcomingChecks: [],
      ));
      return;
    }

    // Step 1: Provide instant display without screen wiping
    if (state is! DashboardLoaded) {
      final cachedState = await _loadFromLocalCache(currentEntId);
      if (cachedState != null && !emit.isDone) {
        emit(cachedState);
        debugPrint('[DashboardBloc] Rendered instantaneous dashboard from local SharedPreferences cache');
      } else if (!emit.isDone) {
        emit(DashboardLoading());
      }
    }

    final db = FirebaseFirestore.instance;

    // Step 2: Try Firestore offline cache & offline pending documents
    try {
      final pendingInvoices = await OfflineDocumentService.instance.getPendingDocuments('invoices');
      final pendingDeliveryNotes = await OfflineDocumentService.instance.getPendingDocuments('delivery_notes');

      // Safely query each collection independently
      final invoicesCache = await _safeGet(
        db.collection('invoices').where('enterprise_id', isEqualTo: currentEntId).where('is_deleted', isEqualTo: 0),
        source: Source.cache,
      );
      final paymentsCache = await _safeGet(
        db.collection('paiements').where('enterprise_id', isEqualTo: currentEntId).where('direction', isEqualTo: 'encaissement'),
        source: Source.cache,
      );
      final deliveryNotesCache = await _safeGet(
        db.collection('delivery_notes').where('enterprise_id', isEqualTo: currentEntId).where('is_deleted', isEqualTo: 0),
        source: Source.cache,
      );
      final purchaseInvoicesCache = await _safeGet(
        db.collection('purchase_invoices').where('enterprise_id', isEqualTo: currentEntId).where('is_deleted', isEqualTo: 0),
        source: Source.cache,
      );
      final productsCache = await _safeGet(
        db.collection('articles').where('enterprise_id', isEqualTo: currentEntId).where('is_deleted', isEqualTo: 0),
        source: Source.cache,
      );

      final hasAnyDocs = (invoicesCache?.docs.isNotEmpty ?? false) ||
          (paymentsCache?.docs.isNotEmpty ?? false) ||
          (deliveryNotesCache?.docs.isNotEmpty ?? false) ||
          (purchaseInvoicesCache?.docs.isNotEmpty ?? false) ||
          (productsCache?.docs.isNotEmpty ?? false) ||
          pendingInvoices.isNotEmpty;

      if (hasAnyDocs && !emit.isDone) {
        final cachedComputed = _computeState(
          invoicesDocs: invoicesCache?.docs ?? [],
          paymentsDocs: paymentsCache?.docs ?? [],
          deliveryNotesCount: (deliveryNotesCache?.docs.length.toDouble() ?? 0.0) + pendingDeliveryNotes.length.toDouble(),
          purchaseInvoicesDocs: purchaseInvoicesCache?.docs ?? [],
          productsDocs: productsCache?.docs ?? [],
          pendingInvoices: pendingInvoices,
        );
        emit(cachedComputed);
        unawaited(_saveToLocalCache(currentEntId, cachedComputed));
        debugPrint('[DashboardBloc] Updated dashboard from Firestore offline cache');
      }
    } catch (e) {
      debugPrint('[DashboardBloc] Local cache reading info: $e');
    }

    // Step 3: Fetch fresh data from remote server in parallel
    try {
      final timeout = kIsWeb ? const Duration(seconds: 4) : const Duration(seconds: 5);

      final results = await Future.wait([
        db.collection('invoices')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .get()
            .timeout(timeout),
        db.collection('paiements')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('direction', isEqualTo: 'encaissement')
            .get()
            .timeout(timeout),
        db.collection('delivery_notes')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .get()
            .timeout(timeout),
        db.collection('purchase_invoices')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .get()
            .timeout(timeout),
        db.collection('articles')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .get()
            .timeout(timeout),
      ]);

      final pendingInvoices = await OfflineDocumentService.instance.getPendingDocuments('invoices');
      final pendingDeliveryNotes = await OfflineDocumentService.instance.getPendingDocuments('delivery_notes');

      final freshState = _computeState(
        invoicesDocs: results[0].docs,
        paymentsDocs: results[1].docs,
        deliveryNotesCount: results[2].docs.length.toDouble() + pendingDeliveryNotes.length.toDouble(),
        purchaseInvoicesDocs: results[3].docs,
        productsDocs: results[4].docs,
        pendingInvoices: pendingInvoices,
      );

      if (!emit.isDone) {
        emit(freshState);
        unawaited(_saveToLocalCache(currentEntId, freshState));
        debugPrint('[DashboardBloc] Successfully loaded fresh dashboard metrics from server');
      }
    } catch (e) {
      debugPrint('[DashboardBloc] Server fetch unavailable/offline/timeout: $e');
      
      // CRITICAL FIX: If we already have a loaded state, NEVER replace it with an error!
      if (state is DashboardLoaded) {
        debugPrint('[DashboardBloc] Retaining current dashboard state while offline.');
        return;
      }

      // Check if we can recover from SharedPreferences cache
      final fallbackState = await _loadFromLocalCache(currentEntId);
      if (fallbackState != null && !emit.isDone) {
        emit(fallbackState);
        debugPrint('[DashboardBloc] Recovered dashboard from fallback local cache.');
        return;
      }

      // Only emit error if there is zero data available
      if (!emit.isDone) {
        emit(DashboardError('Erreur de chargement du tableau de bord: ${ErrorHandler.parseError(e)}'));
      }
    }
  }
}
