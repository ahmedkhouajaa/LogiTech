import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock_withdrawal.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/sync_service.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';
import 'package:business_manager_pro/services/error_handler.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class ExitVouchersEvent {}

class LoadExitVouchers extends ExitVouchersEvent {}

class LoadFirstExitVouchers extends ExitVouchersEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadFirstExitVouchers({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextExitVouchers extends ExitVouchersEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextExitVouchers({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetExitVouchersPagination extends ExitVouchersEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetExitVouchersPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class AddExitVoucher extends ExitVouchersEvent {
  final StockWithdrawal withdrawal;
  AddExitVoucher(this.withdrawal);
}

class UpdateExitVoucher extends ExitVouchersEvent {
  final StockWithdrawal withdrawal;
  UpdateExitVoucher(this.withdrawal);
}

class DeleteExitVoucher extends ExitVouchersEvent {
  final String withdrawalId;
  DeleteExitVoucher(this.withdrawalId);
}

class FilterExitVouchers extends ExitVouchersEvent {
  final String? clientId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;
  FilterExitVouchers({this.clientId, this.dateFrom, this.dateTo, this.status});
}

// ─── States ──────────────────────────────────────────────────────
abstract class ExitVouchersState {}

class ExitVouchersInitial extends ExitVouchersState {}

class ExitVouchersLoading extends ExitVouchersState {}

class ExitVouchersLoaded extends ExitVouchersState {
  final List<StockWithdrawal> withdrawals;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  ExitVouchersLoaded(
    this.withdrawals, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });

  ExitVouchersLoaded copyWith({
    List<StockWithdrawal>? withdrawals,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? clientFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    String? statusFilter,
  }) {
    return ExitVouchersLoaded(
      withdrawals ?? this.withdrawals,
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

class ExitVouchersError extends ExitVouchersState {
  final String message;
  ExitVouchersError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class ExitVouchersBloc extends Bloc<ExitVouchersEvent, ExitVouchersState> {
  static const int pageSize = 10;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  ExitVouchersBloc() : super(ExitVouchersInitial()) {
    on<LoadExitVouchers>(_onLoad);
    on<LoadFirstExitVouchers>(_onLoadFirstExitVouchers);
    on<LoadNextExitVouchers>(_onLoadNextExitVouchers);
    on<ResetExitVouchersPagination>(_onResetExitVouchersPagination);
    on<AddExitVoucher>(_onAdd);
    on<UpdateExitVoucher>(_onUpdate);
    on<DeleteExitVoucher>(_onDelete);
    on<FilterExitVouchers>(_onFilter);
  }

  Future<void> _onLoadFirstExitVouchers(LoadFirstExitVouchers event, Emitter<ExitVouchersState> emit) async {
    emit(ExitVouchersLoading());
    try {
      FirestorePaginationService.instance.resetExitVouchersPagination();
      final itemsFuture = FirestorePaginationService.instance.getFirstExitVouchers(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getExitVouchersCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([itemsFuture, countFuture]);
      final items = results[0] as List<StockWithdrawal>;
      final totalCount = results[1] as int;

      emit(ExitVouchersLoaded(
        items,
        totalCount: totalCount > items.length ? totalCount : items.length,
        hasMore: items.length >= pageSize,
        clientFilter: event.customerId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
        statusFilter: event.status,
      ));
    } catch (e) {
      emit(ExitVouchersError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadNextExitVouchers(LoadNextExitVouchers event, Emitter<ExitVouchersState> emit) async {
    final currentState = state;
    if (currentState is! ExitVouchersLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextItems = await FirestorePaginationService.instance.getNextExitVouchers(
        pageSize: pageSize,
        currentOffset: currentState.withdrawals.length,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextItems.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<StockWithdrawal>.from(currentState.withdrawals)..addAll(nextItems);
        emit(ExitVouchersLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextItems.length >= pageSize,
          isLoadingMore: false,
          clientFilter: event.customerId,
          dateFromFilter: event.dateFrom,
          dateToFilter: event.dateTo,
          statusFilter: event.status,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetExitVouchersPagination(ResetExitVouchersPagination event, Emitter<ExitVouchersState> emit) async {
    FirestorePaginationService.instance.resetExitVouchersPagination();
    add(LoadFirstExitVouchers(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onLoad(LoadExitVouchers event, Emitter<ExitVouchersState> emit) async {
    await _onLoadFirstExitVouchers(LoadFirstExitVouchers(), emit);
  }

  Future<void> _onAdd(AddExitVoucher event, Emitter<ExitVouchersState> emit) async {
    try {
      await FirestoreRepository.instance.saveStockWithdrawal(event.withdrawal);
      add(LoadFirstExitVouchers());
    } catch (e) {
      emit(ExitVouchersError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdate(UpdateExitVoucher event, Emitter<ExitVouchersState> emit) async {
    try {
      await FirestoreRepository.instance.saveStockWithdrawal(event.withdrawal);
      add(LoadFirstExitVouchers());
    } catch (e) {
      emit(ExitVouchersError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDelete(DeleteExitVoucher event, Emitter<ExitVouchersState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('bons_sortie', event.withdrawalId);
    } catch (_) {
      try {
        await FirestoreRepository.instance.deleteDocument('bons_sortie', event.withdrawalId);
      } catch (_) {}
    }
    add(LoadFirstExitVouchers());
  }

  Future<void> _onFilter(FilterExitVouchers event, Emitter<ExitVouchersState> emit) async {
    add(LoadFirstExitVouchers(
      customerId: event.clientId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }
}
