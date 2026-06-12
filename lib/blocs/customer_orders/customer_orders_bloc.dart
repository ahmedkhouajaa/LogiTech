import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/customer_order.dart';
import '../../database/database_helper.dart';

// ─── Events ────────────────────────────────────────────────────────
abstract class CustomerOrdersEvent {}

class LoadCustomerOrders extends CustomerOrdersEvent {}

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
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  CustomerOrdersLoaded(
    this.orders, {
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });

  CustomerOrdersLoaded copyWith({
    List<CustomerOrder>? orders,
    String? clientFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    String? statusFilter,
  }) {
    return CustomerOrdersLoaded(
      orders ?? this.orders,
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
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  CustomerOrdersBloc() : super(CustomerOrdersInitial()) {
    on<LoadCustomerOrders>(_onLoadCustomerOrders);
    on<AddCustomerOrder>(_onAddCustomerOrder);
    on<UpdateCustomerOrder>(_onUpdateCustomerOrder);
    on<DeleteCustomerOrder>(_onDeleteCustomerOrder);
    on<FilterCustomerOrders>(_onFilterCustomerOrders);
  }

  Future<void> _onLoadCustomerOrders(LoadCustomerOrders event, Emitter<CustomerOrdersState> emit) async {
    emit(CustomerOrdersLoading());
    try {
      final orders = await _dbHelper.getCustomerOrders();
      emit(CustomerOrdersLoaded(orders));
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onAddCustomerOrder(AddCustomerOrder event, Emitter<CustomerOrdersState> emit) async {
    try {
      await _dbHelper.insertCustomerOrder(event.order);
      add(LoadCustomerOrders());
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onUpdateCustomerOrder(UpdateCustomerOrder event, Emitter<CustomerOrdersState> emit) async {
    try {
      await _dbHelper.updateCustomerOrder(event.order);
      add(LoadCustomerOrders());
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onDeleteCustomerOrder(DeleteCustomerOrder event, Emitter<CustomerOrdersState> emit) async {
    try {
      await _dbHelper.softDeleteCustomerOrder(event.orderId);
      add(LoadCustomerOrders());
    } catch (e) {
      emit(CustomerOrdersError(e.toString()));
    }
  }

  Future<void> _onFilterCustomerOrders(FilterCustomerOrders event, Emitter<CustomerOrdersState> emit) async {
    final currentState = state;
    if (currentState is CustomerOrdersLoaded) {
      emit(CustomerOrdersLoading());
      try {
        final allOrders = await _dbHelper.getCustomerOrders(
          status: event.status,
          startDate: event.dateFrom,
          endDate: event.dateTo,
        );

        final filteredOrders = allOrders.where((order) {
          if (event.clientId != null && event.clientId != 'all' && event.clientId!.isNotEmpty) {
            return order.customerId == event.clientId;
          }
          return true;
        }).toList();

        emit(CustomerOrdersLoaded(
          filteredOrders,
          clientFilter: event.clientId,
          dateFromFilter: event.dateFrom,
          dateToFilter: event.dateTo,
          statusFilter: event.status,
        ));
      } catch (e) {
        emit(CustomerOrdersError(e.toString()));
      }
    } else {
      // If not loaded yet, just load with filters (though UI usually ensures it's loaded)
      emit(CustomerOrdersLoading());
      try {
        final allOrders = await _dbHelper.getCustomerOrders(
          status: event.status,
          startDate: event.dateFrom,
          endDate: event.dateTo,
        );
        final filteredOrders = allOrders.where((order) {
          if (event.clientId != null && event.clientId != 'all' && event.clientId!.isNotEmpty) {
            return order.customerId == event.clientId;
          }
          return true;
        }).toList();
        emit(CustomerOrdersLoaded(
          filteredOrders,
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
}
