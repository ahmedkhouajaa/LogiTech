import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection_quality_service.dart';
import 'connectivity_service.dart';
import 'offline_document_service.dart';
import 'offline_quote_service.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  Timer? _syncTimer;
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _documentSyncController = StreamController<int>.broadcast();

  SyncStatus _currentStatus = SyncStatus.idle;

  Stream<SyncStatus> get onSyncStatusChanged => _syncStatusController.stream;
  Stream<int> get onDocumentSyncCompleted => _documentSyncController.stream;
  Stream<int> get onQuoteSyncCompleted => _documentSyncController.stream; // Backward compatibility
  SyncStatus get currentStatus => _currentStatus;

  void startPeriodicSync() {
    _syncTimer?.cancel();
    
    // Auto-sync on startup if connected
    if (ConnectivityService.instance.isOnline) {
      unawaited(triggerDocumentSync());
    }

    // Auto-sync when connectivity changes to online
    ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        _setStatus(SyncStatus.syncing);
        triggerDocumentSync();
      } else {
        _setStatus(SyncStatus.idle);
      }
    });

    ConnectionQualityService.instance.onQualityChanged.listen((quality) {
      if (quality != ConnectionQuality.disconnected) {
        _setStatus(SyncStatus.success);
      } else {
        _setStatus(SyncStatus.idle);
      }
    });
  }

  Future<int> triggerDocumentSync() async {
    _setStatus(SyncStatus.syncing);
    final quoteCount = await OfflineQuoteService.instance.syncPendingQuotes();
    final allCount = await OfflineDocumentService.instance.syncAllPendingDocuments();
    final total = quoteCount + allCount;

    if (total > 0) {
      _setStatus(SyncStatus.success);
      _documentSyncController.add(total);
    } else {
      _setStatus(SyncStatus.idle);
    }
    return total;
  }

  Future<int> triggerQuoteSync() async => triggerDocumentSync();

  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  Future<void> triggerSync() async {
    await triggerDocumentSync();
  }

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
    _documentSyncController.close();
  }
}

