import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/treasury_account.dart';
import '../../database/database_helper.dart';

// Events
abstract class TreasuryAccountsEvent extends Equatable {
  const TreasuryAccountsEvent();
  @override
  List<Object?> get props => [];
}

class LoadTreasuryAccounts extends TreasuryAccountsEvent {}

class CreateTreasuryAccount extends TreasuryAccountsEvent {
  final TreasuryAccount account;
  const CreateTreasuryAccount(this.account);
  @override
  List<Object?> get props => [account];
}

class UpdateTreasuryAccount extends TreasuryAccountsEvent {
  final TreasuryAccount account;
  const UpdateTreasuryAccount(this.account);
  @override
  List<Object?> get props => [account];
}

class DeleteTreasuryAccount extends TreasuryAccountsEvent {
  final String id;
  const DeleteTreasuryAccount(this.id);
  @override
  List<Object?> get props => [id];
}

// States
abstract class TreasuryAccountsState extends Equatable {
  const TreasuryAccountsState();
  @override
  List<Object?> get props => [];
}

class TreasuryAccountsInitial extends TreasuryAccountsState {}
class TreasuryAccountsLoading extends TreasuryAccountsState {}

class TreasuryAccountsLoaded extends TreasuryAccountsState {
  final List<TreasuryAccount> accounts;
  const TreasuryAccountsLoaded(this.accounts);
  @override
  List<Object?> get props => [accounts];
}

class TreasuryAccountsError extends TreasuryAccountsState {
  final String message;
  const TreasuryAccountsError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class TreasuryAccountsBloc extends Bloc<TreasuryAccountsEvent, TreasuryAccountsState> {
  final DatabaseHelper databaseHelper;

  TreasuryAccountsBloc({required this.databaseHelper}) : super(TreasuryAccountsInitial()) {
    on<LoadTreasuryAccounts>(_onLoadAccounts);
    on<CreateTreasuryAccount>(_onCreateAccount);
    on<UpdateTreasuryAccount>(_onUpdateAccount);
    on<DeleteTreasuryAccount>(_onDeleteAccount);
  }

  Future<void> _onLoadAccounts(LoadTreasuryAccounts event, Emitter<TreasuryAccountsState> emit) async {
    emit(TreasuryAccountsLoading());
    try {
      final maps = await databaseHelper.getTreasuryAccounts();
      final accounts = maps.map((e) => TreasuryAccount.fromMap(e)).toList();
      emit(TreasuryAccountsLoaded(accounts));
    } catch (e) {
      emit(TreasuryAccountsError(e.toString()));
    }
  }

  Future<void> _onCreateAccount(CreateTreasuryAccount event, Emitter<TreasuryAccountsState> emit) async {
    try {
      await databaseHelper.createTreasuryAccount(event.account.toMap());
      add(LoadTreasuryAccounts());
    } catch (e) {
      emit(TreasuryAccountsError(e.toString()));
    }
  }

  Future<void> _onUpdateAccount(UpdateTreasuryAccount event, Emitter<TreasuryAccountsState> emit) async {
    try {
      await databaseHelper.updateTreasuryAccount(event.account.id, event.account.toMap());
      add(LoadTreasuryAccounts());
    } catch (e) {
      emit(TreasuryAccountsError(e.toString()));
    }
  }

  Future<void> _onDeleteAccount(DeleteTreasuryAccount event, Emitter<TreasuryAccountsState> emit) async {
    try {
      await databaseHelper.deleteTreasuryAccount(event.id);
      add(LoadTreasuryAccounts());
    } catch (e) {
      emit(TreasuryAccountsError(e.toString()));
    }
  }
}
