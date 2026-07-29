import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/customer.dart';
import '../../services/firestore_pagination_service.dart';

// Events
abstract class CustomersEvent extends Equatable {
  const CustomersEvent();
  @override
  List<Object?> get props => [];
}

class LoadCustomers extends CustomersEvent {}

class LoadFirstClients extends CustomersEvent {
  final String? searchQuery;
  const LoadFirstClients({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class LoadNextClients extends CustomersEvent {
  final String? searchQuery;
  const LoadNextClients({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class ResetClientsPagination extends CustomersEvent {
  final String? searchQuery;
  const ResetClientsPagination({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class AddCustomer extends CustomersEvent {
  final Customer customer;
  const AddCustomer(this.customer);
  @override
  List<Object?> get props => [customer];
}

class UpdateCustomer extends CustomersEvent {
  final Customer customer;
  const UpdateCustomer(this.customer);
  @override
  List<Object?> get props => [customer];
}

class DeleteCustomer extends CustomersEvent {
  final String id;
  const DeleteCustomer(this.id);
  @override
  List<Object?> get props => [id];
}

// States
abstract class CustomersState extends Equatable {
  const CustomersState();
  @override
  List<Object?> get props => [];
}

class CustomersInitial extends CustomersState {}
class CustomersLoading extends CustomersState {}
class CustomersLoaded extends CustomersState {
  final List<Customer> customers;
  final int? _totalCount;
  final bool? _hasMore;
  final bool? _isLoadingMore;

  int get totalCount => _totalCount ?? 0;
  bool get hasMore => _hasMore ?? true;
  bool get isLoadingMore => _isLoadingMore ?? false;

  const CustomersLoaded(
    this.customers, {
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  })  : _totalCount = totalCount,
        _hasMore = hasMore,
        _isLoadingMore = isLoadingMore;

  CustomersLoaded copyWith({
    List<Customer>? customers,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CustomersLoaded(
      customers ?? this.customers,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [customers, _totalCount, _hasMore, _isLoadingMore];
}

class CustomersError extends CustomersState {
  final String message;
  const CustomersError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  CustomersBloc() : super(CustomersInitial()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<LoadFirstClients>(_onLoadFirstClients);
    on<LoadNextClients>(_onLoadNextClients);
    on<ResetClientsPagination>(_onResetClientsPagination);
    on<AddCustomer>(_onAddCustomer);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
  }

  Future<void> _onLoadCustomers(LoadCustomers event, Emitter<CustomersState> emit) async {
    emit(CustomersLoading());
    try {
      final customers = await DatabaseHelper.instance.getCustomers();
      emit(CustomersLoaded(customers, totalCount: customers.length, hasMore: false));
    } catch (e) {
      emit(CustomersError(e.toString()));
    }
  }

  Future<void> _onLoadFirstClients(LoadFirstClients event, Emitter<CustomersState> emit) async {
    emit(CustomersLoading());
    try {
      FirestorePaginationService.instance.resetCustomersPagination();
      final clientsFuture = FirestorePaginationService.instance.getFirstCustomers(
        pageSize: 10,
        searchQuery: event.searchQuery,
      );
      final countFuture = FirestorePaginationService.instance.getCustomersCount(
        searchQuery: event.searchQuery,
      );

      final results = await Future.wait([clientsFuture, countFuture]);
      final clients = results[0] as List<Customer>;
      final totalCount = results[1] as int;

      emit(CustomersLoaded(
        clients,
        totalCount: totalCount > clients.length ? totalCount : clients.length,
        hasMore: clients.length >= 10,
      ));
    } catch (e) {
      emit(CustomersError(e.toString()));
    }
  }

  Future<void> _onLoadNextClients(LoadNextClients event, Emitter<CustomersState> emit) async {
    final currentState = state;
    if (currentState is! CustomersLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextClients = await FirestorePaginationService.instance.getNextCustomers(
        pageSize: 10,
        currentOffset: currentState.customers.length,
        searchQuery: event.searchQuery,
      );

      if (nextClients.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<Customer>.from(currentState.customers)..addAll(nextClients);
        emit(CustomersLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextClients.length >= 10,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetClientsPagination(ResetClientsPagination event, Emitter<CustomersState> emit) async {
    FirestorePaginationService.instance.resetCustomersPagination();
    add(LoadFirstClients(searchQuery: event.searchQuery));
  }

  Future<void> _onAddCustomer(AddCustomer event, Emitter<CustomersState> emit) async {
    try {
      await DatabaseHelper.instance.insertCustomer(event.customer);
      add(LoadCustomers());
    } catch (e) {
      emit(CustomersError(e.toString()));
    }
  }

  Future<void> _onUpdateCustomer(UpdateCustomer event, Emitter<CustomersState> emit) async {
    try {
      await DatabaseHelper.instance.updateCustomer(event.customer);
      add(LoadCustomers());
    } catch (e) {
      emit(CustomersError(e.toString()));
    }
  }

  Future<void> _onDeleteCustomer(DeleteCustomer event, Emitter<CustomersState> emit) async {
    try {
      await DatabaseHelper.instance.deleteCustomer(event.id);
      add(LoadCustomers());
    } catch (e) {
      emit(CustomersError(e.toString()));
    }
  }
}
