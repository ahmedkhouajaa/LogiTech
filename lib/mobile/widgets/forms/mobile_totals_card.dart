import 'package:flutter/material.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../../l10n/app_localizations.dart';

class MobileTotalsCard extends StatelessWidget {
  final double subTotalHT;
  final Map<double, double> tvaBreakdown;
  final double totalTva;
  final double timbreFiscal;
  final bool applyTimbreFiscal;
  final ValueChanged<bool?> onTimbreFiscalChanged;
  final double totalTTC;

  final bool withFodec;
  final double fodecAmount;
  final Map<String, double>? customTaxesBreakdown;
  final VoidCallback? onSettingsTap;

  const MobileTotalsCard({
    super.key,
    required this.subTotalHT,
    required this.tvaBreakdown,
    required this.totalTva,
    required this.timbreFiscal,
    required this.applyTimbreFiscal,
    required this.onTimbreFiscalChanged,
    required this.totalTTC,
    this.withFodec = false,
    this.fodecAmount = 0.0,
    this.customTaxesBreakdown,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBlueBorder, width: 1.5),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onSettingsTap != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('Récapitulatif des taxes & totaux'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                InkWell(
                  onTap: onSettingsTap,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('Paramètres'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildRow(context, 'Sous-total HT', formatCurrencyDT(subTotalHT)),
          if (tvaBreakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...tvaBreakdown.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRow(context, '${context.tr('TVA')} ${e.key.toInt()}%', formatCurrencyDT(e.value)),
            )),
          ] else ...[
            const SizedBox(height: 12),
            _buildRow(context, '${context.tr('TVA')} 0%', '0,000 TND'),
          ],
          if (withFodec) ...[
            const SizedBox(height: 12),
            _buildRow(context, 'FODEC (1%)', formatCurrencyDT(fodecAmount)),
          ],
          if (customTaxesBreakdown != null && customTaxesBreakdown!.isNotEmpty) ...[
            for (final entry in customTaxesBreakdown!.entries) ...[
              const SizedBox(height: 12),
              _buildRow(context, entry.key, formatCurrencyDT(entry.value)),
            ],
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          
          InkWell(
            onTap: () => onTimbreFiscalChanged(!applyTimbreFiscal),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: applyTimbreFiscal,
                      onChanged: onTimbreFiscalChanged,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.tr('Timbre fiscal'), style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                  Text(
                    formatCurrencyDT(applyTimbreFiscal ? timbreFiscal : 0),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('Total TTC'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: totalTTC),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Text(
                      formatCurrencyDT(value),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(context.tr(label), style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
    );
  }
}
