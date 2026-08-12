import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/treasury_transaction.dart';
import '../../models/transaction_category.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager_pro/services/error_handler.dart';

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

class LoadFirstTreasuryTransactions extends TreasuryTransactionsEvent {
  final String searchQuery;
  final String typeFilter;
  const LoadFirstTreasuryTransactions({this.searchQuery = '', this.typeFilter = 'Tous'});
  @override
  List<Object?> get props => [searchQuery, typeFilter];
}

class LoadNextTreasuryTransactions extends TreasuryTransactionsEvent {
  const LoadNextTreasuryTransactions();
}

class ResetTreasuryTransactionsPagination extends TreasuryTransactionsEvent {
  final String searchQuery;
  final String typeFilter;
  const ResetTreasuryTransactionsPagination({this.searchQuery = '', this.typeFilter = 'Tous'});
  @override
  List<Object?> get props => [searchQuery, typeFilter];
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
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String activeTypeFilter;
  final String searchQuery;

  const TreasuryTransactionsLoaded({
    required this.transactions, 
    required this.categories,
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.activeTypeFilter = 'Tous',
    this.searchQuery = '',
  });

  TreasuryTransactionsLoaded copyWith({
    List<TreasuryTransaction>? transactions,
    List<TransactionCategory>? categories,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? activeTypeFilter,
    String? searchQuery,
  }) {
    return TreasuryTransactionsLoaded(
      transactions: transactions ?? this.transactions,
      categories: categories ?? this.categories,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      activeTypeFilter: activeTypeFilter ?? this.activeTypeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [transactions, categories, totalCount, hasMore, isLoadingMore, activeTypeFilter, searchQuery];
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
    on<LoadFirstTreasuryTransactions>(_onLoadFirst);
    on<LoadNextTreasuryTransactions>(_onLoadNext);
    on<ResetTreasuryTransactionsPagination>(_onResetPagination);
    on<CreateTreasuryTransaction>(_onCreateTransaction);
    on<DeleteTreasuryTransaction>(_onDeleteTransaction);
    on<LoadTransactionCategories>(_onLoadCategories);
    on<CreateTransactionCategory>(_onCreateCategory);
    on<DeleteTransactionCategory>(_onDeleteCategory);
  }

  Future<void> _onLoadTransactions(LoadTreasuryTransactions event, Emitter<TreasuryTransactionsState> emit) async {
    emit(TreasuryTransactionsLoading());
    try {
      final txs = await FirestorePaginationService.instance.getFirstTreasuryTransactions(
        pageSize: 500, // Load all for desktop
      );
      var transactions = txs.toList();
      
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
      emit(TreasuryTransactionsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadFirst(LoadFirstTreasuryTransactions event, Emitter<TreasuryTransactionsState> emit) async {
    emit(TreasuryTransactionsLoading());
    try {
      final count = await FirestorePaginationService.instance.getTreasuryTransactionsCount(
        searchQuery: event.searchQuery,
        typeFilter: event.typeFilter,
      );
      final txs = await FirestorePaginationService.instance.getFirstTreasuryTransactions(
        searchQuery: event.searchQuery,
        typeFilter: event.typeFilter,
      );
      
      final catMaps = await databaseHelper.getTransactionCategories();
      final categories = catMaps.map((e) => TransactionCategory.fromMap(e)).toList();

      emit(TreasuryTransactionsLoaded(
        transactions: txs,
        categories: categories,
        totalCount: count,
        hasMore: txs.length >= 10,
        activeTypeFilter: event.typeFilter,
        searchQuery: event.searchQuery,
      ));
    } catch (e) {
      emit(TreasuryTransactionsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadNext(LoadNextTreasuryTransactions event, Emitter<TreasuryTransactionsState> emit) async {
    if (state is TreasuryTransactionsLoaded) {
      final currentState = state as TreasuryTransactionsLoaded;
      if (!currentState.hasMore || currentState.isLoadingMore) return;

      emit(currentState.copyWith(isLoadingMore: true));
      try {
        final nextTxs = await FirestorePaginationService.instance.getNextTreasuryTransactions(
          currentOffset: currentState.transactions.length,
          searchQuery: currentState.searchQuery,
          typeFilter: currentState.activeTypeFilter,
        );

        emit(currentState.copyWith(
          transactions: [...currentState.transactions, ...nextTxs],
          hasMore: nextTxs.length >= 10,
          isLoadingMore: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> _onResetPagination(ResetTreasuryTransactionsPagination event, Emitter<TreasuryTransactionsState> emit) async {
    FirestorePaginationService.instance.resetTreasuryTransactionsPagination();
    add(LoadFirstTreasuryTransactions(searchQuery: event.searchQuery, typeFilter: event.typeFilter));
  }

  Future<void> _onCreateTransaction(CreateTreasuryTransaction event, Emitter<TreasuryTransactionsState> emit) async {
    try {
      final seq = await databaseHelper.getNextTreasuryTransactionSequence();
      final prefix = event.transaction.transactionNumber.contains('-') 
          ? event.transaction.transactionNumber.split('-').first 
          : 'TR';
      final year = DateTime.now().year;
      final newNumber = '$prefix-$year-${seq.toString().padLeft(6, '0')}';
      
      final updatedTx = event.transaction.copyWith(transactionNumber: newNumber);

      await FirestoreRepository.instance.saveDocument('treasury_transactions', updatedTx.id, updatedTx.toMap());
      
      // Update the associated treasury account balance
      final accountRef = FirebaseFirestore.instance.collection('treasury_accounts').doc(updatedTx.accountId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(accountRef);
        if (snapshot.exists) {
          final double currentBalance = double.tryParse(snapshot.data()?['balance']?.toString() ?? '0') ?? 0.0;
          final double amount = updatedTx.amount;
          final double newBalance = updatedTx.type == 'income' ? currentBalance + amount : currentBalance - amount;
          transaction.update(accountRef, {'balance': newBalance});
        }
      });

      if (state is TreasuryTransactionsLoaded) {
        final s = state as TreasuryTransactionsLoaded;
        add(LoadFirstTreasuryTransactions(searchQuery: s.searchQuery, typeFilter: s.activeTypeFilter));
      } else {
        add(const LoadTreasuryTransactions());
      }
    } catch (e) {
      emit(TreasuryTransactionsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteTransaction(DeleteTreasuryTransaction event, Emitter<TreasuryTransactionsState> emit) async {
    try {
      // First fetch the transaction to know its amount and type
      final docSnap = await FirebaseFirestore.instance.collection('treasury_transactions').doc(event.id).get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final type = data['type']?.toString();
        final amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
        final accountId = data['account_id']?.toString();

        if (accountId != null && accountId.isNotEmpty) {
          final accountRef = FirebaseFirestore.instance.collection('treasury_accounts').doc(accountId);
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final accSnap = await transaction.get(accountRef);
            if (accSnap.exists) {
              final double currentBalance = double.tryParse(accSnap.data()?['balance']?.toString() ?? '0') ?? 0.0;
              // Reverse the operation: if it was income, subtract it; if expense, add it back.
              final double newBalance = type == 'income' ? currentBalance - amount : currentBalance + amount;
              transaction.update(accountRef, {'balance': newBalance});
            }
          });
        }
      }

      await FirestoreRepository.instance.softDeleteDocument('treasury_transactions', event.id);
      if (state is TreasuryTransactionsLoaded) {
        final s = state as TreasuryTransactionsLoaded;
        add(LoadFirstTreasuryTransactions(searchQuery: s.searchQuery, typeFilter: s.activeTypeFilter));
      } else {
        add(const LoadTreasuryTransactions());
      }
    } catch (e) {
      emit(TreasuryTransactionsError(ErrorHandler.parseError(e)));
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
        emit(TreasuryTransactionsError(ErrorHandler.parseError(e)));
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
      emit(TreasuryTransactionsError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteCategory(DeleteTransactionCategory event, Emitter<TreasuryTransactionsState> emit) async {
    try {
      await databaseHelper.deleteTransactionCategory(event.id);
      add(LoadTransactionCategories());
    } catch (e) {
      emit(TreasuryTransactionsError(ErrorHandler.parseError(e)));
    }
  }
}
