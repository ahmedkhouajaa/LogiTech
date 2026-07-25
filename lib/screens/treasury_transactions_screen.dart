import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../models/treasury_transaction.dart';
import '../models/treasury_account.dart';
import '../models/transaction_category.dart';
import '../services/transaction_export_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/searchable_dropdown_field.dart';

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

  void _handleExport(String type) {
    final state = context.read<TreasuryTransactionsBloc>().state;
    if (state is TreasuryTransactionsLoaded) {
      final filtered = state.transactions.where((t) {
        if (_selectedAccountId != 'all' && t.accountId != _selectedAccountId) return false;
        if (_selectedCategoryId != 'all' && t.category != _selectedCategoryId) return false;
        return true;
      }).toList();

      if (type == 'pdf') {
        TransactionExportService.exportToPdf(context, filtered);
      } else if (type == 'excel') {
        TransactionExportService.exportToExcel(context, filtered);
      }
    }
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
                  children: [
                    Text(
                      'Transactions',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Consultez et gerez toutes les transactions de tresorerie',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                offset: Offset(0, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: BorderSide(color: AppColors.border)),
                tooltip: 'Options d\'exportation',
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(100), // Rounded pill shape like original outlined button
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 18, color: AppColors.textPrimary),
                      SizedBox(width: 8),
                      Text('Exporter', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 18),
                        const SizedBox(width: 8),
                        const Text('Exporter en PDF'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excel',
                    child: Row(
                      children: [
                        const Icon(Icons.table_chart, size: 18),
                        const SizedBox(width: 8),
                        const Text('Exporter en Excel'),
                      ],
                    ),
                  ),
                ],
                onSelected: _handleExport,
              ),
            ],
          ),
        ),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: BlocBuilder<TreasuryTransactionsBloc, TreasuryTransactionsState>(
            builder: (context, state) {
              List<TreasuryTransaction> transactions = [];
              if (state is TreasuryTransactionsLoaded) {
                transactions = state.transactions;
              }
              final filtered = transactions.where((t) {
                if (_selectedAccountId != 'all' && t.accountId != _selectedAccountId) return false;
                if (_selectedCategoryId != 'all' && t.category != _selectedCategoryId) return false;
                return true;
              }).toList();

              return Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Compte de Tresorerie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                                builder: (context, accountState) {
                                  final accounts = accountState is TreasuryAccountsLoaded ? accountState.accounts : <TreasuryAccount>[];
                                  String? displayName = 'Tous les Comptes';
                                  if (_selectedAccountId != 'all') {
                                    final acc = accounts.cast<TreasuryAccount?>().firstWhere((a) => a?.id == _selectedAccountId, orElse: () => null);
                                    if (acc != null) displayName = acc.name;
                                  }
                                  return SizedBox(
                                    height: 40,
                                    child: SearchableSelectorField(
                                      hint: 'Tous les Comptes',
                                      selectedText: displayName,
                                      onTap: () async {
                                        final res = await showTreasuryAccountSelectDialog(context, accounts, selectedAccountId: _selectedAccountId, includeAll: true);
                                        if (res != null && res != _selectedAccountId) {
                                          setState(() => _selectedAccountId = res);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Categorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: Builder(
                                  builder: (context) {
                                    final categories = state is TreasuryTransactionsLoaded ? state.categories : <TransactionCategory>[];
                                    String? displayName = 'Toutes les Categories';
                                    if (_selectedCategoryId != 'all') {
                                      final cat = categories.cast<TransactionCategory?>().firstWhere((c) => c?.id == _selectedCategoryId, orElse: () => null);
                                      if (cat != null) displayName = cat.name;
                                    }
                                    return SearchableSelectorField(
                                      hint: 'Toutes les Categories',
                                      selectedText: displayName,
                                      onTap: () async {
                                        final res = await showCategorySelectDialog(context, categories, selectedCategoryId: _selectedCategoryId, includeAll: true);
                                        if (res != null && res != _selectedCategoryId) {
                                          setState(() => _selectedCategoryId = res);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date de debut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: TextFormField(
                                  readOnly: true,
                                  controller: TextEditingController(text: DateFormat('dd MMM yyyy', 'fr_FR').format(_startDate)),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                  ),
                                  onTap: () async {
                                    final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                    if (picked != null) {
                                      setState(() => _startDate = picked);
                                      _loadData();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date de fin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: TextFormField(
                                  readOnly: true,
                                  controller: TextEditingController(text: DateFormat('dd MMM yyyy', 'fr_FR').format(_endDate)),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                                  ),
                                  onTap: () async {
                                    final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                    if (picked != null) {
                                      setState(() => _endDate = picked);
                                      _loadData();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_selectedAccountId != 'all' || _selectedCategoryId != 'all')
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${filtered.length} résultat${filtered.length > 1 ? 's' : ''}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                            Spacer(),
                            TextButton.icon(
                              onPressed: _resetFilters,
                              icon: Icon(Icons.refresh_rounded, size: 16),
                              label: Text('Réinitialiser les filtres'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
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
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DataTableWidget<TreasuryTransaction>(
                      columns: const ['Reference', 'Compte', 'Debit', 'Credit', 'Solde', 'Motif', 'Actions'],
                      rows: filtered,
                      emptyMessage: 'Aucune transaction trouvee',
                      cellBuilder: (tx) {
                        final isDebit = tx.type == 'income'; // Encaissement (incoming) = Debit transaction
                        final isCredit = tx.type == 'expense'; // Decaissement (outgoing) = Credit transaction
                        
                        final balance = tx.balance ?? 0.0;
                        final balanceColor = balance < 0 ? AppColors.error : AppColors.textPrimary;

                        return [
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tx.transactionNumber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                              Text(DateFormat('dd MMM yyyy - HH:mm', 'fr_FR').format(tx.dateTransaction), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            ],
                          )),
                          DataCell(Text(tx.accountName ?? '—', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                          DataCell(
                            isDebit 
                              ? Text('+ ${formatCurrencyDT(tx.amount)}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))
                              : Text('-', style: TextStyle(color: AppColors.textTertiary)),
                          ),
                          DataCell(
                            isCredit 
                              ? Text('- ${formatCurrencyDT(tx.amount)}', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600))
                              : Text('-', style: TextStyle(color: AppColors.textTertiary)),
                          ),
                          DataCell(
                            Text(formatCurrencyDT(balance), style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold)),
                          ),
                          DataCell(Text(tx.description ?? '—', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
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
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text('Supprimer', style: TextStyle(color: AppColors.error)),
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
        content: const Text('Voulez-vous vraiment supprimer cette transaction ? Le solde du compte sera recalcule automatiquement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              context.read<TreasuryTransactionsBloc>().add(DeleteTreasuryTransaction(id));
              Navigator.pop(ctx);
            },
            child: Text('Supprimer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
