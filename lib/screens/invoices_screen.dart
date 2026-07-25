import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
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
import '../widgets/invoice_payment_dialog.dart';
import '../blocs/payments/payments_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../blocs/credit_notes/credit_notes_bloc.dart';
import '../models/credit_note.dart';
import 'create_invoice_screen.dart';
import '../services/pdf_service.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';

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
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Factures Client',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text('Gerer vos factures', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
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
          child: BlocBuilder<InvoicesBloc, InvoicesState>(
            builder: (context, state) {
              return _buildFilterBar(state);
            },
          ),
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

  Widget _buildFilterBar(InvoicesState state) {
    int totalItems = 0;
    if (state is InvoicesLoaded) {
      List<Invoice> filteredInvoices = state.invoices;
      if (_selectedClientId != null) {
        filteredInvoices = filteredInvoices.where((i) => i.customerId == _selectedClientId).toList();
      }
      if (_dateFrom != null) {
        filteredInvoices = filteredInvoices.where((i) => i.date.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
      }
      if (_dateTo != null) {
        filteredInvoices = filteredInvoices.where((i) => i.date.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
      }
      if (_statusFilter != null) {
        filteredInvoices = filteredInvoices.where((i) => i.status == _statusFilter).toList();
      }
      totalItems = filteredInvoices.length;
    }

    final activeFilterCount = (_selectedClientId != null ? 1 : 0) +
        (_dateFrom != null ? 1 : 0) +
        (_dateTo != null ? 1 : 0) +
        (_statusFilter != null ? 1 : 0);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Client filter
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: 'Client',
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                  String selectedCustomerName = 'Tous les clients';
                  if (_selectedClientId != null && _selectedClientId != 'all') {
                    final found = customers.firstWhere(
                      (c) => c.id == _selectedClientId,
                      orElse: () => Customer(id: '', code: '', name: 'Inconnu', country: ''),
                    );
                    selectedCustomerName = found.companyName?.isNotEmpty == true
                        ? found.companyName!
                        : (found.responsibleName?.isNotEmpty == true ? found.responsibleName! : found.name);
                  }

                  return InkWell(
                    onTap: () async {
                      final selected = await _showCustomerSearchDialog(context, customers, _selectedClientId);
                      if (selected != null) {
                        setState(() {
                          _selectedClientId = selected.id == 'all' ? null : selected.id;
                        });
                        _applyFilters();
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedClientId == null || _selectedClientId == 'all'
                                  ? 'Tous les clients'
                                  : selectedCustomerName,
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedClientId != null && _selectedClientId != 'all'
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date de debut
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: 'Date de debut',
              child: _buildDateFilterField(
                value: _dateFrom,
                hint: 'Selectionner une date',
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
                hint: 'Selectionner une date',
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
              child: PopupMenuButton<InvoiceStatus?>(
                tooltip: 'Filtrer par statut',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(color: AppColors.border),
                ),
                color: AppColors.surface,
                elevation: 6,
                offset: const Offset(0, 44),
                initialValue: _statusFilter,
                onSelected: (v) {
                  setState(() => _statusFilter = v);
                  _applyFilters();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<InvoiceStatus?>(
                    value: null,
                    height: 38,
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'Tous',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ),
                        Spacer(),
                        if (_statusFilter == null)
                          Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  ...InvoiceStatus.values.map(
                    (s) => PopupMenuItem<InvoiceStatus?>(
                      value: s,
                      height: 38,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: s.color,
                              ),
                            ),
                          ),
                          Spacer(),
                          if (_statusFilter == s)
                            Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: _statusFilter != null ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statusFilter == null
                            ? Text(
                                'Tous',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusFilter!.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  _statusFilter!.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _statusFilter!.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      if (activeFilterCount > 0)
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
                  '$totalItems résultat${totalItems > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
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
                    _currentPage = 0;
                  });
                  context.read<InvoicesBloc>().add(LoadInvoices());
                },
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
  }

  Future<Customer?> _showCustomerSearchDialog(
    BuildContext context,
    List<Customer> customers,
    String? selectedCustomerId,
  ) async {
    return showDialog<Customer?>(
      context: context,
      builder: (context) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = search.trim().toLowerCase();
            final filtered = customers.where((c) {
              if (query.isEmpty) return true;
              final nameMatch = c.name.toLowerCase().contains(query);
              final companyMatch = c.companyName?.toLowerCase().contains(query) ?? false;
              final respMatch = c.responsibleName?.toLowerCase().contains(query) ?? false;
              final codeMatch = c.code.toLowerCase().contains(query);
              final phoneMatch = c.phone?.toLowerCase().contains(query) ?? false;
              return nameMatch || companyMatch || respMatch || codeMatch || phoneMatch;
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              backgroundColor: AppColors.surface,
              child: Container(
                width: 440,
                constraints: const BoxConstraints(maxHeight: 520),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title & Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sélectionner un client',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    // Live Search Bar
                    SizedBox(
                      height: 38,
                      child: TextField(
                        autofocus: true,
                        onChanged: (val) => setDialogState(() => search = val),
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un client...',
                          hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Divider(height: 1, color: AppColors.border),
                    SizedBox(height: 4),

                    // "Tous les clients" Option
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      selected: selectedCustomerId == null || selectedCustomerId == 'all',
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                      title: Text(
                        'Tous les clients',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                      trailing: (selectedCustomerId == null || selectedCustomerId == 'all')
                          ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop(Customer(id: 'all', code: '', name: 'Tous les clients', country: ''));
                      },
                    ),

                    // Scrollable Client List
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  'Aucun client trouvé',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final customer = filtered[index];
                                final isSelected = customer.id == selectedCustomerId;
                                final displayName = customer.companyName?.isNotEmpty == true
                                    ? customer.companyName!
                                    : (customer.responsibleName?.isNotEmpty == true
                                        ? customer.responsibleName!
                                        : customer.name);

                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  selected: isSelected,
                                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                  title: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: (customer.code.isNotEmpty || (customer.phone?.isNotEmpty ?? false))
                                      ? Text(
                                          [
                                            if (customer.code.isNotEmpty) customer.code,
                                            if (customer.phone?.isNotEmpty ?? false) customer.phone!,
                                          ].join(' • '),
                                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                      : null,
                                  onTap: () {
                                    Navigator.of(context).pop(customer);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
            hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            prefixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      fillColor: AppColors.surfaceAlt,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              SizedBox(height: 12),
                              Text('Aucune facture trouvee', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.resolveWith((_) => AppColors.background),
                              headingTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                              dataTextStyle: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              dividerThickness: 0.5,
                              columnSpacing: 24,
                              horizontalMargin: 16,
                              columns: [
                                DataColumn(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 24), // Spacer for Checkbox
                                      const SizedBox(width: 12),
                                      const Text('Reference'),
                                    ],
                                  ),
                                ),
                                const DataColumn(label: Text('Client')),
                                const DataColumn(label: Text('Statut')),
                                const DataColumn(label: Text('Montant')),
                                const DataColumn(label: Text('Actions')),
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
        // Checkbox & Reference (number + date)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                child: Checkbox(
                  value: false,
                  onChanged: (_) {},
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(inv.number, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text(
                    formatDateTimeLong(inv.createdAt),
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
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
              color: AppColors.textPrimary,
            ),
          ),
        ),
        // Actions (three dots menu)
        DataCell(
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            offset: Offset(0, 30),
            onSelected: (val) => _handleAction(context, val, inv),
            itemBuilder: (_) => [
              _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
              PopupMenuDivider(height: 1),
              _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
              PopupMenuDivider(height: 1),
              _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
              PopupMenuDivider(height: 1),
              _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
              PopupMenuDivider(height: 1),
              if (inv.status != InvoiceStatus.paid) ...[
                _buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'),
                PopupMenuDivider(height: 1),
              ],
              if (inv.creditNoteId != null && inv.creditNoteId!.isNotEmpty)
                _buildMenuItem('view_credit_note', Icons.receipt_long_outlined, AppColors.primary, 'Voir l\'avoir')
              else
                _buildMenuItem('to_credit_note', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Avoir'),
              PopupMenuDivider(height: 1),
              _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Telecharger PDF'),
              PopupMenuDivider(height: 1),
              _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
              PopupMenuDivider(height: 1),
              _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
              PopupMenuDivider(height: 1),
              _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
//               PopupMenuDivider(height: 1),
//               _buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'),
//               PopupMenuDivider(height: 1),
//               _buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gerer les pieces jointes'),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Rows per page
          Text('Lignes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(width: 8),
          Container(
            height: 32,
            padding: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: DropdownButton<int>(
              value: _rowsPerPage,
              underline: SizedBox(),
              isDense: true,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              items: [10, 20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
              onChanged: (v) => setState(() {
                _rowsPerPage = v ?? 20;
                _currentPage = 0;
              }),
            ),
          ),
          SizedBox(width: 24),
          // Page info
          Text('Page ${_currentPage + 1} sur $totalPages', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(width: 24),
          // Display info
          Text(
            'Affichage de $startRow a $endRow sur $totalRows resultats',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
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

  void _createCreditNoteFromInvoice(BuildContext context, Invoice inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Confirmation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voulez-vous transformer cette facture en avoir ?'),
            const SizedBox(height: 16),
            Text('Facture: ${inv.number}', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Client: ${inv.customerName}'),
            Text('Montant: ${formatCurrencyDT(inv.totalTTC + inv.timbreFiscal)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog

              final now = DateTime.now();
              final String cnId = Uuid().v4();

              final String cnNumber = 'AV-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0');
              
              final creditNote = CreditNote(
                id: cnId,
                number: cnNumber,
                invoiceId: inv.id,
                customerId: inv.customerId,
                customerName: inv.customerName,
                date: now,
                status: CreditNoteStatus.unused,
                totalHT: inv.totalHT > 0 ? -inv.totalHT : inv.totalHT,
                totalTva: inv.totalTva > 0 ? -inv.totalTva : inv.totalTva,
                totalTTC: inv.totalTTC > 0 ? -inv.totalTTC : inv.totalTTC,
                items: inv.items.map((i) => CreditNoteItem(
                  id: const Uuid().v4(),
                  productId: i.productId,
                  quantity: i.quantity > 0 ? -i.quantity : i.quantity,
                  unitPrice: i.unitPrice,
                  tvaRate: i.tvaRate,
                  totalHT: i.totalHT > 0 ? -i.totalHT : i.totalHT,
                )).toList(),
                createdAt: now,
                updatedAt: now,
              );

              // Create the credit note
              context.read<CreditNotesBloc>().add(AddCreditNote(creditNote));
              
              // Update the invoice to link it
              final updatedInvoice = inv.copyWith(creditNoteId: cnId);
              context.read<InvoicesBloc>().add(UpdateInvoice(updatedInvoice));
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Avoir $cnNumber créé avec succès'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value, IconData icon, Color iconColor, String text) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Color(0xFF64748B)),
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, Invoice inv) {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(
              document: DocumentWrapper.fromInvoice(inv),
            ),
          ),
        );
        break;
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
            case 'print':
        final doc = DocumentWrapper.fromInvoice(inv);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;
      case 'add_payment':
        showDialog(
          context: context,
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<PaymentsBloc>()),
              BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
              BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
              BlocProvider.value(value: context.read<InvoicesBloc>()),
            ],
            child: InvoicePaymentDialog(invoice: inv),
          ),
        ).then((created) {
          if (created == true && context.mounted) {
            context.read<InvoicesBloc>().add(LoadInvoices());
          }
        });
        break;
      case 'to_credit_note':
        _createCreditNoteFromInvoice(context, inv);
        break;
      case 'view_credit_note':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Affichage de l\'avoir non implementé')));
        break;
      case 'delete':
        _confirmDelete(inv);
        break;
      case 'status':
        _showChangeStatusDialog(context, inv);
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromInvoice(inv);
        PdfService.instance.downloadDocument(context, doc);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implementee')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, Invoice inv) {
    InvoiceStatus selectedStatus = inv.status;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Changer le statut'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nouveau statut:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: InvoiceStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.label, style: TextStyle(color: s.color, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => selectedStatus = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Notes (optionnel):'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ajouter une note...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<InvoicesBloc>().add(
                    UpdateInvoice(inv.copyWith(status: selectedStatus))
                  );
                  Navigator.pop(dialogCtx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
