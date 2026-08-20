import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/transactions/transactions_bloc.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TransactionsBloc>().add(LoadTransactions());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              SizedBox(
                width: 250,
                height: 32,
                child: AppSearchBar(onChanged: (v) {}),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouvelle transaction', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: BlocBuilder<TransactionsBloc, TransactionsState>(
            builder: (context, state) {
              if (state is TransactionsLoading || state is TransactionsInitial) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ShimmerTable(
                    headerColumns: [
                      Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Compte', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Methode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                    ],
                  ),
                );
              }
              if (state is TransactionsLoaded) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<TransactionModel>(
                      columns: const ['Date', 'Compte', 'Type', 'Montant', 'Methode', 'Reference', 'Notes'],
                      rows: state.transactions,
                      emptyMessage: 'Aucune transaction',
                      cellBuilder: (t) => [
                        DataCell(Text(formatDate(t.date), style: const TextStyle(fontSize: 12.5))),
                        DataCell(Text(t.accountId, style: const TextStyle(fontSize: 12.5))), // Should map to name ideally
                        DataCell(StatusBadge(label: t.type == TransactionType.income ? 'Revenu' : 'Depense', color: t.type == TransactionType.income ? AppColors.success : AppColors.error)),
                        DataCell(Text(formatCurrency(t.amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: t.type == TransactionType.income ? AppColors.success : AppColors.error))),
                        DataCell(Text(t.category ?? '—', style: const TextStyle(fontSize: 12.5))),
                        DataCell(Text(t.reference ?? '—', style: const TextStyle(fontSize: 12.5))),
                        DataCell(Text(t.description ?? '—', style: const TextStyle(fontSize: 12.5))),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }
}
