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
      
      final results = await Future.wait([
        db.getTotalInvoiced(),
        db.getTotalPaid(),
        db.getTotalDeliveryNotes(),
        db.getTotalTvaCollected(),
        db.getTotalTvaDeductible(),
        db.getInvoiceStatusBreakdown(),
        db.getRecentInvoices(limit: 5),
        db.getLowStockProducts(),
        db.getUpcomingChecksTraites(),
      ]);

      emit(DashboardLoaded(
        totalInvoiced: results[0] as double,
        totalPaid: results[1] as double,
        totalDeliveryNotes: results[2] as double,
        totalTvaCollected: results[3] as double,
        totalTvaDeductible: results[4] as double,
        invoiceStatusBreakdown: results[5] as Map<String, double>,
        recentInvoices: results[6] as List<Invoice>,
        lowStockProducts: results[7] as List<Product>,
        upcomingChecks: results[8] as List<CheckTraite>,
      ));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
