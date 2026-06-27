import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../utils/mobile_status_colors.dart';

class MobileGenericCard extends StatelessWidget {
  final String reference;
  final String status;
  final String? name;
  final IconData? nameIcon;
  final DateTime? date;
  final double amount;
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
    this.date,
    required this.amount,
    required this.onTap,
    this.onEdit,
    this.onPdf,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Reference and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    reference,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MobileStatusColors.getColorForStatus(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MobileStatusColors.getColorForStatus(status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: MobileStatusColors.getColorForStatus(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Name
              if (name != null)
                Row(
                  children: [
                    Icon(nameIcon ?? Icons.person, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (name != null) const SizedBox(height: 8),

              // Row 3: Date and Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (date != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      const Icon(Icons.attach_money, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${amount.toStringAsFixed(2)} TND',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: onEdit,
                ),
              if (onPdf != null)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  onPressed: onPdf,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
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
