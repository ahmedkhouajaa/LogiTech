import 'package:flutter/material.dart';
import '../../models/treasury_account.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class MobileTreasuryAccountCard extends StatelessWidget {
  final TreasuryAccount account;
  final VoidCallback onTap;
  final Widget? popupMenu;

  const MobileTreasuryAccountCard({
    super.key,
    required this.account,
    required this.onTap,
    this.popupMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Name styled inside light blue badge chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              account.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: account.type == 'bank' ? Colors.blue.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: account.type == 'bank'
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : Colors.orange.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              account.type == 'bank' ? 'Compte Bancaire' : 'Caisse',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: account.type == 'bank' ? Colors.blue : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatCurrencyDT(account.balance),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: account.balance >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                if (popupMenu != null) ...[
                  const SizedBox(width: 8),
                  popupMenu!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
