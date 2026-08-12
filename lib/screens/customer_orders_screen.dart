import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/customer_orders/customer_orders_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../models/customer_order.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import 'create_customer_order_screen.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../models/invoice.dart';
import '../models/delivery_note.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import 'create_delivery_note_screen.dart';
import 'create_invoice_screen.dart';
import '../services/pdf_service.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});
  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  // Filter state
  String? _selectedClientId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  CustomerOrderStatus? _statusFilter;

  // Pagination state
  int _rowsPerPage = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<CustomerOrdersBloc>().add(const LoadFirstCustomerOrders());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  void _applyFilters() {
    context.read<CustomerOrdersBloc>().add(FilterCustomerOrders(
      clientId: _selectedClientId,
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
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commandes Client',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text('Gerer vos commandes client', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              AppButton(
                label: 'Creer une Commande Client',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: context.read<CustomerOrdersBloc>()),
                        BlocProvider.value(value: context.read<CustomersBloc>()),
                        BlocProvider.value(value: context.read<ProductsBloc>()),
                        BlocProvider.value(value: context.read<ProjectsBloc>()),
                        BlocProvider.value(value: context.read<WarehousesBloc>()),
                      ],
                      child: const CreateCustomerOrderScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        // Filter bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: BlocBuilder<CustomerOrdersBloc, CustomerOrdersState>(
            builder: (context, state) {
              return _buildFilterBar(state);
            },
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        // Table
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

  Widget _buildFilterBar(CustomerOrdersState state) {
    int totalItems = 0;
    if (state is CustomerOrdersLoaded) {
      List<CustomerOrder> filteredOrders = state.orders;
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
              // Client
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: BlocBuilder<CustomersBloc, CustomersState>(
                    builder: (context, state) {
                      List<Customer> customers = [];
                      if (state is CustomersLoaded) {
                        customers = state.customers;
                      }
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
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          // Date From
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Date de debut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                SizedBox(height: 8),
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
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateFrom != null ? formatDateLong(_dateFrom!) : 'Selectionner une date',
                            style: TextStyle(fontSize: 13, color: _dateFrom != null ? AppColors.textPrimary : AppColors.textSecondary),
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
          SizedBox(width: AppSpacing.md),
          // Date To
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Date de fin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                SizedBox(height: 8),
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
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateTo != null ? formatDateLong(_dateTo!) : 'Selectionner une date',
                            style: TextStyle(fontSize: 13, color: _dateTo != null ? AppColors.textPrimary : AppColors.textSecondary),
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
          SizedBox(width: AppSpacing.md),
          // Status
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: PopupMenuButton<CustomerOrderStatus?>(
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
                      PopupMenuItem<CustomerOrderStatus?>(
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
                      ...CustomerOrderStatus.values.map(
                        (s) => PopupMenuItem<CustomerOrderStatus?>(
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
              ],
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildTable() {
    return BlocBuilder<CustomerOrdersBloc, CustomerOrdersState>(
      builder: (context, state) {
        if (state is CustomerOrdersLoading) {
          return Center(child: CircularProgressIndicator());
        }
        if (state is CustomerOrdersError) {
            return AppErrorWidget(message: state.message);
          }
        if (state is CustomerOrdersLoaded) {
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
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                            color: AppColors.background,
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 32), // Checkbox space
                              Expanded(flex: 2, child: Text('Reference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              Expanded(flex: 3, child: Text('Client', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Container(alignment: Alignment.centerLeft, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)))),
                              Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                              SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                        // Table body
                        Expanded(
                          child: paginatedOrders.isEmpty
                              ? Center(
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
                                  separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border),
                                  itemBuilder: (context, index) {
                                    final order = paginatedOrders[index];
                                    final statusEnum = CustomerOrderStatus.values.firstWhere(
                                      (e) => e.name == order.status,
                                      orElse: () => CustomerOrderStatus.draft,
                                    );

                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withOpacity(0.3),
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
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(order.number, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                                                SizedBox(height: 4),
                                                Text(formatDateTimeLong(order.date), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                                                    SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        order.customerCompany ?? order.customerName ?? 'Client Inconnu',
                                                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                                color: statusEnum == CustomerOrderStatus.draft ? AppColors.textSecondary : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 80,
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: PopupMenuButton<String>(
                                                icon: Icon(Icons.more_horiz, color: AppColors.textSecondary),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                color: AppColors.surface,
                                                onSelected: (val) => _handleAction(context, val, order),
                                                itemBuilder: (_) => [
                                                  _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
                                                  PopupMenuDivider(height: 1),
                                                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                                                  PopupMenuDivider(height: 1),
                                                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                                                  PopupMenuDivider(height: 1),
                                                  _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
                                                  PopupMenuDivider(height: 1),
                                                  if (!order.isConvertedToInvoice && !order.isConvertedToDelivery) ...[
                                                    _buildMenuItem('to_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Facture'),
                                                    PopupMenuDivider(height: 1),
                                                    _buildMenuItem('to_delivery', Icons.local_shipping_outlined, AppColors.textSecondary, 'Transformer en Bon de Livraison'),
                                                    PopupMenuDivider(height: 1),
                                                  ] else ...[
                                                    if (order.isConvertedToInvoice) ...[
                                                      _buildMenuItem('view_invoice', Icons.receipt_long_outlined, AppColors.success, 'Voir la facture creee'),
                                                      PopupMenuDivider(height: 1),
                                                    ],
                                                    if (order.isConvertedToDelivery) ...[
                                                      _buildMenuItem('view_delivery', Icons.local_shipping_outlined, AppColors.success, 'Voir le bon de livraison cree'),
                                                      PopupMenuDivider(height: 1),
                                                    ],
                                                  ],
                                                  _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Telecharger PDF'),
                                                  PopupMenuDivider(height: 1),
                                                  _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                                                  PopupMenuDivider(height: 1),
                                                  _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
                                                  PopupMenuDivider(height: 1),
                                                  _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
//                                                   PopupMenuDivider(height: 1),
//                                                   _buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'),
//                                                   PopupMenuDivider(height: 1),
//                                                   _buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gerer les pieces jointes'),
                                                ],
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
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border)),
                            color: AppColors.background,
                          ),
                          child: Row(
                            children: [
                              Text('Lignes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              SizedBox(width: 8),
                              Container(
                                height: 32,
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: SizedBox(),
                                  icon: Icon(Icons.keyboard_arrow_down, size: 16),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                  items: [10, 20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text(v.toString()))).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() {
                                      _rowsPerPage = v;
                                      _currentPage = 0;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 24),
                              Text('Page ${_currentPage + 1} sur $totalPages', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Spacer(),
                              Text(
                                totalItems == 0 ? 'Affichage de 0 a 0 sur 0 resultats' : 'Affichage de ${startIndex + 1} a $endIndex sur $totalItems resultats',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              SizedBox(width: 16),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withOpacity(0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_left, size: 20, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  InkWell(
                                    onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
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
        return SizedBox();
      },
    );
  }

  void _confirmDelete(CustomerOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer la commande ${order.number} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CustomerOrdersBloc>().add(DeleteCustomerOrder(order.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
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

  void _handleAction(BuildContext context, String action, CustomerOrder order) {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(
              document: DocumentWrapper.fromCustomerOrder(order),
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
                BlocProvider.value(value: context.read<CustomerOrdersBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
                BlocProvider.value(value: context.read<ProjectsBloc>()),
                BlocProvider.value(value: context.read<WarehousesBloc>()),
              ],
              child: CreateCustomerOrderScreen(existing: order),
            ),
          ),
        );
        break;
            case 'print':
        final doc = DocumentWrapper.fromCustomerOrder(order);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewScreen(document: doc),
          ),
        );
        break;
      case 'delete':
        _confirmDelete(order);
        break;
      case 'status':
        _showChangeStatusDialog(context, order);
        break;
      case 'to_invoice':
        _showConversionDialog(context, order);
        break;
      case 'view_invoice':
        _openConvertedInvoice(context, order.convertedToInvoiceId);
        break;
      case 'to_delivery':
        _showDeliveryConversionDialog(context, order);
        break;
      case 'view_delivery':
        _openConvertedDelivery(context, order.convertedToDeliveryId);
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromCustomerOrder(order);
        PdfService.instance.downloadDocument(context, doc);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implementee')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, CustomerOrder order) {
    CustomerOrderStatus selectedStatus = CustomerOrderStatus.values.firstWhere(
      (e) => e.name == order.status,
      orElse: () => CustomerOrderStatus.draft,
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
                    items: CustomerOrderStatus.values.map((s) => DropdownMenuItem(
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
              AppButton(
                label: 'Enregistrer',
                onPressed: () {
                  context.read<CustomerOrdersBloc>().add(
                    UpdateCustomerOrder(order.copyWith(status: selectedStatus.name))
                  );
                  Navigator.pop(dialogCtx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConversionDialog(BuildContext context, CustomerOrder order) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
            Text('Voulez-vous transformer cette commande en facture ?'),
            SizedBox(height: 16),
            Text('Commande: ${order.number}', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${order.customerName ?? '—'}'),
            Text('Montant: ${formatCurrencyDT(order.totalTTC)}', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _convertOrderToInvoice(context, order);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertOrderToInvoice(BuildContext context, CustomerOrder order) async {
    final invoiceId = const Uuid().v4();
    final seq = await DatabaseHelper.instance.getNextInvoiceSequence();
    final invoiceNumber = generateDocNumber('FA', seq);
    
    final invoiceItems = order.items.map((qi) => InvoiceItem(
      id: const Uuid().v4(),
      invoiceId: invoiceId,
      productId: qi.productId,
      description: qi.description,
      quantity: qi.quantity,
      unitPrice: qi.unitPrice,
      tvaRate: qi.tvaRate,
      discountPercent: qi.discountPercent,
      totalHT: qi.totalHT,
    )).toList();

    final invoice = Invoice(
      id: invoiceId,
      number: invoiceNumber,
      customerId: order.customerId,
      customerName: order.customerName,
      orderId: order.id,
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid,
      totalHT: order.totalHTAfterDiscount,
      totalTva: order.totalTVA,
      totalTTC: order.totalTTC,
      notes: order.notes,
      items: invoiceItems,
      createdAt: DateTime.now(),
    );

    try {
      final invoicesBloc = context.read<InvoicesBloc>();
      invoicesBloc.add(AddInvoice(invoice));
    } catch (e) {
      await DatabaseHelper.instance.insertInvoice(invoice);
    }

    final updatedOrder = order.copyWith(
      isConvertedToInvoice: true,
      convertedToInvoiceId: invoiceId,
      status: CustomerOrderStatus.validatedAndInvoiced.name,
    );
    context.read<CustomerOrdersBloc>().add(UpdateCustomerOrder(updatedOrder));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Commande convertie en facture avec succes'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _openConvertedInvoice(BuildContext context, String? invoiceId) async {
    if (invoiceId == null) return;
    
    final invoice = await DatabaseHelper.instance.getInvoice(invoiceId);
    if (!mounted) return;
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
            ],
            child: CreateInvoiceScreen(existing: invoice),
          ),
        ),
      );
    } catch (e) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateInvoiceScreen(existing: invoice)));
    }
  }

  void _showDeliveryConversionDialog(BuildContext context, CustomerOrder order) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
            Text('Voulez-vous transformer cette commande en bon de livraison ?'),
            SizedBox(height: 16),
            Text('Commande: ${order.number}', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${order.customerName ?? '—'}'),
            Text('Montant: ${formatCurrencyDT(order.totalTTC)}', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _convertOrderToDelivery(context, order);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertOrderToDelivery(BuildContext context, CustomerOrder order) async {
    final deliveryId = const Uuid().v4();
    final seq = await DatabaseHelper.instance.getNextDeliveryNoteSequence();
    final deliveryNumber = generateDocNumber(DocPrefix.deliveryNote, seq);
    
    final deliveryItems = order.items.map((qi) => DeliveryNoteItem(
      id: const Uuid().v4(),
      deliveryNoteId: deliveryId,
      productId: qi.productId,
      description: qi.description,
      quantity: qi.quantity,
      unitPrice: qi.unitPrice,
      tvaRate: qi.tvaRate,
      discountPercent: qi.discountPercent,
    )).toList();

    final deliveryNote = DeliveryNote(
      id: deliveryId,
      number: deliveryNumber,
      customerId: order.customerId,
      customerName: order.customerName,
      orderId: order.id,
      date: DateTime.now(),
      status: 'delivered',
      notes: order.notes,
      items: deliveryItems,
      createdAt: DateTime.now(),
    );

    try {
      final deliveryBloc = context.read<DeliveryNotesBloc>();
      deliveryBloc.add(AddDeliveryNote(deliveryNote));
    } catch (e) {
      await DatabaseHelper.instance.insertDeliveryNote(deliveryNote);
    }

    final updatedOrder = order.copyWith(
      isConvertedToDelivery: true,
      convertedToDeliveryId: deliveryId,
      status: CustomerOrderStatus.validated.name,
    );
    if (!mounted) return;
    context.read<CustomerOrdersBloc>().add(UpdateCustomerOrder(updatedOrder));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Commande convertie en bon de livraison avec succes'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _openConvertedDelivery(BuildContext context, String? deliveryId) async {
    if (deliveryId == null) return;
    
    final delivery = await DatabaseHelper.instance.getDeliveryNote(deliveryId);
    if (!mounted) return;
    
    if (delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bon de livraison introuvable'),
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
              BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
              BlocProvider.value(value: context.read<CustomersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
            ],
            child: CreateDeliveryNoteScreen(existing: delivery),
          ),
        ),
      );
    } catch (e) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateDeliveryNoteScreen(existing: delivery)));
    }
  }
}
