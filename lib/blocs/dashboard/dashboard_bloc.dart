import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/error_handler.dart';
import '../../services/enterprise_service.dart';
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
  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onRefreshRequested(DashboardRefreshRequested event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
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
      
      final db = FirebaseFirestore.instance;
      final timeout = kIsWeb ? const Duration(seconds: 5) : const Duration(seconds: 15);

      DashboardLoaded computeState({
        required QuerySnapshot invoicesSnapshot,
        required QuerySnapshot paymentsSnapshot,
        required QuerySnapshot deliveryNotesSnapshot,
        required QuerySnapshot purchaseInvoicesSnapshot,
        required QuerySnapshot productsSnapshot,
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

        for (var doc in invoicesSnapshot.docs) {
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

        recentInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        recentInvoices = recentInvoices.take(5).toList();

        double totalPaid = 0.0;
        for (var doc in paymentsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          bool isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['is_deleted'] == '1';
          if (!isDeleted) {
            totalPaid += (data['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final totalDeliveryNotes = deliveryNotesSnapshot.docs.length.toDouble();

        double totalTvaDeductible = 0.0;
        for (var doc in purchaseInvoicesSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalTvaDeductible += (data['total_tva'] as num?)?.toDouble() ?? 0.0;
        }

        List<Product> lowStockProducts = [];
        for (var doc in productsSnapshot.docs) {
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
          totalDeliveryNotes: totalDeliveryNotes,
          totalTvaCollected: totalTvaCollected,
          totalTvaDeductible: totalTvaDeductible,
          invoiceStatusBreakdown: statusBreakdown,
          recentInvoices: recentInvoices,
          lowStockProducts: lowStockProducts,
          upcomingChecks: const [],
        );
      }

      // Phase 1: Try reading from local Firestore cache for INSTANT <50ms display
      try {
        final cacheFutures = await Future.wait([
          db.collection('invoices').where('enterprise_id', isEqualTo: currentEntId).where('is_deleted', isEqualTo: 0).get(const GetOptions(source: Source.cache)),
          db.collection('paiements').where('enterprise_id', isEqualTo: currentEntId).where('direction', isEqualTo: 'encaissement').get(const GetOptions(source: Source.cache)),
          db.collection('delivery_notes').where('enterprise_id', isEqualTo: currentEntId).where('is_deleted', isEqualTo: 0).get(const GetOptions(source: Source.cache)),
          db.collection('purchase_invoices').where('enterprise_id', isEqualTo: currentEntId).where('is_deleted', isEqualTo: 0).get(const GetOptions(source: Source.cache)),
          db.collection('articles').where('enterprise_id', isEqualTo: currentEntId).where('is_deleted', isEqualTo: 0).get(const GetOptions(source: Source.cache)),
        ]);
        
        final hasCachedData = cacheFutures.any((s) => s.docs.isNotEmpty);
        if (hasCachedData && !emit.isDone) {
          emit(computeState(
            invoicesSnapshot: cacheFutures[0],
            paymentsSnapshot: cacheFutures[1],
            deliveryNotesSnapshot: cacheFutures[2],
            purchaseInvoicesSnapshot: cacheFutures[3],
            productsSnapshot: cacheFutures[4],
          ));
          debugPrint('[PERF/Dashboard] Displayed metrics from local cache instantaneously (<50ms)');
        }
      } catch (_) {}

      // Phase 2: Fetch fresh data from server in parallel
      final fetchStopwatch = Stopwatch()..start();
      final futures = await Future.wait([
        // 1. Invoices
        db.collection('invoices')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .get(),
        // 2. Payments (for totalPaid)
        db.collection('paiements')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('direction', isEqualTo: 'encaissement')
            .get(),
        // 3. Delivery Notes
        db.collection('delivery_notes')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .get(),
        // 4. Purchase Invoices (for totalTvaDeductible)
        db.collection('purchase_invoices')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .get(),
        // 5. Low Stock Products (Articles)
        db.collection('articles')
            .where('enterprise_id', isEqualTo: currentEntId)
            .where('is_deleted', isEqualTo: 0)
            .get(),
      ]).timeout(timeout);

      fetchStopwatch.stop();
      final invoicesSnapshot = futures[0];
      final paymentsSnapshot = futures[1];
      final deliveryNotesSnapshot = futures[2];
      final purchaseInvoicesSnapshot = futures[3];
      final productsSnapshot = futures[4];

      debugPrint('[PERF/Dashboard] Fetched server metrics in ${fetchStopwatch.elapsedMilliseconds}ms');

      final freshState = computeState(
        invoicesSnapshot: invoicesSnapshot,
        paymentsSnapshot: paymentsSnapshot,
        deliveryNotesSnapshot: deliveryNotesSnapshot,
        purchaseInvoicesSnapshot: purchaseInvoicesSnapshot,
        productsSnapshot: productsSnapshot,
      );

      if (!emit.isDone) {
        emit(freshState);
      }
    } catch (e) {
      debugPrint('[DashboardBloc] Error loading dashboard metrics: $e');
      if (!emit.isDone) {
        emit(DashboardError('Erreur de chargement du tableau de bord: ${ErrorHandler.parseError(e)}'));
      }
    }
  }
}
