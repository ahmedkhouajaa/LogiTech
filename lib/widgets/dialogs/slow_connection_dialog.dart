import 'package:flutter/material.dart';

class SlowConnectionDialog extends StatelessWidget {
  final VoidCallback onContinueAnyway;
  final VoidCallback onCancel;

  const SlowConnectionDialog({
    super.key,
    required this.onContinueAnyway,
    required this.onCancel,
  });

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SlowConnectionDialog(
        onContinueAnyway: () => Navigator.of(ctx).pop(true),
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
          Icon(Icons.network_check_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text('Connexion Lente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Text(
        'Votre connexion internet semble instable ou très lente. L\'opération peut prendre plus de temps que prévu.\n\nVoulez-vous quand même continuer ?',
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onContinueAnyway,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Continuer quand même'),
        ),
      ],
    );
  }
}
