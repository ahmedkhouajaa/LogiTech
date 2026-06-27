import 'package:flutter/material.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';

class MobileTotalsCard extends StatelessWidget {
  final double subTotalHT;
  final Map<double, double> tvaBreakdown;
  final double totalTva;
  final double timbreFiscal;
  final bool applyTimbreFiscal;
  final ValueChanged<bool?> onTimbreFiscalChanged;
  final double totalTTC;

  const MobileTotalsCard({
    super.key,
    required this.subTotalHT,
    required this.tvaBreakdown,
    required this.totalTva,
    required this.timbreFiscal,
    required this.applyTimbreFiscal,
    required this.onTimbreFiscalChanged,
    required this.totalTTC,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRow('Sous-total HT', formatCurrencyDT(subTotalHT)),
          if (tvaBreakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...tvaBreakdown.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRow('TVA ${e.key.toInt()}%', formatCurrencyDT(e.value)),
            )),
          ] else ...[
            const SizedBox(height: 12),
            _buildRow('TVA 0%', '0,000 TND'),
          ],
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
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
                  const Expanded(
                    child: Text('Timbre fiscal', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                  Text(
                    formatCurrencyDT(applyTimbreFiscal ? timbreFiscal : 0),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total TTC', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
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

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
    );
  }
}
