import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../database/database_helper.dart';
import 'connectivity_service.dart';
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  Timer? _syncTimer;
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.idle;

  Stream<SyncStatus> get onSyncStatusChanged => _syncStatusController.stream;
  SyncStatus get currentStatus => _currentStatus;

  void startPeriodicSync() {
    _syncTimer?.cancel();
    
    // Trigger an initial sync shortly after app launch
    // Future.delayed(const Duration(seconds: 2), () {
    //   triggerSync();
    // });
    
    // _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => triggerSync());
    
    // Trigger sync when coming online, with a delay to let native network adapters stabilize
    // ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
    //   if (isOnline) {
    //     Future.delayed(const Duration(seconds: 3), () {
    //       triggerSync();
    //     });
    //   }
    // });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  Future<void> triggerSync() async {
    if (!ConnectivityService.instance.isOnline) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    if (_currentStatus == SyncStatus.syncing) return;

    _setStatus(SyncStatus.syncing);

    try {
      final pendingItems = await DatabaseHelper.instance.getPendingSyncItems();
      
      if (pendingItems.isNotEmpty) {
        for (var item in pendingItems) {
          try {
            final tableName = item['table_name'] as String;
            final recordId = item['record_id'] as String;
            final operation = item['operation'] as String;
            final dataJson = item['data_json'] as String;
            
            final docRef = FirebaseFirestore.instance.collection(tableName).doc(recordId);
            if (operation == 'DELETE') {
              // Convert hard-delete to soft-delete in Firebase so other devices can pull it
              final dataToMerge = {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()};
              await docRef.set(dataToMerge, SetOptions(merge: true));
            } else {
              final Map<String, dynamic> data = jsonDecode(dataJson);
              // Force updated_at to be UTC to prevent timezone string comparison bugs across devices
              data['updated_at'] = DateTime.now().toUtc().toIso8601String();
              await docRef.set(data, SetOptions(merge: true));
            }
            await DatabaseHelper.instance.markSynced(item['id'] as int);
          } catch (e) {
            await DatabaseHelper.instance.markSyncError(item['id'] as int, e.toString());
          }
        }
      }
      
      // Pulling changes from Firestore
      final prefs = await SharedPreferences.getInstance();
      String lastSyncStr = prefs.getString('last_sync_time') ?? '1970-01-01T00:00:00.000Z';
      
      // Convert old local-time strings to UTC to fix timezone mismatch
      if (!lastSyncStr.endsWith('Z')) {
        try {
          lastSyncStr = DateTime.parse(lastSyncStr).toUtc().toIso8601String();
        } catch (_) {}
      }
      
      // Force a 30-day buffer temporarily to catch missed records
      try {
        final lastSyncDate = DateTime.parse(lastSyncStr);
        final bufferDate = lastSyncDate.subtract(const Duration(days: 30));
        // Firebase C++ SDK on Windows crashes if date is before 1970
        if (bufferDate.year >= 1970) {
          lastSyncStr = bufferDate.toIso8601String();
        } else {
          lastSyncStr = '1970-01-01T00:00:00.000Z';
        }
      } catch (_) {}
      
      final tablesToPull = [
        'customers', 'suppliers', 'products', 'invoices', 'quotes',
        'customer_orders', 'delivery_notes', 'return_notes', 'credit_notes',
        'bons_sortie', 'stock_entries', 'receiving_vouchers', 'purchase_invoices', 'supplier_returns',
        'supplier_orders', 'supplier_credit_notes', 'stock_movements', 'projects',
        'transactions', 'check_traites', 'payment_accounts', 'product_families',
        'warehouses', 'treasury_accounts', 'payments', 'payment_allocations'
      ];
      
      final itemTableMap = {
        'quotes': {'table': 'quote_items', 'fk': 'quote_id'},
        'invoices': {'table': 'invoice_items', 'fk': 'invoice_id'},
        'customer_orders': {'table': 'customer_order_items', 'fk': 'order_id'},
        'delivery_notes': {'table': 'delivery_note_items', 'fk': 'delivery_note_id'},
        'return_notes': {'table': 'return_note_items', 'fk': 'return_note_id'},
        'credit_notes': {'table': 'credit_note_items', 'fk': 'credit_note_id'},
        'bons_sortie': {'table': 'bons_sortie_items', 'fk': 'withdrawal_id'},
        'stock_entries': {'table': 'stock_entry_items', 'fk': 'entry_id'},
        'receiving_vouchers': {'table': 'receiving_voucher_items', 'fk': 'voucher_id'},
        'purchase_invoices': {'table': 'purchase_invoice_items', 'fk': 'invoice_id'},
        'supplier_returns': {'table': 'supplier_return_items', 'fk': 'return_id'},
        'supplier_orders': {'table': 'supplier_order_items', 'fk': 'order_id'},
        'supplier_credit_notes': {'table': 'supplier_credit_note_items', 'fk': 'supplier_credit_note_id'},
      };

      final db = await DatabaseHelper.instance.database;
      
      for (final table in tablesToPull) {
        print("DEBUG (Sync): Pulling table $table ...");
        
        try {
          print("DEBUG (Sync): Querying with lastSyncStr: $lastSyncStr");
          final snapshot = await FirebaseFirestore.instance
              .collection(table)
              .where('updated_at', isGreaterThan: lastSyncStr)
              .get();
              
          print("DEBUG (Sync): Snapshot received for $table, docs: ${snapshot.docs.length}");
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id; // Ensure ID is present even for partial documents
          
          if (data.containsKey('items')) {
            final itemsInfo = itemTableMap[table];
            if (itemsInfo != null) {
              final itemsList = data['items'] as List<dynamic>?;
              final itemTable = itemsInfo['table']!;
              final fkColumn = itemsInfo['fk']!;
              
              try {
                await db.transaction((txn) async {
                  await txn.delete(itemTable, where: '$fkColumn = ?', whereArgs: [data['id']]);
                  if (itemsList != null) {
                    for (final item in itemsList) {
                      final itemMap = Map<String, dynamic>.from(item as Map);
                      await txn.insert(itemTable, itemMap, conflictAlgorithm: ConflictAlgorithm.replace);
                    }
                  }
                });
              } catch (e) {
                print('Error syncing items for $table ${data['id']}: $e');
              }
            }
            data.remove('items');
          }
          
          try {
            final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
            final validColumns = tableInfo.map((e) => e['name'] as String).toList();
            
            final sanitizedData = Map<String, dynamic>.from(data)
                ..removeWhere((key, value) => !validColumns.contains(key));

            final changes = await db.update(table, sanitizedData, where: 'id = ?', whereArgs: [data['id']]);
            if (changes == 0) {
              await db.insert(table, sanitizedData, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (e) {
            print('Error syncing $table ${data['id']}: $e');
          }
        }
        } catch (e) {
          print("DEBUG (Sync): Error getting snapshot for $table: $e");
        }
      }
      
      print("DEBUG (Sync): All tables pulled successfully!");
      await prefs.setString('last_sync_time', DateTime.now().toUtc().toIso8601String());
      
      _setStatus(SyncStatus.success);
    } catch (e) {
      _setStatus(SyncStatus.error);
    } finally {
      // Revert to idle after showing success/error
      Future.delayed(const Duration(seconds: 3), () {
        if (_currentStatus != SyncStatus.syncing) {
          _setStatus(SyncStatus.idle);
        }
      });
    }
  }

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
  }
}

enum SyncStatus { idle, syncing, success, error }
