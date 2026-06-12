import 'package:flutter/material.dart';
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
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/dashboard_card.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Invoice? existing;
  const CreateInvoiceScreen({super.key, this.existing});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  Customer? _selectedCustomer;
  String? _selectedProjectId;
  List<InvoiceItem> _items = [];
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  bool _pricingModeHT = true; // true = HT, false = TTC
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  InvoiceStatus _status = InvoiceStatus.draft;

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
      _items = inv.items.toList();
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
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildArticlesSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildArticleActions(),
                    const SizedBox(height: AppSpacing.md),
                    _buildGlobalDiscountSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTotalsSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildNotesSection(),
                    const SizedBox(height: AppSpacing.xl),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            _isEditing ? 'Modifier la facture' : 'Ajouter une facture',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          // Status badge
          StatusBadge(label: _status.label, color: _status.color),
          const Spacer(),
          // Action buttons
          _buildHeaderButton(Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          const SizedBox(width: 8),
          _buildHeaderButton(Icons.description_rounded, 'Brouillon', () {
            setState(() => _status = InvoiceStatus.draft);
          }),
          const SizedBox(width: 8),
          _buildHeaderButton(Icons.visibility_rounded, 'Aperçu', () {}),
          const SizedBox(width: 8),
          _buildHeaderButton(Icons.settings_rounded, 'Paramètres', () {}),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Valider', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  // ─── Form Card (Date, Client, Project, Pricing Mode) ─────────────
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date d'émission
          const Text("Date d'émission", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
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
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Client & Project row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    BlocBuilder<CustomersBloc, CustomersState>(
                      builder: (context, state) {
                        final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                        return DropdownButtonFormField<String>(
                          value: _selectedCustomer?.id,
                          isExpanded: true,
                          hint: const Text('Rechercher des clients...', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                          items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) {
                            final customer = customers.firstWhere((c) => c.id == v);
                            setState(() => _selectedCustomer = customer);
                          },
                          decoration: _formInputDecoration(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Projet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                        return DropdownButtonFormField<String>(
                          value: _selectedProjectId,
                          isExpanded: true,
                          hint: const Text('Projet par défaut', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Projet par défaut', style: TextStyle(fontSize: 13))),
                            ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (v) => setState(() => _selectedProjectId = v),
                          decoration: _formInputDecoration(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Pricing mode radio
          const Text('Les prix des articles sont en', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              const Text('Hors taxes', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 24),
              Radio<bool>(
                value: false,
                groupValue: _pricingModeHT,
                onChanged: (v) => setState(() => _pricingModeHT = v!),
                activeColor: AppColors.primary,
              ),
              const Text('Taxe incluse', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _formInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
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
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: const Text('Articles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Désignation', style: _tableHeaderStyle())),
                SizedBox(width: 120, child: Text('Quantité', style: _tableHeaderStyle(), textAlign: TextAlign.center)),
                SizedBox(width: 130, child: Text('P.U', style: _tableHeaderStyle(), textAlign: TextAlign.center)),
                SizedBox(width: 100, child: Text('TVA', style: _tableHeaderStyle(), textAlign: TextAlign.center)),
                SizedBox(width: 140, child: Text('Total HT', style: _tableHeaderStyle(), textAlign: TextAlign.right)),
                const SizedBox(width: 60),
              ],
            ),
          ),
          // Items or empty state
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              width: double.infinity,
              child: const Text('Aucun article', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
            )
          else
            ..._items.asMap().entries.map((e) => _buildItemRow(e.key, e.value)),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary);
  }

  Widget _buildItemRow(int index, InvoiceItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Désignation
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.productName ?? '',
                  decoration: _itemInputDecoration(''),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => setState(() => _items[index] = item.copyWith(productName: v)),
                ),
              ),
              const SizedBox(width: 8),
              // Quantité with + button
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _items[index] = item.copyWith(quantity: item.quantity + 1)),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('qty_${item.id}_${item.quantity}'),
                        initialValue: formatQuantity(item.quantity),
                        decoration: _itemInputDecoration(''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = item.copyWith(quantity: double.tryParse(v) ?? 1)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // P.U (unit price)
              SizedBox(
                width: 130,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('pu_${item.id}_init'),
                        initialValue: item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(0) : '',
                        decoration: _itemInputDecoration(''),
                        style: const TextStyle(fontSize: 13),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => _items[index] = item.copyWith(unitPrice: double.tryParse(v) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _pricingModeHT ? 'DT HT' : 'DT TTC',
                      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // TVA dropdown
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<double>(
                  value: item.tvaRate,
                  items: TvaRates.all.map((r) => DropdownMenuItem(value: r, child: Text('${r.toInt()}%', style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _items[index] = item.copyWith(tvaRate: v)),
                  decoration: _itemInputDecoration(''),
                  isDense: true,
                ),
              ),
              const SizedBox(width: 8),
              // Total HT (read-only)
              SizedBox(
                width: 140,
                child: TextFormField(
                  readOnly: true,
                  controller: TextEditingController(text: formatCurrencyDT(item.computedTotalHT)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  ),
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 4),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                onPressed: () => setState(() => _items.removeAt(index)),
                splashRadius: 16,
                tooltip: 'Supprimer',
              ),
              // Drag handle
              const Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: 6),
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
                    const SizedBox(width: 6),
                    Text('Afficher la description', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
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
                    const SizedBox(width: 6),
                    Text('Appliquer remise', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
          // Description field (expandable)
          if (item.showDescription)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextFormField(
                initialValue: item.description ?? '',
                decoration: _itemInputDecoration('Description du produit'),
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                onChanged: (v) => setState(() => _items[index] = item.copyWith(description: v)),
              ),
            ),
          // Discount field (expandable)
          if (item.showDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      initialValue: item.discountPercent > 0 ? item.discountPercent.toString() : '',
                      decoration: _itemInputDecoration('Remise %'),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() => _items[index] = item.copyWith(discountPercent: double.tryParse(v) ?? 0)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _itemInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  // ─── Article Action Buttons ──────────────────────────────────────
  Widget _buildArticleActions() {
    return Row(
      children: [
        // Select article dropdown
        Expanded(
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              final products = state is ProductsLoaded ? state.products : <Product>[];
              return Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonFormField<String>(
                  hint: const Text('Sélectionner un article...', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                  isExpanded: true,
                  items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final product = products.firstWhere((p) => p.id == v);
                    _addProductItem(product);
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // Add empty line button
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: _addEmptyItem,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Ajouter une Ligne Vide', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  // ─── Global Discount Section ─────────────────────────────────────
  Widget _buildGlobalDiscountSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
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
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Ajouter une remise globale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_withGlobalDiscount) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    initialValue: _globalDiscountPercent > 0 ? _globalDiscountPercent.toString() : '',
                    decoration: _itemInputDecoration('Remise %'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() => _globalDiscountPercent = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Text('= ${formatCurrencyDT(_globalDiscountAmount)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
            const SizedBox(height: 6),
            // TVA breakdown
            ..._tvaBreakdown.entries.map((entry) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildTotalLine('TVA ${entry.key.toInt()}%:', formatCurrencyDT(entry.value)),
              ),
            ),
            if (_withTimbreFiscal) ...[
              _buildTotalLine('Timbre fiscal:', formatCurrencyDT(_timbreFiscal)),
              const SizedBox(height: 6),
            ],
            if (_withGlobalDiscount && _globalDiscountAmount > 0) ...[
              _buildTotalLine('Remise:', '- ${formatCurrencyDT(_globalDiscountAmount)}'),
              const SizedBox(height: 6),
            ],
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total TTC:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text(formatCurrencyDT(_totalTTC), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
              const Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Visible sur le document final',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Conditions Générales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Conditions générales pour ce document',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                style: const TextStyle(fontSize: 13),
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
  void _save() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: AppColors.error),
      );
      return;
    }

    final invoiceId = _isEditing ? widget.existing!.id : _uuid.v4();
    final invoice = Invoice(
      id: invoiceId,
      number: _isEditing ? widget.existing!.number : generateDocNumber(DocPrefix.invoice, DateTime.now().millisecondsSinceEpoch % 1000000),
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
      items: _items.map((item) => item.copyWith(invoiceId: invoiceId)).toList(),
      createdAt: _isEditing ? widget.existing!.createdAt : null,
    );

    if (_isEditing) {
      context.read<InvoicesBloc>().add(UpdateInvoice(invoice));
    } else {
      context.read<InvoicesBloc>().add(AddInvoice(invoice));
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing
            ? 'Facture ${invoice.number} mise à jour'
            : 'Facture ${invoice.number} créée avec succès'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
