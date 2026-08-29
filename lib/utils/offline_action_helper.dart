import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import 'constants.dart';

/// Centralized helper for offline-aware action handling across all modules.
///
/// Provides:
/// - A standardized confirmation dialog ("Confirmer l'action")
/// - Connectivity check on confirm only
/// - Offline error dialog when user is offline
class OfflineActionHelper {
  OfflineActionHelper._();

  /// The set of action keys considered as "write" operations across Ventes, Achats, and Stock.
  /// These require an internet connection to execute.
  static const Set<String> writeActions = {
    'edit',
    'create',
    'add',
    'delete',
    'status',
    'duplicate',
    'validate',
    'cancel',
    'to_invoice',
    'to_order',
    'to_delivery',
    'to_receiving',
    'to_purchase_invoice',
    'to_supplier_order',
    'to_return',
    'to_credit_note',
    'to_exit_voucher',
    'to_withdrawal',
    'add_payment',
    'payment',
    'to_receipt',
    'convert_invoice',
    'convert_return',
  };

  /// Returns a human-readable French label for the given action key.
  static String _actionLabel(String action) {
    switch (action) {
      case 'edit':
        return 'modifier';
      case 'create':
      case 'add':
        return 'créer';
      case 'delete':
        return 'supprimer';
      case 'status':
        return 'changer le statut de';
      case 'duplicate':
        return 'dupliquer';
      case 'validate':
        return 'valider';
      case 'cancel':
        return 'annuler';
      case 'add_payment':
      case 'payment':
        return 'ajouter un paiement à';
      case 'to_invoice':
        return 'transformer en facture';
      case 'to_order':
        return 'transformer en commande client';
      case 'to_delivery':
        return 'transformer en bon de livraison';
      case 'to_receipt':
      case 'to_receiving':
        return 'transformer en bon de réception';
      case 'convert_invoice':
      case 'to_purchase_invoice':
        return 'transformer en facture d\'achat';
      case 'to_supplier_order':
        return 'transformer en commande fournisseur';
      case 'convert_return':
      case 'to_return':
        return 'transformer en bon de retour';
      case 'to_credit_note':
        return 'transformer en avoir';
      case 'to_exit_voucher':
        return 'transformer en bon de sortie';
      case 'to_withdrawal':
        return 'transformer en bon de prélèvement';
      default:
        return 'effectuer cette action sur';
    }
  }

  /// Actions that skip the confirmation dialog — either because they create
  /// new documents (allowing offline creation) or because the destination
  /// screen already has its own built-in confirmation/save logic.
  static const Set<String> _noConfirmActions = {
    'create',
    'add',
    'edit',        // Edit screen has its own save/cancel confirmation
    'add_payment', // Payment screen has its own confirm/cancel logic
    'payment',     // Payment screen has its own confirm/cancel logic
  };

  /// Executes [onConfirmed] directly if the action is a read-only action
  /// or a create/add action, or shows a confirmation dialog with offline
  /// check if it's any other write action.
  ///
  /// - For read actions: [onConfirmed] runs immediately (no dialog).
  /// - For create/add actions: [onConfirmed] runs immediately (no dialog,
  ///   no internet check) to allow offline document creation.
  /// - For other write actions (edit, delete, payment, etc.): shows a
  ///   confirmation dialog. On confirm, checks connectivity and either
  ///   runs [onConfirmed] or shows an error.
  static void executeAction({
    required BuildContext context,
    required String action,
    required VoidCallback onConfirmed,
    String? customActionLabel,
  }) {
    if (!writeActions.contains(action)) {
      // Read action — execute directly, works offline
      onConfirmed();
      return;
    }

    if (_noConfirmActions.contains(action)) {
      // Create/Add action — execute directly without confirmation or
      // internet check to allow offline document creation.
      onConfirmed();
      return;
    }

    // Other write action — show confirmation dialog
    _showConfirmationDialog(
      context: context,
      action: action,
      customActionLabel: customActionLabel,
      onConfirmed: onConfirmed,
    );
  }

  /// Shows the standardized confirmation dialog for write actions.
  static void _showConfirmationDialog({
    required BuildContext context,
    required String action,
    String? customActionLabel,
    required VoidCallback onConfirmed,
  }) {
    final label = customActionLabel ?? _actionLabel(action);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Text(
              'Confirmer l\'action',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir $label ce document ?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Annuler',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Check connectivity only at confirm time
              final isOnline = await ConnectivityService.instance.checkConnectivity();
              if (!dialogCtx.mounted) return;

              if (isOnline) {
                Navigator.pop(dialogCtx);
                onConfirmed();
              } else {
                Navigator.pop(dialogCtx);
                _showOfflineErrorDialog(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Confirmer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Checks online status before saving/submitting in forms or dialogs.
  /// If online, returns true.
  /// If offline, displays the offline error dialog and returns false.
  static Future<bool> checkOnlineOrShowError(BuildContext context) async {
    final isOnline = await ConnectivityService.instance.checkConnectivity();
    if (!isOnline && context.mounted) {
      _showOfflineErrorDialog(context);
      return false;
    }
    return isOnline;
  }

  /// Shows the offline error dialog.
  static void showOfflineError(BuildContext context) {
    _showOfflineErrorDialog(context);
  }

  /// Internal helper to show the offline error dialog.
  static void _showOfflineErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Action indisponible hors ligne',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cette action nécessite une connexion Internet.\nVeuillez vous connecter et réessayer.',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('Compris', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
