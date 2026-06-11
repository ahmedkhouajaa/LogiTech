import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

class SyncIndicator extends StatefulWidget {
  const SyncIndicator({super.key});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onConnectivityChanged,
      initialData: ConnectivityService.instance.isOnline,
      builder: (context, connSnap) {
        final isOnline = connSnap.data ?? false;
        return StreamBuilder<SyncStatus>(
          stream: SyncService.instance.onSyncStatusChanged,
          initialData: SyncService.instance.currentStatus,
          builder: (context, syncSnap) {
            final syncStatus = syncSnap.data ?? SyncStatus.idle;
            return _buildIndicator(isOnline, syncStatus);
          },
        );
      },
    );
  }

  Widget _buildIndicator(bool isOnline, SyncStatus status) {
    Color color;
    IconData icon;
    String label;

    if (!isOnline) {
      color = AppColors.warning;
      icon = Icons.cloud_off_rounded;
      label = 'Hors ligne';
    } else if (status == SyncStatus.syncing) {
      color = AppColors.primary;
      icon = Icons.sync_rounded;
      label = 'Synchro...';
    } else if (status == SyncStatus.success) {
      color = AppColors.success;
      icon = Icons.cloud_done_rounded;
      label = 'Synchronisé';
    } else if (status == SyncStatus.error) {
      color = AppColors.error;
      icon = Icons.cloud_off_rounded;
      label = 'Erreur sync';
    } else {
      color = AppColors.success;
      icon = Icons.cloud_done_rounded;
      label = 'En ligne';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          status == SyncStatus.syncing
              ? RotationTransition(
                  turns: _spinController,
                  child: Icon(Icons.sync_rounded, color: color, size: 14),
                )
              : Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
