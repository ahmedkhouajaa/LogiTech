import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../models/treasury_transaction.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import 'forms/mobile_transaction_form_screen.dart';

class MobileTreasuryTransactionDetailScreen extends StatefulWidget {
  final TreasuryTransaction transaction;

  const MobileTreasuryTransactionDetailScreen({super.key, required this.transaction});

  @override
  State<MobileTreasuryTransactionDetailScreen> createState() => _MobileTreasuryTransactionDetailScreenState();
}

class _MobileTreasuryTransactionDetailScreenState extends State<MobileTreasuryTransactionDetailScreen> {
  late TreasuryTransaction currentTransaction;

  @override
  void initState() {
    super.initState();
    currentTransaction = widget.transaction;
  }

  void _handleAction(String val) {
    if (val == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MobileTransactionFormScreen(existing: currentTransaction)),
      ).then((_) {
        context.read<TreasuryTransactionsBloc>().add(LoadTreasuryTransactions());
      });
    } else if (val == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Voulez-vous vraiment supprimer cette transaction ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                context.read<TreasuryTransactionsBloc>().add(DeleteTreasuryTransaction(currentTransaction.id));
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
    return BlocListener<TreasuryTransactionsBloc, TreasuryTransactionsState>(
      listener: (context, state) {
        if (state is TreasuryTransactionsLoaded) {
          try {
             final updated = state.transactions.firstWhere((t) => t.id == currentTransaction.id);
             if (mounted) {
               setState(() {
                 currentTransaction = updated;
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
          title: const Text('Détails de la transaction', style: TextStyle(color: Colors.white, fontSize: 18)),
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
                            currentTransaction.transactionNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentTransaction.type == 'income' ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              currentTransaction.type == 'income' ? 'Entrée' : 'Sortie',
                              style: TextStyle(
                                color: currentTransaction.type == 'income' ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('Date et heure', DateFormat('dd MMM yyyy - HH:mm').format(currentTransaction.dateTransaction)),
                      const Divider(height: 24),
                      _buildDetailRow('Compte', currentTransaction.accountName ?? currentTransaction.accountId),
                      const SizedBox(height: 12),
                      _buildDetailRow('Montant', formatCurrency(currentTransaction.amount)),
                      if (currentTransaction.category != null) ...[
                         const SizedBox(height: 12),
                         _buildDetailRow('Catégorie', currentTransaction.category!),
                      ],
                      if (currentTransaction.projectName != null) ...[
                         const SizedBox(height: 12),
                         _buildDetailRow('Projet', currentTransaction.projectName!),
                      ],
                      if (currentTransaction.withholdingTax > 0) ...[
                         const SizedBox(height: 12),
                         _buildDetailRow('Retenue à la source', '${formatCurrency(currentTransaction.withholdingTax)} (${currentTransaction.withholdingTaxRate}%)'),
                      ],
                    ],
                  ),
                ),
              ),
              if (currentTransaction.description != null && currentTransaction.description!.isNotEmpty) ...[
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
                         const Text('Motif / Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary)),
                         const SizedBox(height: 8),
                         Text(currentTransaction.description!, style: const TextStyle(fontSize: 16)),
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
}
