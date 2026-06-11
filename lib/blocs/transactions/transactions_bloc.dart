import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/transaction_model.dart';
import '../../models/check_traite.dart';

abstract class TransactionsEvent extends Equatable { const TransactionsEvent(); @override List<Object?> get props => []; }
class LoadTransactions extends TransactionsEvent {}
class AddTransaction extends TransactionsEvent { final TransactionModel txn; const AddTransaction(this.txn); @override List<Object?> get props => [txn]; }
class AddCheckTraite extends TransactionsEvent { final CheckTraite ct; const AddCheckTraite(this.ct); @override List<Object?> get props => [ct]; }
class UpdateCheckTraite extends TransactionsEvent { final CheckTraite ct; const UpdateCheckTraite(this.ct); @override List<Object?> get props => [ct]; }
class AddAccount extends TransactionsEvent { final Account account; const AddAccount(this.account); @override List<Object?> get props => [account]; }

abstract class TransactionsState extends Equatable { const TransactionsState(); @override List<Object?> get props => []; }
class TransactionsInitial extends TransactionsState {}
class TransactionsLoading extends TransactionsState {}
class TransactionsLoaded extends TransactionsState {
  final List<TransactionModel> transactions;
  final List<CheckTraite> checksTraites;
  final List<Account> accounts;
  const TransactionsLoaded(this.transactions, this.checksTraites, this.accounts);
  @override List<Object?> get props => [transactions, checksTraites, accounts];
}
class TransactionsError extends TransactionsState { final String message; const TransactionsError(this.message); @override List<Object?> get props => [message]; }

class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  TransactionsBloc() : super(TransactionsInitial()) {
    on<LoadTransactions>(_onLoad);
    on<AddTransaction>(_onAddTxn);
    on<AddCheckTraite>(_onAddCheck);
    on<UpdateCheckTraite>(_onUpdateCheck);
    on<AddAccount>(_onAddAccount);
  }

  Future<void> _onLoad(LoadTransactions event, Emitter<TransactionsState> emit) async {
    emit(TransactionsLoading());
    try {
      final txns = await DatabaseHelper.instance.getTransactions();
      final checks = await DatabaseHelper.instance.getChecksTraites();
      final accounts = await DatabaseHelper.instance.getAccounts();
      emit(TransactionsLoaded(txns, checks, accounts));
    } catch (e) { emit(TransactionsError(e.toString())); }
  }

  Future<void> _onAddTxn(AddTransaction event, Emitter<TransactionsState> emit) async {
    try { await DatabaseHelper.instance.insertTransaction(event.txn); add(LoadTransactions()); } catch (e) { emit(TransactionsError(e.toString())); }
  }

  Future<void> _onAddCheck(AddCheckTraite event, Emitter<TransactionsState> emit) async {
    try { await DatabaseHelper.instance.insertCheckTraite(event.ct); add(LoadTransactions()); } catch (e) { emit(TransactionsError(e.toString())); }
  }

  Future<void> _onUpdateCheck(UpdateCheckTraite event, Emitter<TransactionsState> emit) async {
    try { await DatabaseHelper.instance.update('checks_traites', event.ct.toMap(), event.ct.id); add(LoadTransactions()); } catch (e) { emit(TransactionsError(e.toString())); }
  }

  Future<void> _onAddAccount(AddAccount event, Emitter<TransactionsState> emit) async {
    try { await DatabaseHelper.instance.insertAccount(event.account); add(LoadTransactions()); } catch (e) { emit(TransactionsError(e.toString())); }
  }
}
