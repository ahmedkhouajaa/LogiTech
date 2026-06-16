import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../models/treasury_transaction.dart';
import '../models/treasury_account.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/data_table_widget.dart';

class TreasuryTransactionsScreen extends StatefulWidget {
  const TreasuryTransactionsScreen({super.key});

  @override
  State<TreasuryTransactionsScreen> createState() => _TreasuryTransactionsScreenState();
}

class _TreasuryTransactionsScreenState extends State<TreasuryTransactionsScreen> {
  String _selectedAccountId = 'all';
  String _selectedCategoryId = 'all';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
  }

  void _loadData() {
    context.read<TreasuryTransactionsBloc>().add(LoadTreasuryTransactions(
      startDate: _startDate,
      endDate: _endDate,
    ));
  }

  void _resetFilters() {
    setState(() {
      _selectedAccountId = 'all';
      _selectedCategoryId = 'all';
      _startDate = DateTime.now().subtract(const Duration(days: 30));
      _endDate = DateTime.now();
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Transactions',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Consultez et gérez toutes les transactions de trésorerie',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  // Export functionality could go here
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Exporter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compte de Trésorerie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                        builder: (context, state) {
                          List<DropdownMenuItem<String>> items = [
                            const DropdownMenuItem(value: 'all', child: Text('Tous les Comptes')),
                          ];
                          if (state is TreasuryAccountsLoaded) {
                            items.addAll(state.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))));
                          }
                          return DropdownButtonFormField<String>(
                            value: _selectedAccountId,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            isExpanded: true,
                            items: items,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedAccountId = val);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Catégorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      BlocBuilder<TreasuryTransactionsBloc, TreasuryTransactionsState>(
                        builder: (context, state) {
                          List<DropdownMenuItem<String>> items = [
                            const DropdownMenuItem(value: 'all', child: Text('Toutes les Catégories')),
                          ];
                          if (state is TreasuryTransactionsLoaded) {
                            items.addAll(state.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))));
                          }
                          return DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            isExpanded: true,
                            items: items,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategoryId = val);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de début', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        controller: TextEditingController(text: DateFormat('dd MMM yyyy', 'fr_FR').format(_startDate)),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) {
                            setState(() => _startDate = picked);
                            _loadData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de fin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        controller: TextEditingController(text: DateFormat('dd MMM yyyy', 'fr_FR').format(_endDate)),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) {
                            setState(() => _endDate = picked);
                            _loadData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
                    onPressed: _resetFilters,
                    tooltip: 'Réinitialiser les filtres',
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Table
        Expanded(
          child: BlocBuilder<TreasuryTransactionsBloc, TreasuryTransactionsState>(
            builder: (context, state) {
              if (state is TreasuryTransactionsLoading) return const Center(child: CircularProgressIndicator());
              if (state is TreasuryTransactionsError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is TreasuryTransactionsLoaded) {
                // Apply Dropdown Filters
                final filtered = state.transactions.where((t) {
                  if (_selectedAccountId != 'all' && t.accountId != _selectedAccountId) return false;
                  if (_selectedCategoryId != 'all' && t.category != _selectedCategoryId) return false;
                  return true;
                }).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DataTableWidget<TreasuryTransaction>(
                      columns: const ['Référence', 'Compte', 'Débit', 'Crédit', 'Solde', 'Motif', 'Actions'],
                      rows: filtered,
                      emptyMessage: 'Aucune transaction trouvée',
                      cellBuilder: (tx) {
                        final isDebit = tx.type == 'income'; // Encaissement (incoming) = Debit transaction
                        final isCredit = tx.type == 'expense'; // Décaissement (outgoing) = Credit transaction
                        
                        final balance = tx.balance ?? 0.0;
                        final balanceColor = balance < 0 ? AppColors.error : AppColors.textPrimary;

                        return [
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tx.transactionNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                              Text(DateFormat('dd MMM yyyy - HH:mm', 'fr_FR').format(tx.dateTransaction), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            ],
                          )),
                          DataCell(Text(tx.accountName ?? '—', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                          DataCell(
                            isDebit 
                              ? Text('+ ${formatCurrencyDT(tx.amount)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))
                              : const Text('-', style: TextStyle(color: AppColors.textTertiary)),
                          ),
                          DataCell(
                            isCredit 
                              ? Text('- ${formatCurrencyDT(tx.amount)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600))
                              : const Text('-', style: TextStyle(color: AppColors.textTertiary)),
                          ),
                          DataCell(
                            Text(formatCurrencyDT(balance), style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold)),
                          ),
                          DataCell(Text(tx.description ?? '—', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
                              onPressed: () {
                                // Options menu
                                _showOptions(context, tx);
                              },
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _showOptions(BuildContext context, TreasuryTransaction tx) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, tx.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette transaction ? Le solde du compte sera recalculé automatiquement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              context.read<TreasuryTransactionsBloc>().add(DeleteTreasuryTransaction(id));
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
