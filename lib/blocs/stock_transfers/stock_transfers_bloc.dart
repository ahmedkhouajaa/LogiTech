import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/stock_transfer.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';
import 'package:business_manager_pro/services/error_handler.dart';

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
    await _onLoadFirstStockTransfers(LoadFirstStockTransfers(), emit);
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
      emit(StockTransfersError(ErrorHandler.parseError(e)));
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
      String number = event.transfer.number;
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextStockTransferSequence();
        number = generateDocNumber(DocPrefix.stockTransfer, seq);
      }
      final transferToSave = event.transfer.copyWith(number: number);
      await FirestoreRepository.instance.saveStockTransfer(transferToSave);

      for (var item in event.transfer.items) {
        if (item.productId.isNotEmpty && item.quantityToTransfer > 0) {
          String? prodName;
          try {
            final prodRef = FirebaseFirestore.instance.collection('products').doc(item.productId);
            final doc = await prodRef.get();
            if (doc.exists && doc.data() != null) {
              prodName = doc.data()!['name']?.toString();
            }
          } catch (_) {}

          String? srcWhName;
          try {
            if (event.transfer.sourceWarehouseId.isNotEmpty) {
              final whRef = FirebaseFirestore.instance.collection('warehouses').doc(event.transfer.sourceWarehouseId);
              final doc = await whRef.get();
              if (doc.exists && doc.data() != null) {
                srcWhName = doc.data()!['name']?.toString();
              }
            }
          } catch (_) {}

          String? destWhName;
          try {
            if (event.transfer.destinationWarehouseId.isNotEmpty) {
              final whRef = FirebaseFirestore.instance.collection('warehouses').doc(event.transfer.destinationWarehouseId);
              final doc = await whRef.get();
              if (doc.exists && doc.data() != null) {
                destWhName = doc.data()!['name']?.toString();
              }
            }
          } catch (_) {}

          // Outbound movement from source warehouse
          final movOutId = const Uuid().v4();
          final movOut = StockMovement(
            id: movOutId,
            productId: item.productId,
            productName: prodName,
            warehouseId: event.transfer.sourceWarehouseId,
            warehouseName: srcWhName,
            type: MovementType.transfer_out,
            quantity: item.quantityToTransfer,
            referenceType: 'stock_transfer',
            referenceId: event.transfer.number.isNotEmpty ? event.transfer.number : event.transfer.id,
            date: event.transfer.date,
            notes: event.transfer.notes ?? 'Transfert de stock (Sortie)',
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
          );
          await FirestoreRepository.instance.saveDocument('stock_movements', movOut.id, movOut.toMap());

          // Inbound movement to destination warehouse
          final movInId = const Uuid().v4();
          final movIn = StockMovement(
            id: movInId,
            productId: item.productId,
            productName: prodName,
            warehouseId: event.transfer.destinationWarehouseId,
            warehouseName: destWhName,
            type: MovementType.transfer_in,
            quantity: item.quantityToTransfer,
            referenceType: 'stock_transfer',
            referenceId: event.transfer.number.isNotEmpty ? event.transfer.number : event.transfer.id,
            date: event.transfer.date,
            notes: event.transfer.notes ?? 'Transfert de stock (Entrée)',
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
          );
          await FirestoreRepository.instance.saveDocument('stock_movements', movIn.id, movIn.toMap());
        }
      }

      add(LoadFirstStockTransfers());
    } catch (e) {
      emit(StockTransfersError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdate(UpdateStockTransfer event, Emitter<StockTransfersState> emit) async {
    try {
      await FirestoreRepository.instance.saveStockTransfer(event.transfer);
      add(LoadFirstStockTransfers());
    } catch (e) {
      emit(StockTransfersError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDelete(DeleteStockTransfer event, Emitter<StockTransfersState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('stock_transfers', event.transferId);
      add(LoadFirstStockTransfers());
    } catch (e) {
      emit(StockTransfersError(ErrorHandler.parseError(e)));
    }
  }
}
