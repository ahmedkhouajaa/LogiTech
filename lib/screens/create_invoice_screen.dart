import 'package:flutter/material.dart';
import '../widgets/searchable_dropdown_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../blocs/warehouses/warehouses_event.dart';
import '../models/stock_movement.dart' show Warehouse;
import '../models/document_template.dart';
import 'create_article_screen.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/dashboard_card.dart';
import '../screens/customers_screen.dart';
import '../services/enterprise_service.dart';
import 'package:business_manager_pro/services/error_handler.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Invoice? existing;
  const CreateInvoiceScreen({super.key, this.existing});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _isSaving = false;

  Customer? _selectedCustomer;
  String? _selectedProjectId;
  String? _selectedWarehouseId;
  List<InvoiceItem> _items = [];
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  bool _pricingModeHT = true; // true = HT, false = TTC
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0.0;
  
  Key _autocompleteKey = UniqueKey();
  InvoiceStatus _status = InvoiceStatus.unpaid;

  final Map<String, TextEditingController> _qtyControllers = {};

  TextEditingController _getQtyController(InvoiceItem item) {
    if (!_qtyControllers.containsKey(item.id)) {
      _qtyControllers[item.id] = TextEditingController(text: formatQuantity(item.quantity));
    }
    return _qtyControllers[item.id]!;
  }

  List<Map<String, dynamic>> _customColumns = [];

  // Computed totals
  double get _totalHT => _items.fold(0, (s, i) => s + i.computedTotalHT);

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
    // Recalculate TVA on discounted HT
    return _items.fold(0, (s, i) {
      final itemHT = i.computedTotalHT;
      final discountedHT = itemHT - (itemHT * _globalDiscountPercent / 100);
      return s + discountedHT * (i.tvaRate / 100);
    });
  }

  double get _timbreFiscal => _withTimbreFiscal ? 1.0 : 0;
  double get _totalTTC => _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<ProjectsBloc>().add(LoadProjects());
    context.read<WarehousesBloc>().add(LoadWarehouses());
    _loadTemplate();

    // Load existing invoice data if editing
    if (widget.existing != null) {
      final inv = widget.existing!;
      _date = inv.date;
      _dueDate = inv.dueDate;
      _status = inv.status;
      _notesCtrl.text = inv.notes ?? '';
      _conditionsCtrl.text = inv.conditionsGenerales ?? '';
      _pricingModeHT = inv.pricingMode == 'ht';
      _withTimbreFiscal = inv.timbreFiscal > 0;
      _withGlobalDiscount = inv.globalDiscountPercent > 0;
      _globalDiscountPercent = inv.globalDiscountPercent;
      _selectedProjectId = inv.projectId;
      _selectedWarehouseId = inv.warehouseId;
      _items = inv.items.toList();
    }
  }

  Future<void> _loadTemplate() async {
    final template = await DatabaseHelper.instance.getDefaultTemplate('invoice');
    final config = template?.config ?? DocumentTemplate.defaultConfig();
    final cols = (config['tableColumns'] as List?) ?? DocumentTemplate.defaultConfig()['tableColumns'] as List;
    
    if (mounted) {
      setState(() {
        _customColumns = cols.where((c) => c['type'] == 'custom' && c['visible'] == true).cast<Map<String, dynamic>>().toList();
      });
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
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

  // ─── Top Bar ─────────────────────────────────────────────────────
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
            _isEditing ? 'Modifier la facture' : 'Ajouter une facture',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(width: 12),
          // Status badge
          StatusBadge(label: _status.label, color: _status.color),
          const Spacer(),
          // Action buttons
          _buildHeaderButton(Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.description_rounded, 'Non payé', () {
            setState(() => _status = InvoiceStatus.unpaid);
          }),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.visibility_rounded, 'Apercu', () {}),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.settings_rounded, 'Parametres', () {}),
          SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(Icons.check_rounded, size: 16),
              label: Text(_isSaving ? 'Enregistrement...' : 'Valider',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  // ─── Form Card (Date, Client, Project, Pricing Mode) ─────────────
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
          // Date d'emission
          Text("Date d'emission", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context, initialDate: _date,
                firstDate: DateTime(2020), lastDate: DateTime(2030),
                locale: const Locale('fr', 'FR'),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: AbsorbPointer(
              child: TextFormField(
                controller: TextEditingController(text: formatDateLong(_date)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                ),
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          SizedBox(height: 20),
          // Client & Project row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: BlocBuilder<CustomersBloc, CustomersState>(
                            builder: (context, state) {
                              final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                              final selectedCustomer = _selectedCustomer ??
                                  (widget.existing != null && state is CustomersLoaded
                                      ? state.customers.cast<Customer?>().firstWhere((c) => c?.id == widget.existing!.customerId, orElse: () => null)
                                      : null);
                              if (_selectedCustomer == null && selectedCustomer != null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) setState(() => _selectedCustomer = selectedCustomer);
                                });
                              }
                              final displayName = selectedCustomer != null
                                  ? (selectedCustomer.companyName?.isNotEmpty == true
                                      ? selectedCustomer.companyName!
                                      : (selectedCustomer.responsibleName?.isNotEmpty == true
                                          ? selectedCustomer.responsibleName!
                                          : selectedCustomer.name))
                                  : null;

                              return FormField<String>(
                                initialValue: _selectedCustomer?.id,
                                validator: (v) => _selectedCustomer == null ? 'Requis' : null,
                                builder: (field) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SearchableSelectorField(
                                        hint: 'Rechercher des clients...',
                                        selectedText: displayName,
                                        hasError: field.hasError,
                                        onTap: () async {
                                          final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedCustomer?.id);
                                          if (res != null) {
                                            final customer = customers.firstWhere((c) => c.id == res);
                                            setState(() => _selectedCustomer = customer);
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
                                final res = await showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<CustomersBloc>(),
                                    child: const CustomerDialog(existing: null),
                                  ),
                                );
                                if (res != null && mounted) {
                                  if (res is Customer) {
                                    setState(() => _selectedCustomer = res);
                                  } else if (res is String) {
                                    final custs = context.read<CustomersBloc>().state;
                                    if (custs is CustomersLoaded) {
                                      final found = custs.customers.firstWhere((c) => c.id == res, orElse: () => Customer(id: res, code: '', name: 'Client'));
                                      setState(() => _selectedCustomer = found);
                                    }
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
                    Text('Projet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        final projects = state is ProjectsLoaded ? state.projects : <Project>[];
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
                  final selectedWh = warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _selectedWarehouseId, orElse: () => null);
                  final warehouseName = selectedWh != null ? selectedWh.name : 'Entrepôt Principal';

                  return SearchableSelectorField(
                    hint: 'Sélectionner un entrepôt',
                    selectedText: warehouseName,
                    onTap: () async {
                      final res = await showWarehouseSelectDialog(context, warehouses, selectedWarehouseId: _selectedWarehouseId);
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
          // Pricing mode radio
          Text('Les prix des articles sont en', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
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

  InputDecoration _formInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  // ─── Articles Section ────────────────────────────────────────────
  Widget _buildArticlesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text('Articles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          // Table header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Designation', style: _tableHeaderStyle())),
                SizedBox(width: 140, child: Text('Quantite', style: _tableHeaderStyle(), textAlign: TextAlign.center)),
                SizedBox(width: 130, child: Text('P.U HT', style: _tableHeaderStyle(), textAlign: TextAlign.center)),
                SizedBox(width: 100, child: Text('Remise %', style: _tableHeaderStyle(), textAlign: TextAlign.center)),
                SizedBox(width: 100, child: Text('TVA', style: _tableHeaderStyle(), textAlign: TextAlign.center)),
                SizedBox(width: 140, child: Text('Total HT', style: _tableHeaderStyle(), textAlign: TextAlign.right)),
                SizedBox(width: 60),
              ],
            ),
          ),
          // Items or empty state
          if (_items.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 32),
              width: double.infinity,
              child: Text('Aucun article', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            )
          else
            ..._items.asMap().entries.map((e) => _buildItemRow(e.key, e.value)),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  }

  Widget _buildItemRow(int index, InvoiceItem item) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
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
                      selectedText: item.productName?.isNotEmpty == true ? item.productName : null,
                      onTap: () async {
                        final res = await showProductSelectDialog(context, products, warehouseId: _selectedWarehouseId);
                        if (res != null && mounted) {
                          final selection = products.firstWhere((p) => p.id == res);
                          setState(() {
                            _items[index] = item.copyWith(
                              productId: selection.id,
                              productName: selection.name,
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
              // Quantite with - and + buttons
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        if (item.quantity > 1) {
                          final newQty = item.quantity - 1;
                          final ctrl = _getQtyController(item);
                          ctrl.text = formatQuantity(newQty);
                          setState(() => _items[index] = item.copyWith(quantity: newQty));
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                        child: Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        controller: _getQtyController(item),
                        decoration: _itemInputDecoration(''),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final newQty = double.tryParse(v) ?? 1;
                          setState(() => _items[index] = item.copyWith(quantity: newQty));
                        },
                      ),
                    ),
                    SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        final newQty = item.quantity + 1;
                        final ctrl = _getQtyController(item);
                        ctrl.text = formatQuantity(newQty);
                        setState(() => _items[index] = item.copyWith(quantity: newQty));
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                        child: Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // P.U (unit price)
              SizedBox(
                width: 130,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('pu_${item.id}_${item.productId}'),
                        initialValue: item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(0) : '',
                        decoration: _itemInputDecoration(''),
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = item.copyWith(unitPrice: double.tryParse(v) ?? 0)),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      _pricingModeHT ? 'DT HT' : 'DT TTC',
                      style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
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
                        initialValue: item.discountPercent > 0 ? item.discountPercent.toStringAsFixed(0) : '',
                        decoration: _itemInputDecoration(''),
                        style: TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = item.copyWith(discountPercent: double.tryParse(v) ?? 0)),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '%',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // TVA dropdown
              SizedBox(
                width: 100,
                child: DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  value: item.tvaRate,
                  items: TvaRates.all.map((r) => DropdownMenuItem(value: r, child: Text('${r.toInt()}%', style: TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _items[index] = item.copyWith(tvaRate: v)),
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
                  controller: TextEditingController(text: formatCurrencyDT(item.computedTotalHT)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  ),
                  style: TextStyle(fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 4),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                onPressed: () => setState(() => _items.removeAt(index)),
                splashRadius: 16,
                tooltip: 'Supprimer',
              ),
              Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _itemInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  // ─── Article Action Buttons ──────────────────────────────────────
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
                    _addProductItem(product);
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
            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateArticleScreen()));
            if (res != null && res is Product && mounted) {
              _addProductItem(res);
            }
          },
          splashRadius: 24,
        ),
        SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: _addEmptyItem,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text('Ajouter une Ligne Vide', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  // ─── Global Discount Section ─────────────────────────────────────
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
            onTap: () => setState(() => _withGlobalDiscount = !_withGlobalDiscount),
            child: Row(
              children: [
                SizedBox(
                  width: 18, height: 18,
                  child: Checkbox(
                    value: _withGlobalDiscount,
                    onChanged: (v) => setState(() => _withGlobalDiscount = v ?? false),
                   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: AppColors.border),
                            activeColor: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8),
                Text('Ajouter une remise globale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
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
                    initialValue: _globalDiscountPercent > 0 ? _globalDiscountPercent.toString() : '',
                    decoration: _itemInputDecoration('Remise %'),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() => _globalDiscountPercent = double.tryParse(v) ?? 0),
                  ),
                ),
                SizedBox(width: 12),
                Text('= ${formatCurrencyDT(_globalDiscountAmount)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Totals Section ──────────────────────────────────────────────
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
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  // ─── Notes Section ───────────────────────────────────────────────
  Widget _buildNotesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Visible sur le document final',
                  hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
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
              Text('Conditions Generales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Conditions generales pour ce document',
                  hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Add Item Methods ────────────────────────────────────────────
  void _addEmptyItem() {
    setState(() {
      _items.add(InvoiceItem(
        id: _uuid.v4(),
        invoiceId: '',
        productId: '',
        quantity: 1,
        unitPrice: 0,
        tvaRate: 19,
      ));
    });
  }

  void _addProductItem(Product product) {
    setState(() {
      _items.add(InvoiceItem(
        id: _uuid.v4(),
        invoiceId: '',
        productId: product.id,
        productName: product.name,
        description: product.description,
        quantity: 1,
        unitPrice: product.sellingPrice,
        tvaRate: product.tvaRate,
      ));
    });
  }

  // ─── Save ────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_isSaving) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez selectionner un client'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String number = widget.existing?.number ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextInvoiceSequence();
        number = generateDocNumber('FA', seq);
      }

      final invoiceId = _isEditing ? widget.existing!.id : _uuid.v4();
      final invoice = Invoice(
        id: invoiceId,
        number: number,
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        projectId: _selectedProjectId,
        warehouseId: _selectedWarehouseId,
        enterpriseId: widget.existing?.enterpriseId ?? EnterpriseService.instance.currentEnterpriseId,
        date: _date,
        dueDate: _dueDate,
        status: _status,
        totalHT: _totalHTAfterDiscount,
        totalTva: _totalTvaAfterDiscount,
        totalTTC: _totalHTAfterDiscount + _totalTvaAfterDiscount,
        stampTax: 0,
        timbreFiscal: _timbreFiscal,
        globalDiscountPercent: _globalDiscountPercent,
        globalDiscountAmount: _globalDiscountAmount,
        pricingMode: _pricingModeHT ? 'ht' : 'ttc',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        conditionsGenerales: _conditionsCtrl.text.trim().isEmpty ? null : _conditionsCtrl.text.trim(),
        items: _items.map((item) => item.copyWith(invoiceId: invoiceId)).toList(),
        createdAt: _isEditing ? widget.existing!.createdAt : null,
      );

      if (_isEditing) {
        context.read<InvoicesBloc>().add(UpdateInvoice(invoice));
      } else {
        context.read<InvoicesBloc>().add(AddInvoice(invoice));
      }

      context.read<WarehousesBloc>().add(LoadWarehouses());
      context.read<ProductsBloc>().add(const ResetProductsPagination());

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Facture ${invoice.number} mise a jour'
              : 'Facture ${invoice.number} creee avec succes'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
