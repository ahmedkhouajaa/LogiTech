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
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';

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
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transactions',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Consultez et gérez toutes les transactions de trésorerie',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: BorderSide(color: AppColors.border)),
                tooltip: 'Options d\'exportation',
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.surfaceAlt,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 16, color: AppColors.textPrimary),
                      const SizedBox(width: 6),
                      Text('Exporter', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 16),
                        const SizedBox(width: 8),
                        const Text('Exporter en PDF'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'excel',
                    child: Row(
                      children: [
                        const Icon(Icons.table_chart, size: 16),
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
        const SizedBox(height: 10),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Compte de Trésorerie', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                            builder: (context, accountState) {
                              final accounts = accountState is TreasuryAccountsLoaded ? accountState.accounts : <TreasuryAccount>[];
                              String? displayName = 'Tous les Comptes';
                              if (_selectedAccountId != 'all') {
                                final acc = accounts.cast<TreasuryAccount?>().firstWhere((a) => a?.id == _selectedAccountId, orElse: () => null);
                                if (acc != null) displayName = acc.name;
                              }
                              return SizedBox(
                                height: 32,
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
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Catégorie', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: Builder(
                              builder: (context) {
                                final categories = state is TreasuryTransactionsLoaded ? state.categories : <TransactionCategory>[];
                                String? displayName = 'Toutes les Catégories';
                                if (_selectedCategoryId != 'all') {
                                  final cat = categories.cast<TransactionCategory?>().firstWhere((c) => c?.id == _selectedCategoryId, orElse: () => null);
                                  if (cat != null) displayName = cat.name;
                                }
                                return SearchableSelectorField(
                                  hint: 'Toutes les Catégories',
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
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Date de début', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: TextFormField(
                              readOnly: true,
                              controller: TextEditingController(text: DateFormat('dd MMM yyyy', 'fr_FR').format(_startDate)),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 14),
                                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                                filled: true,
                                fillColor: AppColors.surfaceAlt,
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
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Date de fin', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 32,
                            child: TextFormField(
                              readOnly: true,
                              controller: TextEditingController(text: DateFormat('dd MMM yyyy', 'fr_FR').format(_endDate)),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 14),
                                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                                filled: true,
                                fillColor: AppColors.surfaceAlt,
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
                    if (_selectedAccountId != 'all' || _selectedCategoryId != 'all') ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: IconButton(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          tooltip: 'Réinitialiser les filtres',
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.error,
                            backgroundColor: AppColors.error.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Table
        Expanded(
          child: BlocBuilder<TreasuryTransactionsBloc, TreasuryTransactionsState>(
            builder: (context, state) {
              if (state is TreasuryTransactionsLoading || state is TreasuryTransactionsInitial) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ShimmerTable(
                    headerColumns: [
                      Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Compte', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Debit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Credit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Solde', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Motif', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                    ],
                  ),
                );
              }
              if (state is TreasuryTransactionsError) return AppErrorWidget(message: state.message);
              if (state is TreasuryTransactionsLoaded) {
                // Apply Dropdown Filters
                final filtered = state.transactions.where((t) {
                  if (_selectedAccountId != 'all' && t.accountId != _selectedAccountId) return false;
                  if (_selectedCategoryId != 'all' && t.category != _selectedCategoryId) return false;
                  return true;
                }).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                      builder: (context, accountState) {
                        final accounts = accountState is TreasuryAccountsLoaded ? accountState.accounts : <TreasuryAccount>[];
                        return DataTableWidget<TreasuryTransaction>(
                          columns: const ['Reference', 'Compte', 'Debit', 'Credit', 'Solde', 'Motif', 'Actions'],
                          rows: filtered,
                          emptyMessage: 'Aucune transaction trouvee',
                          cellBuilder: (tx) {
                            final isDebit = tx.type == 'income'; // Encaissement (incoming) = Debit transaction
                            final isCredit = tx.type == 'expense'; // Decaissement (outgoing) = Credit transaction
                            
                            final balance = tx.balance ?? 0.0;
                            final balanceColor = balance < 0 ? AppColors.error : AppColors.textPrimary;
                            
                            final account = accounts.cast<TreasuryAccount?>().firstWhere((a) => a?.id == tx.accountId, orElse: () => null);
                            final accountName = account?.name ?? tx.accountName ?? '—';

                            return [
                              DataCell(Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(tx.transactionNumber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary)),
                                  Text(DateFormat('dd MMM yyyy - HH:mm', 'fr_FR').format(tx.dateTransaction), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                ],
                              )),
                              DataCell(Text(accountName, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                              DataCell(
                            isDebit 
                              ? Text('+ ${formatCurrencyDT(tx.amount)}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12.5))
                              : Text('-', style: TextStyle(color: AppColors.textTertiary)),
                          ),
                          DataCell(
                            isCredit 
                              ? Text('- ${formatCurrencyDT(tx.amount)}', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12.5))
                              : Text('-', style: TextStyle(color: AppColors.textTertiary)),
                          ),
                          DataCell(
                            Text(formatCurrencyDT(balance), style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ),
                          DataCell(Text(tx.description ?? '—', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                          DataCell(
                            PermissionService.instance.canDelete(UserPermissionResources.treasuryTransactions)
                                ? IconButton(
                                    icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _showOptions(context, tx);
                                    },
                                  )
                                : const SizedBox(),
                          ),
                        ];
                      },
                    );
                  },
                ),
              ),
            );
          }
              return const SizedBox();
            },
          ),
        ),
        const SizedBox(height: 10),
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
