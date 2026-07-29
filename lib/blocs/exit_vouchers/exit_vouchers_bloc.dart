import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock_withdrawal.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/sync_service.dart';

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
      emit(ExitVouchersError("Erreur lors du chargement: $e"));
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
      final db = await _dbHelper.database;
      
      String number = event.withdrawal.number;
      // Only auto-generate a number if it's genuinely empty
      if (number.trim().isEmpty) {
        final now = DateTime.now();
        final countMap = await db.rawQuery(
            "SELECT COUNT(*) as count FROM bons_sortie WHERE number LIKE 'BS-${now.year}-%'"
        );
        final count = (countMap.first['count'] as int? ?? 0) + 1;
        number = 'BS-${now.year}-${count.toString().padLeft(5, '0')}';
      }

      final newWithdrawal = event.withdrawal.copyWith(number: number);

      final List<StockMovement> movements = [];
      final List<StockWithdrawalItem> savedItems = [];
      await db.transaction((txn) async {
        final data = newWithdrawal.toMap();
        data.remove('items');
        await txn.insert('bons_sortie', data);

        for (var item in newWithdrawal.items) {
          final newItem = item.copyWith(id: _uuid.v4(), withdrawalId: newWithdrawal.id);
          savedItems.add(newItem);
          await txn.insert('bons_sortie_items', newItem.toMap());

          final movement = StockMovement(
            id: _uuid.v4(),
            productId: item.productId,
            warehouseId: newWithdrawal.warehouseId ?? 'default_warehouse',
            type: MovementType.exit,
            quantity: item.quantity,
            referenceType: 'stock_withdrawal',
            referenceId: newWithdrawal.id,
            date: newWithdrawal.date,
            notes: newWithdrawal.conditionsGenerales,
          );
          movements.add(movement);
          await txn.insert('stock_movements', movement.toMap());

          await txn.rawUpdate(
            'UPDATE products SET stock_qty = COALESCE(stock_qty, 0) - ? WHERE id = ?',
            [item.quantity, item.productId]
          );
        }
      });

      final newWithdrawalMap = newWithdrawal.toMap();
      newWithdrawalMap['items'] = savedItems.map((i) => i.toMap()).toList();
      await _dbHelper.addToSyncQueue('bons_sortie', newWithdrawal.id, 'INSERT', newWithdrawalMap);
      
      for (var mov in movements) {
        await _dbHelper.addToSyncQueue('stock_movements', mov.id, 'INSERT', mov.toMap());
      }
      
      for (var item in newWithdrawal.items) {
        final pMap = await _dbHelper.getById('products', item.productId);
        if (pMap != null) {
          await _dbHelper.addToSyncQueue('products', item.productId, 'UPDATE', pMap);
        }
      }

      // Immediately sync to Firestore so the new item appears when we reload from Firestore
      await SyncService.instance.triggerSync();

      add(LoadFirstExitVouchers());
    } catch (e) {
      emit(ExitVouchersError("Erreur lors de l'ajout: $e"));
    }
  }

  Future<void> _onUpdate(UpdateExitVoucher event, Emitter<ExitVouchersState> emit) async {
    try {
      final db = await _dbHelper.database;
      final withdrawal = event.withdrawal.copyWith(updatedAt: DateTime.now());

      final List<Map<String, dynamic>> oldMovements = await db.query(
        'stock_movements',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['stock_withdrawal', withdrawal.id],
      );

      final List<StockMovement> newMovements = [];
      final List<Map<String, dynamic>> oldItems = await db.query(
        'bons_sortie_items',
        where: 'withdrawal_id = ?',
        whereArgs: [withdrawal.id],
      );
      final List<StockWithdrawalItem> savedNewItems = [];

      await db.transaction((txn) async {
        final data = withdrawal.toMap();
        data.remove('items');
        await txn.update(
          'bons_sortie',
          data,
          where: 'id = ?',
          whereArgs: [withdrawal.id],
        );

        for (var oldMap in oldItems) {
          final oldQty = (oldMap['quantity'] as num).toDouble();
          final oldProductId = oldMap['product_id'] as String;
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = COALESCE(stock_qty, 0) + ? WHERE id = ?',
            [oldQty, oldProductId]
          );
        }

        await txn.delete(
          'bons_sortie_items',
          where: 'withdrawal_id = ?',
          whereArgs: [withdrawal.id],
        );
        
        await txn.delete(
          'stock_movements',
          where: 'reference_type = ? AND reference_id = ?',
          whereArgs: ['stock_withdrawal', withdrawal.id],
        );

        for (var item in withdrawal.items) {
          final newItem = item.copyWith(
            id: item.id.isEmpty ? _uuid.v4() : item.id,
            withdrawalId: withdrawal.id,
          );
          savedNewItems.add(newItem);
          await txn.insert('bons_sortie_items', newItem.toMap());
          
          final movement = StockMovement(
            id: _uuid.v4(),
            productId: item.productId,
            warehouseId: withdrawal.warehouseId ?? 'default_warehouse',
            type: MovementType.exit,
            quantity: item.quantity,
            referenceType: 'stock_withdrawal',
            referenceId: withdrawal.id,
            date: withdrawal.date,
            notes: withdrawal.conditionsGenerales,
          );
          newMovements.add(movement);
          await txn.insert('stock_movements', movement.toMap());

          await txn.rawUpdate(
            'UPDATE products SET stock_qty = COALESCE(stock_qty, 0) - ? WHERE id = ?',
            [item.quantity, item.productId]
          );
        }
      });

      final withdrawalMap = withdrawal.toMap();
      withdrawalMap['items'] = savedNewItems.map((i) => i.toMap()).toList();
      await _dbHelper.addToSyncQueue('bons_sortie', withdrawal.id, 'UPDATE', withdrawalMap);

      for (var mov in oldMovements) {
        await _dbHelper.addToSyncQueue('stock_movements', mov['id'] as String, 'DELETE', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()});
      }
      for (var mov in newMovements) {
        await _dbHelper.addToSyncQueue('stock_movements', mov.id, 'INSERT', mov.toMap());
      }

      final productIds = <String>{};
      for (var i in oldItems) {
        productIds.add(i['product_id'] as String);
      }
      for (var i in withdrawal.items) {
        productIds.add(i.productId);
      }

      for (var pId in productIds) {
        final pMap = await _dbHelper.getById('products', pId);
        if (pMap != null) {
          await _dbHelper.addToSyncQueue('products', pId, 'UPDATE', pMap);
        }
      }

      add(LoadFirstExitVouchers());
    } catch (e) {
      emit(ExitVouchersError('Erreur lors de la mise a jour: $e'));
    }
  }

  Future<void> _onDelete(DeleteExitVoucher event, Emitter<ExitVouchersState> emit) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> movementsToDelete = await db.query(
        'stock_movements',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['stock_withdrawal', event.withdrawalId],
      );
      final List<Map<String, dynamic>> oldItems = await db.query(
        'bons_sortie_items',
        where: 'withdrawal_id = ?',
        whereArgs: [event.withdrawalId],
      );

      await db.transaction((txn) async {
        await txn.update(
          'bons_sortie',
          {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [event.withdrawalId],
        );

        for (var oldMap in oldItems) {
          final oldQty = (oldMap['quantity'] as num).toDouble();
          final oldProductId = oldMap['product_id'] as String;
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = COALESCE(stock_qty, 0) + ? WHERE id = ?',
            [oldQty, oldProductId]
          );
        }

        await txn.update(
          'stock_movements',
          {'is_deleted': 1},
          where: 'reference_type = ? AND reference_id = ?',
          whereArgs: ['stock_withdrawal', event.withdrawalId],
        );
      });

      final data = {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()};
      await _dbHelper.addToSyncQueue('bons_sortie', event.withdrawalId, 'DELETE', data);
      
      for (var mov in movementsToDelete) {
        await _dbHelper.addToSyncQueue('stock_movements', mov['id'] as String, 'DELETE', data);
      }
      
      for (var oldMap in oldItems) {
        final pId = oldMap['product_id'] as String;
        final pMap = await _dbHelper.getById('products', pId);
        if (pMap != null) {
          await _dbHelper.addToSyncQueue('products', pId, 'UPDATE', pMap);
        }
      }

      add(LoadFirstExitVouchers());
    } catch (e) {
      emit(ExitVouchersError('Erreur lors de la suppression: $e'));
    }
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
