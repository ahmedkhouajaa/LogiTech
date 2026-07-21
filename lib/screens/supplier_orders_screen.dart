import 'package:flutter/material.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../widgets/supplier_order_payment_dialog.dart';
import '../blocs/payments/payments_bloc.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/supplier_orders/supplier_orders_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/supplier_order.dart';
import '../models/supplier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import 'create_supplier_order_screen.dart';
import 'package:uuid/uuid.dart';
import '../models/purchase_invoice.dart';
import '../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../database/database_helper.dart';
import 'create_purchase_invoice_screen.dart';
import '../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import 'create_receiving_voucher_screen.dart';
import '../services/pdf_service.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';
import '../models/receiving_voucher.dart';

class SupplierOrdersScreen extends StatefulWidget {
  const SupplierOrdersScreen({super.key});
  @override
  State<SupplierOrdersScreen> createState() => _SupplierOrdersScreenState();
}

class _SupplierOrdersScreenState extends State<SupplierOrdersScreen> {
  // Filter state
  String? _selectedSupplierId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  SupplierOrderStatus? _statusFilter;

  // Pagination state
  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<SupplierOrdersBloc>().add(LoadSupplierOrders());
    context.read<SuppliersBloc>().add(LoadSuppliers());
  }

  void _applyFilters() {
    context.read<SupplierOrdersBloc>().add(FilterSupplierOrders(
      supplierId: _selectedSupplierId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _statusFilter?.name,
    ));
    setState(() {
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      const Text(
                        'Commandes Fournisseur',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.shopping_cart_checkout, color: Colors.blue[600], size: 24),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Gerer vos commandes fournisseur', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              AppButton(
                label: 'Creer une Commande',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: context.read<SupplierOrdersBloc>()),
                        BlocProvider.value(value: context.read<SuppliersBloc>()),
                        BlocProvider.value(value: context.read<ProductsBloc>()),
                        BlocProvider.value(value: context.read<ProjectsBloc>()),
                      ],
                      child: const CreateSupplierOrderScreen(),
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
          child: BlocBuilder<SupplierOrdersBloc, SupplierOrdersState>(
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

  Widget _buildFilterBar(SupplierOrdersState state) {
    int totalItems = 0;
    if (state is SupplierOrdersLoaded) {
      List<SupplierOrder> filteredOrders = state.orders;
      if (_selectedSupplierId != null && _selectedSupplierId != 'all') {
        filteredOrders = filteredOrders.where((q) => q.supplierId == _selectedSupplierId).toList();
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Supplier
              Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: BlocBuilder<SuppliersBloc, SuppliersState>(
                    builder: (context, state) {
                      List<Supplier> suppliers = [];
                      if (state is SuppliersLoaded) {
                        suppliers = state.suppliers;
                      }
                      return Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSupplierId,
                            hint: const Text('Selectionner un fournisseur...', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('Tous les fournisseurs', style: TextStyle(color: AppColors.textSecondary))),
                              ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedSupplierId = val);
                              _applyFilters();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Date From
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Date de debut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateFrom ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (date != null) {
                      setState(() => _dateFrom = date);
                      _applyFilters();
                    }
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
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateFrom != null ? formatDateLong(_dateFrom!) : 'Selectionner une date',
                            style: TextStyle(fontSize: 13, color: _dateFrom != null ? AppColors.textPrimary : AppColors.textTertiary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Date To
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Date de fin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateTo ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (date != null) {
                      setState(() => _dateTo = date);
                      _applyFilters();
                    }
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
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateTo != null ? formatDateLong(_dateTo!) : 'Selectionner une date',
                            style: TextStyle(fontSize: 13, color: _dateTo != null ? AppColors.textPrimary : AppColors.textTertiary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Status
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SupplierOrderStatus?>(
                        value: _statusFilter,
                        hint: const Text('Tous', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.textSecondary),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(color: AppColors.textPrimary))),
                          ...SupplierOrderStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                        ],
                        onChanged: (val) {
                          setState(() => _statusFilter = val);
                          _applyFilters();
                        },
                      ),
                    ),
                  ),
                ),
              ],
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
                    _selectedSupplierId = null;
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

  Widget _buildTable() {
    return BlocBuilder<SupplierOrdersBloc, SupplierOrdersState>(
      builder: (context, state) {
        if (state is SupplierOrdersLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is SupplierOrdersError) {
          return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
        }
        if (state is SupplierOrdersLoaded) {
          final orders = state.orders;

          // Pagination logic
          final totalItems = orders.length;
          final totalPages = (totalItems / _rowsPerPage).ceil() == 0 ? 1 : (totalItems / _rowsPerPage).ceil();
          if (_currentPage >= totalPages) _currentPage = totalPages - 1;
          if (_currentPage < 0) _currentPage = 0;

          final startIndex = _currentPage * _rowsPerPage;
          final endIndex = (startIndex + _rowsPerPage > totalItems) ? totalItems : startIndex + _rowsPerPage;
          final paginatedOrders = orders.sublist(startIndex, endIndex);

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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                            color: AppColors.background,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 32), // Checkbox space
                              const Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              const Expanded(flex: 3, child: Text('Fournisseur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Container(alignment: Alignment.centerLeft, child: const Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)))),
                              const Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              const SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                        // Table body
                        Expanded(
                          child: paginatedOrders.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.border),
                                      SizedBox(height: 16),
                                      Text("Aucune commande trouvee", style: TextStyle(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: paginatedOrders.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                                  itemBuilder: (context, index) {
                                    final order = paginatedOrders[index];
                                    final statusEnum = SupplierOrderStatus.values.firstWhere(
                                      (e) => e.name == order.status,
                                      orElse: () => SupplierOrderStatus.draft,
                                    );

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withOpacity(0.3),
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
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(order.number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                                const SizedBox(height: 4),
                                                Text(formatDateTimeLong(order.date), style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                const Icon(Icons.business_outlined, size: 14, color: AppColors.textSecondary),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    order.supplierName ?? 'Fournisseur Inconnu',
                                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusEnum.color.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  statusEnum.label,
                                                  style: TextStyle(color: statusEnum.color, fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              formatCurrencyDT(order.totalTTC),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: statusEnum == SupplierOrderStatus.draft ? AppColors.textSecondary : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 80,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                color: const Color(0xFFF8FAFC), // Light gray background
                                                elevation: 4,
                                                padding: EdgeInsets.zero,
                                                itemBuilder: (ctx) => _buildActionMenu(context, order),
                                                onSelected: (val) {
                                                  if (val == 'view') {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => MultiBlocProvider(
                                                          providers: [
                                                            BlocProvider.value(value: context.read<SupplierOrdersBloc>()),
                                                            BlocProvider.value(value: context.read<SuppliersBloc>()),
                                                            BlocProvider.value(value: context.read<ProductsBloc>()),
                                                            BlocProvider.value(value: context.read<ProjectsBloc>()),
                                                          ],
                                                          child: CreateSupplierOrderScreen(existing: order, isReadOnly: true),
                                                        ),
                                                      ),
                                                    );
                                                  } else if (val == 'to_invoice') {
                                                    _showConversionDialog(context, order, true);
                                                  } else if (val == 'to_receipt') {
                                                    _showConversionDialog(context, order, false);
                                                  } else if (val == 'view_invoice') {
                                                    _openConvertedInvoice(context, order.convertedToInvoiceId!, order);
                                                  } else if (val == 'view_receipt') {
                                                    _openConvertedReceipt(context, order.convertedToReceiptId!, order);
                                                  } else if (val == 'edit') {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => MultiBlocProvider(
                                                          providers: [
                                                            BlocProvider.value(value: context.read<SupplierOrdersBloc>()),
                                                            BlocProvider.value(value: context.read<SuppliersBloc>()),
                                                            BlocProvider.value(value: context.read<ProductsBloc>()),
                                                            BlocProvider.value(value: context.read<ProjectsBloc>()),
                                                          ],
                                                          child: CreateSupplierOrderScreen(existing: order),
                                                        ),
                                                      ),
                                                    );
                                                  } else if (val == 'delete') {
                                                    _confirmDelete(order);
                                                  } else if (val == 'pdf') {
                                                    final doc = DocumentWrapper.fromSupplierOrder(order);
                                                    PdfService.instance.downloadDocument(context, doc);
                                                  } else if (val == 'payment') {
                                                    showDialog(
                                                      context: context,
                                                      builder: (_) => MultiBlocProvider(
                                                        providers: [
                                                          BlocProvider.value(value: context.read<PaymentsBloc>()),
                                                          BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
                                                          BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
                                                          BlocProvider.value(value: context.read<SupplierOrdersBloc>()),
                                                        ],
                                                        child: SupplierOrderPaymentDialog(supplierOrder: order),
                                                      ),
                                                    ).then((created) {
                                                      if (created == true && context.mounted) {
                                                        context.read<SupplierOrdersBloc>().add(LoadSupplierOrders());
                                                      }
                                                    });
                                                  } else if (val == 'print' || val == 'credit_note' || val == 'email' || val == 'whatsapp' || val == 'status' || val == 'duplicate' || val == 'attachments') {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                                      content: Text('Cette fonctionnalité sera disponible prochainement'),
                                                      backgroundColor: AppColors.info,
                                                    ));
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // Pagination footer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border)),
                            color: AppColors.background,
                          ),
                          child: Row(
                            children: [
                              const Text('Lignes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                  items: [10, 20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text(v.toString()))).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() {
                                      _rowsPerPage = v;
                                      _currentPage = 0;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Text('Page ${_currentPage + 1} sur $totalPages', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                totalItems == 0 ? 'Affichage de 0 a 0 sur 0 resultats' : 'Affichage de ${startIndex + 1} a $endIndex sur $totalItems resultats',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_left, size: 20, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage < totalPages - 1 ? AppColors.border : AppColors.border.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_right, size: 20, color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
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

  void _confirmDelete(SupplierOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer la commande ${order.number} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SupplierOrdersBloc>().add(DeleteSupplierOrder(order.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String label, Color iconColor, {bool showBorder = true}) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: EdgeInsets.zero,
      child: Container(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: showBorder ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label, 
                style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildActionMenu(BuildContext context, SupplierOrder order) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(_buildMenuItem('view', Icons.visibility_outlined, 'Voir', const Color(0xFF6366F1)));
    items.add(_buildMenuItem('edit', Icons.edit_outlined, 'Modifier', const Color(0xFF2563EB)));
    items.add(_buildMenuItem('delete', Icons.delete_outline, 'Supprimer', const Color(0xFFEF4444)));
    items.add(_buildMenuItem('print', Icons.print_outlined, 'Imprimer', const Color(0xFF475569)));


    if (!order.isConvertedToInvoice && !order.isConvertedToReceipt) {
      items.add(_buildMenuItem('to_invoice', Icons.receipt_long_outlined, 'Transformer en facture d\'achat', const Color(0xFF475569)));
      items.add(_buildMenuItem('to_receipt', Icons.local_shipping_outlined, 'Transformer en bon de réception', const Color(0xFF475569)));
    }
    if (order.isConvertedToInvoice) {
      items.add(_buildMenuItem('view_invoice', Icons.visibility_outlined, 'Voir la facture d\'achat creee', const Color(0xFF475569)));
    }
    if (order.isConvertedToReceipt) {
      items.add(_buildMenuItem('view_receipt', Icons.visibility_outlined, 'Voir le bon de reception cree', const Color(0xFF475569)));
    }
    
    items.add(_buildMenuItem('pdf', Icons.picture_as_pdf_outlined, 'Telecharger PDF', const Color(0xFFEF4444)));
    items.add(_buildMenuItem('email', Icons.email_outlined, 'Envoyer par email', const Color(0xFF2563EB)));
    items.add(_buildMenuItem('whatsapp', Icons.chat_bubble_outline, 'Envoyer par WhatsApp', const Color(0xFF10B981)));
    items.add(_buildMenuItem('status', Icons.swap_horiz_outlined, 'Changer le statut', const Color(0xFFF59E0B)));
    items.add(_buildMenuItem('duplicate', Icons.content_copy_outlined, 'Dupliquer', const Color(0xFF475569)));
    items.add(_buildMenuItem('attachments', Icons.attach_file_outlined, 'Gerer les pieces jointes', const Color(0xFF475569), showBorder: false));

    return items;
  }

  void _showConversionDialog(BuildContext context, SupplierOrder order, bool toInvoice) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(toInvoice ? 'Transformer en facture d\'achat' : 'Transformer en bon de réception'),
        content: Text('Voulez-vous transformer la commande ${order.number} en ${toInvoice ? 'facture d\'achat' : 'bon de réception'} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (toInvoice) {
                _convertToInvoice(context, order);
              } else {
                _convertToReceipt(context, order);
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _convertToInvoice(BuildContext context, SupplierOrder order) {
    final invoiceId = const Uuid().v4();
    final newInvoice = PurchaseInvoice(
      id: invoiceId,
      number: 'FA-${order.number.replaceAll("CMD-", "")}',
      supplierId: order.supplierId,
      supplierName: order.supplierName,
      orderId: order.id,
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid,
      totalHT: order.subTotalHT,
      totalTva: order.totalTVA,
      totalTTC: order.subTotalTTC,
      items: order.items.map((i) => PurchaseInvoiceItem(
        id: const Uuid().v4(),
        purchaseInvoiceId: invoiceId,
        productId: i.productId,
        productName: i.description,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        totalHT: i.totalHT,
      )).toList(),
    );

    context.read<PurchaseInvoicesBloc>().add(AddPurchaseInvoice(newInvoice));

    final updatedOrder = order.copyWith(
      isConvertedToInvoice: true,
      convertedToInvoiceId: invoiceId,
      status: 'validated',
    );
    context.read<SupplierOrdersBloc>().add(UpdateSupplierOrder(updatedOrder));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Commande transformée en facture d'achat avec succès")),
    );
  }

  void _convertToReceipt(BuildContext context, SupplierOrder order) {
    final receiptId = const Uuid().v4();
    final newReceipt = ReceivingVoucher(
      id: receiptId,
      number: 'BR-${order.number.replaceAll("CMD-", "")}',
      supplierId: order.supplierId,
      supplierName: order.supplierName,
      orderId: order.id,
      date: DateTime.now(),
      status: 'validated',
      pricingMode: order.pricingMode,
      globalDiscountPercent: order.globalDiscountPercent,
      globalDiscountAmount: order.globalDiscountAmount,
      timbreFiscal: order.timbreFiscal,
      conditionsGenerales: order.conditionsGenerales,
      items: order.items.map((i) => ReceivingVoucherItem(
        id: const Uuid().v4(),
        voucherId: receiptId,
        productId: i.productId,
        productName: i.description,
        quantityExpected: i.quantity,
        quantityReceived: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
      )).toList(),
    );

    context.read<ReceivingVouchersBloc>().add(AddReceivingVoucher(newReceipt));

    final updatedOrder = order.copyWith(
      isConvertedToReceipt: true,
      convertedToReceiptId: receiptId,
      status: 'validated',
    );
    context.read<SupplierOrdersBloc>().add(UpdateSupplierOrder(updatedOrder));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Commande transformée en bon de réception avec succès")),
    );
  }

  void _openConvertedInvoice(BuildContext context, String invoiceId, SupplierOrder originalOrder) async {
    final invoice = await DatabaseHelper.instance.getPurchaseInvoice(invoiceId);
    if (invoice != null) {
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
            child: CreatePurchaseInvoiceScreen(existing: invoice, isReadOnly: true),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Facture introuvable', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
    }
  }

  void _openConvertedReceipt(BuildContext context, String receiptId, SupplierOrder originalOrder) async {
    final receiptData = await DatabaseHelper.instance.getReceivingVoucher(receiptId);
    if (receiptData != null) {
      final receipt = ReceivingVoucher.fromMap(receiptData);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<ReceivingVouchersBloc>()),
              BlocProvider.value(value: context.read<SuppliersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
            ],
            child: CreateReceivingVoucherScreen(existing: receipt, isReadOnly: true),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bon de réception introuvable', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
    }
  }
}
