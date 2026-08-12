import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/report_data.dart';
import '../../repositories/report_repository.dart';
import 'package:business_manager_pro/services/error_handler.dart';

// ─── Events ────────────────────────────────────────────────────────
abstract class ReportsEvent extends Equatable {
  const ReportsEvent();
  @override
  List<Object?> get props => [];
}

class ReportsRefreshRequested extends ReportsEvent {
  final String dateRange;
  final String? warehouse;
  final String? category;

  const ReportsRefreshRequested({
    required this.dateRange,
    this.warehouse,
    this.category,
  });

  @override
  List<Object?> get props => [dateRange, warehouse, category];
}

// ─── States ────────────────────────────────────────────────────────
abstract class ReportsState extends Equatable {
  const ReportsState();
  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final double turnoverRate;
  final double fulfillmentRate;
  final double avgDeliveryTime;
  final double stockoutRate;

  final List<MonthlySales> monthlySales;
  final List<WarehouseStock> warehouseStock;
  final List<CategorySales> categorySales;
  final List<TopClient> topClients;
  final List<SupplierPerformance> supplierPerformance;

  const ReportsLoaded({
    required this.turnoverRate,
    required this.fulfillmentRate,
    required this.avgDeliveryTime,
    required this.stockoutRate,
    required this.monthlySales,
    required this.warehouseStock,
    required this.categorySales,
    required this.topClients,
    required this.supplierPerformance,
  });

  @override
  List<Object?> get props => [
        turnoverRate,
        fulfillmentRate,
        avgDeliveryTime,
        stockoutRate,
        monthlySales,
        warehouseStock,
        categorySales,
        topClients,
        supplierPerformance,
      ];
}

class ReportsError extends ReportsState {
  final String message;
  const ReportsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ──────────────────────────────────────────────────────────
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final _repository = ReportRepository();

  ReportsBloc() : super(ReportsInitial()) {
    on<ReportsRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onRefreshRequested(
      ReportsRefreshRequested event, Emitter<ReportsState> emit) async {
    emit(ReportsLoading());
    try {
      final monthlySales = await _repository.getMonthlySales(event.dateRange);
      final warehouseStock = await _repository.getWarehouseStock();
      final categorySales = await _repository.getCategorySales();
      final topClients = await _repository.getTopClients(10);
      final kpis = await _repository.getKPIs();
      final supplierPerformance = await _repository.getSupplierPerformance();

      emit(ReportsLoaded(
        turnoverRate: kpis['turnoverRate'] ?? 0.0,
        fulfillmentRate: kpis['fulfillmentRate'] ?? 0.0,
        avgDeliveryTime: kpis['avgDeliveryTime'] ?? 0.0,
        stockoutRate: kpis['stockoutRate'] ?? 0.0,
        monthlySales: monthlySales,
        warehouseStock: warehouseStock,
        categorySales: categorySales,
        topClients: topClients,
        supplierPerformance: supplierPerformance,
      ));
    } catch (e) {
      emit(ReportsError(ErrorHandler.parseError(e)));
    }
  }
}

