import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../models/payment_model.dart';
import '../../models/supplier.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../database/database_helper.dart';
import '../../blocs/payments/payments_bloc.dart';
import '../../widgets/premium_detail_shell.dart';
import 'forms/mobile_payment_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobilePaymentDetailScreen extends StatefulWidget {
  final Payment payment;

  const MobilePaymentDetailScreen({super.key, required this.payment});

  @override
  State<MobilePaymentDetailScreen> createState() => _MobilePaymentDetailScreenState();
}

class _MobilePaymentDetailScreenState extends State<MobilePaymentDetailScreen> {
  late Payment currentPayment;
  String? _contactName;

  @override
  void initState() {
    super.initState();
    currentPayment = widget.payment;
    _loadContactName();
  }

  Future<void> _loadContactName() async {
    final rawName = currentPayment.contactName;
    if (rawName != null && rawName.isNotEmpty && rawName != currentPayment.contactId) {
      if (mounted) setState(() => _contactName = rawName);
      return;
    }

    final cid = currentPayment.contactId;
    if (cid.isEmpty) return;

    try {
      if (currentPayment.contactType == 'customer' || currentPayment.direction == 'encaissement') {
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
  }

  void _handleAction(String val) {
    if (val == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MobilePaymentFormScreen(existing: currentPayment)),
      ).then((_) {
        context.read<PaymentsBloc>().add(LoadPayments());
      });
    } else if (val == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Voulez-vous vraiment supprimer ce paiement ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                context.read<PaymentsBloc>().add(DeletePayment(currentPayment.id));
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  PopupMenuItem<String> _buildMenuItem(String val, IconData icon, Color color, String text) {
    return PopupMenuItem<String>(
      value: val,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = translateStatus(currentPayment.status);
    final statusColor = _getStatusColor(currentPayment.status);
    final isEncaissement = currentPayment.direction == 'encaissement';

    final infoSections = [
      PremiumInfoSection(
        title: 'Détails du Paiement',
        icon: Icons.receipt_outlined,
        fields: [
          PremiumInfoField(
            label: isEncaissement ? 'Client' : 'Fournisseur',
            value: _contactName ?? currentPayment.contactName ?? currentPayment.contactId,
            icon: Icons.person_outline,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date',
            value: formatDateTimeLong(currentPayment.paymentDate),
            icon: Icons.calendar_today_outlined,
          ),
          PremiumInfoField(
            label: 'Mode de règlement',
            value: _translatePaymentMethod(currentPayment.method),
            icon: Icons.payment_outlined,
          ),
          if (currentPayment.reference != null && currentPayment.reference!.isNotEmpty)
            PremiumInfoField(
              label: 'Référence / Chèque',
              value: currentPayment.reference!,
              icon: Icons.tag_outlined,
            ),
        ],
      ),
    ];

    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: isEncaissement ? 'Montant Encaissé' : 'Montant Décaissé',
        amount: currentPayment.amount,
        isGrandTotal: true,
      ),
    ];

    return BlocListener<PaymentsBloc, PaymentsState>(
      listener: (context, state) {
        if (state is PaymentsLoaded) {
          try {
             final updated = state.payments.firstWhere((p) => p.id == currentPayment.id);
             if (mounted) {
               setState(() {
                 currentPayment = updated;
               });
             }
          } catch (_) {
             if (mounted) Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(currentPayment.paymentNumber, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: _handleAction,
              itemBuilder: (_) => [
                if (PermissionService.instance.canUpdate(UserPermissionResources.payments))
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                if (PermissionService.instance.canUpdate(UserPermissionResources.payments) &&
                    PermissionService.instance.canDelete(UserPermissionResources.payments))
                  const PopupMenuDivider(height: 1),
                if (PermissionService.instance.canDelete(UserPermissionResources.payments))
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
              ],
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: isEncaissement ? 'Paiement (Encaissement)' : 'Paiement (Décaissement)',
          referenceNumber: currentPayment.paymentNumber,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          totals: totals,
          notes: currentPayment.notes,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    final isEncaissement = currentPayment.direction == 'encaissement';
    final amountColor = isEncaissement ? AppColors.success : AppColors.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              fontSize: isHighlight ? 15 : 14,
              color: isHighlight ? amountColor : AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return AppColors.success;
      case 'pending': return AppColors.warning;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  String _translatePaymentMethod(String method) {
    switch (method) {
      case 'especes': return 'Espèces';
      case 'cheque': return 'Chèque';
      case 'virement': return 'Virement';
      case 'carte': return 'Carte Bancaire';
      case 'retenue_source': return 'Retenue à la source';
      case 'traite': return 'Traite';
      default: return method;
    }
  }
}
