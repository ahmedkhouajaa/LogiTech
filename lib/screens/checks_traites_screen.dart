import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/transactions/transactions_bloc.dart';
import '../models/check_traite.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

class ChecksTraitesScreen extends StatefulWidget {
  const ChecksTraitesScreen({super.key});

  @override
  State<ChecksTraitesScreen> createState() => _ChecksTraitesScreenState();
}

class _ChecksTraitesScreenState extends State<ChecksTraitesScreen> {
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
              AppButton(label: 'Nouveau', icon: Icons.add_rounded, onPressed: () {}),
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
                    child: DataTableWidget<CheckTraite>(
                      columns: const ['N°', 'Type', 'Banque', 'Tiers', 'Montant', 'Échéance', 'Statut'],
                      rows: state.checksTraites,
                      emptyMessage: 'Aucun chèque ou traite',
                      cellBuilder: (c) => [
                        DataCell(Text(c.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(c.type.label)),
                        DataCell(Text(c.bankName ?? '—')),
                        DataCell(Text(c.partyName)),
                        DataCell(Text(formatCurrency(c.amount), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(formatDate(c.maturityDate), style: TextStyle(color: c.daysUntilMaturity < 0 ? AppColors.error : AppColors.textPrimary))),
                        DataCell(StatusBadge(label: c.status.label, color: AppColors.primary)), // Needs mapping
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
