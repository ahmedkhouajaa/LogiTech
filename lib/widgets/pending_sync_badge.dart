import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class PendingSyncBadge extends StatefulWidget {
  final String label;
  final double fontSize;

  const PendingSyncBadge({
    super.key,
    this.label = 'En attente',
    this.fontSize = 11,
  });

  @override
  State<PendingSyncBadge> createState() => _PendingSyncBadgeState();
}

class _PendingSyncBadgeState extends State<PendingSyncBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<SyncStatus>? _sub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    if (SyncService.instance.currentStatus == SyncStatus.syncing) {
      _controller.repeat();
    }
    _sub = SyncService.instance.onSyncStatusChanged.listen((status) {
      if (mounted) {
        if (status == SyncStatus.syncing) {
          _controller.repeat();
        } else {
          _controller.stop();
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSyncing = SyncService.instance.currentStatus == SyncStatus.syncing;
    return Tooltip(
      message: isSyncing ? 'Synchronisation en cours...' : 'En attente de synchronisation',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSyncing ? Colors.blue.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSyncing ? Colors.blue.shade700 : Colors.orange.shade700,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _controller,
              child: Icon(
                Icons.sync,
                size: widget.fontSize + 2,
                color: isSyncing ? Colors.blue.shade800 : Colors.orange.shade800,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                isSyncing ? 'Sync...' : widget.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSyncing ? Colors.blue.shade900 : Colors.orange.shade900,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
