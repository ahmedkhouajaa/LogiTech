import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/transactions/transactions_bloc.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

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
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppSearchBar(onChanged: (v) {}),
              const Spacer(),
              AppButton(label: 'Nouvelle transaction', icon: Icons.add_rounded, onPressed: () {}),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<TransactionsBloc, TransactionsState>(
            builder: (context, state) {
              if (state is TransactionsLoading) return const Center(child: CircularProgressIndicator());
              if (state is TransactionsLoaded) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<TransactionModel>(
                      columns: const ['Date', 'Compte', 'Type', 'Montant', 'Methode', 'Reference', 'Notes'],
                      rows: state.transactions,
                      emptyMessage: 'Aucune transaction',
                      cellBuilder: (t) => [
                        DataCell(Text(formatDate(t.date))),
                        DataCell(Text(t.accountId)), // Should map to name ideally
                        DataCell(StatusBadge(label: t.type == TransactionType.income ? 'Revenu' : 'Depense', color: t.type == TransactionType.income ? AppColors.success : AppColors.error)),
                        DataCell(Text(formatCurrency(t.amount), style: TextStyle(fontWeight: FontWeight.bold, color: t.type == TransactionType.income ? AppColors.success : AppColors.error))),
                        DataCell(Text(t.category ?? '—')),
                        DataCell(Text(t.reference ?? '—')),
                        DataCell(Text(t.description ?? '—')),
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
