import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/exit_vouchers/exit_vouchers_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/stock_withdrawal.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_exit_voucher_screen.dart';

enum ExitVoucherStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Valide', AppColors.primary),
  cancelled('Annule', AppColors.error);

  final String label;
  final Color color;
  const ExitVoucherStatus(this.label, this.color);
}

class ExitVouchersScreen extends StatefulWidget {
  const ExitVouchersScreen({super.key});

  @override
  State<ExitVouchersScreen> createState() => _ExitVouchersScreenState();
}

class _ExitVouchersScreenState extends State<ExitVouchersScreen> {
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  ExitVoucherStatus? _statusFilter;

  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<ExitVouchersBloc>().add(LoadExitVouchers());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  void _applyFilters() {
    context.read<ExitVouchersBloc>().add(FilterExitVouchers(
      clientId: _selectedClientId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter?.name,
    ));
    setState(() => _currentPage = 0);
  }

  void _navigate(BuildContext context, [StockWithdrawal? existing]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<ExitVouchersBloc>()),
            BlocProvider.value(value: context.read<CustomersBloc>()),
            BlocProvider.value(value: context.read<ProductsBloc>()),
            BlocProvider.value(value: context.read<ProjectsBloc>()),
          ],
          child: CreateExitVoucherScreen(existing: existing),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        return isMobile ? _buildMobileLayout(context) : _buildDesktopLayout(context);
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bon de Sortie',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Gerer vos bons de sortie',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _navigate(context, null),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Creer un Bon de Sortie'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            // Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: BlocBuilder<ExitVouchersBloc, ExitVouchersState>(
                builder: (context, state) {
                  return _buildFilterBar(state);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Cards List
            Expanded(
              child: BlocBuilder<ExitVouchersBloc, ExitVouchersState>(
                builder: (context, state) {
                  if (state is ExitVouchersLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ExitVouchersError) {
                    return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
                  }
                  if (state is ExitVouchersLoaded) {
                    final entries = state.withdrawals;
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text("Aucun bon de sortie trouve", style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 80),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _buildMobileCard(context, entries[index]);
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bon de Sortie',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gerer vos bons de sortie',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _navigate(context, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Creer un Bon de Sortie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ),
        
        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: BlocBuilder<ExitVouchersBloc, ExitVouchersState>(
            builder: (context, state) {
              return _buildFilterBar(state);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildTable(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildFilterBar(ExitVouchersState state) {
    int totalItems = 0;
    if (state is ExitVouchersLoaded) {
      List<StockWithdrawal> filteredVouchers = state.withdrawals;
      if (_selectedClientId != null && _selectedClientId != 'all') {
        filteredVouchers = filteredVouchers.where((q) => q.customerId == _selectedClientId).toList();
      }
      if (_dateFrom != null) {
        filteredVouchers = filteredVouchers.where((q) => q.date.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
      }
      if (_dateTo != null) {
        filteredVouchers = filteredVouchers.where((q) => q.date.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
      }
      if (_statusFilter != null) {
        filteredVouchers = filteredVouchers.where((q) => q.status == _statusFilter!.name).toList();
      }
      totalItems = filteredVouchers.length;
    }

    final activeFilterCount = (_selectedClientId != null && _selectedClientId != 'all' ? 1 : 0) +
        (_dateFrom != null ? 1 : 0) +
        (_dateTo != null ? 1 : 0) +
        (_statusFilter != null ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
            child: _filterSection(
              label: 'Client',
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  List<Customer> customers = [];
                  if (state is CustomersLoaded) customers = state.customers;
                  return _dropdownField(
                    hint: 'Selectionner un client...',
                    value: _selectedClientId,
                    items: [
                      const DropdownMenuItem(
                          value: 'all',
                          child: Text('Tous les clients',
                              style: TextStyle(color: AppColors.textSecondary))),
                      ...customers.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.companyName ?? c.responsibleName ?? 'Inconnu'))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedClientId = val == 'all' ? null : val);
                      _applyFilters();
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Date de debut',
              child: _datePicker(
                value: _dateFrom,
                hint: 'Selectionner une date',
                onPicked: (d) {
                  setState(() => _dateFrom = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Date de fin',
              child: _datePicker(
                value: _dateTo,
                hint: 'Selectionner une date',
                onPicked: (d) {
                  setState(() => _dateTo = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Statut',
              child: _dropdownField(
                hint: 'Tous',
                value: _statusFilter,
                items: [
                  const DropdownMenuItem(
                      value: null,
                      child: Text('Tous', style: TextStyle(color: AppColors.textPrimary))),
                  ...ExitVoucherStatus.values.map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.label))),
                ],
                onChanged: (val) {
                  setState(() => _statusFilter = val);
                  _applyFilters();
                },
              ),
            ),
          ),
          ],
        ),
        if (activeFilterCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$totalItems résultat${totalItems > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedClientId = null;
                      _dateFrom = null;
                      _dateTo = null;
                      _statusFilter = null;
                    });
                    _applyFilters();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Réinitialiser les filtres'),
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
  }

  Widget _filterSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        SizedBox(height: 40, child: child),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePicker({
    required DateTime? value,
    required String hint,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: const Locale('fr', 'FR'),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? formatDateLong(value) : hint,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? AppColors.textPrimary : AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    return BlocBuilder<ExitVouchersBloc, ExitVouchersState>(
      builder: (context, state) {
        if (state is ExitVouchersLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ExitVouchersError) {
          return Center(
              child: Text(state.message,
                  style: const TextStyle(color: AppColors.error)));
        }
        if (state is ExitVouchersLoaded) {
          final notes = state.withdrawals;
          final total = notes.length;
          final totalPages = total == 0 ? 1 : (total / _rowsPerPage).ceil();
          final page = _currentPage.clamp(0, totalPages - 1);
          final start = page * _rowsPerPage;
          final end = (start + _rowsPerPage).clamp(0, total);
          final pageNotes = notes.sublist(start, end);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Column(
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            border:
                                Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 32),
                              const Expanded(
                                  flex: 2,
                                  child: Text('Reference',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              const Expanded(
                                  flex: 3,
                                  child: Text('Client',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              const Expanded(
                                  flex: 2,
                                  child: Text('Statut',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              const Expanded(
                                  flex: 2,
                                  child: Text('Montant',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              const SizedBox(
                                  width: 80,
                                  child: Text('Actions',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                        
                        // Body
                        Expanded(
                          child: pageNotes.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.local_shipping_outlined,
                                          size: 48, color: AppColors.border),
                                      SizedBox(height: 16),
                                      Text('Aucun bon de sortie trouve',
                                          style: TextStyle(
                                              color: AppColors.textSecondary)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: pageNotes.length,
                                  separatorBuilder: (_, __) => const Divider(
                                      height: 1, color: AppColors.border),
                                  itemBuilder: (context, i) =>
                                      _buildRow(context, pageNotes[i], i),
                                ),
                        ),

                        // Pagination footer
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            border:
                                Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              const Text('Lignes',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Container(
                                height: 32,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down,
                                      size: 16),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary),
                                  items: [10, 20, 50, 100]
                                      .map((v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(v.toString())))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _rowsPerPage = v;
                                        _currentPage = 0;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Text('Page ${page + 1} sur $totalPages',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                total == 0
                                    ? 'Affichage de 0 a 0 sur 0 resultats'
                                    : 'Affichage de ${start + 1} a $end sur $total resultats',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  _pageButton(
                                    icon: Icons.chevron_left,
                                    enabled: page > 0,
                                    onTap: () =>
                                        setState(() => _currentPage = page - 1),
                                  ),
                                  const SizedBox(width: 8),
                                  _pageButton(
                                    icon: Icons.chevron_right,
                                    enabled: page < totalPages - 1,
                                    onTap: () =>
                                        setState(() => _currentPage = page + 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildRow(BuildContext context, StockWithdrawal note, int index) {
    final statusEnum = ExitVoucherStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => ExitVoucherStatus.draft,
    );
    final clientLabel =
        note.customerCompany ?? note.customerName ?? 'Client inconnu';
    final isDraft = statusEnum == ExitVoucherStatus.draft;

    return Container(
      color: index % 2 == 0
          ? AppColors.surface
          : AppColors.background.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: false,
              onChanged: (_) {},
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
          ),
          // Reference
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.number,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(formatDateTimeLong(note.date),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          // Client
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(clientLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          // Statut badge
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusEnum.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusEnum.label,
                  style: TextStyle(
                      color: statusEnum.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          // Montant
          Expanded(
            flex: 2,
            child: Text(
              formatCurrencyDT(note.totalTTC),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDraft ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz,
                    color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'edit') _navigate(context, note);
                  if (val == 'delete') _confirmDelete(note);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Modifier')
                      ])),
                  const PopupMenuItem(
                      value: 'print',
                      child: Row(children: [
                        Icon(Icons.print_rounded,
                            size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Imprimer')
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_rounded,
                            size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Supprimer',
                            style: TextStyle(color: AppColors.error))
                      ])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context, StockWithdrawal note) {
    final statusEnum = ExitVoucherStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => ExitVoucherStatus.draft,
    );
    final clientLabel =
        note.customerCompany ?? note.customerName ?? 'Client inconnu';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _navigate(context, note),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        note.number,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusEnum.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusEnum.label,
                        style: TextStyle(
                            color: statusEnum.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      color: AppColors.surface,
                      onSelected: (val) {
                        if (val == 'edit') _navigate(context, note);
                        if (val == 'delete') _confirmDelete(note);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Modifier')
                            ])),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Supprimer', style: TextStyle(color: AppColors.error))
                            ])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        clientLabel,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 6),
                          Text(formatDateTimeLong(note.date), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrencyDT(note.totalTTC),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageButton(
      {required IconData icon,
      required bool enabled,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
              color: enabled
                  ? AppColors.border
                  : AppColors.border.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
          color: AppColors.surface,
        ),
        child: Icon(icon,
            size: 20,
            color: enabled
                ? AppColors.textPrimary
                : AppColors.textTertiary),
      ),
    );
  }

  void _confirmDelete(StockWithdrawal note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
            'Voulez-vous vraiment supprimer le bon de sortie ${note.number} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<ExitVouchersBloc>()
                  .add(DeleteExitVoucher(note.id));
              // Refresh products list so stock quantities are updated immediately
              context.read<ProductsBloc>().add(LoadProducts());
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
