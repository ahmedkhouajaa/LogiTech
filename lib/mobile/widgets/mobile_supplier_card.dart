import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../utils/constants.dart';

class MobileSupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;

  const MobileSupplierCard({
    super.key,
    required this.supplier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEntreprise = supplier.supplierType.toLowerCase() == 'entreprise';

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
                // Top Row: Supplier name (left, truncating with ellipsis if long) + Fixed Right Status Badge + Chevron
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        supplier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isEntreprise ? Colors.blue.withValues(alpha: 0.12) : Colors.purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isEntreprise ? Colors.blue.withValues(alpha: 0.25) : Colors.purple.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            isEntreprise ? 'Entreprise' : 'Particulier',
                            style: TextStyle(
                              color: isEntreprise ? Colors.blue[800] : Colors.purple[800],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Details: Code + Par défaut badge + Email + Phone
                Row(
                  children: [
                    Icon(Icons.tag, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '# ${supplier.code}',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (supplier.isDefault || supplier.name.trim().toLowerCase() == 'fournisseur passager') ...[
                      const SizedBox(width: 8),
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
                              'Par défaut',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (supplier.email != null && supplier.email!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          supplier.email!,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (supplier.phone != null && supplier.phone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('📞', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        supplier.phone!,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
  }
}
