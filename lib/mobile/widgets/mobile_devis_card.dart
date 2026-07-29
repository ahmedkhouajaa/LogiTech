import 'package:flutter/material.dart';
import '../../models/quote.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class MobileDevisCard extends StatelessWidget {
  final Quote quote;
  final VoidCallback onTap;

  const MobileDevisCard({
    super.key,
    required this.quote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(quote.status);
    final statusText = quote.status.label;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Ref Badge + Status Chip + Chevron
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        quote.number,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 1: Long Date & Time
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      formatDate(quote.date),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 2: Client Name on left + Total Amount on right (NO $ SIGN)
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        quote.customerName != null && quote.customerName!.isNotEmpty
                            ? quote.customerName!
                            : 'Client Inconnu',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${quote.totalTTC.toStringAsFixed(2)} TND',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.accepted:
      case DocumentStatus.converted:
        return AppColors.success;
      case DocumentStatus.rejected:
      case DocumentStatus.cancelled:
        return AppColors.error;
      case DocumentStatus.sent:
        return AppColors.primary;
      case DocumentStatus.draft:
      case DocumentStatus.created:
        return AppColors.textSecondary;
    }
  }
}
