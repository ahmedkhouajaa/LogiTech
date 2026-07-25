import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/credit_notes/credit_notes_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/credit_note.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../models/document_template.dart';
import 'create_article_screen.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/dashboard_card.dart';
import '../screens/customers_screen.dart';
import '../widgets/searchable_dropdown_field.dart';

class CreateCreditNoteScreen extends StatefulWidget {
  final CreditNote? existing;
  const CreateCreditNoteScreen({super.key, this.existing});

  @override
  State<CreateCreditNoteScreen> createState() => _CreateCreditNoteScreenState();
}

class _CreateCreditNoteScreenState extends State<CreateCreditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  Customer? _selectedCustomer;
  String? _selectedProjectId;
  List<CreditNoteItem> _items = [];
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  bool _pricingModeHT = true; // true = HT, false = TTC
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0.0;
  
  Key _autocompleteKey = UniqueKey();
  CreditNoteStatus _status = CreditNoteStatus.unused;

  final Map<String, TextEditingController> _qtyControllers = {};

  TextEditingController _getQtyController(CreditNoteItem item) {
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
    _loadTemplate();

    // Load existing creditNote data if editing
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
      _items = inv.items.toList();
    }
  }

  Future<void> _loadTemplate() async {
    final template = await DatabaseHelper.instance.getDefaultTemplate('creditNote');
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
            _isEditing ? 'Modifier la avoir' : 'Ajouter une avoir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(width: 12),
          // Status badge
          StatusBadge(label: _status.label, color: _status == CreditNoteStatus.unused ? AppColors.warning : AppColors.success),
          const Spacer(),
          // Action buttons
          _buildHeaderButton(Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          SizedBox(width: 8),
          _buildHeaderButton(Icons.description_rounded, 'Non utilisé', () {
            setState(() => _status = CreditNoteStatus.unused);
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
              label: Text('Valider', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                              final selectedCustomer = _selectedCustomer;
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
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<CustomersBloc>(),
                                    child: const CustomerDialog(existing: null),
                                  ),
                                );
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
                SizedBox(width: 130, child: Text('P.U', style: _tableHeaderStyle(), textAlign: TextAlign.center)),
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

  Widget _buildItemRow(int index, CreditNoteItem item) {
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
                    return Autocomplete<Product>(
                      initialValue: TextEditingValue(text: item.productName ?? ''),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                        return products.where((Product p) => 
                          p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                          (p.reference?.toLowerCase().contains(textEditingValue.text.toLowerCase()) ?? false)
                        );
                      },
                      displayStringForOption: (Product option) => option.name,
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: _itemInputDecoration('Rechercher un article...'),
                          style: TextStyle(fontSize: 13),
                          onChanged: (v) => setState(() => _items[index] = item.copyWith(productName: v)),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, i) {
                                  final option = options.elementAt(i);
                                  return ListTile(
                                    title: Text(option.name, style: TextStyle(fontSize: 13)),
                                    subtitle: option.reference != null ? Text(option.reference!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)) : null,
                                    trailing: Text('${option.sellingPrice.toStringAsFixed(2)} DT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onTap: () => onSelected(option),
                                    dense: true,
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      onSelected: (Product selection) {
                        setState(() {
                          _items[index] = item.copyWith(
                            productId: selection.id,
                            productName: selection.name,
                            unitPrice: selection.sellingPrice,
                            tvaRate: selection.tvaRate,
                          );
                        });
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
                          final newQty = item.quantity < -1 ? item.quantity + 1 : item.quantity;
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
                          final rawQty = double.tryParse(v) ?? -1;
                          final newQty = rawQty > 0 ? -rawQty : rawQty;
                          setState(() => _items[index] = item.copyWith(quantity: newQty));
                        },
                      ),
                    ),
                    SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        final newQty = item.quantity - 1;
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
              // Drag handle
              Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.textTertiary),
            ],
          ),
          SizedBox(height: 6),
          // Bottom row: show description, apply discount
          Row(
            children: [
              // Show description toggle
              InkWell(
                onTap: () => setState(() => _items[index] = item.copyWith(showDescription: !item.showDescription)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: Checkbox(
                        value: item.showDescription,
                        onChanged: (v) => setState(() => _items[index] = item.copyWith(showDescription: v)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: AppColors.border),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Afficher la description', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              SizedBox(width: 24),
              // Apply discount toggle
              InkWell(
                onTap: () => setState(() => _items[index] = item.copyWith(showDiscount: !item.showDiscount)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: Checkbox(
                        value: item.showDiscount,
                        onChanged: (v) => setState(() => _items[index] = item.copyWith(showDiscount: v)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: AppColors.border),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Appliquer remise', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
          // Description field (expandable)
          if (item.showDescription)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: TextFormField(
                initialValue: item.description ?? '',
                decoration: _itemInputDecoration('Description du produit'),
                style: TextStyle(fontSize: 12),
                maxLines: 2,
                onChanged: (v) => setState(() => _items[index] = item.copyWith(description: v)),
              ),
            ),
          // Discount field (expandable)
          if (item.showDiscount)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: item.discountPercent > 0 ? item.discountPercent.toString() : '',
                      decoration: _itemInputDecoration('Remise %'),
                      style: TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() => _items[index] = item.copyWith(discountPercent: double.tryParse(v) ?? 0)),
                    ),
                  ),
                ],
              ),
            ),
          // Custom Columns fields
          if (_customColumns.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: _customColumns.map((col) {
                  final id = col['id'] as String;
                  return SizedBox(
                    width: 200,
                    child: TextFormField(
                      initialValue: item.customFields[id] ?? '',
                      decoration: _itemInputDecoration(col['label'] as String),
                      style: TextStyle(fontSize: 12),
                      onChanged: (v) {
                        final newFields = Map<String, String>.from(item.customFields);
                        newFields[id] = v;
                        setState(() => _items[index] = item.copyWith(customFields: newFields));
                      },
                    ),
                  );
                }).toList(),
              ),
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
                  final res = await showProductSelectDialog(context, products);
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
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateArticleScreen()));
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
      _items.add(CreditNoteItem(
        id: _uuid.v4(),
        productId: '',
        quantity: -1,
        unitPrice: 0,
        tvaRate: 19,
      ));
    });
  }

  void _addProductItem(Product product) {
    setState(() {
      _items.add(CreditNoteItem(
        id: _uuid.v4(),
        productId: product.id,
        productName: product.name,
        description: product.description,
        quantity: -1,
        unitPrice: product.sellingPrice,
        tvaRate: product.tvaRate,
      ));
    });
  }

  // ─── Save ────────────────────────────────────────────────────────
  void _save() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez selectionner un client'), backgroundColor: AppColors.error),
      );
      return;
    }

    final creditNoteId = _isEditing ? widget.existing!.id : const Uuid().v4();
    final creditNote = CreditNote(
      id: creditNoteId,
      number: _isEditing ? widget.existing!.number : generateDocNumber(DocPrefix.creditNote, DateTime.now().millisecondsSinceEpoch % 1000000),
      invoiceId: widget.existing?.invoiceId ?? '',
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.name,
      projectId: _selectedProjectId,
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
      items: _items,
      createdAt: _isEditing ? widget.existing!.createdAt : null,
    );

    if (_isEditing) {
      context.read<CreditNotesBloc>().add(UpdateCreditNote(creditNote));
    } else {
      context.read<CreditNotesBloc>().add(AddCreditNote(creditNote));
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing
            ? 'Avoir ${creditNote.number} mise a jour'
            : 'Avoir ${creditNote.number} creee avec succes'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

