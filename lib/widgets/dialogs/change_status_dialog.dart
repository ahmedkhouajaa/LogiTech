import 'package:flutter/material.dart';
import '../../models/custom_status_definition.dart';
import '../../services/custom_status_service.dart';
import '../../utils/constants.dart';
import '../dashboard_card.dart';

/// Opens the standard "Changer le statut" dialog for any document type in Ventes and Achats.
/// Displays all available statuses (default + custom) and lets the user select one,
/// add optional notes, and save.
Future<void> showDocumentChangeStatusDialog({
  required BuildContext context,
  required String documentType,
  required String currentStatus,
  required Future<void> Function(String newStatusKey, String? notes) onSave,
}) async {
  final allStatuses = await CustomStatusService.instance.getAllStatuses(documentType);
  if (!context.mounted) return;

  // Resolve currently selected status
  CustomStatusDefinition selectedStatus;
  final match = allStatuses.where(
    (s) =>
        s.key.toLowerCase() == currentStatus.toLowerCase() ||
        s.name.toLowerCase() == currentStatus.toLowerCase() ||
        s.id == currentStatus,
  ).firstOrNull;

  if (match != null) {
    selectedStatus = match;
  } else if (allStatuses.isNotEmpty) {
    selectedStatus = allStatuses.first;
  } else {
    selectedStatus = CustomStatusDefinition(
      id: 'default_draft',
      enterpriseId: '',
      documentType: documentType,
      name: 'Brouillon',
      key: 'draft',
      colorValue: AppColors.warning.toARGB32(),
      isDefault: true,
    );
  }

  final notesController = TextEditingController();
  bool isSaving = false;

  await showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text(
            'Changer le statut',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nouveau statut:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CustomStatusDefinition>(
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  initialValue: selectedStatus,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  items: allStatuses.map((s) {
                    return DropdownMenuItem<CustomStatusDefinition>(
                      value: s,
                      child: Row(
                        children: [
                          StatusBadge(label: s.name, color: s.color),
                          if (!s.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Personnalisé',
                                style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedStatus = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Notes (optionnel):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    hintText: 'Ajouter une note...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        final notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
                        await onSave(selectedStatus.key, notes);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (dialogCtx.mounted) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}
