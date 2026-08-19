import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../models/treasury_transaction.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../../widgets/premium_detail_shell.dart';
import 'forms/mobile_transaction_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

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
          Text(text, style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = currentTransaction.type == 'income';
    final statusLabel = isIncome ? 'Entrée' : 'Sortie';
    final statusColor = isIncome ? AppColors.success : AppColors.error;

    final accountState = context.watch<TreasuryAccountsBloc>().state;
    String accountDisplayName = currentTransaction.accountName ?? currentTransaction.accountId;
    if (accountState is TreasuryAccountsLoaded) {
      final acc = accountState.accounts.cast<dynamic>().firstWhere(
        (a) => a?.id == currentTransaction.accountId, 
        orElse: () => null,
      );
      if (acc != null) accountDisplayName = acc.name;
    }

    final infoSections = [
      PremiumInfoSection(
        title: 'Détails de la Transaction',
        icon: Icons.account_balance_wallet_outlined,
        fields: [
          PremiumInfoField(
            label: 'Compte de trésorerie',
            value: accountDisplayName,
            icon: Icons.account_balance_outlined,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date & Heure',
            value: DateFormat('dd MMM yyyy - HH:mm').format(currentTransaction.dateTransaction),
            icon: Icons.calendar_today_outlined,
          ),
          if (currentTransaction.category != null && currentTransaction.category!.isNotEmpty)
            PremiumInfoField(
              label: 'Catégorie',
              value: currentTransaction.category!,
              icon: Icons.category_outlined,
            ),
          if (currentTransaction.projectName != null && currentTransaction.projectName!.isNotEmpty)
            PremiumInfoField(
              label: 'Projet',
              value: currentTransaction.projectName!,
              icon: Icons.work_outline,
            ),
          if (currentTransaction.withholdingTax > 0)
            PremiumInfoField(
              label: 'Retenue à la source',
              value: formatCurrencyDT(currentTransaction.withholdingTax),
              icon: Icons.percent_outlined,
            ),
        ],
      ),
    ];

    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: isIncome ? 'Montant Entré' : 'Montant Sorti',
        amount: currentTransaction.amount,
        isGrandTotal: true,
      ),
    ];

    return BlocListener<TreasuryTransactionsBloc, TreasuryTransactionsState>(
      listener: (context, state) {
        if (state is TreasuryTransactionsLoaded) {
          try {
             final updated = state.transactions.firstWhere((p) => p.id == currentTransaction.id);
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
          title: Text(currentTransaction.transactionNumber, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: _handleAction,
              itemBuilder: (_) => [
                if (PermissionService.instance.canUpdate(UserPermissionResources.treasuryTransactions))
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                if (PermissionService.instance.canUpdate(UserPermissionResources.treasuryTransactions) &&
                    PermissionService.instance.canDelete(UserPermissionResources.treasuryTransactions))
                  const PopupMenuDivider(height: 1),
                if (PermissionService.instance.canDelete(UserPermissionResources.treasuryTransactions))
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
              ],
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: isIncome ? 'Mouvement Trésorerie (Entrée)' : 'Mouvement Trésorerie (Sortie)',
          referenceNumber: currentTransaction.transactionNumber,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          totals: totals,
          notes: currentTransaction.description,
        ),
      ),
    );
  }
}
