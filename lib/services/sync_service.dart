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
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => triggerSync());
    
    // Trigger sync when coming online
    ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (isOnline) triggerSync();
    });
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
              await docRef.delete();
            } else {
              final Map<String, dynamic> data = jsonDecode(dataJson);
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
      final lastSyncStr = prefs.getString('last_sync_time') ?? '1970-01-01T00:00:00.000Z';
      
      final tablesToPull = ['customers', 'suppliers', 'products', 'invoices', 'quotes'];
      final db = await DatabaseHelper.instance.database;
      
      for (final table in tablesToPull) {
        final snapshot = await FirebaseFirestore.instance
            .collection(table)
            .where('updated_at', isGreaterThan: lastSyncStr)
            .get();
            
        for (final doc in snapshot.docs) {
          final data = doc.data();
          await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      
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
