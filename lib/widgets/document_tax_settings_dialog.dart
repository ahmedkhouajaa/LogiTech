import 'package:flutter/material.dart';
import '../models/custom_tax_rate.dart';
import '../services/custom_tax_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';
import 'create_tax_rate_dialog.dart';

/// Modal dialog for document advanced settings ("Configuration Avancée du Document").
/// Matches the design from Image 2 & 4 with LogiTech Pro design tokens.
class DocumentTaxSettingsDialog extends StatefulWidget {
  final bool withFodec;
  final bool withTimbreFiscal;
  final ValueChanged<bool> onFodecChanged;
  final ValueChanged<bool> onTimbreFiscalChanged;
  final Map<String, bool> activeCustomTaxes;
  final ValueChanged<Map<String, bool>>? onCustomTaxesChanged;
  final String usage; // 'sale', 'purchase', or 'all'

  const DocumentTaxSettingsDialog({
    super.key,
    required this.withFodec,
    required this.withTimbreFiscal,
    required this.onFodecChanged,
    required this.onTimbreFiscalChanged,
    this.activeCustomTaxes = const {},
    this.onCustomTaxesChanged,
    this.usage = 'all',
  });

  static Future<void> show({
    required BuildContext context,
    required bool withFodec,
    required bool withTimbreFiscal,
    required ValueChanged<bool> onFodecChanged,
    required ValueChanged<bool> onTimbreFiscalChanged,
    Map<String, bool> activeCustomTaxes = const {},
    ValueChanged<Map<String, bool>>? onCustomTaxesChanged,
    String usage = 'all',
    String? documentType,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DocumentTaxSettingsDialog(
        withFodec: withFodec,
        withTimbreFiscal: withTimbreFiscal,
        onFodecChanged: onFodecChanged,
        onTimbreFiscalChanged: onTimbreFiscalChanged,
        activeCustomTaxes: activeCustomTaxes,
        onCustomTaxesChanged: onCustomTaxesChanged,
        usage: documentType ?? usage,
      ),
    );
  }

  @override
  State<DocumentTaxSettingsDialog> createState() => _DocumentTaxSettingsDialogState();
}

class _DocumentTaxSettingsDialogState extends State<DocumentTaxSettingsDialog> {
  late bool _withFodec;
  late bool _withTimbreFiscal;
  late Map<String, bool> _activeCustomTaxes;
  List<CustomTaxRate> _customTaxes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _withFodec = widget.withFodec;
    _withTimbreFiscal = widget.withTimbreFiscal;
    _activeCustomTaxes = Map<String, bool>.from(widget.activeCustomTaxes);
    _loadCustomTaxes();
  }

  Future<void> _loadCustomTaxes() async {
    final taxes = await CustomTaxService.instance.getTaxes(usage: widget.usage);
    if (mounted) {
      setState(() {
        _customTaxes = List.from(taxes);
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateTaxDialog() async {
    final newTax = await CreateTaxRateDialog.show(context, defaultUsage: widget.usage);
    if (newTax != null && mounted) {
      setState(() {
        _customTaxes.removeWhere((t) => t.id == newTax.id);
        _customTaxes.add(newTax);
        _activeCustomTaxes[newTax.id] = true;
      });
      widget.onCustomTaxesChanged?.call(Map.unmodifiable(_activeCustomTaxes));
    }
  }

  Future<void> _confirmDeleteTax(CustomTaxRate tax) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.cardBlueBorder, width: 1.5),
        ),
        title: Text(
          context.tr('Supprimer cette taxe ?'),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
        ),
        content: Text(
          '${context.tr('Voulez-vous vraiment supprimer la taxe')} « ${tax.name} » ?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(context.tr('Annuler'), style: TextStyle(color: AppColors.textPrimary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(context.tr('Supprimer')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await CustomTaxService.instance.deleteTax(tax.id);
      setState(() {
        _customTaxes.removeWhere((t) => t.id == tax.id);
        _activeCustomTaxes.remove(tax.id);
      });
      widget.onCustomTaxesChanged?.call(Map.unmodifiable(_activeCustomTaxes));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 560.0 : (screenWidth * 0.94);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.lg,
          border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Title + Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Configuration Avancée du Document'),
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 19 : 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                    splashRadius: 20,
                    tooltip: context.tr('Fermer'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),

            // Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card: Configuration des Taxes
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card Header: Title + Button "+ Ajouter une taxe personnalisée"
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr('Configuration des Taxes'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openCreateTaxDialog,
                                icon: Icon(Icons.add_rounded, size: 16, color: AppColors.textPrimary),
                                label: Text(
                                  context.tr('Ajouter une taxe personnalisée'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppColors.surface,
                                  side: BorderSide(color: AppColors.cardBlueBorder, width: 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Tax Item 1: FODEC 1%
                          _buildTaxRow(
                            title: 'FODEC 1%',
                            subtitle: context.tr('Fonds de développement et de compétitivité (1% du HT)'),
                            value: _withFodec,
                            onChanged: (val) {
                              setState(() => _withFodec = val);
                              widget.onFodecChanged(val);
                            },
                          ),
                          const SizedBox(height: 12),
                          Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),

                          // Tax Item 2: Timbre fiscal
                          _buildTaxRow(
                            title: context.tr('Timbre fiscal'),
                            subtitle: context.tr('Droit de timbre légal (1,000 TND)'),
                            value: _withTimbreFiscal,
                            onChanged: (val) {
                              setState(() => _withTimbreFiscal = val);
                              widget.onTimbreFiscalChanged(val);
                            },
                          ),

                          // Custom Tax Items (Image 4)
                          if (_isLoading) ...[
                            const SizedBox(height: 16),
                            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          ] else ...[
                            for (final tax in _customTaxes) ...[
                              const SizedBox(height: 12),
                              Divider(height: 1, color: AppColors.border),
                              const SizedBox(height: 12),
                              _buildCustomTaxRow(tax),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.cardBlueBorder,
              activeColor: Colors.white,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTaxRow(CustomTaxRate tax) {
    final isEnabled = _activeCustomTaxes[tax.id] ?? false;
    final subtitle = tax.isPercentage
        ? '${tax.value}% (${tax.appliedWhen == 'after_tva' ? context.tr('Après TVA') : context.tr('Avant TVA')})'
        : '${tax.value.toStringAsFixed(3)} TND (${context.tr('Fixe')})';

    return InkWell(
      onTap: () {
        final newVal = !isEnabled;
        setState(() => _activeCustomTaxes[tax.id] = newVal);
        widget.onCustomTaxesChanged?.call(Map.unmodifiable(_activeCustomTaxes));
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tax.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Delete button
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error.withValues(alpha: 0.8)),
              tooltip: context.tr('Supprimer cette taxe'),
              splashRadius: 18,
              onPressed: () => _confirmDeleteTax(tax),
            ),
            const SizedBox(width: 4),
            Switch.adaptive(
              value: isEnabled,
              activeTrackColor: AppColors.cardBlueBorder,
              activeColor: Colors.white,
              onChanged: (val) {
                setState(() => _activeCustomTaxes[tax.id] = val);
                widget.onCustomTaxesChanged?.call(Map.unmodifiable(_activeCustomTaxes));
              },
            ),
          ],
        ),
      ),
    );
  }
}
