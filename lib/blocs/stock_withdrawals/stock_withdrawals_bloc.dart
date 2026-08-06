import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock_withdrawal.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/enterprise_service.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class StockWithdrawalsEvent {}

class LoadStockWithdrawals extends StockWithdrawalsEvent {}

class LoadFirstStockWithdrawals extends StockWithdrawalsEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadFirstStockWithdrawals({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextStockWithdrawals extends StockWithdrawalsEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextStockWithdrawals({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetStockWithdrawalsPagination extends StockWithdrawalsEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetStockWithdrawalsPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class AddStockWithdrawal extends StockWithdrawalsEvent {
  final StockWithdrawal withdrawal;
  AddStockWithdrawal(this.withdrawal);
}

class UpdateStockWithdrawal extends StockWithdrawalsEvent {
  final StockWithdrawal withdrawal;
  UpdateStockWithdrawal(this.withdrawal);
}

class DeleteStockWithdrawal extends StockWithdrawalsEvent {
  final String withdrawalId;
  DeleteStockWithdrawal(this.withdrawalId);
}

class FilterStockWithdrawals extends StockWithdrawalsEvent {
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  FilterStockWithdrawals({
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

// ─── States ──────────────────────────────────────────────────────
abstract class StockWithdrawalsState {}

class StockWithdrawalsInitial extends StockWithdrawalsState {}

class StockWithdrawalsLoading extends StockWithdrawalsState {}

class StockWithdrawalsLoaded extends StockWithdrawalsState {
  final List<StockWithdrawal> withdrawals;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  StockWithdrawalsLoaded(
    this.withdrawals, {
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  StockWithdrawalsLoaded copyWith({
    List<StockWithdrawal>? withdrawals,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return StockWithdrawalsLoaded(
      withdrawals ?? this.withdrawals,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class StockWithdrawalsError extends StockWithdrawalsState {
  final String message;
  StockWithdrawalsError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class StockWithdrawalsBloc extends Bloc<StockWithdrawalsEvent, StockWithdrawalsState> {
  static const int pageSize = 10;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  StockWithdrawalsBloc() : super(StockWithdrawalsInitial()) {
    on<LoadStockWithdrawals>(_onLoad);
    on<LoadFirstStockWithdrawals>(_onLoadFirstStockWithdrawals);
    on<LoadNextStockWithdrawals>(_onLoadNextStockWithdrawals);
    on<ResetStockWithdrawalsPagination>(_onResetStockWithdrawalsPagination);
    on<AddStockWithdrawal>(_onAdd);
    on<UpdateStockWithdrawal>(_onUpdate);
    on<DeleteStockWithdrawal>(_onDelete);
    on<FilterStockWithdrawals>(_onFilter);
  }

  Future<void> _onLoadFirstStockWithdrawals(LoadFirstStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    emit(StockWithdrawalsLoading());
    try {
      FirestorePaginationService.instance.resetStockWithdrawalsPagination();
      final itemsFuture = FirestorePaginationService.instance.getFirstStockWithdrawals(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getStockWithdrawalsCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([itemsFuture, countFuture]);
      final items = results[0] as List<StockWithdrawal>;
      final totalCount = results[1] as int;

      emit(StockWithdrawalsLoaded(
        items,
        totalCount: totalCount > items.length ? totalCount : items.length,
        hasMore: items.length >= pageSize,
      ));
    } catch (e) {
      emit(StockWithdrawalsError("Erreur lors du chargement: $e"));
    }
  }

  Future<void> _onLoadNextStockWithdrawals(LoadNextStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    final currentState = state;
    if (currentState is! StockWithdrawalsLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextItems = await FirestorePaginationService.instance.getNextStockWithdrawals(
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
        emit(StockWithdrawalsLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextItems.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetStockWithdrawalsPagination(ResetStockWithdrawalsPagination event, Emitter<StockWithdrawalsState> emit) async {
    FirestorePaginationService.instance.resetStockWithdrawalsPagination();
    add(LoadFirstStockWithdrawals(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onLoad(LoadStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    emit(StockWithdrawalsLoading());
    try {
      final allWithdrawals = await _dbHelper.getStockWithdrawals();
      final filtered = allWithdrawals.where((w) => w.number.startsWith('BP-')).toList();
      emit(StockWithdrawalsLoaded(filtered, totalCount: filtered.length));
    } catch (e) {
      emit(StockWithdrawalsError("Erreur lors du chargement: $e"));
    }
  }

  Future<void> _onAdd(AddStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
    try {
      final db = await _dbHelper.database;
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      
      String number = event.withdrawal.number;
      if (number.isEmpty || number.startsWith('BP-') || number.startsWith('BS-') || number.startsWith('BL-')) {
        final now = DateTime.now();
        String countWhere = "date LIKE '${now.year}-%'";
        if (currentEntId != null && currentEntId.isNotEmpty) {
          if (EnterpriseService.instance.isDefaultEnterprise) {
            countWhere += " AND (enterprise_id = '$currentEntId' OR enterprise_id IS NULL)";
          } else {
            countWhere += " AND enterprise_id = '$currentEntId'";
          }
        }
        final countMap = await db.rawQuery(
            "SELECT COUNT(*) as count FROM bons_sortie WHERE $countWhere"
        );
        final count = (countMap.first['count'] as int? ?? 0) + 1;
        number = 'BP-${now.year}-${count.toString().padLeft(5, '0')}';
      }

      final newWithdrawal = event.withdrawal.copyWith(number: number);

      final List<StockMovement> movements = [];
      final List<StockWithdrawalItem> savedItems = [];
      await db.transaction((txn) async {
        final data = newWithdrawal.toMap();
        if (currentEntId != null && currentEntId.isNotEmpty) {
          data['enterprise_id'] = currentEntId;
        }
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
            enterpriseId: currentEntId,
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
      if (currentEntId != null && currentEntId.isNotEmpty) {
        newWithdrawalMap['enterprise_id'] = currentEntId;
      }
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

      add(LoadStockWithdrawals());
    } catch (e) {
      emit(StockWithdrawalsError("Erreur lors de l'ajout: $e"));
    }
  }

  Future<void> _onUpdate(UpdateStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
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

      add(LoadStockWithdrawals());
    } catch (e) {
      emit(StockWithdrawalsError('Erreur lors de la mise a jour: $e'));
    }
  }

  Future<void> _onDelete(DeleteStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
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

      add(LoadStockWithdrawals());
    } catch (e) {
      emit(StockWithdrawalsError('Erreur lors de la suppression: $e'));
    }
  }

  Future<void> _onFilter(FilterStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    emit(StockWithdrawalsLoading());
    try {
      final allWithdrawals = await _dbHelper.getStockWithdrawals(
        status: event.status,
        startDate: event.dateFrom,
        endDate: event.dateTo,
      );

      final filtered = allWithdrawals.where((w) {
        if (!w.number.startsWith('BP-')) return false;
        if (event.customerId != null && event.customerId!.isNotEmpty && event.customerId != 'all') {
          return w.customerId == event.customerId;
        }
        return true;
      }).toList();

      emit(StockWithdrawalsLoaded(
        filtered,
        totalCount: filtered.length,
      ));
    } catch (e) {
      emit(StockWithdrawalsError(e.toString()));
    }
  }
}
