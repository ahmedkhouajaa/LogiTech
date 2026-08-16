import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../models/payment_model.dart';
import '../../models/supplier.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../database/database_helper.dart';
import '../../blocs/payments/payments_bloc.dart';
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
          title: Text('Confirmer la suppression'),
          content: Text('Voulez-vous vraiment supprimer ce paiement ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                context.read<PaymentsBloc>().add(DeletePayment(currentPayment.id));
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text('Supprimer', style: TextStyle(color: Colors.red)),
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
          SizedBox(width: 8),
          Text(text, style: TextStyle(color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text('Détails du paiement', style: TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
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
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                color: AppColors.surface,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentPayment.paymentNumber,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentPayment.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getStatusColor(currentPayment.status).withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              translateStatus(currentPayment.status),
                              style: TextStyle(
                                color: _getStatusColor(currentPayment.status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildDetailRow('Date et heure', DateFormat('dd MMM yyyy - HH:mm').format(currentPayment.paymentDate)),
                      Divider(height: 24),
                      _buildDetailRow('Contact', _contactName ?? currentPayment.contactName ?? currentPayment.contactId),
                      SizedBox(height: 12),
                      _buildDetailRow('Montant', formatCurrency(currentPayment.amount), isHighlight: true),
                      SizedBox(height: 12),
                      _buildDetailRow('Méthode', _translatePaymentMethod(currentPayment.method)),
                      SizedBox(height: 12),
                      _buildDetailRow('Direction', currentPayment.direction == 'encaissement' ? 'Encaissement' : 'Décaissement'),
                      if (currentPayment.accountName != null) ...[
                         SizedBox(height: 12),
                         _buildDetailRow('Compte', currentPayment.accountName!),
                      ],
                      if (currentPayment.reference != null && currentPayment.reference!.isNotEmpty) ...[
                         SizedBox(height: 12),
                         _buildDetailRow('Référence (Chèque/Traite)', currentPayment.reference!),
                      ],
                    ],
                  ),
                ),
              ),
              if (currentPayment.notes != null && currentPayment.notes!.isNotEmpty) ...[
                 SizedBox(height: 16),
                 Card(
                   elevation: 0,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                   color: AppColors.surface,
                   child: Padding(
                     padding: EdgeInsets.all(16.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                         SizedBox(height: 8),
                         Text(currentPayment.notes!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                       ],
                     ),
                   ),
                 ),
              ]
            ],
          ),
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
