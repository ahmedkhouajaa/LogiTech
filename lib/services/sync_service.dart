import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection_quality_service.dart';

enum SyncStatus { idle, syncing, success, error }

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
    ConnectionQualityService.instance.onQualityChanged.listen((quality) {
      if (quality != ConnectionQuality.disconnected) {
        _setStatus(SyncStatus.success);
      } else {
        _setStatus(SyncStatus.idle);
      }
    });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  Future<void> triggerSync() async {
    _setStatus(SyncStatus.success);
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
