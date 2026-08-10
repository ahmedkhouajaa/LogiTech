import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/supplier_order.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';

// ─── Events ────────────────────────────────────────────────────────
abstract class SupplierOrdersEvent {}

class LoadSupplierOrders extends SupplierOrdersEvent {}

class LoadFirstSupplierOrders extends SupplierOrdersEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadFirstSupplierOrders({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextSupplierOrders extends SupplierOrdersEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextSupplierOrders({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetSupplierOrdersPagination extends SupplierOrdersEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetSupplierOrdersPagination({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

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
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String? supplierFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  SupplierOrdersLoaded(
    this.orders, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.supplierFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });

  SupplierOrdersLoaded copyWith({
    List<SupplierOrder>? orders,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? supplierFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    String? statusFilter,
  }) {
    return SupplierOrdersLoaded(
      orders ?? this.orders,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
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
  static const int pageSize = 10;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SupplierOrdersBloc() : super(SupplierOrdersInitial()) {
    on<LoadSupplierOrders>(_onLoadSupplierOrders);
    on<LoadFirstSupplierOrders>(_onLoadFirstSupplierOrders);
    on<LoadNextSupplierOrders>(_onLoadNextSupplierOrders);
    on<ResetSupplierOrdersPagination>(_onResetSupplierOrdersPagination);
    on<AddSupplierOrder>(_onAddSupplierOrder);
    on<UpdateSupplierOrder>(_onUpdateSupplierOrder);
    on<DeleteSupplierOrder>(_onDeleteSupplierOrder);
    on<FilterSupplierOrders>(_onFilterSupplierOrders);
  }

  Future<void> _onLoadSupplierOrders(LoadSupplierOrders event, Emitter<SupplierOrdersState> emit) async {
    await _onLoadFirstSupplierOrders(LoadFirstSupplierOrders(), emit);
  }

  Future<void> _onLoadFirstSupplierOrders(LoadFirstSupplierOrders event, Emitter<SupplierOrdersState> emit) async {
    emit(SupplierOrdersLoading());
    try {
      FirestorePaginationService.instance.resetSupplierOrdersPagination();
      final ordersFuture = FirestorePaginationService.instance.getFirstSupplierOrders(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getSupplierOrdersCount(
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([ordersFuture, countFuture]);
      final orders = results[0] as List<SupplierOrder>;
      final totalCount = results[1] as int;

      emit(SupplierOrdersLoaded(
        orders,
        totalCount: totalCount > orders.length ? totalCount : orders.length,
        hasMore: orders.length >= pageSize,
      ));
    } catch (e) {
      emit(SupplierOrdersError(e.toString()));
    }
  }

  Future<void> _onLoadNextSupplierOrders(LoadNextSupplierOrders event, Emitter<SupplierOrdersState> emit) async {
    final currentState = state;
    if (currentState is! SupplierOrdersLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextOrders = await FirestorePaginationService.instance.getNextSupplierOrders(
        pageSize: pageSize,
        currentOffset: currentState.orders.length,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextOrders.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<SupplierOrder>.from(currentState.orders)..addAll(nextOrders);
        emit(SupplierOrdersLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextOrders.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetSupplierOrdersPagination(ResetSupplierOrdersPagination event, Emitter<SupplierOrdersState> emit) async {
    FirestorePaginationService.instance.resetSupplierOrdersPagination();
    add(LoadFirstSupplierOrders(
      searchQuery: event.searchQuery,
      supplierId: event.supplierId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAddSupplierOrder(AddSupplierOrder event, Emitter<SupplierOrdersState> emit) async {
    try {
      await FirestoreRepository.instance.saveSupplierOrder(event.order);
      add(LoadFirstSupplierOrders());
    } catch (e) {
      emit(SupplierOrdersError(e.toString()));
    }
  }

  Future<void> _onUpdateSupplierOrder(UpdateSupplierOrder event, Emitter<SupplierOrdersState> emit) async {
    try {
      await FirestoreRepository.instance.saveSupplierOrder(event.order);
      add(LoadFirstSupplierOrders());
    } catch (e) {
      emit(SupplierOrdersError(e.toString()));
    }
  }

  Future<void> _onDeleteSupplierOrder(DeleteSupplierOrder event, Emitter<SupplierOrdersState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('supplier_orders', event.orderId);
      add(LoadFirstSupplierOrders());
    } catch (e) {
      emit(SupplierOrdersError(e.toString()));
    }
  }

  Future<void> _onFilterSupplierOrders(FilterSupplierOrders event, Emitter<SupplierOrdersState> emit) async {
    add(LoadFirstSupplierOrders(
      supplierId: event.supplierId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }
}
