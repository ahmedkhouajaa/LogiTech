import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/supplier_order.dart';
import '../../database/database_helper.dart';

// ─── Events ────────────────────────────────────────────────────────
abstract class SupplierOrdersEvent {}

class LoadSupplierOrders extends SupplierOrdersEvent {}

class AddSupplierOrder extends SupplierOrdersEvent {
  final SupplierOrder order;
  AddSupplierOrder(this.order);
}

class UpdateSupplierOrder extends SupplierOrdersEvent {
  final SupplierOrder order;
  UpdateSupplierOrder(this.order);
}

class DeleteSupplierOrder extends SupplierOrdersEvent {
  final String orderId;
  DeleteSupplierOrder(this.orderId);
}

class FilterSupplierOrders extends SupplierOrdersEvent {
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  FilterSupplierOrders({this.supplierId, this.dateFrom, this.dateTo, this.status});
}

// ─── States ────────────────────────────────────────────────────────
abstract class SupplierOrdersState {}

class SupplierOrdersInitial extends SupplierOrdersState {}

class SupplierOrdersLoading extends SupplierOrdersState {}

class SupplierOrdersLoaded extends SupplierOrdersState {
  final List<SupplierOrder> orders;
  final String? supplierFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  SupplierOrdersLoaded(
    this.orders, {
    this.supplierFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });

  SupplierOrdersLoaded copyWith({
    List<SupplierOrder>? orders,
    String? supplierFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    String? statusFilter,
  }) {
    return SupplierOrdersLoaded(
      orders ?? this.orders,
      supplierFilter: supplierFilter ?? this.supplierFilter,
      dateFromFilter: dateFromFilter ?? this.dateFromFilter,
      dateToFilter: dateToFilter ?? this.dateToFilter,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class SupplierOrdersError extends SupplierOrdersState {
  final String message;
  SupplierOrdersError(this.message);
}

// ─── BLoC ──────────────────────────────────────────────────────────
class SupplierOrdersBloc extends Bloc<SupplierOrdersEvent, SupplierOrdersState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SupplierOrdersBloc() : super(SupplierOrdersInitial()) {
    on<LoadSupplierOrders>(_onLoadSupplierOrders);
    on<AddSupplierOrder>(_onAddSupplierOrder);
    on<UpdateSupplierOrder>(_onUpdateSupplierOrder);
    on<DeleteSupplierOrder>(_onDeleteSupplierOrder);
    on<FilterSupplierOrders>(_onFilterSupplierOrders);
  }

  Future<void> _onLoadSupplierOrders(LoadSupplierOrders event, Emitter<SupplierOrdersState> emit) async {
    emit(SupplierOrdersLoading());
    try {
      final orders = await _dbHelper.getSupplierOrders();
      emit(SupplierOrdersLoaded(orders));
    } catch (e) {
      emit(SupplierOrdersError(e.toString()));
    }
  }

  Future<void> _onAddSupplierOrder(AddSupplierOrder event, Emitter<SupplierOrdersState> emit) async {
    try {
      await _dbHelper.insertSupplierOrder(event.order);
      add(LoadSupplierOrders());
    } catch (e) {
      emit(SupplierOrdersError(e.toString()));
    }
  }

  Future<void> _onUpdateSupplierOrder(UpdateSupplierOrder event, Emitter<SupplierOrdersState> emit) async {
    try {
      await _dbHelper.updateSupplierOrder(event.order);
      add(LoadSupplierOrders());
    } catch (e) {
      emit(SupplierOrdersError(e.toString()));
    }
  }

  Future<void> _onDeleteSupplierOrder(DeleteSupplierOrder event, Emitter<SupplierOrdersState> emit) async {
    try {
      await _dbHelper.softDeleteSupplierOrder(event.orderId);
      add(LoadSupplierOrders());
    } catch (e) {
      emit(SupplierOrdersError(e.toString()));
    }
  }

  Future<void> _onFilterSupplierOrders(FilterSupplierOrders event, Emitter<SupplierOrdersState> emit) async {
    final currentState = state;
    if (currentState is SupplierOrdersLoaded) {
      emit(SupplierOrdersLoading());
      try {
        final allOrders = await _dbHelper.getSupplierOrders(
          status: event.status,
          startDate: event.dateFrom,
          endDate: event.dateTo,
        );

        final filteredOrders = allOrders.where((order) {
          if (event.supplierId != null && event.supplierId != 'all' && event.supplierId!.isNotEmpty) {
            return order.supplierId == event.supplierId;
          }
          return true;
        }).toList();

        emit(SupplierOrdersLoaded(
          filteredOrders,
          supplierFilter: event.supplierId,
          dateFromFilter: event.dateFrom,
          dateToFilter: event.dateTo,
          statusFilter: event.status,
        ));
      } catch (e) {
        emit(SupplierOrdersError(e.toString()));
      }
    } else {
      emit(SupplierOrdersLoading());
      try {
        final allOrders = await _dbHelper.getSupplierOrders(
          status: event.status,
          startDate: event.dateFrom,
          endDate: event.dateTo,
        );
        final filteredOrders = allOrders.where((order) {
          if (event.supplierId != null && event.supplierId != 'all' && event.supplierId!.isNotEmpty) {
            return order.supplierId == event.supplierId;
          }
          return true;
        }).toList();
        emit(SupplierOrdersLoaded(
          filteredOrders,
          supplierFilter: event.supplierId,
          dateFromFilter: event.dateFrom,
          dateToFilter: event.dateTo,
          statusFilter: event.status,
        ));
      } catch (e) {
        emit(SupplierOrdersError(e.toString()));
      }
    }
  }
}
