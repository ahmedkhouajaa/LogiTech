import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

class StorageFullDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const StorageFullDialog({
    super.key,
    required this.onRetry,
    required this.onCancel,
  });

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StorageFullDialog(
        onRetry: () async {
          final hasStorage = await StorageService.instance.hasMinimumStorage();
          if (hasStorage) {
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
          Icon(Icons.sd_card_alert_rounded, color: Colors.deepOrange, size: 28),
          SizedBox(width: 12),
          Text('Espace de Stockage Insuffisant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Text(
        'Votre appareil dispose de moins de 100 Mo d\'espace disque libre. Les opérations d\'écriture sont désactivées pour prévenir la perte de données.\n\nVeuillez libérer de l\'espace disque et réessayer.',
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
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
