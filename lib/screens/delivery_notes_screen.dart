import 'package:flutter/material.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../widgets/delivery_note_payment_dialog.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/delivery_note.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_delivery_note_screen.dart';
import '../blocs/payments/payments_bloc.dart';
import '../models/payment_model.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../blocs/return_notes/return_notes_bloc.dart';
import '../blocs/return_notes/return_notes_event.dart';
import '../models/invoice.dart';
import '../models/return_note.dart';
import 'create_invoice_screen.dart';
import 'create_return_note_screen.dart';
import '../services/pdf_service.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';

class DeliveryNotesScreen extends StatefulWidget {
  const DeliveryNotesScreen({super.key});

  @override
  State<DeliveryNotesScreen> createState() => _DeliveryNotesScreenState();
}

class _DeliveryNotesScreenState extends State<DeliveryNotesScreen> {
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  DeliveryNoteStatus? _statusFilter;

  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<DeliveryNotesBloc>().add(LoadDeliveryNotes());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  void _applyFilters() {
    context.read<DeliveryNotesBloc>().add(FilterDeliveryNotes(
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
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Bon de Livraison',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 8),
                     
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gerer vos bons de livraison',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _navigate(context, null),
                icon: Icon(Icons.add_rounded, size: 18),
                label: Text('Creer un Bon de Livraison'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ),

        // ── Filter Bar ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: BlocBuilder<DeliveryNotesBloc, DeliveryNotesState>(
            builder: (context, state) {
              return _buildFilterBar(state);
            },
          ),
        ),
        SizedBox(height: AppSpacing.lg),

        // ── Table ──
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildTable(),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _navigate(BuildContext context, DeliveryNote? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
            BlocProvider.value(value: context.read<CustomersBloc>()),
            BlocProvider.value(value: context.read<ProductsBloc>()),
            BlocProvider.value(value: context.read<ProjectsBloc>()),
          ],
          child: CreateDeliveryNoteScreen(existing: existing),
        ),
      ),
    );
  }

  Widget _buildFilterBar(DeliveryNotesState state) {
    int totalItems = 0;
    if (state is DeliveryNotesLoaded) {
      List<DeliveryNote> filteredOrders = state.notes;
      if (_selectedClientId != null && _selectedClientId != 'all') {
        filteredOrders = filteredOrders.where((q) => q.customerId == _selectedClientId).toList();
      }
      if (_dateFrom != null) {
        filteredOrders = filteredOrders.where((q) => q.date.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
      }
      if (_dateTo != null) {
        filteredOrders = filteredOrders.where((q) => q.date.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
      }
      if (_statusFilter != null) {
        filteredOrders = filteredOrders.where((q) => q.status == _statusFilter!.name).toList();
      }
      totalItems = filteredOrders.length;
    }

    final activeFilterCount = (_selectedClientId != null && _selectedClientId != 'all' ? 1 : 0) +
        (_dateFrom != null ? 1 : 0) +
        (_dateTo != null ? 1 : 0) +
        (_statusFilter != null ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Client dropdown
          Expanded(
            flex: 3,
            child: _filterSection(
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
                      padding: EdgeInsets.symmetric(horizontal: 12),
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
          SizedBox(width: AppSpacing.md),

          // Date From
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
          SizedBox(width: AppSpacing.md),

          // Date To
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
          SizedBox(width: AppSpacing.md),

          // Status
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Statut',
              child: PopupMenuButton<DeliveryNoteStatus?>(
                tooltip: 'Filtrer par statut',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(color: AppColors.border),
                ),
                color: AppColors.surface,
                elevation: 6,
                offset: const Offset(0, 44),
                initialValue: _statusFilter,
                onSelected: (val) {
                  setState(() => _statusFilter = val);
                  _applyFilters();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<DeliveryNoteStatus?>(
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
                  ...DeliveryNoteStatus.values.map(
                    (s) => PopupMenuItem<DeliveryNoteStatus?>(
                      value: s,
                      height: 38,
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  _applyFilters();
                },
                icon: Icon(Icons.refresh_rounded, size: 16),
                label: Text('Réinitialiser les filtres'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
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
                padding: EdgeInsets.all(AppSpacing.md),
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

  Widget _filterSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 8),
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
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
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
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textSecondary),
            SizedBox(width: 8),
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
    return BlocBuilder<DeliveryNotesBloc, DeliveryNotesState>(
      builder: (context, state) {
        if (state is DeliveryNotesLoading) {
          return Center(child: CircularProgressIndicator());
        }
        if (state is DeliveryNotesError) {
          return Center(
              child: Text(state.message,
                  style: TextStyle(color: AppColors.error)));
        }
        if (state is DeliveryNotesLoaded) {
          final notes = state.notes;
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border:
                                Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 32),
                              Expanded(
                                  flex: 2,
                                  child: Text('Reference',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              Expanded(
                                  flex: 3,
                                  child: Text('Client',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Statut',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Montant',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textSecondary))),
                              SizedBox(
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
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.local_shipping_outlined,
                                          size: 48, color: AppColors.border),
                                      SizedBox(height: 16),
                                      Text('Aucun bon de livraison trouve',
                                          style: TextStyle(
                                              color: AppColors.textSecondary)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: pageNotes.length,
                                  separatorBuilder: (_, __) => Divider(
                                      height: 1, color: AppColors.border),
                                  itemBuilder: (context, i) =>
                                      _buildRow(context, pageNotes[i], i),
                                ),
                        ),

                        // Pagination footer
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border:
                                Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Text('Lignes',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                              SizedBox(width: 8),
                              Container(
                                height: 32,
                                padding:
                                    EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: SizedBox(),
                                  icon: Icon(Icons.keyboard_arrow_down,
                                      size: 16),
                                  style: TextStyle(
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
                              SizedBox(width: 24),
                              Text('Page ${page + 1} sur $totalPages',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                total == 0
                                    ? 'Affichage de 0 a 0 sur 0 resultats'
                                    : 'Affichage de ${start + 1} a $end sur $total resultats',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                              SizedBox(width: 16),
                              _pageButton(
                                icon: Icons.chevron_left,
                                enabled: page > 0,
                                onTap: () =>
                                    setState(() => _currentPage = page - 1),
                              ),
                              SizedBox(width: 8),
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
        return SizedBox();
      },
    );
  }

  Widget _buildRow(BuildContext context, DeliveryNote note, int index) {
    final statusEnum = DeliveryNoteStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => DeliveryNoteStatus.draft,
    );
    final clientLabel =
        note.customerCompany ?? note.customerName ?? 'Client inconnu';
    final isDraft = statusEnum == DeliveryNoteStatus.draft;

    return Container(
      color: index % 2 == 0
          ? AppColors.surface
          : AppColors.background.withValues(alpha: 0.3),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: false,
              onChanged: (_) {},
              side: BorderSide(color: AppColors.border),
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
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                SizedBox(height: 3),
                Text(formatDateTimeLong(note.date),
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),

          // Client
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(clientLabel,
                      style: TextStyle(
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
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                icon: Icon(Icons.more_horiz,
                    color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) => _handleAction(context, val, note),
                itemBuilder: (_) {
                  final items = <PopupMenuEntry<String>>[
                    _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
                    PopupMenuDivider(height: 1),
                    _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                    PopupMenuDivider(height: 1),
                    _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                    PopupMenuDivider(height: 1),
                    _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
                    const PopupMenuDivider(height: 1),
                  ];

                  if (note.isConvertedToInvoice) {
                    items.add(_buildMenuItem('view_invoice', Icons.receipt_long_outlined, AppColors.success, 'Voir la facture creee'));
                  } else if (note.isConvertedToReturn) {
                    items.add(_buildMenuItem('view_return', Icons.assignment_return_outlined, AppColors.success, 'Voir le bon de retour cree'));
                  } else {
                    if (note.status != 'paid') {
                      items.add(_buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'));
                      items.add(const PopupMenuDivider(height: 1));
                    }
                    items.add(_buildMenuItem('to_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Facture'));
                    items.add(const PopupMenuDivider(height: 1));
                    items.add(_buildMenuItem('to_return', Icons.assignment_return_outlined, AppColors.textSecondary, 'Transformer en Bon de Retour'));
                  }

                  items.addAll([
                    PopupMenuDivider(height: 1),
                    _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Telecharger PDF'),
                    PopupMenuDivider(height: 1),
                    _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                    PopupMenuDivider(height: 1),
                    _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
                    PopupMenuDivider(height: 1),
                    _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
//                     PopupMenuDivider(height: 1),
//                     _buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'),
//                     PopupMenuDivider(height: 1),
//                     _buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gerer les pieces jointes'),
                  ]);
                  
                  return items;
                },
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
        padding: EdgeInsets.all(4),
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

  void _confirmDelete(DeliveryNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text(
            'Voulez-vous vraiment supprimer le bon ${note.number} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<DeliveryNotesBloc>()
                  .add(DeleteDeliveryNote(note.id));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color iconColor, String text) {
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

  void _handleAction(BuildContext context, String action, DeliveryNote note) {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(
              document: DocumentWrapper.fromDeliveryNote(note),
            ),
          ),
        );
        break;
      case 'edit':
        _navigate(context, note);
        break;
      case 'duplicate':
        // TODO: Duplicate logic
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromDeliveryNote(note);
        PdfService.instance.downloadDocument(context, doc);
        break;
            case 'print':
        final doc = DocumentWrapper.fromDeliveryNote(note);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;
      case 'to_invoice':
        _showInvoiceConversionDialog(context, note);
        break;
      case 'view_invoice':
        _openConvertedInvoice(context, note.convertedToInvoiceId);
        break;
      case 'to_return':
        _showReturnConversionDialog(context, note);
        break;
      case 'view_return':
        _openConvertedReturn(context, note.convertedToReturnId);
        break;
      case 'add_payment':
        showDialog(
          context: context,
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<PaymentsBloc>()),
              BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
              BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
              BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
            ],
            child: DeliveryNotePaymentDialog(deliveryNote: note),
          ),
        ).then((created) {
          if (created == true && context.mounted) {
            context.read<DeliveryNotesBloc>().add(LoadDeliveryNotes());
          }
        });
        break;
      case 'delete':
        _confirmDelete(note);
        break;
      case 'status':
        _showChangeStatusDialog(context, note);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implementee')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, DeliveryNote note) {
    DeliveryNoteStatus selectedStatus = DeliveryNoteStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => DeliveryNoteStatus.draft,
    );
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Changer le statut'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nouveau statut:'),
                  SizedBox(height: 8),
                  DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    value: selectedStatus,
                    decoration: InputDecoration(border: OutlineInputBorder()),
                    items: DeliveryNoteStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  SizedBox(height: 16),
                  Text('Notes (optionnel):'),
                  SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
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
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<DeliveryNotesBloc>().add(
                    UpdateDeliveryNote(note.copyWith(status: selectedStatus.name))
                  );
                  Navigator.pop(dialogCtx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, DeliveryNote note) {
    final amountCtrl = TextEditingController(text: note.totalTTC.toStringAsFixed(3));
    final methodNotifier = ValueNotifier<String>('especes');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter un paiement pour BL ${note.number}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(
                labelText: 'Montant (DT)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: methodNotifier,
              builder: (context, val, child) => DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                value: val,
                decoration: InputDecoration(
                  labelText: 'Methode de paiement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'especes', child: Text('Especes')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'virement', child: Text('Virement')),
                  DropdownMenuItem(value: 'carte', child: Text('Carte')),
                ],
                onChanged: (v) {
                  if (v != null) methodNotifier.value = v;
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final amountStr = amountCtrl.text.replaceAll(',', '.');
              final amount = double.tryParse(amountStr) ?? 0.0;
              if (amount > 0) {
                final payment = Payment(
                  id: const Uuid().v4(),
                  paymentNumber: 'PAI-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 1000000}',
                  direction: 'encaissement',
                  contactId: note.customerId,
                  contactType: 'customer',
                  contactName: note.customerName ?? note.customerCompany,
                  amount: amount,
                  method: methodNotifier.value,
                  reference: note.number,
                  paymentDate: DateTime.now(),
                  status: 'paid',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                
                try {
                  context.read<PaymentsBloc>().add(AddPayment(payment));
                } catch (e) {
                  await DatabaseHelper.instance.insertPayment(payment);
                }
                
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Paiement ajoute avec succes'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Veuillez entrer un montant valide'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showInvoiceConversionDialog(BuildContext context, DeliveryNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            Text('Voulez-vous transformer ce bon de livraison en facture ?'),
            SizedBox(height: 16),
            Text('BL: ${note.number}', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${note.customerName ?? note.customerCompany ?? "Inconnu"}'),
            Text('Montant: ${formatCurrencyDT(note.totalTTC)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _convertDeliveryToInvoice(context, note);
            },
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _convertDeliveryToInvoice(BuildContext context, DeliveryNote note) {
    final now = DateTime.now();
    final year = now.year;
    final seq = now.millisecondsSinceEpoch % 100000;
    final invoiceNumber = 'FAC-$year-${seq.toString().padLeft(5, '0')}';

    final invoiceItems = note.items.map((i) => InvoiceItem(
      id: const Uuid().v4(),
      invoiceId: '', // Will be set in Invoice constructor/DB
      productId: i.productId,
      description: i.description,
      quantity: i.quantity,
      unitPrice: i.unitPrice,
      tvaRate: i.tvaRate,
      discountPercent: i.discountPercent,
      totalHT: i.totalHT,
      showDescription: i.showDescription,
      showDiscount: i.showDiscount,
    )).toList();

    final newInvoice = Invoice(
      id: const Uuid().v4(),
      number: invoiceNumber,
      customerId: note.customerId,
      customerName: note.customerName,
      orderId: note.orderId,
      deliveryNoteId: note.id,
      projectId: note.projectId,
      projectName: note.projectName,
      date: now,
      dueDate: now.add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid,
      totalHT: note.totalHTAfterDiscount,
      totalTva: note.totalTVA,
      totalTTC: note.totalTTC,
      pricingMode: note.pricingMode,
      globalDiscountPercent: note.globalDiscountPercent,
      globalDiscountAmount: note.globalDiscountAmount,
      timbreFiscal: note.timbreFiscal,
      notes: note.notes,
      conditionsGenerales: note.conditionsGenerales,
      items: invoiceItems,
    );

    context.read<InvoicesBloc>().add(AddInvoice(newInvoice));

    final updatedNote = note.copyWith(
      isConvertedToInvoice: true,
      convertedToInvoiceId: newInvoice.id,
      status: DeliveryNoteStatus.invoiced.name,
    );
    context.read<DeliveryNotesBloc>().add(UpdateDeliveryNote(updatedNote));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Facture $invoiceNumber creee avec succes'),
      backgroundColor: AppColors.success,
    ));
  }

  void _showReturnConversionDialog(BuildContext context, DeliveryNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            Text('Voulez-vous transformer ce bon de livraison en bon de retour ?'),
            SizedBox(height: 16),
            Text('BL: ${note.number}', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${note.customerName ?? note.customerCompany ?? "Inconnu"}'),
            Text('Montant: ${formatCurrencyDT(note.totalTTC)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _convertDeliveryToReturn(context, note);
            },
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _convertDeliveryToReturn(BuildContext context, DeliveryNote note) async {
    final now = DateTime.now();
    final year = now.year;
    
    // Get next return number sequence
    final seq = await DatabaseHelper.instance.getNextReturnNoteSequence();
    final returnNumber = 'RET-$year-${seq.toString().padLeft(5, '0')}';

    final returnItems = note.items.map((i) => ReturnNoteItem(
      id: const Uuid().v4(),
      returnNoteId: '', // Will be set in DB when saving if needed, but the model doesn't strictly enforce it for items if generated
      productId: i.productId,
      designation: i.description ?? '',
      quantity: -i.quantity, // Negative for returns
      unitPrice: i.unitPrice,
      tvaRate: i.tvaRate,
      totalHT: -i.totalHT, // Negative for returns
    )).toList();

    final newReturn = ReturnNote(
      id: const Uuid().v4(),
      returnNumber: returnNumber,
      customerId: note.customerId,
      customerName: note.customerName,
      customerCompany: note.customerCompany,
      deliveryNoteId: note.id,
      dateEmission: now,
      status: ReturnNoteStatus.validated.name,
      subtotalHT: -note.subTotalHT,
      totalTTC: -note.totalTTC,
      notes: note.notes,
      conditions: note.conditionsGenerales,
      items: returnItems,
    );

    for (var item in newReturn.items) {
      // Re-assign return note ID properly
      // Using copyWith is not possible if it doesn't exist, we can use a small hack or just re-map
    }
    
    final finalItems = returnItems.map((i) => i.copyWith(returnNoteId: newReturn.id)).toList();
    final returnWithItems = newReturn.copyWith(items: finalItems);

    if (!context.mounted) return;
    context.read<ReturnNotesBloc>().add(AddReturnNote(returnWithItems));

    final updatedNote = note.copyWith(
      isConvertedToReturn: true,
      convertedToReturnId: returnWithItems.id,
      status: DeliveryNoteStatus.returned.name,
    );
    context.read<DeliveryNotesBloc>().add(UpdateDeliveryNote(updatedNote));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Bon de retour $returnNumber cree avec succes'),
      backgroundColor: AppColors.success,
    ));
  }

  Future<void> _openConvertedReturn(BuildContext context, String? returnId) async {
    if (returnId == null) return;
    
    final returnNote = await DatabaseHelper.instance.getReturnNote(returnId);
    if (!context.mounted) return;
    if (returnNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bon de retour introuvable'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<ReturnNotesBloc>()),
              BlocProvider.value(value: context.read<CustomersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
              BlocProvider.value(value: context.read<ProjectsBloc>()),
            ],
            child: CreateReturnNoteScreen(existing: returnNote),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Impossible d\'ouvrir le bon de retour'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _openConvertedInvoice(BuildContext context, String? invoiceId) async {
    if (invoiceId == null) return;
    
    final invoice = await DatabaseHelper.instance.getInvoice(invoiceId);
    if (!context.mounted) return;
    if (invoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Facture introuvable'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    try {
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
            child: CreateInvoiceScreen(existing: invoice),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Impossible d\'ouvrir la facture'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}
