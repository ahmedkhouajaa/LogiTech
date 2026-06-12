import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/stock_withdrawals/stock_withdrawals_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/stock_withdrawal.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_stock_withdrawal_screen.dart';

class StockWithdrawalsScreen extends StatefulWidget {
  const StockWithdrawalsScreen({super.key});

  @override
  State<StockWithdrawalsScreen> createState() => _StockWithdrawalsScreenState();
}

class _StockWithdrawalsScreenState extends State<StockWithdrawalsScreen> {
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  StockWithdrawalStatus? _statusFilter;

  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<StockWithdrawalsBloc>().add(LoadStockWithdrawals());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  void _applyFilters() {
    context.read<StockWithdrawalsBloc>().add(FilterStockWithdrawals(
      clientId: _selectedClientId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter?.name,
    ));
    setState(() => _currentPage = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Bon de Sortie',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.play_circle_fill, color: Colors.red[600], size: 24),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gérer vos bons de sortie',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _navigate(context, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer un Bon de Sortie'),
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

        // ── Filter Bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _buildFilterBar(),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Table ──
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

  void _navigate(BuildContext context, StockWithdrawal? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<StockWithdrawalsBloc>()),
            BlocProvider.value(value: context.read<CustomersBloc>()),
            BlocProvider.value(value: context.read<ProductsBloc>()),
            BlocProvider.value(value: context.read<ProjectsBloc>()),
          ],
          child: CreateStockWithdrawalScreen(existing: existing),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Client dropdown
          Expanded(
            flex: 3,
            child: _filterSection(
              label: 'Client',
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  List<Customer> customers = [];
                  if (state is CustomersLoaded) customers = state.customers;
                  return _dropdownField(
                    hint: 'Sélectionner un client...',
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
                      setState(() => _selectedClientId = val);
                      _applyFilters();
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Date From
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Date de début',
              child: _datePicker(
                value: _dateFrom,
                hint: 'Sélectionner une date',
                onPicked: (d) {
                  setState(() => _dateFrom = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Date To
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Date de fin',
              child: _datePicker(
                value: _dateTo,
                hint: 'Sélectionner une date',
                onPicked: (d) {
                  setState(() => _dateTo = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Status
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
                  ...StockWithdrawalStatus.values.map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.label))),
                ],
                onChanged: (val) {
                  setState(() => _statusFilter = val);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Reset button
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _selectedClientId = null;
                  _dateFrom = null;
                  _dateTo = null;
                  _statusFilter = null;
                });
                _applyFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary)),
        isDense: true,
      ),
      icon: const Icon(Icons.expand_more, size: 16),
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      items: items,
      onChanged: onChanged,
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
    return BlocBuilder<StockWithdrawalsBloc, StockWithdrawalsState>(
      builder: (context, state) {
        if (state is StockWithdrawalsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is StockWithdrawalsError) {
          return Center(
              child: Text(state.message,
                  style: const TextStyle(color: AppColors.error)));
        }
        if (state is StockWithdrawalsLoaded) {
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
                                  child: Text('Référence',
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
                                      Text('Aucun bon de sortie trouvé',
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
                                    ? 'Affichage de 0 à 0 sur 0 résultats'
                                    : 'Affichage de ${start + 1} à $end sur $total résultats',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 16),
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
    final statusEnum = StockWithdrawalStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => StockWithdrawalStatus.draft,
    );
    final clientLabel =
        note.customerCompany ?? note.customerName ?? 'Client inconnu';
    final isDraft = statusEnum == StockWithdrawalStatus.draft;

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

          // Référence
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
                  .read<StockWithdrawalsBloc>()
                  .add(DeleteStockWithdrawal(note.id));
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
