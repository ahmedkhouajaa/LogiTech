import 'package:flutter/material.dart';
import '../../services/connection_quality_service.dart';

class OfflineDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback? onCancel;

  const OfflineDialog({
    super.key,
    required onRetry,
    this.onCancel,
  }) : onRetry = onRetry;

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OfflineDialog(
        onRetry: () async {
          final quality = await ConnectionQualityService.instance.checkQuality();
          if (quality != ConnectionQuality.disconnected) {
            Navigator.of(ctx).pop(true);
          }
        },
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.wifi_off_rounded, color: Colors.red, size: 28),
          SizedBox(width: 12),
          Text('Pas de Connexion Internet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Text(
        'Vous êtes actuellement hors ligne. La création, modification et suppression de données sont bloquées en mode hors ligne.\n\nVeuillez vérifier votre connexion internet et réessayer.',
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}
