import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/stock_transfer.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class StockTransfersEvent {}

class LoadStockTransfers extends StockTransfersEvent {}

class LoadFirstStockTransfers extends StockTransfersEvent {
  final String? searchQuery;
  final String? sourceWarehouseId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadFirstStockTransfers({
    this.searchQuery,
    this.sourceWarehouseId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextStockTransfers extends StockTransfersEvent {
  final String? searchQuery;
  final String? sourceWarehouseId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextStockTransfers({
    this.searchQuery,
    this.sourceWarehouseId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetStockTransfersPagination extends StockTransfersEvent {
  final String? searchQuery;
  final String? sourceWarehouseId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetStockTransfersPagination({
    this.searchQuery,
    this.sourceWarehouseId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class AddStockTransfer extends StockTransfersEvent {
  final StockTransfer transfer;
  AddStockTransfer(this.transfer);
}

class UpdateStockTransfer extends StockTransfersEvent {
  final StockTransfer transfer;
  UpdateStockTransfer(this.transfer);
}

class DeleteStockTransfer extends StockTransfersEvent {
  final String transferId;
  DeleteStockTransfer(this.transferId);
}

// ─── States ──────────────────────────────────────────────────────
abstract class StockTransfersState {}

class StockTransfersInitial extends StockTransfersState {}

class StockTransfersLoading extends StockTransfersState {}

class StockTransfersLoaded extends StockTransfersState {
  final List<StockTransfer> transfers;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  StockTransfersLoaded(
    this.transfers, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  StockTransfersLoaded copyWith({
    List<StockTransfer>? transfers,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return StockTransfersLoaded(
      transfers ?? this.transfers,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class StockTransfersError extends StockTransfersState {
  final String message;
  StockTransfersError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class StockTransfersBloc extends Bloc<StockTransfersEvent, StockTransfersState> {
  static const int pageSize = 10;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  StockTransfersBloc() : super(StockTransfersInitial()) {
    on<LoadStockTransfers>(_onLoad);
    on<LoadFirstStockTransfers>(_onLoadFirstStockTransfers);
    on<LoadNextStockTransfers>(_onLoadNextStockTransfers);
    on<ResetStockTransfersPagination>(_onResetStockTransfersPagination);
    on<AddStockTransfer>(_onAdd);
    on<UpdateStockTransfer>(_onUpdate);
    on<DeleteStockTransfer>(_onDelete);
  }

  Future<void> _onLoad(LoadStockTransfers event, Emitter<StockTransfersState> emit) async {
    emit(StockTransfersLoading());
    try {
      final transfers = await _dbHelper.getStockTransfers();
      emit(StockTransfersLoaded(transfers, totalCount: transfers.length));
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }

  Future<void> _onLoadFirstStockTransfers(LoadFirstStockTransfers event, Emitter<StockTransfersState> emit) async {
    emit(StockTransfersLoading());
    try {
      FirestorePaginationService.instance.resetStockTransfersPagination();
      final transfersFuture = FirestorePaginationService.instance.getFirstStockTransfers(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        sourceWarehouseId: event.sourceWarehouseId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getStockTransfersCount(
        searchQuery: event.searchQuery,
        sourceWarehouseId: event.sourceWarehouseId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([transfersFuture, countFuture]);
      final transfers = results[0] as List<StockTransfer>;
      final totalCount = results[1] as int;

      emit(StockTransfersLoaded(
        transfers,
        totalCount: totalCount > transfers.length ? totalCount : transfers.length,
        hasMore: transfers.length >= pageSize,
      ));
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }

  Future<void> _onLoadNextStockTransfers(LoadNextStockTransfers event, Emitter<StockTransfersState> emit) async {
    final currentState = state;
    if (currentState is! StockTransfersLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextTransfers = await FirestorePaginationService.instance.getNextStockTransfers(
        pageSize: pageSize,
        currentOffset: currentState.transfers.length,
        searchQuery: event.searchQuery,
        sourceWarehouseId: event.sourceWarehouseId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextTransfers.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<StockTransfer>.from(currentState.transfers)..addAll(nextTransfers);
        emit(StockTransfersLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextTransfers.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetStockTransfersPagination(ResetStockTransfersPagination event, Emitter<StockTransfersState> emit) async {
    FirestorePaginationService.instance.resetStockTransfersPagination();
    add(LoadFirstStockTransfers(
      searchQuery: event.searchQuery,
      sourceWarehouseId: event.sourceWarehouseId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAdd(AddStockTransfer event, Emitter<StockTransfersState> emit) async {
    try {
      final db = await _dbHelper.database;
      
      String number = event.transfer.number;
      if (number.isEmpty || number.startsWith('BT-')) {
        final now = DateTime.now();
        final countMap = await db.rawQuery(
            "SELECT COUNT(*) as count FROM stock_transfers WHERE date LIKE '${now.year}-%'"
        );
        final count = (countMap.first['count'] as int? ?? 0) + 1;
        number = 'BT-${now.year}-${count.toString().padLeft(5, '0')}';
      }

      final transferToInsert = event.transfer.copyWith(number: number);
      await _dbHelper.insertStockTransfer(transferToInsert);
      add(LoadStockTransfers());
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateStockTransfer event, Emitter<StockTransfersState> emit) async {
    try {
      await _dbHelper.updateStockTransfer(event.transfer);
      add(LoadStockTransfers());
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteStockTransfer event, Emitter<StockTransfersState> emit) async {
    try {
      await _dbHelper.deleteStockTransfer(event.transferId);
      add(LoadStockTransfers());
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }
}
