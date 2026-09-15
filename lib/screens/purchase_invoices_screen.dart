import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import '../utils/file_download_helper.dart';
import '../models/document_wrapper.dart';
import 'package:uuid/uuid.dart';
import '../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../services/sync_service.dart';
import '../widgets/pending_sync_badge.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../models/purchase_invoice.dart';
import '../models/supplier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/purchase_invoice_payment_dialog.dart';
import '../blocs/payments/payments_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/stock/stock_bloc.dart';
import '../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import '../models/supplier_credit_note.dart';
import 'create_purchase_invoice_screen.dart';
import '../services/pdf_service.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'document_preview_screen.dart';
import 'document_detail_screen.dart';
import '../utils/offline_action_helper.dart';
import '../services/document_share_service.dart';
import '../services/document_numbering_service.dart';
import '../database/database_helper.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';
import '../services/custom_status_service.dart';
import '../widgets/dialogs/change_status_dialog.dart';
import '../widgets/document_status_filter_dropdown.dart';
import '../l10n/app_localizations.dart';

class PurchaseInvoicesScreen extends StatefulWidget {
  const PurchaseInvoicesScreen({super.key});
  @override
  State<PurchaseInvoicesScreen> createState() => _PurchaseInvoicesScreenState();
}

class _PurchaseInvoicesScreenState extends State<PurchaseInvoicesScreen> {
  final Set<String> _selectedPurchaseInvoiceIds = {};

  // Filter state
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _statusFilter;

  // Pagination state
  int _rowsPerPage = 20;
  int _currentPage = 0;

  StreamSubscription<int>? _syncSub;

