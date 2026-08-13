import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/customer_orders/customer_orders_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/customer_order.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../blocs/stock/stock_bloc.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../blocs/warehouses/warehouses_event.dart';
import '../models/stock_movement.dart' show Warehouse;
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'customers_screen.dart';
import 'create_article_screen.dart';
import '../database/database_helper.dart';
import '../services/enterprise_service.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/searchable_dropdown_field.dart';

class CreateCustomerOrderScreen extends StatefulWidget {
  final CustomerOrder? existing;
  const CreateCustomerOrderScreen({super.key, this.existing});

  @override
  State<CreateCustomerOrderScreen> createState() =>
      _CreateCustomerOrderScreenState();
}

class _CreateCustomerOrderScreenState extends State<CreateCustomerOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
  List<CustomerOrderItem> _items = [];
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  CustomerOrderStatus _status = CustomerOrderStatus.draft;

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.totalHT);

  Map<double, double> get _tvaBreakdown {
    final map = <double, double>{};
    for (final item in _items) {
      final rate = item.tvaRate;
      map[rate] = (map[rate] ?? 0) + item.tvaAmount;
    }
    return map;
  }

  double get _totalTva => _items.fold(0, (s, i) => s + i.tvaAmount);

  double get _globalDiscountAmount {
    if (!_withGlobalDiscount || _globalDiscountPercent <= 0) return 0;
    return _totalHT * _globalDiscountPercent / 100;
  }

  double get _totalHTAfterDiscount => _totalHT - _globalDiscountAmount;
  double get _totalTvaAfterDiscount {
    if (!_withGlobalDiscount || _globalDiscountPercent <= 0) return _totalTva;
    return _items.fold(0, (s, i) {
      final itemHT = i.totalHT;
      final discountedHT = itemHT - (itemHT * _globalDiscountPercent / 100);
      return s + discountedHT * (i.tvaRate / 100);
    });
  }

  double get _timbreFiscal => _withTimbreFiscal ? 1.0 : 0;
  double get _totalTTC =>
      _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<ProjectsBloc>().add(LoadProjects());
    context.read<WarehousesBloc>().add(LoadWarehouses());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _selectedCustomerId = n.customerId;
      _selectedCustomerName = n.customerName;
      _selectedProjectId = n.projectId;
      _selectedWarehouseId = n.warehouseId;
      _pricingModeHT = n.pricingMode == 'ht';
      _withGlobalDiscount = n.globalDiscountPercent > 0;
      _globalDiscountPercent = n.globalDiscountPercent;
      _withTimbreFiscal = n.timbreFiscal > 0;
      _status = CustomerOrderStatus.values.firstWhere(
        (e) => e.name == n.status,
        orElse: () => CustomerOrderStatus.draft,
      );
      _notesCtrl.text = n.notes ?? '';
      _conditionsCtrl.text = n.conditionsGenerales ?? '';
      _items = n.items.map((i) => CustomerOrderItem(
        id: i.id,
        orderId: i.orderId,
        productId: i.productId,
        description: i.description,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
        showDescription: i.showDescription,
        showDiscount: i.showDiscount,
      )).toList();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Veuillez selectionner un client'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final bloc = context.read<CustomerOrdersBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String number = widget.existing?.number ?? '';
    if (number.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextCustomerOrderSequence();
      number = generateDocNumber('CC', seq);
    }

    final custState = context.read<CustomersBloc>().state;
    String? custName;
    if (custState is CustomersLoaded) {
      final found = custState.customers.firstWhere(
        (c) => c.id == _selectedCustomerId,
        orElse: () => Customer(id: '', code: '', name: 'Client Inconnu'),
      );
      custName = found.companyName?.isNotEmpty == true
          ? found.companyName
          : (found.responsibleName?.isNotEmpty == true ? found.responsibleName : found.name);
    }

    final orderId = widget.existing?.id ?? _uuid.v4();
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final order = CustomerOrder(
      id: orderId,
      number: number,
      customerId: _selectedCustomerId!,
      customerName: custName ?? _selectedCustomerName,
      projectId: _selectedProjectId,
      warehouseId: _selectedWarehouseId,
      date: _date,
      status: _status.name,
      pricingMode: _pricingModeHT ? 'ht' : 'ttc',
      globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
      globalDiscountAmount: _globalDiscountAmount,
      timbreFiscal: _timbreFiscal,
      enterpriseId: currentEntId,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      conditionsGenerales:
          _conditionsCtrl.text.isNotEmpty ? _conditionsCtrl.text : null,
      items: _items.map((item) => CustomerOrderItem(
        id: item.id,
        orderId: orderId,
        productId: item.productId,
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate,
        discountPercent: item.discountPercent,
        showDescription: item.showDescription,
        showDiscount: item.showDiscount,
      )).toList(),
    );

    if (_isEditing) {
      bloc.add(UpdateCustomerOrder(order));
    } else {
      bloc.add(AddCustomerOrder(order));
    }

    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_isEditing
          ? 'Commande ${order.number} mise a jour'
          : 'Commande ${order.number} creee avec succes'),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormCard(),
                    SizedBox(height: AppSpacing.lg),
                    _buildArticlesSection(),
                    SizedBox(height: AppSpacing.md),
                    _buildArticleActions(),
                    SizedBox(height: AppSpacing.md),
                    _buildGlobalDiscountSection(),
                    SizedBox(height: AppSpacing.lg),
                    _buildTotalsSection(),
                    SizedBox(height: AppSpacing.lg),
                    _buildNotesSection(),
                    SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.sm,
      ),
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            _isEditing ? 'Modifier la commande client' : 'Ajouter une commande client',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          SizedBox(width: 12),
          StatusBadge(label: _status.label, color: _status.color),
          const Spacer(),
          _buildHeaderButton(
              Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.description_rounded, 'Brouillon', () {
            setState(() => _status = CustomerOrderStatus.draft);
          }),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.visibility_rounded, 'Apercu', () {}),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.settings_rounded, 'Parametres', () {}),
          SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: Icon(Icons.check_rounded, size: 16),
              label: Text('Valider',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(
      IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label,
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  // ── Form Card ─────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Text("Date d'emission",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('fr', 'FR'),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: AbsorbPointer(
              child: TextFormField(
                controller:
                    TextEditingController(text: formatDateLong(_date)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  suffixIcon: Icon(Icons.calendar_today_rounded,
                      size: 16, color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                ),
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Client & Projet
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: BlocBuilder<CustomersBloc, CustomersState>(
                            builder: (context, state) {
                              final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                              final selectedCustomer = customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null);
                              final displayName = selectedCustomer != null
                                  ? (selectedCustomer.companyName?.isNotEmpty == true
                                      ? selectedCustomer.companyName!
                                      : (selectedCustomer.responsibleName?.isNotEmpty == true
                                          ? selectedCustomer.responsibleName!
                                          : selectedCustomer.name))
                                  : null;

                              return FormField<String>(
                                initialValue: _selectedCustomerId,
                                validator: (v) => _selectedCustomerId == null ? 'Requis' : null,
                                builder: (field) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SearchableSelectorField(
                                        hint: 'Rechercher des clients...',
                                        selectedText: displayName,
                                        hasError: field.hasError,
                                        onTap: () async {
                                          final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedCustomerId);
                                          if (res != null) {
                                            setState(() => _selectedCustomerId = res);
                                            field.didChange(res);
                                          }
                                        },
                                      ),
                                      if (field.hasError) ...[
                                        SizedBox(height: 4),
                                        Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Text(field.errorText!, style: TextStyle(color: AppColors.error, fontSize: 11)),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: Tooltip(
                            message: 'Créer un nouveau client',
                            child: ElevatedButton(
                              onPressed: () async {
                                final newRes = await showDialog<dynamic>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<CustomersBloc>(),
                                    child: const CustomerDialog(existing: null),
                                  ),
                                );
                                if (newRes != null && mounted) {
                                  if (newRes is Customer) {
                                    final displayName = newRes.companyName?.isNotEmpty == true
                                        ? newRes.companyName!
                                        : (newRes.responsibleName?.isNotEmpty == true
                                            ? newRes.responsibleName!
                                            : newRes.name);
                                    setState(() {
                                      _selectedCustomerId = newRes.id;
                                      _selectedCustomerName = displayName;
                                    });
                                  } else if (newRes is String) {
                                    setState(() => _selectedCustomerId = newRes);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                foregroundColor: AppColors.primary,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Icon(Icons.person_add_alt_1_rounded, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projet',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        final projects = state is ProjectsLoaded
                            ? state.projects
                            : <Project>[];
                        final selectedProject = projects.cast<Project?>().firstWhere((p) => p?.id == _selectedProjectId, orElse: () => null);

                        return SearchableSelectorField(
                          hint: 'Projet par defaut',
                          selectedText: selectedProject?.name ?? 'Projet par defaut',
                          onTap: () async {
                            final res = await showProjectSelectDialog(context, projects, selectedProjectId: _selectedProjectId);
                            if (res != null) {
                              setState(() => _selectedProjectId = (res == '__default__' ? null : res));
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Entrepôt field (under Projet)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entrepôt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              SizedBox(height: 6),
              BlocBuilder<WarehousesBloc, WarehousesState>(
                builder: (context, state) {
                  final warehouses = state is WarehousesLoaded ? state.warehouses : <Warehouse>[];
                  final defaultWh = warehouses.cast<Warehouse?>().firstWhere(
                    (w) => w?.isDefault == true,
                    orElse: () => warehouses.cast<Warehouse?>().firstWhere((w) => w?.name.toLowerCase().contains('défaut') == true || w?.name.toLowerCase().contains('defaut') == true, orElse: () => warehouses.isNotEmpty ? warehouses.first : null),
                  );
                  if (_selectedWarehouseId == null && defaultWh != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _selectedWarehouseId == null) {
                        setState(() => _selectedWarehouseId = defaultWh.id);
                      }
                    });
                  }
                  final selectedWh = warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == (_selectedWarehouseId ?? defaultWh?.id), orElse: () => defaultWh);
                  final warehouseName = selectedWh?.name;

                  return SearchableSelectorField(
                    hint: 'Sélectionner un entrepôt',
                    selectedText: warehouseName,
                    onTap: () async {
                      final res = await showWarehouseSelectDialog(context, warehouses, selectedWarehouseId: _selectedWarehouseId ?? defaultWh?.id);
                      if (res != null && mounted) {
                        setState(() => _selectedWarehouseId = res);
                      }
                    },
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 20),

          // Pricing mode
          Text('Les prix des articles sont en',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              Text('Hors taxes', style: TextStyle(fontSize: 13)),
              SizedBox(width: 24),
              Radio<bool>(
                value: false,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              Text('Taxe incluse', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _formInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: AppColors.textPrimary, fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding:
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  // ── Articles Section ──────────────────────────────────────────────
  Widget _buildArticlesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text('Articles',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          // Header
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Designation',
                        style: _tableHeaderStyle())),
                SizedBox(
                    width: 140,
                    child: Text('Quantite',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 130,
                    child: Text('P.U HT',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 100,
                    child: Text('Remise %',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 100,
                    child: Text('TVA',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 140,
                    child: Text('Total HT',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right)),
                SizedBox(width: 60),
              ],
            ),
          ),
          // Items
          if (_items.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 32),
              width: double.infinity,
              child: Text('Aucun article',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textPrimary)),
            )
          else
            ..._items.asMap().entries.map((e) => _buildItemRow(e.key, e.value)),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary);
  }

  Widget _buildItemRow(int index, CustomerOrderItem item) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Designation
              Expanded(
                flex: 3,
                child: BlocBuilder<ProductsBloc, ProductsState>(
                  builder: (context, state) {
                    final products = state is ProductsLoaded ? state.products : <Product>[];
                    return SearchableSelectorField(
                      hint: 'Rechercher un article...',
                      selectedText: item.description?.isNotEmpty == true ? item.description : null,
                      onTap: () async {
                        final res = await showProductSelectDialog(context, products, warehouseId: _selectedWarehouseId);
                        if (res != null && mounted) {
                          final selection = products.firstWhere((p) => p.id == res);
                          setState(() {
                            _items[index] = item.copyWith(
                              productId: selection.id,
                              description: selection.name,
                              unitPrice: selection.sellingPrice,
                              tvaRate: selection.tvaRate,
                            );
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              SizedBox(width: 8),
              // Quantite with - / + buttons
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        final newQ = item.quantity > 1 ? item.quantity - 1 : 1.0;
                        _items[index] = item.copyWith(quantity: newQ);
                      }),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(4)),
                        child: Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey(
                            'qty_${item.id}_${item.quantity}'),
                        initialValue: formatQuantity(item.quantity),
                        decoration: _itemInputDecoration(''),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() =>
                            _items[index] = item.copyWith(
                                quantity:
                                    double.tryParse(v) ?? 1)),
                      ),
                    ),
                    SizedBox(width: 4),
                    InkWell(
                      onTap: () => setState(() => _items[index] =
                          item.copyWith(quantity: item.quantity + 1)),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(4)),
                        child: Icon(Icons.add,
                            size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // P.U
              SizedBox(
                width: 130,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('pu_${item.id}_${item.productId}'),
                        initialValue: item.unitPrice > 0
                            ? item.unitPrice.toStringAsFixed(0)
                            : '',
                        decoration: _itemInputDecoration(''),
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() =>
                            _items[index] = item.copyWith(
                                unitPrice:
                                    double.tryParse(v) ?? 0)),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      _pricingModeHT ? 'DT HT' : 'DT TTC',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // Remise %
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('remise_${item.id}_init'),
                        initialValue: item.discountPercent > 0
                            ? item.discountPercent.toStringAsFixed(0)
                            : '',
                        decoration: _itemInputDecoration(''),
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() =>
                            _items[index] = item.copyWith(
                                discountPercent:
                                    double.tryParse(v) ?? 0)),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '%',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // TVA
              SizedBox(
                width: 100,
                child: DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  value: item.tvaRate,
                  items: (TvaRates.all.contains(item.tvaRate) ? TvaRates.all : [...TvaRates.all, item.tvaRate])
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('${r.toInt()}%',
                              style:
                                  TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() =>
                      _items[index] = item.copyWith(tvaRate: v)),
                  decoration: _itemInputDecoration(''),
                  isDense: true,
                ),
              ),
              SizedBox(width: 8),
              // Total HT (read-only)
              SizedBox(
                width: 140,
                child: TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                      text: formatCurrencyDT(item.totalHT)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                            color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(
                            color: AppColors.border)),
                  ),
                  style: TextStyle(fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.error),
                onPressed: () =>
                    setState(() => _items.removeAt(index)),
                splashRadius: 16,
                tooltip: 'Supprimer',
              ),
              Icon(Icons.drag_indicator_rounded,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _itemInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: AppColors.textPrimary, fontSize: 12),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding:
          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  // ── Article Actions ───────────────────────────────────────────────
    Widget _buildArticleActions() {
    return Row(
      children: [
        Expanded(
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              final products = state is ProductsLoaded ? state.products : <Product>[];
              return SearchableSelectorField(
                hint: 'Sélectionner un article...',
                selectedText: null,
                onTap: () async {
                  final res = await showProductSelectDialog(context, products, warehouseId: _selectedWarehouseId);
                  if (res != null) {
                    final product = products.firstWhere((p) => p.id == res);
                    setState(() {
                      _items.add(CustomerOrderItem(
                        id: _uuid.v4(),
                        orderId: widget.existing?.id ?? '',
                        productId: product.id,
                        description: product.name,
                        quantity: 1,
                        unitPrice: product.sellingPrice,
                        tvaRate: product.tvaRate,
                      ));
                    });
                  }
                },
              );
            },
          ),
        ),
        SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 24),
          tooltip: 'Créer un nouvel article',
          onPressed: () async {
            final newProd = await Navigator.push<dynamic>(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ProductsBloc>(),
                  child: const CreateArticleScreen(),
                ),
              ),
            );
            if (newProd != null && newProd is Product && mounted) {
              setState(() {
                _items.add(CustomerOrderItem(
                  id: _uuid.v4(),
                  orderId: widget.existing?.id ?? '',
                  productId: newProd.id,
                  description: newProd.name,
                  quantity: 1,
                  unitPrice: newProd.sellingPrice,
                  tvaRate: newProd.tvaRate,
                ));
              });
            }
          },
          splashRadius: 24,
        ),
        SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _items.add(CustomerOrderItem(
                  id: _uuid.v4(),
                  orderId: widget.existing?.id ?? '',
                  productId: 'custom',
                  description: '',
                  quantity: 1,
                  unitPrice: 0,
                  tvaRate: 19,
                ));
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text('Ajouter une Ligne Vide', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Global Discount Section ────────────────────────────────────────
  Widget _buildGlobalDiscountSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _withGlobalDiscount = !_withGlobalDiscount),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _withGlobalDiscount,
                    onChanged: (v) => setState(
                        () => _withGlobalDiscount = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: AppColors.border),
                    activeColor: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8),
                Text('Ajouter une remise globale',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_withGlobalDiscount) ...[
            SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    initialValue: _globalDiscountPercent > 0
                        ? _globalDiscountPercent.toString()
                        : '',
                    decoration: _itemInputDecoration('Remise %'),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() =>
                        _globalDiscountPercent =
                            double.tryParse(v) ?? 0),
                  ),
                ),
                SizedBox(width: 12),
                Text('= ${formatCurrencyDT(_globalDiscountAmount)}',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Totals Section ─────────────────────────────────────────────────
  Widget _buildTotalsSection() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildTotalLine('Sous-total HT:', formatCurrencyDT(_totalHTAfterDiscount)),
            SizedBox(height: 6),
            // TVA breakdown
            ..._tvaBreakdown.entries.map((entry) =>
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: _buildTotalLine('TVA ${entry.key.toInt()}%:', formatCurrencyDT(entry.value)),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _withTimbreFiscal = !_withTimbreFiscal),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: Checkbox(
                            value: _withTimbreFiscal,
                            onChanged: (v) => setState(() => _withTimbreFiscal = v ?? false),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: AppColors.border),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Timbre fiscal:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    Text(formatCurrencyDT(_timbreFiscal), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6),
            if (_withGlobalDiscount && _globalDiscountAmount > 0) ...[
              _buildTotalLine('Remise:', '- ${formatCurrencyDT(_globalDiscountAmount)}'),
              SizedBox(height: 6),
            ],
            Divider(),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total TTC:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(formatCurrencyDT(_totalTTC), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }

  // ── Notes Section ──────────────────────────────────────────────────
  Widget _buildNotesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notes',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Visible sur le document final',
                  hintStyle: TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conditions Generales',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Conditions generales pour ce document',
                  hintStyle: TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
