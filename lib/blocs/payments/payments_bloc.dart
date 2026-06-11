import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/payment_model.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class PaymentsEvent extends Equatable {
  const PaymentsEvent();
  @override
  List<Object?> get props => [];
}

class LoadPayments extends PaymentsEvent {}

class AddPayment extends PaymentsEvent {
  final Payment payment;
  const AddPayment(this.payment);
  @override
  List<Object?> get props => [payment];
}

class UpdatePayment extends PaymentsEvent {
  final Payment payment;
  const UpdatePayment(this.payment);
  @override
  List<Object?> get props => [payment];
}

class DeletePayment extends PaymentsEvent {
  final String id;
  const DeletePayment(this.id);
  @override
  List<Object?> get props => [id];
}

class AddPaymentAccount extends PaymentsEvent {
  final PaymentAccount account;
  const AddPaymentAccount(this.account);
  @override
  List<Object?> get props => [account];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class PaymentsState extends Equatable {
  const PaymentsState();
  @override
  List<Object?> get props => [];
}

class PaymentsInitial extends PaymentsState {}

class PaymentsLoading extends PaymentsState {}

class PaymentsLoaded extends PaymentsState {
  final List<Payment> payments;
  final List<PaymentAccount> accounts;

  const PaymentsLoaded(this.payments, this.accounts);

  @override
  List<Object?> get props => [payments, accounts];
}

class PaymentsError extends PaymentsState {
  final String message;
  const PaymentsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────
class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  PaymentsBloc() : super(PaymentsInitial()) {
    on<LoadPayments>(_onLoad);
    on<AddPayment>(_onAdd);
    on<UpdatePayment>(_onUpdate);
    on<DeletePayment>(_onDelete);
    on<AddPaymentAccount>(_onAddAccount);
  }

  Future<void> _onLoad(LoadPayments event, Emitter<PaymentsState> emit) async {
    emit(PaymentsLoading());
    try {
      final payments = await DatabaseHelper.instance.getPayments();
      final accounts = await DatabaseHelper.instance.getPaymentAccounts();
      emit(PaymentsLoaded(payments, accounts));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onAdd(AddPayment event, Emitter<PaymentsState> emit) async {
    try {
      await DatabaseHelper.instance.insertPayment(event.payment);
      add(LoadPayments());
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdatePayment event, Emitter<PaymentsState> emit) async {
    try {
      await DatabaseHelper.instance.updatePayment(event.payment);
      add(LoadPayments());
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onDelete(DeletePayment event, Emitter<PaymentsState> emit) async {
    try {
      await DatabaseHelper.instance.softDeletePayment(event.id);
      add(LoadPayments());
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onAddAccount(AddPaymentAccount event, Emitter<PaymentsState> emit) async {
    try {
      await DatabaseHelper.instance.insertPaymentAccount(event.account);
      add(LoadPayments());
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }
}
