import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/shimmer_table_row.dart';
import '../blocs/supplier_returns/supplier_returns_bloc.dart';
import '../blocs/supplier_returns/supplier_returns_event.dart';
import '../blocs/supplier_returns/supplier_returns_state.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../models/supplier_return.dart';
import '../models/supplier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_supplier_return_screen.dart';
import '../blocs/payments/payments_bloc.dart';
import '../models/payment_model.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../services/pdf_service.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';
import 'document_detail_screen.dart';
import '../services/document_share_service.dart';

enum SupplierReturnStatus {
  draft('Brouillon'),
  validated('Validé'),
  canceled('Annulé'),
  paid('Remboursé');

  final String label;
  const SupplierReturnStatus(this.label);

  Color get color {
    switch (this) {
      case draft: return AppColors.warning;
      case validated: return AppColors.success;
      case canceled: return AppColors.error;
      case paid: return AppColors.success;
    }
  }
}

class SupplierReturnsScreen extends StatefulWidget {
  const SupplierReturnsScreen({super.key});

  @override
  State<SupplierReturnsScreen> createState() => _SupplierReturnsScreenState();
}

class _SupplierReturnsScreenState extends State<SupplierReturnsScreen> {
  String? _selectedSupplierId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  SupplierReturnStatus? _statusFilter;

  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<SupplierReturnsBloc>().add(const LoadFirstSupplierReturns());
    context.read<SuppliersBloc>().add(LoadSuppliers());
  }

  void _applyFilters() {
    context.read<SupplierReturnsBloc>().add(LoadFirstSupplierReturns(
      supplierId: _selectedSupplierId,
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
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bons de Retour Fournisseur',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gérer vos bons de retour fournisseur',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (PermissionService.instance.canCreate(UserPermissionResources.purchasesSupplierReturns))
                ElevatedButton.icon(
                  onPressed: () => _navigate(context, null),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Créer un Bon de retour'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
            ],
          ),
        ),

        // Filter Bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: BlocBuilder<SupplierReturnsBloc, SupplierReturnsState>(
            builder: (context, state) {
              return _buildFilterBar(state);
            },
          ),
        ),
        const SizedBox(height: 10),

        // Table
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildTable(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  void _navigate(BuildContext context, SupplierReturn? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<SupplierReturnsBloc>()),
            BlocProvider.value(value: context.read<SuppliersBloc>()),
            BlocProvider.value(value: context.read<ProductsBloc>()),
            BlocProvider.value(value: context.read<ProjectsBloc>()),
            BlocProvider.value(value: context.read<WarehousesBloc>()),
          ],
          child: CreateSupplierReturnScreen(existing: existing),
        ),
      ),
    );
  }

  Widget _buildFilterBar(SupplierReturnsState state) {
    int totalItems = 0;
    if (state is SupplierReturnsLoaded) {
      List<SupplierReturn> filteredReturns = state.returns;
      if (_selectedSupplierId != null && _selectedSupplierId != 'all') {
        filteredReturns = filteredReturns.where((q) => q.supplierId == _selectedSupplierId).toList();
      }
      if (_dateFrom != null) {
        filteredReturns = filteredReturns.where((q) => q.date.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
      }
      if (_dateTo != null) {
        filteredReturns = filteredReturns.where((q) => q.date.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
      }
      if (_statusFilter != null) {
        filteredReturns = filteredReturns.where((q) => q.status == _statusFilter!.name).toList();
      }
      totalItems = filteredReturns.length;
    }

    final activeFilterCount = (_selectedSupplierId != null && _selectedSupplierId != 'all' ? 1 : 0) +
        (_dateFrom != null ? 1 : 0) +
        (_dateTo != null ? 1 : 0) +
        (_statusFilter != null ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Fournisseur dropdown
          Expanded(
            flex: 3,
            child: _filterSection(
              label: 'Fournisseur',
              child: BlocBuilder<SuppliersBloc, SuppliersState>(
                builder: (context, state) {
                  final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                  String selectedSupplierName = 'Tous les fournisseurs';
                  if (_selectedSupplierId != null && _selectedSupplierId != 'all') {
                    final found = suppliers.firstWhere(
                      (s) => s.id == _selectedSupplierId,
                      orElse: () => Supplier(id: '', code: '', name: 'Inconnu', country: ''),
                    );
                    selectedSupplierName = found.companyName?.isNotEmpty == true
                        ? found.companyName!
                        : (found.responsibleName?.isNotEmpty == true ? found.responsibleName! : found.name);
                  }

                  return InkWell(
                    onTap: () async {
                      final selected = await _showSupplierSearchDialog(context, suppliers, _selectedSupplierId);
                      if (selected != null) {
                        setState(() {
                          _selectedSupplierId = selected.id == 'all' ? null : selected.id;
                        });
                        _applyFilters();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedSupplierId == null || _selectedSupplierId == 'all'
                                  ? 'Tous les fournisseurs'
                                  : selectedSupplierName,
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedSupplierId != null && _selectedSupplierId != 'all'
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Date From
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Date de début',
              child: _datePicker(
                value: _dateFrom,
                hint: 'Sélectionner date',
                onPicked: (d) {
                  setState(() => _dateFrom = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Date To
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Date de fin',
              child: _datePicker(
                value: _dateTo,
                hint: 'Sélectionner date',
                onPicked: (d) {
                  setState(() => _dateTo = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Status
          Expanded(
            flex: 2,
            child: _filterSection(
              label: 'Statut',
              child: PopupMenuButton<SupplierReturnStatus?>(
                tooltip: 'Filtrer par statut',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: AppColors.border),
                ),
                color: AppColors.surface,
                elevation: 4,
                offset: const Offset(0, 36),
                initialValue: _statusFilter,
                onSelected: (val) {
                  setState(() => _statusFilter = val);
                  _applyFilters();
                },
                itemBuilder: (context) => [
                  PopupMenuItem<SupplierReturnStatus?>(
                    value: null,
                    height: 34,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Tous',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ),
                        const Spacer(),
                        if (_statusFilter == null)
                          Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                  ...SupplierReturnStatus.values.map(
                    (s) => PopupMenuItem<SupplierReturnStatus?>(
                      value: s,
                      height: 34,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: s.color,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_statusFilter == s)
                            Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _statusFilter != null ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statusFilter == null
                            ? Text(
                                'Tous',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusFilter!.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _statusFilter!.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _statusFilter!.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (activeFilterCount > 0) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _selectedSupplierId = null;
                    _dateFrom = null;
                    _dateTo = null;
                    _statusFilter = null;
                  });
                  _applyFilters();
                },
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
  }

  Widget _filterSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Future<Supplier?> _showSupplierSearchDialog(
    BuildContext context,
    List<Supplier> suppliers,
    String? selectedSupplierId,
  ) async {
    return showDialog<Supplier?>(
      context: context,
      builder: (context) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = search.trim().toLowerCase();
            final filtered = suppliers.where((s) {
              if (query.isEmpty) return true;
              final nameMatch = s.name.toLowerCase().contains(query);
              final companyMatch = s.companyName?.toLowerCase().contains(query) ?? false;
              final respMatch = s.responsibleName?.toLowerCase().contains(query) ?? false;
              final codeMatch = s.code.toLowerCase().contains(query);
              final phoneMatch = s.phone?.toLowerCase().contains(query) ?? false;
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
                          'Sélectionner un fournisseur',
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
                          hintText: 'Rechercher un fournisseur...',
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

                    // "Tous les fournisseurs" Option
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      selected: selectedSupplierId == null || selectedSupplierId == 'all',
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                      title: Text(
                        'Tous les fournisseurs',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                      trailing: (selectedSupplierId == null || selectedSupplierId == 'all')
                          ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop(Supplier(id: 'all', code: '', name: 'Tous les fournisseurs', country: ''));
                      },
                    ),

                    // Scrollable Supplier List
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  'Aucun fournisseur trouvé',
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final supplier = filtered[index];
                                final isSelected = supplier.id == selectedSupplierId;
                                final displayName = supplier.companyName?.isNotEmpty == true
                                    ? supplier.companyName!
                                    : (supplier.responsibleName?.isNotEmpty == true
                                        ? supplier.responsibleName!
                                        : supplier.name);

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
                                  subtitle: (supplier.code.isNotEmpty || (supplier.phone?.isNotEmpty ?? false))
                                      ? Text(
                                          [
                                            if (supplier.code.isNotEmpty) supplier.code,
                                            if (supplier.phone?.isNotEmpty ?? false) supplier.phone!,
                                          ].join(' • '),
                                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                                      : null,
                                  onTap: () {
                                    Navigator.of(context).pop(supplier);
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
    required ValueChanged<DateTime?> onPicked,
  }) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: const Locale('fr', 'FR'),
        );
        if (d != null) onPicked(d);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value != null ? formatDateLong(value) : hint,
                style: TextStyle(
                  fontSize: 12,
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

  Widget _buildTableShimmer() {
    return ShimmerTable(
      headerColumns: [
        const SizedBox(width: 28),
        Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
        Expanded(flex: 3, child: Text('Fournisseur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
        Expanded(flex: 2, child: Container(alignment: Alignment.centerLeft, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)))),
        Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
        SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _buildTable() {
    return BlocBuilder<SupplierReturnsBloc, SupplierReturnsState>(
      builder: (context, state) {
        if (state is SupplierReturnsLoading || state is SupplierReturnsInitial) {
          return _buildTableShimmer();
        }
        if (state is SupplierReturnsError) {
          return Center(
              child: Text(state.message,
                  style: TextStyle(color: AppColors.error)));
        }
        if (state is SupplierReturnsLoaded) {
          final notes = state.returns;
          final total = notes.length;
          final totalPages = total == 0 ? 1 : ((total / _rowsPerPage).ceil().toInt());
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
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border:
                                Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 28),
                              Expanded(
                                  flex: 2,
                                  child: Text('Reference',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppColors.textSecondary))),
                              Expanded(
                                  flex: 3,
                                  child: Text('Fournisseur',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppColors.textSecondary))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Statut',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppColors.textSecondary))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Montant',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppColors.textSecondary))),
                              SizedBox(
                                  width: 60,
                                  child: Text('Actions',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
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
                                          size: 40, color: AppColors.border),
                                      const SizedBox(height: 12),
                                      Text('Aucun bon de retour trouvé',
                                          style: TextStyle(
                                              fontSize: 13,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border:
                                Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Text('Lignes',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Container(
                                height: 28,
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
                                  icon: Icon(Icons.keyboard_arrow_down,
                                      size: 14, color: AppColors.textSecondary),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary),
                                  items: [20, 50, 100]
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
                              const SizedBox(width: 20),
                              Text('Page ${page + 1} sur $totalPages',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                total == 0
                                    ? 'Affichage de 0 à 0 sur 0 résultats'
                                    : 'Affichage de ${start + 1} à $end sur $total résultats',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              _pageButton(
                                icon: Icons.chevron_left,
                                enabled: page > 0,
                                onTap: () =>
                                    setState(() => _currentPage = page - 1),
                              ),
                              const SizedBox(width: 6),
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

  Widget _buildRow(BuildContext context, SupplierReturn note, int index) {
    final statusEnum = SupplierReturnStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => SupplierReturnStatus.draft,
    );
    final FournisseurLabel =
        note.supplierName ?? note.supplierName ?? 'Fournisseur inconnu';
    final isDraft = statusEnum == SupplierReturnStatus.draft;

    return Container(
      color: index % 2 == 0
          ? AppColors.surface
          : AppColors.background.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: false,
              onChanged: (_) {},
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
          ),

          // Reference
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(note.number,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 1),
                Text(formatDateTimeLong(note.date),
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),

          // Fournisseur
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(FournisseurLabel,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
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
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusEnum.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusEnum.label,
                  style: TextStyle(
                      color: statusEnum.color,
                      fontSize: 11.5,
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
                fontSize: 12.5,
                color: isDraft ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz,
                    size: 18, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) => _handleAction(context, val, note),
                itemBuilder: (_) {
                  final items = <PopupMenuEntry<String>>[
                    _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
                    if (PermissionService.instance.canUpdate(UserPermissionResources.purchasesSupplierReturns)) ...[
                      const PopupMenuDivider(height: 1),
                      _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                    ],
                    if (PermissionService.instance.canDelete(UserPermissionResources.purchasesSupplierReturns)) ...[
                      const PopupMenuDivider(height: 1),
                      _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                    ],
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
                    const PopupMenuDivider(height: 1),
                  ];

                  if (note.status != 'paid') {
                    items.add(_buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'));
                    items.add(const PopupMenuDivider(height: 1));
                  }

                  items.addAll([
                    _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Telecharger PDF'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
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

  void _confirmDelete(SupplierReturn note) {
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
                  .read<SupplierReturnsBloc>()
                  .add(DeleteSupplierReturn(note.id));
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

  void _handleAction(BuildContext context, String action, SupplierReturn note) {
    switch (action) {
      case 'view':
        final statusEnum = SupplierReturnStatus.values.firstWhere(
          (e) => e.name == note.status,
          orElse: () => SupplierReturnStatus.draft,
        );
        final doc = DocumentWrapper.fromSupplierReturn(note);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(
              document: doc,
              status: statusEnum.label,
              statusColor: statusEnum.color,
            ),
          ),
        );
        break;
      case 'edit':
        _navigate(context, note);
        break;
            case 'print':
        final doc = DocumentWrapper.fromSupplierReturn(note);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;
      case 'add_payment':
        _showAddPaymentDialog(context, note);
        break;
      case 'delete':
        _confirmDelete(note);
        break;
      case 'status':
        _showChangeStatusDialog(context, note);
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromSupplierReturn(note);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromSupplierReturn(note);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromSupplierReturn(note);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implementee')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, SupplierReturn note) {
    SupplierReturnStatus selectedStatus = SupplierReturnStatus.values.firstWhere(
      (e) => e.name == note.status,
      orElse: () => SupplierReturnStatus.draft,
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
                    items: SupplierReturnStatus.values.map((s) => DropdownMenuItem(
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
                  context.read<SupplierReturnsBloc>().add(
                    UpdateSupplierReturn(note.copyWith(status: selectedStatus.name))
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

  void _showAddPaymentDialog(BuildContext context, SupplierReturn note) {
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
                  contactId: note.supplierId,
                  contactType: 'Supplier',
                  contactName: note.supplierName ?? note.supplierName,
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
                
                // Update SupplierReturn status to 'paid' if amount covers it
                if (amount >= note.totalTTC - 0.01) {
                  context.read<SupplierReturnsBloc>().add(UpdateSupplierReturn(
                    note.copyWith(status: SupplierReturnStatus.paid.name)
                  ));
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
}

