import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/customer.dart';

// Events
abstract class CustomersEvent extends Equatable {
  const CustomersEvent();
  @override
  List<Object?> get props => [];
}

class LoadCustomers extends CustomersEvent {}

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
  const CustomersLoaded(this.customers);
  @override
  List<Object?> get props => [customers];
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
    on<AddCustomer>(_onAddCustomer);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
  }

  Future<void> _onLoadCustomers(LoadCustomers event, Emitter<CustomersState> emit) async {
    emit(CustomersLoading());
    try {
      final customers = await DatabaseHelper.instance.getCustomers();
      emit(CustomersLoaded(customers));
    } catch (e) {
      emit(CustomersError(e.toString()));
    }
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
