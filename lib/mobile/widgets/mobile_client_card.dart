import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../utils/constants.dart';

class MobileClientCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const MobileClientCard({
    super.key,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEntreprise = customer.customerType.toLowerCase() == 'entreprise';

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
                // Top Row: Client name (bold) + Type badge + Chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isEntreprise ? Colors.blue.withOpacity(0.12) : Colors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isEntreprise ? Colors.blue.withOpacity(0.25) : Colors.purple.withOpacity(0.25)),
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
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ],
                ),
                const SizedBox(height: 10),

                // Details: Code, Email, Phone
                Row(
                  children: [
                    Icon(Icons.tag, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '# ${customer.code}',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (customer.email != null && customer.email!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.email!,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (customer.phone != null && customer.phone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('📞', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        customer.phone!,
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
