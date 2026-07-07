import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/supplier_orders/supplier_orders_bloc.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/supplier_order.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';
import '../widgets/dashboard_card.dart';
import 'suppliers_screen.dart';
import 'create_article_screen.dart';

class CreateSupplierOrderScreen extends StatefulWidget {
  final SupplierOrder? existing;
  final bool isReadOnly;
  final String? overrideTitle;
  const CreateSupplierOrderScreen({super.key, this.existing, this.isReadOnly = false, this.overrideTitle});

  @override
  State<CreateSupplierOrderScreen> createState() =>
      _CreateSupplierOrderScreenState();
}

class _CreateSupplierOrderScreenState extends State<CreateSupplierOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  String? _selectedSupplierId;
  String? _selectedProjectId;
  List<SupplierOrderItem> _items = [];
  DateTime _date = DateTime.now();
  final _notesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  bool _pricingModeHT = true;
  bool _withTimbreFiscal = true;
  bool _withGlobalDiscount = false;
  double _globalDiscountPercent = 0;
  SupplierOrderStatus _status = SupplierOrderStatus.draft;

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

  double get _timbreFiscal => _withTimbreFiscal ? 1.000 : 0;
  double get _totalTTC =>
      _totalHTAfterDiscount + _totalTvaAfterDiscount + _timbreFiscal;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<SuppliersBloc>().add(LoadSuppliers());
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<ProjectsBloc>().add(LoadProjects());

    if (widget.existing != null) {
      final n = widget.existing!;
      _date = n.date;
      _selectedSupplierId = n.supplierId;
      _selectedProjectId = n.projectId;
      _pricingModeHT = n.pricingMode == 'ht';
      _withGlobalDiscount = n.globalDiscountPercent > 0;
      _globalDiscountPercent = n.globalDiscountPercent;
      _withTimbreFiscal = n.timbreFiscal > 0;
      _status = SupplierOrderStatus.values.firstWhere(
        (e) => e.name == n.status,
        orElse: () => SupplierOrderStatus.draft,
      );
      _notesCtrl.text = n.notes ?? '';
      _conditionsCtrl.text = n.conditionsGenerales ?? '';
      _items = n.items.map((i) => SupplierOrderItem(
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
    if (widget.isReadOnly) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez selectionner un fournisseur'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final bloc = context.read<SupplierOrdersBloc>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String number = widget.existing?.number ?? '';
    if (number.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextSupplierOrderSequence();
      number = generateDocNumber(DocPrefix.supplierOrder, seq);
    }

    final orderId = widget.existing?.id ?? _uuid.v4();
    final order = SupplierOrder(
      id: orderId,
      number: number,
      supplierId: _selectedSupplierId!,
      projectId: _selectedProjectId,
      date: _date,
      status: _status.name,
      pricingMode: _pricingModeHT ? 'ht' : 'ttc',
      globalDiscountPercent: _withGlobalDiscount ? _globalDiscountPercent : 0,
      globalDiscountAmount: _globalDiscountAmount,
      timbreFiscal: _timbreFiscal,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      conditionsGenerales:
          _conditionsCtrl.text.isNotEmpty ? _conditionsCtrl.text : null,
      items: _items.map((item) => SupplierOrderItem(
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
      bloc.add(UpdateSupplierOrder(order));
    } else {
      bloc.add(AddSupplierOrder(order));
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
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormCard(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildArticlesSection(),
                      if (!widget.isReadOnly) ...[
                        const SizedBox(height: AppSpacing.md),
                        _buildArticleActions(),
                      ],
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
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            widget.overrideTitle ?? (widget.isReadOnly 
                ? 'Détails de la commande fournisseur' 
                : (_isEditing ? 'Modifier la commande fournisseur' : 'Ajouter une commande fournisseur')),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          StatusBadge(label: _status.label, color: _status.color),
          const Spacer(),
          _buildHeaderButton(
              Icons.arrow_back_rounded, 'Retour', () => Navigator.pop(context)),
          if (!widget.isReadOnly) ...[
            const SizedBox(width: 8),
            _buildHeaderButton(Icons.description_rounded, 'Brouillon', () {
              setState(() => _status = SupplierOrderStatus.draft);
            }),
            const SizedBox(width: 8),
            _buildHeaderButton(Icons.send_rounded, 'Envoyer', () {
              setState(() => _status = SupplierOrderStatus.sent);
            }, color: AppColors.info),
            const SizedBox(width: 8),
            _buildHeaderButton(Icons.check_circle_rounded, 'Valider', () {
              setState(() => _status = SupplierOrderStatus.validated);
            }, color: AppColors.success),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
      label: Text(label,
          style: TextStyle(color: color ?? AppColors.textSecondary)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  // ── Form Details ────────────────────────────────────────────────────
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
          // Date d'emission
          const Text("Date", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              if (widget.isReadOnly) return;
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Fournisseur & Project row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: BlocBuilder<SuppliersBloc, SuppliersState>(
                            builder: (context, state) {
                              final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                              return DropdownButtonFormField<String>(
                                value: _selectedSupplierId,
                                isExpanded: true,
                                hint: const Text('Rechercher des fournisseurs...', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) {
                                  if (!widget.isReadOnly) setState(() => _selectedSupplierId = v);
                                },
                                decoration: _formInputDecoration(),
                              );
                            },
                          ),
                        ),
                        if (!widget.isReadOnly) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: Tooltip(
                              message: 'Créer un nouveau fournisseur',
                              child: ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<SuppliersBloc>(),
                                      child: const SupplierDialog(existing: null),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ],
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
                          hint: const Text('Projet par defaut', style: TextStyle(fontSize: 13, color: Colors.black87)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Projet par defaut', style: TextStyle(fontSize: 13))),
                            ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (v) {
                            if (!widget.isReadOnly) setState(() => _selectedProjectId = v);
                          },
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
                onChanged: (v) { if (!widget.isReadOnly) setState(() => _pricingModeHT = v!); },
                activeColor: AppColors.primary,
              ),
              const Text('Hors taxes', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 24),
              Radio<bool>(
                value: false,
                groupValue: _pricingModeHT,
                onChanged: (v) { if (!widget.isReadOnly) setState(() => _pricingModeHT = v!); },
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
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  // ── Articles ────────────────────────────────────────────────────────
  Widget _buildArticlesSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
              color: AppColors.background,
            ),
            child: const Row(
              children: [
                SizedBox(width: 32),
                Expanded(
                    flex: 3,
                    child: Text('Article',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Quantite',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Prix U. HT',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('TVA %',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Remise %',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Total HT',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary))),
                SizedBox(width: 80), // Actions
              ],
            ),
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Aucun article ajoute. Cliquez sur "Ajouter un article".',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _buildArticleRow(item, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArticleRow(SupplierOrderItem item, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          const SizedBox(
            width: 32,
            height: 40,
            child: Icon(Icons.drag_indicator,
                color: AppColors.textTertiary, size: 20),
          ),
          // Product selection
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 40,
                  child: BlocBuilder<ProductsBloc, ProductsState>(
                    builder: (context, state) {
                      List<Product> products = [];
                      if (state is ProductsLoaded) {
                        products = state.products;
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: Autocomplete<Product>(
                              initialValue: TextEditingValue(
                                text: item.productId.isNotEmpty ? products.firstWhere((p) => p.id == item.productId, orElse: () => Product(id: '', code: '', name: '', sellingPrice: 0, purchasePrice: 0, tvaRate: 0)).name : '',
                              ),
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<Product>.empty();
                                }
                          final search = textEditingValue.text.toLowerCase();
                          return products.where((Product option) {
                            return option.name.toLowerCase().contains(search) || 
                                   option.code.toLowerCase().contains(search) ||
                                  (option.reference != null && option.reference!.toLowerCase().contains(search));
                          }).toList();
                        },
                        onSelected: (Product product) {
                          setState(() {
                            _items[index] = item.copyWith(
                              productId: product.id,
                              unitPrice: product.purchasePrice,
                              tvaRate: product.tvaRate,
                            );
                          });
                        },
                        displayStringForOption: (Product option) => option.name,
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Rechercher un article...',
                              hintStyle: const TextStyle(fontSize: 13, color: Colors.black87),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
                            ),
                            style: const TextStyle(fontSize: 13),
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
                                      title: Text(option.name, style: const TextStyle(fontSize: 13)),
                                      subtitle: option.reference != null ? Text(option.reference!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)) : null,
                                      trailing: Text('${option.purchasePrice.toStringAsFixed(2)} DT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onTap: () => onSelected(option),
                                      dense: true,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                              ),
                            ),
                          ],
                        );
                    },
                  ),
                ),
                if (item.showDescription) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: item.description,
                    decoration: const InputDecoration(
                      hintText: 'Description additionnelle...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 2,
                    onChanged: (val) {
                      _items[index] = item.copyWith(description: val);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Quantity
          Expanded(
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    final newQty = item.quantity > 1 ? item.quantity - 1 : 1.0;
                    setState(() => _items[index] = item.copyWith(quantity: newQty));
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('qty_${item.id}_${item.quantity}'),
                    initialValue: item.quantity.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                    onChanged: (val) {
                      final v = double.tryParse(val) ?? 1;
                      setState(() => _items[index] = item.copyWith(quantity: v));
                    },
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    final newQty = item.quantity + 1;
                    setState(() => _items[index] = item.copyWith(quantity: newQty));
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Unit Price
          Expanded(
            child: TextFormField(
              initialValue: item.unitPrice.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0;
                setState(() => _items[index] = item.copyWith(unitPrice: v));
              },
            ),
          ),
          const SizedBox(width: 8),
          // TVA Rate
          Expanded(
            child: DropdownButtonFormField<double>(
              value: item.tvaRate,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              items: TvaRates.all
                  .map((t) => DropdownMenuItem(value: t, child: Text('$t%')))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _items[index] = item.copyWith(tvaRate: val));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Discount
          Expanded(
            child: TextFormField(
              initialValue: item.discountPercent.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0;
                setState(() => _items[index] = item.copyWith(discountPercent: v));
              },
            ),
          ),
          const SizedBox(width: 8),
          // Total HT
          Expanded(
            child: Container(
              height: 40,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(formatCurrencyDT(item.totalHT),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          if (!widget.isReadOnly)
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      item.showDescription ? Icons.description : Icons.description_outlined,
                      color: item.showDescription ? AppColors.primary : AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _items[index] = item.copyWith(showDescription: !item.showDescription);
                      });
                    },
                    tooltip: 'Description',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: () {
                      setState(() {
                        _items.removeAt(index);
                      });
                    },
                    tooltip: 'Supprimer',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleActions() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _items.add(SupplierOrderItem(
                  orderId: widget.existing?.id ?? '', productId: ''));
            });
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Ajouter un article'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            elevation: 0,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 24),
          tooltip: 'Créer un nouvel article',
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateArticleScreen()));
          },
          splashRadius: 24,
        ),
      ],
    );
  }

  // ── Totals & Global Discount ────────────────────────────────────────
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
            onTap: () { if (!widget.isReadOnly) setState(() => _withGlobalDiscount = !_withGlobalDiscount); },
            child: Row(
              children: [
                SizedBox(
                  width: 18, height: 18,
                  child: Checkbox(
                    value: _withGlobalDiscount,
                    onChanged: (v) { if (!widget.isReadOnly) setState(() => _withGlobalDiscount = v ?? false); },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: AppColors.border),
                    activeColor: AppColors.primary,
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

  InputDecoration _itemInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black87, fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

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
            InkWell(
              onTap: () { if (!widget.isReadOnly) setState(() => _withTimbreFiscal = !_withTimbreFiscal); },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: Checkbox(
                            value: _withTimbreFiscal,
                            onChanged: (v) { if (!widget.isReadOnly) setState(() => _withTimbreFiscal = v ?? false); },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: AppColors.border),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Timbre fiscal:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    Text(formatCurrencyDT(_timbreFiscal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
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

  Widget _buildNotesSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notes (Visibles par le fournisseur)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                readOnly: widget.isReadOnly,
                decoration: _formInputDecoration().copyWith(hintText: 'Ajouter une note...'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Conditions d'achat", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _conditionsCtrl,
                maxLines: 4,
                readOnly: widget.isReadOnly,
                decoration: _formInputDecoration().copyWith(hintText: 'Ajouter des conditions...'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
