import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/customer_order.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/sync_service.dart';

// ─── Events ────────────────────────────────────────────────────────
abstract class CustomerOrdersEvent {}

class LoadCustomerOrders extends CustomerOrdersEvent {}

class LoadFirstCustomerOrders extends CustomerOrdersEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadFirstCustomerOrders({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextCustomerOrders extends CustomerOrdersEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextCustomerOrders({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetCustomerOrdersPagination extends CustomerOrdersEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetCustomerOrdersPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class AddCustomerOrder extends CustomerOrdersEvent {
  final CustomerOrder order;
  AddCustomerOrder(this.order);
}

class UpdateCustomerOrder extends CustomerOrdersEvent {
  final CustomerOrder order;
  UpdateCustomerOrder(this.order);
}

class DeleteCustomerOrder extends CustomerOrdersEvent {
  final String orderId;
  DeleteCustomerOrder(this.orderId);
}

class FilterCustomerOrders extends CustomerOrdersEvent {
  final String? clientId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  FilterCustomerOrders({this.clientId, this.dateFrom, this.dateTo, this.status});
}

// ─── States ────────────────────────────────────────────────────────
abstract class CustomerOrdersState {}

class CustomerOrdersInitial extends CustomerOrdersState {}

class CustomerOrdersLoading extends CustomerOrdersState {}

class CustomerOrdersLoaded extends CustomerOrdersState {
  final List<CustomerOrder> orders;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  CustomerOrdersLoaded(
    this.orders, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });

  CustomerOrdersLoaded copyWith({
    List<CustomerOrder>? orders,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? clientFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    String? statusFilter,
  }) {
    return CustomerOrdersLoaded(
      orders ?? this.orders,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      clientFilter: clientFilter ?? this.clientFilter,
      dateFromFilter: dateFromFilter ?? this.dateFromFilter,
      dateToFilter: dateToFilter ?? this.dateToFilter,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class CustomerOrdersError extends CustomerOrdersState {
  final String message;
  CustomerOrdersError(this.message);
}

// ─── BLoC ──────────────────────────────────────────────────────────
class CustomerOrdersBloc extends Bloc<CustomerOrdersEvent, CustomerOrdersState> {
  static const int pageSize = 10;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  CustomerOrdersBloc() : super(CustomerOrdersInitial()) {
    on<LoadCustomerOrders>(_onLoadCustomerOrders);
    on<LoadFirstCustomerOrders>(_onLoadFirstCustomerOrders);
    on<LoadNextCustomerOrders>(_onLoadNextCustomerOrders);
    on<ResetCustomerOrdersPagination>(_onResetCustomerOrdersPagination);
    on<AddCustomerOrder>(_onAddCustomerOrder);
    on<UpdateCustomerOrder>(_onUpdateCustomerOrder);
    on<DeleteCustomerOrder>(_onDeleteCustomerOrder);
    on<FilterCustomerOrders>(_onFilterCustomerOrders);
  }

  Future<void> _onLoadCustomerOrders(LoadCustomerOrders event, Emitter<CustomerOrdersState> emit) async {
    emit(CustomerOrdersLoading());
    try {
      final orders = await _dbHelper.getCustomerOrders();
      emit(CustomerOrdersLoaded(orders, totalCount: orders.length));
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onLoadFirstCustomerOrders(LoadFirstCustomerOrders event, Emitter<CustomerOrdersState> emit) async {
    emit(CustomerOrdersLoading());
    try {
      FirestorePaginationService.instance.resetCustomerOrdersPagination();
      final ordersFuture = FirestorePaginationService.instance.getFirstCustomerOrders(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getCustomerOrdersCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([ordersFuture, countFuture]);
      final orders = results[0] as List<CustomerOrder>;
      final totalCount = results[1] as int;

      emit(CustomerOrdersLoaded(
        orders,
        totalCount: totalCount > orders.length ? totalCount : orders.length,
        hasMore: orders.length >= pageSize,
      ));
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onLoadNextCustomerOrders(LoadNextCustomerOrders event, Emitter<CustomerOrdersState> emit) async {
    final currentState = state;
    if (currentState is! CustomerOrdersLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextOrders = await FirestorePaginationService.instance.getNextCustomerOrders(
        pageSize: pageSize,
        currentOffset: currentState.orders.length,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextOrders.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<CustomerOrder>.from(currentState.orders)..addAll(nextOrders);
        emit(CustomerOrdersLoaded(
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

  Future<void> _onResetCustomerOrdersPagination(ResetCustomerOrdersPagination event, Emitter<CustomerOrdersState> emit) async {
    FirestorePaginationService.instance.resetCustomerOrdersPagination();
    add(LoadFirstCustomerOrders(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAddCustomerOrder(AddCustomerOrder event, Emitter<CustomerOrdersState> emit) async {
    try {
      await _dbHelper.insertCustomerOrder(event.order);
      await SyncService.instance.triggerSync();
      add(LoadFirstCustomerOrders());
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onUpdateCustomerOrder(UpdateCustomerOrder event, Emitter<CustomerOrdersState> emit) async {
    try {
      await _dbHelper.updateCustomerOrder(event.order);
      add(LoadFirstCustomerOrders());
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onDeleteCustomerOrder(DeleteCustomerOrder event, Emitter<CustomerOrdersState> emit) async {
    try {
      await _dbHelper.softDelete('customer_orders', event.orderId);
      add(LoadFirstCustomerOrders());
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onFilterCustomerOrders(FilterCustomerOrders event, Emitter<CustomerOrdersState> emit) async {
    try {
      final allOrders = await _dbHelper.getCustomerOrders(
        status: event.status,
        startDate: event.dateFrom,
        endDate: event.dateTo,
      );

      var filtered = allOrders;
      if (event.clientId != null && event.clientId!.isNotEmpty) {
        filtered = filtered.where((o) => o.customerId == event.clientId).toList();
      }

      emit(CustomerOrdersLoaded(
        filtered,
        clientFilter: event.clientId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
        statusFilter: event.status,
      ));
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }
}
