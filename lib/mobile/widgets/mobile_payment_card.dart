import 'package:flutter/material.dart';
import '../../models/payment_model.dart';
import '../../models/supplier.dart';
import '../../utils/constants.dart';
import '../../database/database_helper.dart';

class MobilePaymentCard extends StatefulWidget {
  final Payment payment;
  final VoidCallback onTap;

  const MobilePaymentCard({
    super.key,
    required this.payment,
    required this.onTap,
  });

  @override
  State<MobilePaymentCard> createState() => _MobilePaymentCardState();
}

class _MobilePaymentCardState extends State<MobilePaymentCard> {
  String? _contactName;

  @override
  void initState() {
    super.initState();
    _loadContactName();
  }

  @override
  void didUpdateWidget(covariant MobilePaymentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payment.id != widget.payment.id ||
        oldWidget.payment.contactId != widget.payment.contactId ||
        oldWidget.payment.contactName != widget.payment.contactName) {
      _loadContactName();
    }
  }

  Future<void> _loadContactName() async {
    final rawName = widget.payment.contactName;
    if (rawName != null && rawName.isNotEmpty && rawName != widget.payment.contactId) {
      if (mounted) setState(() => _contactName = rawName);
      return;
    }

    final cid = widget.payment.contactId;
    if (cid.isEmpty) {
      if (mounted) setState(() => _contactName = 'Contact non spécifié');
      return;
    }

    try {
      if (widget.payment.contactType == 'customer' || widget.payment.direction == 'encaissement') {
        final cust = await DatabaseHelper.instance.getCustomer(cid);
        if (cust != null && mounted) {
          final resolved = (cust.companyName != null && cust.companyName!.isNotEmpty) ? cust.companyName! : cust.name;
          setState(() => _contactName = resolved);
          return;
        }
      }
      final suppliers = await DatabaseHelper.instance.getSuppliers();
      final supp = suppliers.firstWhere((s) => s.id == cid, orElse: () => Supplier(id: '', code: '', name: '', country: ''));
      if (supp.id.isNotEmpty && mounted) {
        final resolved = (supp.companyName != null && supp.companyName!.isNotEmpty) ? supp.companyName! : supp.name;
        setState(() => _contactName = resolved);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _contactName = widget.payment.contactName ?? widget.payment.contactId);
    }
  }

  String _getMethodLabel(String m) {
    switch (m.toLowerCase()) {
      case 'especes':
        return 'Espèces';
      case 'cheque':
        return 'Chèque';
      case 'virement':
        return 'Virement';
      case 'carte':
        return 'Carte';
      case 'retenue_source':
        return 'Retenue Source';
      default:
        return m;
    }
  }

  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return Colors.blue;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusBg(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return AppColors.success.withValues(alpha: 0.12);
      case 'pending':
        return AppColors.warning.withValues(alpha: 0.12);
      case 'confirmed':
        return Colors.blue.withValues(alpha: 0.12);
      case 'cancelled':
      case 'rejected':
        return AppColors.error.withValues(alpha: 0.12);
      default:
        return AppColors.surfaceAlt;
    }
  }

  String _getStatusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return 'Payé';
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmé';
      case 'cancelled':
      case 'rejected':
        return 'Rejeté';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final isEncaissement = payment.direction == 'encaissement';
    final amountColor = isEncaissement ? AppColors.success : AppColors.error;
    final amountPrefix = isEncaissement ? '+' : '-';
    final statusColor = _getStatusColor(payment.status);
    final statusBg = _getStatusBg(payment.status);
    final statusLabel = _getStatusLabel(payment.status);

    final dateStr = '${payment.paymentDate.day.toString().padLeft(2, '0')}/${payment.paymentDate.month.toString().padLeft(2, '0')}/${payment.paymentDate.year} ${payment.paymentDate.hour.toString().padLeft(2, '0')}:${payment.paymentDate.minute.toString().padLeft(2, '0')}';
    final displayName = _contactName ?? payment.contactName ?? payment.contactId;

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
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Reference (bold) + Status badge + Chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        payment.paymentNumber,
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
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
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

                // Details: Date, Client, Method
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.payment_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _getMethodLabel(payment.method),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Bottom row: Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$amountPrefix ${payment.amount.toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
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
}
