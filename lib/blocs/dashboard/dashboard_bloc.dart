import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../models/check_traite.dart';
import '../../models/project.dart';

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
      final db = DatabaseHelper.instance;
      
      final totalInvoiced = await db.getTotalInvoiced();
      final totalPaid = await db.getTotalPaid();
      final totalDeliveryNotes = await db.getTotalDeliveryNotes();
      final totalTvaCollected = await db.getTotalTvaCollected();
      final totalTvaDeductible = await db.getTotalTvaDeductible();
      final invoiceStatusBreakdown = await db.getInvoiceStatusBreakdown();
      final recentInvoices = await db.getRecentInvoices(limit: 5);
      final lowStockProducts = await db.getLowStockProducts();
      final upcomingChecks = await db.getUpcomingChecksTraites();

      print('DashboardBloc: all queries completed, emitting DashboardLoaded!');
      emit(DashboardLoaded(
        totalInvoiced: totalInvoiced,
        totalPaid: totalPaid,
        totalDeliveryNotes: totalDeliveryNotes,
        totalTvaCollected: totalTvaCollected,
        totalTvaDeductible: totalTvaDeductible,
        invoiceStatusBreakdown: invoiceStatusBreakdown,
        recentInvoices: recentInvoices,
        lowStockProducts: lowStockProducts,
        upcomingChecks: upcomingChecks,
      ));
      print('DashboardBloc: emitted DashboardLoaded!');
    } catch (e) {
      print('DashboardBloc: Error: $e');
      emit(DashboardError(e.toString()));
    }
  }
}
