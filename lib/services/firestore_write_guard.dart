import 'package:flutter/material.dart';
import '../services/connection_quality_service.dart';
import '../services/storage_service.dart';
import '../widgets/dialogs/offline_dialog.dart';
import '../widgets/dialogs/slow_connection_dialog.dart';
import '../widgets/dialogs/storage_full_dialog.dart';

class FirestoreWriteGuard {
  static Future<bool> canProceedWrite(BuildContext? context) async {
    // 1. Connection check
    final quality = await ConnectionQualityService.instance.checkQuality();
    if (quality == ConnectionQuality.disconnected) {
      if (context != null && context.mounted) {
        final allowed = await OfflineDialog.show(context);
        if (!allowed) return false;
      } else {
        return false;
      }
    } else if (quality == ConnectionQuality.slow) {
      if (context != null && context.mounted) {
        final allowed = await SlowConnectionDialog.show(context);
        if (!allowed) return false;
      }
    }

    // 2. Storage check
    final hasStorage = await StorageService.instance.hasMinimumStorage();
    if (!hasStorage) {
      if (context != null && context.mounted) {
        final allowed = await StorageFullDialog.show(context);
        if (!allowed) return false;
      } else {
        return false;
      }
    }

    return true;
  }
}
