import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../models/treasury_account.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Events
abstract class TreasuryAccountsEvent extends Equatable {
  const TreasuryAccountsEvent();
  @override
  List<Object?> get props => [];
}

class LoadTreasuryAccounts extends TreasuryAccountsEvent {}

class LoadFirstTreasuryAccounts extends TreasuryAccountsEvent {
  final String? searchQuery;
  const LoadFirstTreasuryAccounts({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class LoadNextTreasuryAccounts extends TreasuryAccountsEvent {
  final String? searchQuery;
  const LoadNextTreasuryAccounts({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class ResetTreasuryAccountsPagination extends TreasuryAccountsEvent {
  final String? searchQuery;
  const ResetTreasuryAccountsPagination({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

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
  final int? _totalCount;
  final bool? _hasMore;
  final bool? _isLoadingMore;

  int get totalCount => _totalCount ?? 0;
  bool get hasMore => _hasMore ?? true;
  bool get isLoadingMore => _isLoadingMore ?? false;

  const TreasuryAccountsLoaded(
    this.accounts, {
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  })  : _totalCount = totalCount,
        _hasMore = hasMore,
        _isLoadingMore = isLoadingMore;

  TreasuryAccountsLoaded copyWith({
    List<TreasuryAccount>? accounts,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return TreasuryAccountsLoaded(
      accounts ?? this.accounts,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [accounts, _totalCount, _hasMore, _isLoadingMore];
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
    on<LoadFirstTreasuryAccounts>(_onLoadFirstTreasuryAccounts);
    on<LoadNextTreasuryAccounts>(_onLoadNextTreasuryAccounts);
    on<ResetTreasuryAccountsPagination>(_onResetTreasuryAccountsPagination);
    on<CreateTreasuryAccount>(_onCreateAccount);
    on<UpdateTreasuryAccount>(_onUpdateAccount);
    on<DeleteTreasuryAccount>(_onDeleteAccount);
  }

  Future<void> _onLoadAccounts(LoadTreasuryAccounts event, Emitter<TreasuryAccountsState> emit) async {
    emit(TreasuryAccountsLoading());
    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('treasury_accounts');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }
      
      bool shownFromCache = false;
      try {
        final cacheSnap = await query.get(const GetOptions(source: Source.cache));
        if (cacheSnap.docs.isNotEmpty && !emit.isDone) {
          final accounts = cacheSnap.docs.map((d) => TreasuryAccount.fromMap(d.data() as Map<String, dynamic>)).toList();
          emit(TreasuryAccountsLoaded(accounts, totalCount: accounts.length, hasMore: false));
          shownFromCache = true;
        }
      } catch (_) {}

      try {
        final serverSnap = await query.get(const GetOptions(source: Source.server));
        List<TreasuryAccount> accounts = serverSnap.docs.map((d) => TreasuryAccount.fromMap(d.data() as Map<String, dynamic>)).toList();
        
        if (accounts.isEmpty) {
          final defaultAccount = TreasuryAccount(
            id: const Uuid().v4(),
            name: 'Compte principal',
            type: 'cash',
            currency: 'TND',
            balance: 0.0,
            isDefault: true,
            enterpriseId: currentEntId,
          );
          accounts = [defaultAccount];

          FirestoreRepository.instance
              .saveDocument('treasury_accounts', defaultAccount.id, defaultAccount.toMap())
              .catchError((e) => print("Firestore default treasury account auto-create error: $e"));
        }

        if (!emit.isDone) {
          emit(TreasuryAccountsLoaded(accounts, totalCount: accounts.length, hasMore: false));
        }
      } catch (e) {
        if (!shownFromCache && !emit.isDone) {
          emit(TreasuryAccountsLoaded(const [], totalCount: 0, hasMore: false));
        }
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(TreasuryAccountsError(e.toString()));
      }
    }
  }

  Future<void> _onLoadFirstTreasuryAccounts(LoadFirstTreasuryAccounts event, Emitter<TreasuryAccountsState> emit) async {
    emit(TreasuryAccountsLoading());
    try {
      FirestorePaginationService.instance.resetTreasuryAccountsPagination();
      final accountsFuture = FirestorePaginationService.instance.getFirstTreasuryAccounts(
        pageSize: 10,
        searchQuery: event.searchQuery,
      );
      final countFuture = FirestorePaginationService.instance.getTreasuryAccountsCount(
        searchQuery: event.searchQuery,
      );

      final results = await Future.wait([accountsFuture, countFuture]);
      final accounts = results[0] as List<TreasuryAccount>;
      final totalCount = results[1] as int;

      emit(TreasuryAccountsLoaded(
        accounts,
        totalCount: totalCount > accounts.length ? totalCount : accounts.length,
        hasMore: accounts.length >= 10,
      ));
    } catch (e) {
      emit(TreasuryAccountsError(e.toString()));
    }
  }

  Future<void> _onLoadNextTreasuryAccounts(LoadNextTreasuryAccounts event, Emitter<TreasuryAccountsState> emit) async {
    final currentState = state;
    if (currentState is! TreasuryAccountsLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextAccounts = await FirestorePaginationService.instance.getNextTreasuryAccounts(
        pageSize: 10,
        currentOffset: currentState.accounts.length,
        searchQuery: event.searchQuery,
      );

      emit(currentState.copyWith(
        accounts: [...currentState.accounts, ...nextAccounts],
        hasMore: nextAccounts.length >= 10,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetTreasuryAccountsPagination(ResetTreasuryAccountsPagination event, Emitter<TreasuryAccountsState> emit) async {
    try {
      FirestorePaginationService.instance.resetTreasuryAccountsPagination();
      final accountsFuture = FirestorePaginationService.instance.getFirstTreasuryAccounts(
        pageSize: 10,
        searchQuery: event.searchQuery,
      );
      final countFuture = FirestorePaginationService.instance.getTreasuryAccountsCount(
        searchQuery: event.searchQuery,
      );

      final results = await Future.wait([accountsFuture, countFuture]);
      final accounts = results[0] as List<TreasuryAccount>;
      final totalCount = results[1] as int;

      emit(TreasuryAccountsLoaded(
        accounts,
        totalCount: totalCount > accounts.length ? totalCount : accounts.length,
        hasMore: accounts.length >= 10,
      ));
    } catch (e) {
      emit(TreasuryAccountsError(e.toString()));
    }
  }

  Future<void> _onCreateAccount(CreateTreasuryAccount event, Emitter<TreasuryAccountsState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final account = (event.account.enterpriseId == null || event.account.enterpriseId!.isEmpty)
        ? event.account.copyWith(enterpriseId: currentEntId)
        : event.account;

    final currentState = state;
    if (currentState is TreasuryAccountsLoaded) {
      final currentList = List<TreasuryAccount>.from(currentState.accounts);
      currentList.insert(0, account);
      emit(currentState.copyWith(accounts: currentList, totalCount: currentList.length));
    }

    try {
      await FirestoreRepository.instance.saveDocument('treasury_accounts', account.id, account.toMap());
    } catch (e) {
      print("Failed to save treasury account: $e");
    }
  }

  Future<void> _onUpdateAccount(UpdateTreasuryAccount event, Emitter<TreasuryAccountsState> emit) async {
    final currentState = state;
    if (currentState is TreasuryAccountsLoaded) {
      final currentList = List<TreasuryAccount>.from(currentState.accounts);
      final idx = currentList.indexWhere((a) => a.id == event.account.id);
      if (idx != -1) {
        currentList[idx] = event.account;
      } else {
        currentList.insert(0, event.account);
      }
      emit(currentState.copyWith(accounts: currentList));
    }

    try {
      await FirestoreRepository.instance.saveDocument('treasury_accounts', event.account.id, event.account.toMap());
    } catch (e) {
      print("Failed to update treasury account: $e");
    }
  }

  Future<void> _onDeleteAccount(DeleteTreasuryAccount event, Emitter<TreasuryAccountsState> emit) async {
    final currentState = state;
    if (currentState is TreasuryAccountsLoaded) {
      final currentList = List<TreasuryAccount>.from(currentState.accounts)..removeWhere((a) => a.id == event.id);
      emit(currentState.copyWith(accounts: currentList, totalCount: currentList.length));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('treasury_accounts', event.id);
    } catch (e) {
      print("Failed to delete treasury account: $e");
    }
  }
}