  @override
  void initState() {
    super.initState();
    context.read<PurchaseInvoicesBloc>().add(const LoadFirstPurchaseInvoices());
    context.read<SuppliersBloc>().add(LoadSuppliers());

    _syncSub = SyncService.instance.onDocumentSyncCompleted.listen((count) {
      if (mounted && count > 0) {
        context.read<PurchaseInvoicesBloc>().add(const LoadFirstPurchaseInvoices());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('$count ${context.tr('document(s) synchronisé(s) avec succès !')}'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  void _applyFilters() {
    _selectedPurchaseInvoiceIds.clear();
    context.read<PurchaseInvoicesBloc>().add(LoadFirstPurchaseInvoices(
      supplierId: _selectedClientId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter,
    ));
    setState(() {
      _currentPage = 0;
    });
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Factures d\'achat'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(context.tr('Gérer vos factures d\'achat'), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              Row(
                children: [
                  if (_selectedPurchaseInvoiceIds.isNotEmpty) ...[
                    _buildBulkActionsDropdown(),
                    const SizedBox(width: 10),
                  ],
                  if (PermissionService.instance.canCreate(UserPermissionResources.purchasesPurchaseInvoices))
                    AppButton(
                      label: context.tr('Nouvelle facture'),
                      icon: Icons.add_rounded,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MultiBlocProvider(
                            providers: [
                              BlocProvider.value(value: context.read<PurchaseInvoicesBloc>()),
                              BlocProvider.value(value: context.read<SuppliersBloc>()),
                              BlocProvider.value(value: context.read<ProductsBloc>()),
                              BlocProvider.value(value: context.read<ProjectsBloc>()),
                              BlocProvider.value(value: context.read<WarehousesBloc>()),
                            ],
                            child: const CreatePurchaseInvoiceScreen(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Filter bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: BlocBuilder<PurchaseInvoicesBloc, PurchaseInvoicesState>(
            builder: (context, state) {
              return _buildFilterBar(state);
            },
          ),
        ),
        const SizedBox(height: 10),
        // Data table
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _buildPurchaseInvoiceTable(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildFilterBar(PurchaseInvoicesState state) {
    int totalItems = 0;
    if (state is PurchaseInvoicesLoaded) {
      List<PurchaseInvoice> filteredInvoices = state.filteredPurchaseInvoices;
      if (_selectedClientId != null && _selectedClientId != 'all') {
        filteredInvoices = filteredInvoices.where((q) => q.supplierId == _selectedClientId).toList();
      }
      if (_dateFrom != null) {
        filteredInvoices = filteredInvoices.where((q) => q.date.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
      }
      if (_dateTo != null) {
        filteredInvoices = filteredInvoices.where((q) => q.date.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
      }
      if (_statusFilter != null) {
        filteredInvoices = filteredInvoices.where((q) => q.effectiveStatus == _statusFilter || q.status.name == _statusFilter).toList();
      }
      totalItems = filteredInvoices.length;
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Supplier filter
          Expanded(
            flex: 3,
            child: _buildFilterField(
              label: context.tr('Fournisseur'),
              child: BlocBuilder<SuppliersBloc, SuppliersState>(
                builder: (context, state) {
                  final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                  String selectedSupplierName = context.tr('Tous les fournisseurs');
                  if (_selectedClientId != null && _selectedClientId != 'all') {
                    final found = suppliers.firstWhere(
                      (s) => s.id == _selectedClientId,
                      orElse: () => Supplier(id: '', code: '', name: context.tr('Inconnu'), country: ''),
                    );
                    selectedSupplierName = found.companyName?.isNotEmpty == true
                        ? found.companyName!
                        : (found.responsibleName?.isNotEmpty == true ? found.responsibleName! : found.name);
                  }

                  return InkWell(
                    onTap: () async {
                      final selected = await _showSupplierSearchDialog(context, suppliers, _selectedClientId);
                      if (selected != null) {
                        setState(() {
                          _selectedClientId = selected.id == 'all' ? null : selected.id;
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
                              _selectedClientId == null || _selectedClientId == 'all'
                                  ? context.tr('Tous les fournisseurs')
                                  : selectedSupplierName,
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedClientId != null && _selectedClientId != 'all'
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
          // Date de debut
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: context.tr('Date de début'),
              child: _buildDateFilterField(
                value: _dateFrom,
                hint: context.tr('Sélectionner date'),
                onChanged: (d) {
                  setState(() => _dateFrom = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Date de fin
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: context.tr('Date de fin'),
              child: _buildDateFilterField(
                value: _dateTo,
                hint: context.tr('Sélectionner date'),
                onChanged: (d) {
                  setState(() => _dateTo = d);
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Status filter
          Expanded(
            flex: 2,
            child: _buildFilterField(
              label: context.tr('Statut'),
              child: DocumentStatusFilterDropdown(
                documentType: 'purchase_invoice',
                currentStatusFilter: _statusFilter,
                onStatusSelected: (v) {
                  setState(() => _statusFilter = v);
                  _applyFilters();
                },
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
                    _selectedClientId = null;
                    _dateFrom = null;
                    _dateTo = null;
                    _statusFilter = null;
                    _currentPage = 0;
                  });
                  context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: context.tr('Réinitialiser les filtres'),
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

  Widget _buildFilterField({required String label, required Widget child}) {
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

  Widget _buildDateFilterField({
    DateTime? value,
    required String hint,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: Localizations.localeOf(context),
        );
        if (picked != null) onChanged(picked);
      },
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
                style: TextStyle(fontSize: 12, color: value != null ? AppColors.textPrimary : AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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
                          context.tr('Sélectionner un fournisseur'),
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
                          hintText: context.tr('Rechercher un fournisseur...'),
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
                        context.tr('Tous les fournisseurs'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                      trailing: (selectedSupplierId == null || selectedSupplierId == 'all')
                          ? Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop(Supplier(id: 'all', code: '', name: context.tr('Tous les fournisseurs'), country: ''));
                      },
                    ),

                    // Scrollable Supplier List
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  context.tr('Aucun fournisseur trouvé'),
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

  Widget _buildTableShimmer() {
    return ShimmerTable(
      headerColumns: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: false,
            onChanged: null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: AppColors.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: Text(context.tr('Reference'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
        Expanded(flex: 3, child: Text(context.tr('Fournisseur'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
        Expanded(flex: 2, child: Container(alignment: Alignment.centerLeft, child: Text(context.tr('Statut'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)))),
        Expanded(flex: 2, child: Text(context.tr('Montant'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
        SizedBox(width: 60, child: Text(context.tr('Actions'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _buildPurchaseInvoiceTable() {
    return BlocBuilder<PurchaseInvoicesBloc, PurchaseInvoicesState>(
      builder: (context, state) {
        if (state is PurchaseInvoicesLoading || state is PurchaseInvoicesInitial) return _buildTableShimmer();
        if (state is PurchaseInvoicesError) return AppErrorWidget(message: state.message);
        if (state is PurchaseInvoicesLoaded) {
          List<PurchaseInvoice> filteredInvoices = state.filteredPurchaseInvoices;
          if (_selectedClientId != null && _selectedClientId != 'all') {
            filteredInvoices = filteredInvoices.where((q) => q.supplierId == _selectedClientId).toList();
          }
          if (_dateFrom != null) {
            filteredInvoices = filteredInvoices.where((q) => q.date.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
          }
          if (_dateTo != null) {
            filteredInvoices = filteredInvoices.where((q) => q.date.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
          }
          if (_statusFilter != null) {
            filteredInvoices = filteredInvoices.where((q) => q.effectiveStatus == _statusFilter || q.status.name == _statusFilter).toList();
          }
          final purchaseInvoices = filteredInvoices;
          final totalRows = purchaseInvoices.length;
          final int totalPages = (totalRows / _rowsPerPage).ceil().clamp(1, 9999).toInt();
          _currentPage = _currentPage.clamp(0, totalPages - 1);
          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
          final pagePurchaseInvoices = totalRows > 0 ? purchaseInvoices.sublist(startIndex, endIndex) : <PurchaseInvoice>[];

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
                  child: pagePurchaseInvoices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textTertiary),
                              SizedBox(height: 12),
                              Text(context.tr('Aucune facture trouvee'), style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              showCheckboxColumn: false,
                              headingRowHeight: 38,
                              dataRowMinHeight: 42,
                              dataRowMaxHeight: 46,
                              headingRowColor: WidgetStateProperty.resolveWith((_) => AppColors.background),
                              headingTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                              dataTextStyle: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                              dividerThickness: 0.5,
                              columnSpacing: 20,
                              horizontalMargin: 16,
                              columns: [
                                DataColumn(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Checkbox(
                                          value: pagePurchaseInvoices.isNotEmpty && pagePurchaseInvoices.every((inv) => _selectedPurchaseInvoiceIds.contains(inv.id)),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedPurchaseInvoiceIds.addAll(pagePurchaseInvoices.map((inv) => inv.id));
                                              } else {
                                                for (final inv in pagePurchaseInvoices) {
                                                  _selectedPurchaseInvoiceIds.remove(inv.id);
                                                }
                                              }
                                            });
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(context.tr('Reference')),
                                    ],
                                  ),
                                ),
                                DataColumn(label: Text(context.tr('Fournisseur'))),
                                DataColumn(label: Text(context.tr('Statut'))),
                                DataColumn(label: Text(context.tr('Montant'))),
                                DataColumn(label: Text(context.tr('Actions'))),
                              ],
                              rows: pagePurchaseInvoices.map((inv) => _buildPurchaseInvoiceRow(inv)).toList(),
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

  DataRow _buildPurchaseInvoiceRow(PurchaseInvoice inv) {
    final isSelected = _selectedPurchaseInvoiceIds.contains(inv.id);
    return DataRow(
      selected: isSelected,
      onSelectChanged: (_) {
        setState(() {
          if (isSelected) {
            _selectedPurchaseInvoiceIds.remove(inv.id);
          } else {
            _selectedPurchaseInvoiceIds.add(inv.id);
          }
        });
      },
      cells: [
        // Checkbox & Reference (number + date)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedPurchaseInvoiceIds.add(inv.id);
                      } else {
                        _selectedPurchaseInvoiceIds.remove(inv.id);
                      }
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(inv.number, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textPrimary)),
                  const SizedBox(height: 1),
                  Text(
                    formatDateTimeLong(inv.createdAt),
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Supplier (icon + name + company)
        DataCell(
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(inv.supplierName ?? '—', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        // Statut badge
        DataCell((!inv.isSynced || inv.number.startsWith('BROUILLON-'))
            ? const PendingSyncBadge()
            : () {
                final sInfo = CustomStatusService.instance.getStatusInfo('purchase_invoice', inv.effectiveStatus, fallbackLabel: inv.status.label, fallbackColor: inv.status.color);
                return StatusBadge(label: context.tr(sInfo.label), color: sInfo.color);
              }()),
        // Montant
        DataCell(
          Text(
            formatCurrencyDT(inv.totalTTC + inv.timbreFiscal),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        // Actions (three dots menu)
        DataCell(
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            offset: const Offset(0, 30),
            onSelected: (val) => _handleAction(context, val, inv),
            itemBuilder: (_) {
              final canRead = PermissionService.instance.hasPermission('purchase_invoices', action: 'read');
              final canUpdate = PermissionService.instance.hasPermission('purchase_invoices', action: 'update');
              final canDelete = PermissionService.instance.hasPermission('purchase_invoices', action: 'delete');
              final hasAnyAccess = PermissionService.instance.hasAnyPermission('purchase_invoices');
              final hasAllAccess = PermissionService.instance.hasPermission('purchase_invoices', action: 'all');
              final canCreatePayment = PermissionService.instance.hasPermission('payments', action: 'create') || hasAllAccess;
              final canCreateCreditNote = hasAllAccess;

              debugPrint('[PurchaseInvoices.3dot] Invoice #${inv.number} building menu: canRead=$canRead, canUpdate=$canUpdate, canDelete=$canDelete, hasAnyAccess=$hasAnyAccess, hasAllAccess=$hasAllAccess, canCreatePayment=$canCreatePayment, canCreateCreditNote=$canCreateCreditNote, isAdmin=${PermissionService.instance.isAdmin}');

              final entries = <PopupMenuEntry<String>>[];

              void addItem(String val, IconData icon, Color col, String label) {
                if (entries.isNotEmpty) entries.add(const PopupMenuDivider(height: 1));
                entries.add(_buildMenuItem(val, icon, col, context.tr(label)));
              }

              if (canRead) {
                addItem('view', Icons.visibility_outlined, AppColors.info, 'Voir');
              }
              if (canUpdate) {
                addItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier');
              }
              if (canDelete) {
                addItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer');
              }

              if (inv.status != InvoiceStatus.paid && canCreatePayment) {
                addItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement');
              }

              if (inv.creditNoteId != null && inv.creditNoteId!.isNotEmpty) {
                if (canRead) {
                  addItem('view_credit_note', Icons.receipt_long_outlined, AppColors.primary, 'Voir l\'avoir');
                }
              } else if (canCreateCreditNote) {
                addItem('to_credit_note', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Avoir');
              }

              if (hasAnyAccess) {
                addItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer');
                addItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Télécharger PDF');
                addItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email');
                addItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp');
              }
              if (hasAllAccess) {
                addItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut');
              }

              return entries;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationBar(int totalRows, int totalPages) {
    final startRow = totalRows > 0 ? (_currentPage * _rowsPerPage) + 1 : 0;
    final endRow = ((_currentPage + 1) * _rowsPerPage).clamp(0, totalRows);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Rows per page
          Text(context.tr('Lignes'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
              color: AppColors.surface,
            ),
            child: DropdownButton<int>(
              value: _rowsPerPage,
              underline: const SizedBox(),
              icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              items: [20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
              onChanged: (v) => setState(() {
                _rowsPerPage = v ?? 20;
                _currentPage = 0;
              }),
            ),
          ),
          const SizedBox(width: 20),
          // Page info
          Text('${context.tr('Page')} ${_currentPage + 1} ${context.tr('sur')} $totalPages', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          // Display info
          Text(
            totalRows == 0 ? '${context.tr('Affichage de')} 0 ${context.tr('à')} 0 ${context.tr('sur')} 0 ${context.tr('résultats')}' : '${context.tr('Affichage de')} $startRow ${context.tr('à')} $endRow ${context.tr('sur')} $totalRows ${context.tr('résultats')}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          // Navigation buttons
          Row(
            children: [
              InkWell(
                onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.surface,
                  ),
                  child: Icon(Icons.chevron_left, size: 18, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: _currentPage < totalPages - 1 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.surface,
                  ),
                  child: Icon(Icons.chevron_right, size: 18, color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(PurchaseInvoice inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Confirmer la suppression')),
        content: Text('${context.tr('Voulez-vous vraiment supprimer la facture')} ${inv.number} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Annuler'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PurchaseInvoicesBloc>().add(DeletePurchaseInvoice(inv.id));
              context.read<StockBloc>().add(LoadStock());
              context.read<ProductsBloc>().add(const ResetProductsPagination());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Supprimer'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _createCreditNoteFromPurchaseInvoice(BuildContext context, PurchaseInvoice inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text(context.tr('Confirmation')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Voulez-vous transformer cette facture en avoir ?')),
            SizedBox(height: 16),
            Text('${context.tr('Facture')}: ${inv.number}', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${context.tr('Fournisseur')}: ${inv.supplierName ?? context.tr('Inconnu')}'),
            Text('${context.tr('Montant')}: ${formatCurrencyDT(inv.totalTTC + inv.timbreFiscal)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Annuler'), style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              final now = DateTime.now();
              final String cnId = const Uuid().v4();
              final seq = await DocumentNumberingService.ensureNumberSequence(
                context: context,
                docCollection: 'supplier_credit_notes',
                docTypeName: 'Avoir fournisseur',
                prefix: DocPrefix.supplierCreditNote,
              );
              if (seq == null) return;
              final String cnNumber = generateDocNumber(DocPrefix.supplierCreditNote, seq, docCollection: 'supplier_credit_notes');
              
              final creditNote = SupplierCreditNote(
                id: cnId,
                number: cnNumber,
                supplierId: inv.supplierId,
                date: now,
                status: 'Brouillon',
                items: inv.items.map((i) => SupplierCreditNoteItem(
                  id: const Uuid().v4(),
                  supplierCreditNoteId: cnId,
                  productId: i.productId,
                  quantity: i.quantity,
                  unitPrice: i.unitPrice,
                  tvaRate: i.tvaRate,
                  totalHT: i.totalHT,
                )).toList(),
                createdAt: now,
                updatedAt: now,
              );

              context.read<SupplierCreditNotesBloc>().add(AddSupplierCreditNote(creditNote));

              final updatedInvoice = inv.copyWith(creditNoteId: creditNote.id);
              context.read<PurchaseInvoicesBloc>().add(UpdatePurchaseInvoice(updatedInvoice));

              if (context.mounted) {
                context.read<StockBloc>().add(LoadStock());
                context.read<ProductsBloc>().add(const ResetProductsPagination());

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${context.tr('Avoir fournisseur')} $cnNumber ${context.tr('créé et stock réajusté avec succès')}'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(context.tr('Confirmer'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openConvertedCreditNote(BuildContext context, String? creditNoteId) async {
    if (creditNoteId == null) return;
    
    final creditNote = await DatabaseHelper.instance.getSupplierCreditNoteById(creditNoteId);
    if (!mounted) return;
    if (creditNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('Avoir fournisseur introuvable')),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final doc = DocumentWrapper.fromSupplierCreditNote(creditNote);
    Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
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

  void _handleAction(BuildContext context, String action, PurchaseInvoice inv) {
    if (OfflineActionHelper.writeActions.contains(action) || action == 'add_payment') {
      OfflineActionHelper.executeAction(
        context: context,
        action: action,
        onConfirmed: () => _executeWriteAction(context, action, inv),
      );
      return;
    }

    switch (action) {
      case 'view':
        final doc = DocumentWrapper.fromPurchaseInvoice(inv);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(
              document: doc,
              status: context.tr(inv.status.label),
              statusColor: inv.status.color,
            ),
          ),
        );
        break;
      case 'print':
        final doc = DocumentWrapper.fromPurchaseInvoice(inv);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;
      case 'view_credit_note':
        _openConvertedCreditNote(context, inv.creditNoteId);
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromPurchaseInvoice(inv);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromPurchaseInvoice(inv);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromPurchaseInvoice(inv);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Cette fonctionnalité sera disponible prochainement'))));
    }
  }

  void _executeWriteAction(BuildContext context, String action, PurchaseInvoice inv) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<PurchaseInvoicesBloc>()),
                BlocProvider.value(value: context.read<SuppliersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
                BlocProvider.value(value: context.read<ProjectsBloc>()),
              ],
              child: CreatePurchaseInvoiceScreen(existing: inv),
            ),
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
              BlocProvider.value(value: context.read<PurchaseInvoicesBloc>()),
            ],
            child: PurchaseInvoicePaymentDialog(purchaseInvoice: inv),
          ),
        ).then((created) {
          if (created == true && context.mounted) {
            context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
          }
        });
        break;
      case 'to_credit_note':
        _createCreditNoteFromPurchaseInvoice(context, inv);
        break;
      case 'delete':
        context.read<PurchaseInvoicesBloc>().add(DeletePurchaseInvoice(inv.id));
        break;
      case 'status':
        _showChangeStatusDialog(context, inv);
        break;
    }
  }

  void _showChangeStatusDialog(BuildContext context, PurchaseInvoice inv) {
    showDocumentChangeStatusDialog(
      context: context,
      documentType: 'purchase_invoice',
      currentStatus: inv.effectiveStatus,
      onSave: (newStatusKey, notes) async {
        final enumMatch = InvoiceStatus.values.where((e) => e.name == newStatusKey).firstOrNull;
        final updatedInv = inv.copyWith(
          status: enumMatch ?? InvoiceStatus.unpaid,
          customStatus: enumMatch == null ? newStatusKey : null,
          notes: notes != null && notes.isNotEmpty ? '${inv.notes ?? ''}\n$notes' : inv.notes,
        );
        context.read<PurchaseInvoicesBloc>().add(UpdatePurchaseInvoice(updatedInv));
      },
    );
  }

  // ── Bulk Actions ──────────────────────────────────────────────────
  Widget _buildBulkActionsDropdown() {
    final count = _selectedPurchaseInvoiceIds.length;
    return PopupMenuButton<String>(
      onSelected: (action) => _handleBulkAction(action),
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'pdf',
          child: Text(
            count > 1 ? '${context.tr('Télécharger')} $count documents ( pdf )' : context.tr('Télécharger PDF'),
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Text(context.tr('Exporter Excel'), style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(context.tr('Supprimer la sélection'), style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('Plus d\'actions'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _handleBulkAction(String action) {
    final state = context.read<PurchaseInvoicesBloc>().state;
    if (state is! PurchaseInvoicesLoaded) return;

    final selectedInvoices = state.purchaseInvoices.where((inv) => _selectedPurchaseInvoiceIds.contains(inv.id)).toList();
    if (selectedInvoices.isEmpty) return;

    switch (action) {
      case 'pdf':
        _bulkDownloadPdf(selectedInvoices);
        break;
      case 'excel':
        _bulkExportExcel(selectedInvoices);
        break;
      case 'delete':
        _bulkDeleteSelected(selectedInvoices);
        break;
    }
  }

  Future<void> _bulkDownloadPdf(List<PurchaseInvoice> selectedInvoices) async {
    for (final inv in selectedInvoices) {
      final docWrapper = DocumentWrapper.fromPurchaseInvoice(inv);
      final pdfBytes = await PdfService.instance.generateDocumentBytes(docWrapper);
      await Printing.sharePdf(bytes: pdfBytes, filename: '${inv.number}.pdf');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${selectedInvoices.length} ${context.tr('document(s) exporté(s) en PDF')}'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _bulkExportExcel(List<PurchaseInvoice> selectedInvoices) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['FacturesDAchat'];
      excel.setDefaultSheet('FacturesDAchat');

      final headers = ['Reference', 'Date', 'Fournisseur', 'Statut', 'Montant HT', 'Montant TVA', 'Montant TTC'];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true, fontFamily: getFontFamily(FontFamily.Arial));
      }

      for (var i = 0; i < selectedInvoices.length; i++) {
        final inv = selectedInvoices[i];
        final rowIndex = i + 1;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(inv.number);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(formatDate(inv.createdAt));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(inv.supplierName ?? '—');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(inv.status.label);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(inv.totalHT);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(inv.totalTva);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(inv.totalTTC);
      }

      final fileBytes = excel.encode();
      if (fileBytes != null && mounted) {
        final fileName = 'Factures_Achat_Selectionnees_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await FileDownloadHelper.saveAndOpenFile(
          Uint8List.fromList(fileBytes),
          fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          context: context,
        );
        setState(() => _selectedPurchaseInvoiceIds.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export Excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _bulkDeleteSelected(List<PurchaseInvoice> selectedInvoices) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(context.tr('Suppression groupée')),
          ],
        ),
        content: Text('${context.tr('Voulez-vous vraiment supprimer les')} ${selectedInvoices.length} ${context.tr('facture(s) d\'achat sélectionnée(s)')} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.tr('Annuler')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              for (final inv in selectedInvoices) {
                context.read<PurchaseInvoicesBloc>().add(DeletePurchaseInvoice(inv.id));
              }
              setState(() => _selectedPurchaseInvoiceIds.clear());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${selectedInvoices.length} ${context.tr('facture(s) d\'achat supprimée(s)')}'),
                backgroundColor: AppColors.success,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('Supprimer')),
          ),
        ],
      ),
    );
  }
}
