import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/dashboard_card.dart';
import 'create_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  // Filter state
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  InvoiceStatus? _statusFilter;

  // Pagination state
  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<InvoicesBloc>().add(LoadInvoices());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  void _applyFilters() {
    context.read<InvoicesBloc>().add(FilterInvoices(
      clientId: _selectedClientId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and button
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Text('Gérer vos factures', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const Spacer(),
              AppButton(
                label: 'Nouvelle facture',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: context.read<InvoicesBloc>()),
                        BlocProvider.value(value: context.read<CustomersBloc>()),
                        BlocProvider.value(value: context.read<ProductsBloc>()),
                        BlocProvider.value(value: context.read<ProjectsBloc>()),
                      ],
                      child: const CreateInvoiceScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _buildFilterBar(),
        ),
        const SizedBox(height: AppSpacing.md),
        // Data table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildInvoiceTable(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          // Client filter
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: 'Client',
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                  return DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    isExpanded: true,
                    hint: const Text('Sélectionner un client...', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Tous les clients', style: TextStyle(fontSize: 13))),
                      ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedClientId = v);
                      _applyFilters();
                    },
                    decoration: _filterInputDecoration(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date de début
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: 'Date de début',
              child: _buildDateFilterField(
                value: _dateFrom,
                hint: 'Sélectionner une date',
                onChanged: (d) {
                  setState(() => _dateFrom = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date de fin
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: 'Date de fin',
              child: _buildDateFilterField(
                value: _dateTo,
                hint: 'Sélectionner une date',
                onChanged: (d) {
                  setState(() => _dateTo = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Status filter
          SizedBox(
            width: 150,
            child: _buildFilterField(
              label: 'Statut',
              child: DropdownButtonFormField<InvoiceStatus?>(
                value: _statusFilter,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<InvoiceStatus?>(value: null, child: Text('Tous', style: TextStyle(fontSize: 13))),
                  ...InvoiceStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 13)))),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _applyFilters();
                },
                decoration: _filterInputDecoration(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter icon button
          Container(
            margin: const EdgeInsets.only(top: 18),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
              onPressed: () {
                setState(() {
                  _selectedClientId = null;
                  _dateFrom = null;
                  _dateTo = null;
                  _statusFilter = null;
                  _currentPage = 0;
                });
                context.read<InvoicesBloc>().add(LoadInvoices());
              },
              tooltip: 'Réinitialiser les filtres',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDateFilterField({
    DateTime? value,
    required String hint,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          locale: const Locale('fr', 'FR'),
        );
        onChanged(picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: value != null ? formatDateLong(value) : ''),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  InputDecoration _filterInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  Widget _buildInvoiceTable() {
    return BlocBuilder<InvoicesBloc, InvoicesState>(
      builder: (context, state) {
        if (state is InvoicesLoading) return const Center(child: CircularProgressIndicator());
        if (state is InvoicesError) return Center(child: Text('Erreur: ${state.message}'));
        if (state is InvoicesLoaded) {
          final invoices = state.filteredInvoices;
          final totalRows = invoices.length;
          final totalPages = (totalRows / _rowsPerPage).ceil().clamp(1, 9999);
          _currentPage = _currentPage.clamp(0, totalPages - 1);
          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
          final pageInvoices = totalRows > 0 ? invoices.sublist(startIndex, endIndex) : <Invoice>[];

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              children: [
                // Table
                Expanded(
                  child: pageInvoices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              const Text('Aucune facture trouvée', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.resolveWith((_) => const Color(0xFFF8FAFC)),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                              dataTextStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              dividerThickness: 0.5,
                              columnSpacing: 24,
                              horizontalMargin: 16,
                              columns: const [
                                DataColumn(label: SizedBox(width: 20)),
                                DataColumn(label: Text('Référence')),
                                DataColumn(label: Text('Client')),
                                DataColumn(label: Text('Statut')),
                                DataColumn(label: Text('Montant')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: pageInvoices.map((inv) => _buildInvoiceRow(inv)).toList(),
                            ),
                          ),
                        ),
                ),
                // Pagination
                _buildPaginationBar(totalRows, totalPages),
              ],
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  DataRow _buildInvoiceRow(Invoice inv) {
    return DataRow(
      cells: [
        // Checkbox
        DataCell(
          Checkbox(
            value: false,
            onChanged: (_) {},
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
        ),
        // Référence (number + date)
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                formatDateTimeLong(inv.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
        // Client (icon + name + company)
        DataCell(
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(inv.customerName ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
                    Text(inv.customerName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Statut badge
        DataCell(StatusBadge(label: inv.status.label, color: inv.status.color)),
        // Montant
        DataCell(
          Text(
            formatCurrencyDT(inv.totalTTC + inv.timbreFiscal),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: inv.status == InvoiceStatus.unpaid || inv.status == InvoiceStatus.overdue
                  ? AppColors.warning
                  : AppColors.textPrimary,
            ),
          ),
        ),
        // Actions (three dots menu)
        DataCell(
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            offset: const Offset(0, 30),
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider.value(value: context.read<InvoicesBloc>()),
                          BlocProvider.value(value: context.read<CustomersBloc>()),
                          BlocProvider.value(value: context.read<ProductsBloc>()),
                          BlocProvider.value(value: context.read<ProjectsBloc>()),
                        ],
                        child: CreateInvoiceScreen(existing: inv),
                      ),
                    ),
                  );
                  break;
                case 'delete':
                  _confirmDelete(inv);
                  break;
                case 'print':
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('Modifier')])),
              const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print_rounded, size: 16, color: AppColors.success), SizedBox(width: 8), Text('Imprimer')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationBar(int totalRows, int totalPages) {
    final startRow = totalRows > 0 ? (_currentPage * _rowsPerPage) + 1 : 0;
    final endRow = ((_currentPage + 1) * _rowsPerPage).clamp(0, totalRows);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Rows per page
          const Text('Lignes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: DropdownButton<int>(
              value: _rowsPerPage,
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              items: [10, 20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
              onChanged: (v) => setState(() {
                _rowsPerPage = v ?? 20;
                _currentPage = 0;
              }),
            ),
          ),
          const SizedBox(width: 24),
          // Page info
          Text('Page ${_currentPage + 1} sur $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: 24),
          // Display info
          Text(
            'Affichage de $startRow à $endRow sur $totalRows résultats',
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const Spacer(),
          // Navigation buttons
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Invoice inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer la facture ${inv.number} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<InvoicesBloc>().add(DeleteInvoice(inv.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
