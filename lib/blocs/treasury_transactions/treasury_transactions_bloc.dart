import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/treasury_transaction.dart';
import '../../models/transaction_category.dart';
import '../../database/database_helper.dart';

// Events
abstract class TreasuryTransactionsEvent extends Equatable {
  const TreasuryTransactionsEvent();
  @override
  List<Object?> get props => [];
}

class LoadTreasuryTransactions extends TreasuryTransactionsEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  const LoadTreasuryTransactions({this.startDate, this.endDate});
  @override
  List<Object?> get props => [startDate, endDate];
}

class CreateTreasuryTransaction extends TreasuryTransactionsEvent {
  final TreasuryTransaction transaction;
  const CreateTreasuryTransaction(this.transaction);
  @override
  List<Object?> get props => [transaction];
}

class DeleteTreasuryTransaction extends TreasuryTransactionsEvent {
  final String id;
  const DeleteTreasuryTransaction(this.id);
  @override
  List<Object?> get props => [id];
}

class LoadTransactionCategories extends TreasuryTransactionsEvent {}

class CreateTransactionCategory extends TreasuryTransactionsEvent {
  final TransactionCategory category;
  const CreateTransactionCategory(this.category);
  @override
  List<Object?> get props => [category];
}

class DeleteTransactionCategory extends TreasuryTransactionsEvent {
  final String id;
  const DeleteTransactionCategory(this.id);
  @override
  List<Object?> get props => [id];
}

// States
abstract class TreasuryTransactionsState extends Equatable {
  const TreasuryTransactionsState();
  @override
  List<Object?> get props => [];
}

class TreasuryTransactionsInitial extends TreasuryTransactionsState {}
class TreasuryTransactionsLoading extends TreasuryTransactionsState {}

class TreasuryTransactionsLoaded extends TreasuryTransactionsState {
  final List<TreasuryTransaction> transactions;
  final List<TransactionCategory> categories;
  const TreasuryTransactionsLoaded({required this.transactions, required this.categories});
  @override
  List<Object?> get props => [transactions, categories];
}

class TreasuryTransactionsError extends TreasuryTransactionsState {
  final String message;
  const TreasuryTransactionsError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class TreasuryTransactionsBloc extends Bloc<TreasuryTransactionsEvent, TreasuryTransactionsState> {
  final DatabaseHelper databaseHelper;

  TreasuryTransactionsBloc({required this.databaseHelper}) : super(TreasuryTransactionsInitial()) {
    on<LoadTreasuryTransactions>(_onLoadTransactions);
    on<CreateTreasuryTransaction>(_onCreateTransaction);
    on<DeleteTreasuryTransaction>(_onDeleteTransaction);
    on<LoadTransactionCategories>(_onLoadCategories);
    on<CreateTransactionCategory>(_onCreateCategory);
    on<DeleteTransactionCategory>(_onDeleteCategory);
  }

  Future<void> _onLoadTransactions(LoadTreasuryTransactions event, Emitter<TreasuryTransactionsState> emit) async {
    emit(TreasuryTransactionsLoading());
    try {
      final txMaps = await databaseHelper.getTreasuryTransactions();
      var transactions = txMaps.map((e) => TreasuryTransaction.fromMap(e)).toList();
      
      // Calculate running balance chronologically
      transactions.sort((a, b) => a.dateTransaction.compareTo(b.dateTransaction));
      Map<String, double> balances = {};
      
      for (int i = 0; i < transactions.length; i++) {
        final tx = transactions[i];
        final currentBal = balances[tx.accountId] ?? 0.0;
        final newBal = tx.type == 'income' ? currentBal + tx.amount : currentBal - tx.amount;
        balances[tx.accountId] = newBal;
        transactions[i] = tx.copyWith(balance: newBal);
      }
      
      // Sort descending for display
      transactions.sort((a, b) => b.dateTransaction.compareTo(a.dateTransaction));
      
      // Apply date filters if any
      if (event.startDate != null && event.endDate != null) {
        transactions = transactions.where((t) {
          return t.dateTransaction.isAfter(event.startDate!.subtract(const Duration(days: 1))) &&
                 t.dateTransaction.isBefore(event.endDate!.add(const Duration(days: 1)));
        }).toList();
      }
      
      final catMaps = await databaseHelper.getTransactionCategories();
      final categories = catMaps.map((e) => TransactionCategory.fromMap(e)).toList();
      
      emit(TreasuryTransactionsLoaded(transactions: transactions, categories: categories));
    } catch (e) {
      emit(TreasuryTransactionsError(e.toString()));
    }
  }

  Future<void> _onCreateTransaction(CreateTreasuryTransaction event, Emitter<TreasuryTransactionsState> emit) async {
    try {
      await databaseHelper.createTreasuryTransaction(event.transaction.toMap());
      add(const LoadTreasuryTransactions());
    } catch (e) {
      emit(TreasuryTransactionsError(e.toString()));
    }
  }

  Future<void> _onDeleteTransaction(DeleteTreasuryTransaction event, Emitter<TreasuryTransactionsState> emit) async {
    try {
      await databaseHelper.deleteTreasuryTransaction(event.id);
      add(const LoadTreasuryTransactions());
    } catch (e) {
      emit(TreasuryTransactionsError(e.toString()));
    }
  }

  Future<void> _onLoadCategories(LoadTransactionCategories event, Emitter<TreasuryTransactionsState> emit) async {
    if (state is TreasuryTransactionsLoaded) {
      final currentState = state as TreasuryTransactionsLoaded;
      try {
        final catMaps = await databaseHelper.getTransactionCategories();
        final categories = catMaps.map((e) => TransactionCategory.fromMap(e)).toList();
        emit(TreasuryTransactionsLoaded(transactions: currentState.transactions, categories: categories));
      } catch (e) {
        emit(TreasuryTransactionsError(e.toString()));
      }
    } else {
      add(const LoadTreasuryTransactions());
    }
  }

  Future<void> _onCreateCategory(CreateTransactionCategory event, Emitter<TreasuryTransactionsState> emit) async {
    try {
      await databaseHelper.createTransactionCategory(event.category.toMap());
      add(LoadTransactionCategories());
    } catch (e) {
      emit(TreasuryTransactionsError(e.toString()));
    }
  }

  Future<void> _onDeleteCategory(DeleteTransactionCategory event, Emitter<TreasuryTransactionsState> emit) async {
    try {
      await databaseHelper.deleteTransactionCategory(event.id);
      add(LoadTransactionCategories());
    } catch (e) {
      emit(TreasuryTransactionsError(e.toString()));
    }
  }
}
