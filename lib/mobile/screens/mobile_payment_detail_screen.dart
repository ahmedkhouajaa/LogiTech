import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../models/payment_model.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../blocs/payments/payments_bloc.dart';
import 'forms/mobile_payment_form_screen.dart';

class MobilePaymentDetailScreen extends StatefulWidget {
  final Payment payment;

  const MobilePaymentDetailScreen({super.key, required this.payment});

  @override
  State<MobilePaymentDetailScreen> createState() => _MobilePaymentDetailScreenState();
}

class _MobilePaymentDetailScreenState extends State<MobilePaymentDetailScreen> {
  late Payment currentPayment;

  @override
  void initState() {
    super.initState();
    currentPayment = widget.payment;
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
          title: const Text('Détails du paiement', style: TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: _handleAction,
              itemBuilder: (_) => [
                _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentPayment.paymentNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentPayment.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
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
                      const SizedBox(height: 16),
                      _buildDetailRow('Date et heure', DateFormat('dd MMM yyyy - HH:mm').format(currentPayment.paymentDate)),
                      const Divider(height: 24),
                      _buildDetailRow('Contact', currentPayment.contactName ?? currentPayment.contactId),
                      const SizedBox(height: 12),
                      _buildDetailRow('Montant', formatCurrency(currentPayment.amount)),
                      const SizedBox(height: 12),
                      _buildDetailRow('Méthode', _translatePaymentMethod(currentPayment.method)),
                      const SizedBox(height: 12),
                      _buildDetailRow('Direction', currentPayment.direction == 'encaissement' ? 'Encaissement' : 'Décaissement'),
                      if (currentPayment.accountName != null) ...[
                         const SizedBox(height: 12),
                         _buildDetailRow('Compte', currentPayment.accountName!),
                      ],
                      if (currentPayment.reference != null && currentPayment.reference!.isNotEmpty) ...[
                         const SizedBox(height: 12),
                         _buildDetailRow('Référence (Chèque/Traite)', currentPayment.reference!),
                      ],
                    ],
                  ),
                ),
              ),
              if (currentPayment.notes != null && currentPayment.notes!.isNotEmpty) ...[
                 const SizedBox(height: 16),
                 Card(
                   elevation: 0,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                   color: Colors.white,
                   child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary)),
                         const SizedBox(height: 8),
                         Text(currentPayment.notes!, style: const TextStyle(fontSize: 16)),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
