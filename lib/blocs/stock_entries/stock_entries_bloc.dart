import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock_entry.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../database/database_helper.dart';
import 'stock_entries_event.dart';
import 'stock_entries_state.dart';

class StockEntriesBloc extends Bloc<StockEntriesEvent, StockEntriesState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  StockEntriesBloc() : super(StockEntriesInitial()) {
    on<LoadStockEntries>(_onLoadStockEntries);
    on<AddStockEntry>(_onAddStockEntry);
    on<UpdateStockEntry>(_onUpdateStockEntry);
    on<DeleteStockEntry>(_onDeleteStockEntry);
    on<FilterStockEntries>(_onFilterStockEntries);
  }

  Future<void> _onLoadStockEntries(LoadStockEntries event, Emitter<StockEntriesState> emit) async {
    emit(StockEntriesLoading());
    try {
      final db = await _dbHelper.database;
      final entryMaps = await db.query(
        'stock_entries',
        where: 'is_deleted = ?',
        whereArgs: [0],
        orderBy: 'date DESC',
      );

      List<StockEntry> entries = [];
      for (var map in entryMaps) {
        final itemMaps = await db.query(
          'stock_entry_items',
          where: 'entry_id = ?',
          whereArgs: [map['id']],
        );
        final items = itemMaps.map((i) => StockEntryItem.fromMap(i)).toList();
        entries.add(StockEntry.fromMap(map, items));
      }

      emit(StockEntriesLoaded(entries));
    } catch (e) {
      emit(StockEntriesError("Erreur lors du chargement des bons d'entree: $e"));
    }
  }

  Future<void> _onAddStockEntry(AddStockEntry event, Emitter<StockEntriesState> emit) async {
    try {
      final db = await _dbHelper.database;
      
      // Auto-generate number if empty or placeholder
      String number = event.entry.number;
      if (number.isEmpty || number.startsWith('BE-')) {
        final now = DateTime.now();
        final countMap = await db.rawQuery(
            "SELECT COUNT(*) as count FROM stock_entries WHERE date LIKE '${now.year}-%'"
        );
        final count = (countMap.first['count'] as int? ?? 0) + 1;
        number = 'BE-${now.year}-${count.toString().padLeft(5, '0')}';
      }

      final newEntry = event.entry.copyWith(number: number);

      final List<StockMovement> movements = [];
      final List<StockEntryItem> savedItems = [];
      await db.transaction((txn) async {
        // Insert entry
        await txn.insert('stock_entries', newEntry.toMap());

        // Insert items
        for (var item in newEntry.items) {
          final newItem = item.copyWith(id: _uuid.v4(), entryId: newEntry.id);
          savedItems.add(newItem);
          await txn.insert('stock_entry_items', newItem.toMap());

          // Create stock movement
          final movement = StockMovement(
            id: _uuid.v4(),
            productId: item.productId,
            warehouseId: newEntry.warehouseId,
            type: MovementType.entry,
            quantity: item.quantity,
            referenceType: 'stock_entry',
            referenceId: newEntry.id,
            date: newEntry.date,
            notes: newEntry.reason,
          );
          movements.add(movement);
          await txn.insert('stock_movements', movement.toMap());

          // Update product stock
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = COALESCE(stock_qty, 0) + ? WHERE id = ?',
            [item.quantity, item.productId]
          );
        }
      });

      // Add to sync queue
      final newEntryMap = newEntry.toMap();
      newEntryMap['items'] = savedItems.map((i) => i.toMap()).toList();
      await _dbHelper.addToSyncQueue('stock_entries', newEntry.id, 'INSERT', newEntryMap);
      
      for (var mov in movements) {
        await _dbHelper.addToSyncQueue('stock_movements', mov.id, 'INSERT', mov.toMap());
      }
      
      for (var item in newEntry.items) {
        final pMap = await _dbHelper.getById('products', item.productId);
        if (pMap != null) {
          await _dbHelper.addToSyncQueue('products', item.productId, 'UPDATE', pMap);
        }
      }

      add(LoadStockEntries());
    } catch (e) {
      emit(StockEntriesError("Erreur lors de l'ajout: $e"));
    }
  }

  Future<void> _onUpdateStockEntry(UpdateStockEntry event, Emitter<StockEntriesState> emit) async {
    try {
      final db = await _dbHelper.database;
      final entry = event.entry.copyWith(updatedAt: DateTime.now());

      final List<Map<String, dynamic>> oldMovements = await db.query(
        'stock_movements',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['stock_entry', entry.id],
      );

      final List<StockMovement> newMovements = [];
      final List<Map<String, dynamic>> oldItems = await db.query(
        'stock_entry_items',
        where: 'entry_id = ?',
        whereArgs: [entry.id],
      );
      final List<StockEntryItem> savedNewItems = [];

      await db.transaction((txn) async {
        // Update entry
        await txn.update(
          'stock_entries',
          entry.toMap(),
          where: 'id = ?',
          whereArgs: [entry.id],
        );

        for (var oldMap in oldItems) {
          final oldQty = (oldMap['quantity'] as num).toDouble();
          final oldProductId = oldMap['product_id'] as String;
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = COALESCE(stock_qty, 0) - ? WHERE id = ?',
            [oldQty, oldProductId]
          );
        }

        // Delete old items
        await txn.delete(
          'stock_entry_items',
          where: 'entry_id = ?',
          whereArgs: [entry.id],
        );
        
        // Delete old movements
        await txn.delete(
          'stock_movements',
          where: 'reference_type = ? AND reference_id = ?',
          whereArgs: ['stock_entry', entry.id],
        );

        // Insert new items
        for (var item in entry.items) {
          final newItem = item.copyWith(
            id: item.id.isEmpty ? _uuid.v4() : item.id,
            entryId: entry.id,
          );
          savedNewItems.add(newItem);
          await txn.insert('stock_entry_items', newItem.toMap());
          
          final movement = StockMovement(
            id: _uuid.v4(),
            productId: item.productId,
            warehouseId: entry.warehouseId,
            type: MovementType.entry,
            quantity: item.quantity,
            referenceType: 'stock_entry',
            referenceId: entry.id,
            date: entry.date,
            notes: entry.reason,
          );
          newMovements.add(movement);
          await txn.insert('stock_movements', movement.toMap());

          await txn.rawUpdate(
            'UPDATE products SET stock_qty = COALESCE(stock_qty, 0) + ? WHERE id = ?',
            [item.quantity, item.productId]
          );
        }
      });

      // Sync queue
      final entryMap = entry.toMap();
      entryMap['items'] = savedNewItems.map((i) => i.toMap()).toList();
      await _dbHelper.addToSyncQueue('stock_entries', entry.id, 'UPDATE', entryMap);

      for (var mov in oldMovements) {
        await _dbHelper.addToSyncQueue('stock_movements', mov['id'] as String, 'DELETE', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()});
      }
      for (var mov in newMovements) {
        await _dbHelper.addToSyncQueue('stock_movements', mov.id, 'INSERT', mov.toMap());
      }

      final productIds = <String>{};
      for (var i in oldItems) productIds.add(i['product_id'] as String);
      for (var i in entry.items) productIds.add(i.productId);

      for (var pId in productIds) {
        final pMap = await _dbHelper.getById('products', pId);
        if (pMap != null) {
          await _dbHelper.addToSyncQueue('products', pId, 'UPDATE', pMap);
        }
      }

      add(LoadStockEntries());
    } catch (e) {
      emit(StockEntriesError('Erreur lors de la mise a jour: $e'));
    }
  }

  Future<void> _onDeleteStockEntry(DeleteStockEntry event, Emitter<StockEntriesState> emit) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> movementsToDelete = await db.query(
        'stock_movements',
        where: 'reference_type = ? AND reference_id = ?',
        whereArgs: ['stock_entry', event.entryId],
      );
      final List<Map<String, dynamic>> oldItems = await db.query(
        'stock_entry_items',
        where: 'entry_id = ?',
        whereArgs: [event.entryId],
      );

      await db.transaction((txn) async {
        await txn.update(
          'stock_entries',
          {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [event.entryId],
        );

        for (var oldMap in oldItems) {
          final oldQty = (oldMap['quantity'] as num).toDouble();
          final oldProductId = oldMap['product_id'] as String;
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = COALESCE(stock_qty, 0) - ? WHERE id = ?',
            [oldQty, oldProductId]
          );
        }

        // Mark movements as deleted
        await txn.update(
          'stock_movements',
          {'is_deleted': 1},
          where: 'reference_type = ? AND reference_id = ?',
          whereArgs: ['stock_entry', event.entryId],
        );
      });

      // Sync queue
      final data = {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()};
      await _dbHelper.addToSyncQueue('stock_entries', event.entryId, 'DELETE', data);
      
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

      add(LoadStockEntries());
    } catch (e) {
      emit(StockEntriesError('Erreur lors de la suppression: $e'));
    }
  }

  void _onFilterStockEntries(FilterStockEntries event, Emitter<StockEntriesState> emit) {
    if (state is StockEntriesLoaded) {
      final currentState = state as StockEntriesLoaded;
      emit(StockEntriesLoaded(
        currentState.entries,
        supplierFilter: event.supplierId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
        statusFilter: event.status,
      ));
    }
  }
}
