import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/enterprise_service.dart';
import '../../database/database_helper.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../models/check_traite.dart';
import '../../models/project.dart';
import 'package:business_manager_pro/services/error_handler.dart';

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
      if (currentEntId == null) {
        throw Exception("Aucune entreprise sélectionnée");
      }
      
      final db = FirebaseFirestore.instance;
      
      // 1. Invoices
      final invoicesSnapshot = await db.collection('invoices')
          .where('enterprise_id', isEqualTo: currentEntId)
          .where('is_deleted', isEqualTo: 0)
          .get();
          
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
        final data = doc.data();
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
        
        data['id'] = doc.id;
        try {
           recentInvoices.add(Invoice.fromMap(data));
        } catch (_) {}
      }
      
      recentInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      recentInvoices = recentInvoices.take(5).toList();
      
      // 2. Payments (for totalPaid)
      final paymentsSnapshot = await db.collection('paiements')
          .where('enterprise_id', isEqualTo: currentEntId)
          .where('direction', isEqualTo: 'encaissement')
          .get();
          
      double totalPaid = 0.0;
      for (var doc in paymentsSnapshot.docs) {
         final data = doc.data();
         bool isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true || data['is_deleted'] == '1';
         if (!isDeleted) {
           totalPaid += (data['amount'] as num?)?.toDouble() ?? 0.0;
         }
      }
      
      // 3. Delivery Notes
      final deliveryNotesSnapshot = await db.collection('delivery_notes')
          .where('enterprise_id', isEqualTo: currentEntId)
          .where('is_deleted', isEqualTo: 0)
          .count()
          .get();
      final totalDeliveryNotes = (deliveryNotesSnapshot.count ?? 0).toDouble();
      
      // 4. Purchase Invoices (for totalTvaDeductible)
      final purchaseInvoicesSnapshot = await db.collection('purchase_invoices')
          .where('enterprise_id', isEqualTo: currentEntId)
          .where('is_deleted', isEqualTo: 0)
          .get();
          
      double totalTvaDeductible = 0.0;
      for (var doc in purchaseInvoicesSnapshot.docs) {
        final data = doc.data();
        totalTvaDeductible += (data['total_tva'] as num?)?.toDouble() ?? 0.0;
      }
      
      // 5. Low Stock Products
      final productsSnapshot = await db.collection('products')
          .where('enterprise_id', isEqualTo: currentEntId)
          .where('is_deleted', isEqualTo: 0)
          .get();
          
      List<Product> lowStockProducts = [];
      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        try {
          final p = Product.fromMap(data);
          if (p.stockQty <= p.lowStockThreshold && p.productType != 'service') {
             lowStockProducts.add(p);
          }
        } catch (_) {}
      }
      lowStockProducts = lowStockProducts.take(10).toList();

      final upcomingChecks = await DatabaseHelper.instance.getUpcomingChecksTraites();

      print('DashboardBloc: all queries completed, emitting DashboardLoaded!');
      emit(DashboardLoaded(
        totalInvoiced: totalInvoiced,
        totalPaid: totalPaid,
        totalDeliveryNotes: totalDeliveryNotes,
        totalTvaCollected: totalTvaCollected,
        totalTvaDeductible: totalTvaDeductible,
        invoiceStatusBreakdown: statusBreakdown,
        recentInvoices: recentInvoices,
        lowStockProducts: lowStockProducts,
        upcomingChecks: upcomingChecks,
      ));
    } catch (e) {
      print('DashboardBloc: Error: $e');
      emit(DashboardError(ErrorHandler.parseError(e)));
    }
  }
}
