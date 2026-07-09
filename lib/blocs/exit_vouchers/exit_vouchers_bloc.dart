import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock_withdrawal.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../database/database_helper.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class ExitVouchersEvent {}

class LoadExitVouchers extends ExitVouchersEvent {}

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
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  ExitVouchersLoaded(
    this.withdrawals, {
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });
}

class ExitVouchersError extends ExitVouchersState {
  final String message;
  ExitVouchersError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class ExitVouchersBloc extends Bloc<ExitVouchersEvent, ExitVouchersState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  ExitVouchersBloc() : super(ExitVouchersInitial()) {
    on<LoadExitVouchers>(_onLoad);
    on<AddExitVoucher>(_onAdd);
    on<UpdateExitVoucher>(_onUpdate);
    on<DeleteExitVoucher>(_onDelete);
    on<FilterExitVouchers>(_onFilter);
  }

  Future<void> _onLoad(LoadExitVouchers event, Emitter<ExitVouchersState> emit) async {
    emit(ExitVouchersLoading());
    try {
      final allWithdrawals = await _dbHelper.getStockWithdrawals();
      final filtered = allWithdrawals.where((w) => w.number.startsWith('BS-')).toList();
      emit(ExitVouchersLoaded(filtered));
    } catch (e) {
      emit(ExitVouchersError("Erreur lors du chargement: $e"));
    }
  }

  Future<void> _onAdd(AddExitVoucher event, Emitter<ExitVouchersState> emit) async {
    try {
      final db = await _dbHelper.database;
      
      String number = event.withdrawal.number;
      if (number.isEmpty || number.startsWith('BP-') || number.startsWith('BS-') || number.startsWith('BL-')) {
        final now = DateTime.now();
        final countMap = await db.rawQuery(
            "SELECT COUNT(*) as count FROM bons_sortie WHERE date LIKE '${now.year}-%'"
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

      add(LoadExitVouchers());
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

      add(LoadExitVouchers());
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

      add(LoadExitVouchers());
    } catch (e) {
      emit(ExitVouchersError('Erreur lors de la suppression: $e'));
    }
  }

  Future<void> _onFilter(FilterExitVouchers event, Emitter<ExitVouchersState> emit) async {
    emit(ExitVouchersLoading());
    try {
      final allWithdrawals = await _dbHelper.getStockWithdrawals(
        status: event.status,
        startDate: event.dateFrom,
        endDate: event.dateTo,
      );

      final filtered = allWithdrawals.where((w) {
        if (!w.number.startsWith('BS-')) return false;
        if (event.clientId != null && event.clientId!.isNotEmpty && event.clientId != 'all') {
          return w.customerId == event.clientId;
        }
        return true;
      }).toList();

      emit(ExitVouchersLoaded(
        filtered,
        clientFilter: event.clientId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
        statusFilter: event.status,
      ));
    } catch (e) {
      emit(ExitVouchersError(e.toString()));
    }
  }
}
