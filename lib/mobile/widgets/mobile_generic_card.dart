import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../utils/mobile_status_colors.dart';

class MobileGenericCard extends StatelessWidget {
  final String reference;
  final String status;
  final String? name;
  final IconData? nameIcon;
  final String? subtitle;
  final IconData? subtitleIcon;
  final String? badgeText;
  final DateTime? date;
  final double? amount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onPdf;
  final VoidCallback? onDelete;

  const MobileGenericCard({
    super.key,
    required this.reference,
    required this.status,
    this.name,
    this.nameIcon,
    this.subtitle,
    this.subtitleIcon,
    this.badgeText,
    this.date,
    this.amount,
    required this.onTap,
    this.onEdit,
    this.onPdf,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = translateStatus(status);
    final statusColor = MobileStatusColors.getColorForStatus(statusLabel);

    Widget card = Container(
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
                // Top row: Ref Badge Chip + BadgeText (left) + Fixed Right Status Pill + Chevron
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                reference,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          if (badgeText != null && badgeText!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_rounded, size: 10, color: AppColors.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    badgeText!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusLabel,
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
                  ],
                ),
                const SizedBox(height: 10),

                // Row 1: Date
                if (date != null) ...[
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Row 2: Name / Client on left + Total Amount on right
                Row(
                  children: [
                    if (name != null && name!.isNotEmpty) ...[
                      Icon(nameIcon ?? Icons.person_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name!,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (amount != null)
                      Text(
                        '${amount!.toStringAsFixed(2)} TND',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                  ],
                ),

                // Subtitle Row (e.g. Address)
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(subtitleIcon ?? Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle!,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Add swipe actions if provided
    if (onEdit != null || onPdf != null || onDelete != null) {
      return Dismissible(
        key: Key(reference),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onEdit != null)
                IconButton(
                  icon: Icon(Icons.edit, color: AppColors.primary),
                  onPressed: onEdit,
                ),
              if (onPdf != null)
                IconButton(
                  icon: Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  onPressed: onPdf,
                ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
        // By setting confirmDismiss to false, we prevent the dismiss animation from fully removing the item
        // unless they actually delete it (handled via dialog)
        confirmDismiss: (direction) async {
          return false;
        },
        child: card,
      );
    }

    return card;
  }
}
