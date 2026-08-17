import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/products/products_bloc.dart';
import '../../../../blocs/product_settings/product_settings_bloc.dart';
import '../../../../blocs/product_settings/product_settings_state.dart';
import '../../../../blocs/product_settings/product_settings_event.dart';
import '../../../../models/product.dart';
import '../../../../models/product_family.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import 'package:business_manager_pro/services/error_handler.dart';

class MobileProductFormScreen extends StatefulWidget {
  final Product? existing;
  final bool isReadOnly;
  const MobileProductFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileProductFormScreen> createState() => _MobileProductFormScreenState();
}

class _MobileProductFormScreenState extends State<MobileProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _refCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _purchasePriceCtrl;
  late TextEditingController _sellingPriceCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _stockQtyCtrl;
  late TextEditingController _minStockQtyCtrl;
  late TextEditingController _maxStockQtyCtrl;
  late TextEditingController _notesCtrl;

  // Form State
  String _productType = 'produit';
  double _tvaRate = 19.0;
  String _unit = 'Piece';
  String? _familyId;
  String? _subFamilyId;
  String? _category;
  String? _brandId;

  double _purchasePrice = 0.0;
  double _sellingPrice = 0.0;
  double _usualDiscount = 0.0;

  double _stockQty = 0.0;
  double _minStockQty = 0.0;
  double _highStockThreshold = 100.0;

  bool _allowNegativeStock = false;
  bool _lowStockAlert = false;
  bool _highStockAlert = false;

  // Collapsible section state
  bool _generalExpanded = true;
  bool _pricingExpanded = true;
  bool _classificationExpanded = true;
  bool _stockExpanded = true;
  bool _extraExpanded = true;

  bool get _isEditing => widget.existing != null;

  static const List<Map<String, String>> _unitOptions = [
    {'value': 'Piece', 'label': 'Pièce', 'code': 'pcs'},
    {'value': 'Kilogramme', 'label': 'Kilogramme', 'code': 'kg'},
    {'value': 'Litre', 'label': 'Litre', 'code': 'L'},
    {'value': 'Metre', 'label': 'Mètre', 'code': 'm'},
    {'value': 'Gramme', 'label': 'Gramme', 'code': 'g'},
    {'value': 'Millilitre', 'label': 'Millilitre', 'code': 'ml'},
    {'value': 'Boite', 'label': 'Boîte', 'code': 'bte'},
    {'value': 'Carton', 'label': 'Carton', 'code': 'ctn'},
    {'value': 'Paquet', 'label': 'Paquet', 'code': 'pqt'},
    {'value': 'Lot', 'label': 'Lot', 'code': 'lot'},
    {'value': 'Heure', 'label': 'Heure', 'code': 'h'},
    {'value': 'Jour', 'label': 'Jour', 'code': 'j'},
    {'value': 'Forfait', 'label': 'Forfait', 'code': 'forf'},
  ];

  static const List<String> _categoryOptions = [
    'Standard',
    'Premium',
    'Informatique',
    'Bureautique',
    'Alimentation',
    'Électronique',
    'Outillage',
    'Mobilier',
    'Services',
    'Divers',
  ];

  static const List<String> _brandOptions = [
    'Samsung',
    'Apple',
    'Dell',
    'HP',
    'Logitech',
    'Lenovo',
    'Asus',
    'Xiaomi',
    'Sony',
    'Canon',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    // Dispatch load families to ensure data is fresh
    context.read<ProductSettingsBloc>().add(LoadFamilies());

    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _refCtrl = TextEditingController(text: p?.reference ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');

    _purchasePrice = p?.purchasePrice ?? 0.0;
    _sellingPrice = p?.sellingPrice ?? 0.0;
    _usualDiscount = p?.usualDiscount ?? 0.0;

    _purchasePriceCtrl = TextEditingController(
      text: _purchasePrice > 0 ? (_purchasePrice == _purchasePrice.truncateToDouble() ? _purchasePrice.toInt().toString() : _purchasePrice.toString()) : '',
    );
    _sellingPriceCtrl = TextEditingController(
      text: _sellingPrice > 0 ? (_sellingPrice == _sellingPrice.truncateToDouble() ? _sellingPrice.toInt().toString() : _sellingPrice.toString()) : '',
    );
    _discountCtrl = TextEditingController(
      text: _usualDiscount > 0 ? (_usualDiscount == _usualDiscount.truncateToDouble() ? _usualDiscount.toInt().toString() : _usualDiscount.toString()) : '',
    );

    _stockQty = p?.stockQty ?? 0.0;
    _minStockQty = p?.minStockQty ?? 0.0;
    _highStockThreshold = p?.highStockThreshold ?? 100.0;

    _stockQtyCtrl = TextEditingController(
      text: _stockQty > 0 ? (_stockQty == _stockQty.truncateToDouble() ? _stockQty.toInt().toString() : _stockQty.toString()) : '',
    );
    _minStockQtyCtrl = TextEditingController(
      text: _minStockQty > 0 ? (_minStockQty == _minStockQty.truncateToDouble() ? _minStockQty.toInt().toString() : _minStockQty.toString()) : '',
    );
    _maxStockQtyCtrl = TextEditingController(
      text: _highStockThreshold > 0 ? (_highStockThreshold == _highStockThreshold.truncateToDouble() ? _highStockThreshold.toInt().toString() : _highStockThreshold.toString()) : '',
    );

    _notesCtrl = TextEditingController(text: p?.privateNotes ?? '');

    _productType = ['produit', 'service', 'consommable'].contains(p?.productType) ? p!.productType : 'produit';
    _tvaRate = p?.tvaRate ?? 19.0;

    // Unit normalize
    String rawUnit = p?.unit ?? 'Piece';
    if (rawUnit == 'Pièce' || rawUnit == 'Unite') rawUnit = 'Piece';
    _unit = _unitOptions.any((u) => u['value'] == rawUnit) ? rawUnit : 'Piece';

    _familyId = p?.familyId;
    _subFamilyId = p?.subFamilyId;
    _category = p?.category;
    _brandId = p?.brandId;

    _allowNegativeStock = p?.allowNegativeStock ?? false;
    _lowStockAlert = p?.lowStockAlert ?? false;
    _highStockAlert = p?.highStockAlert ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _refCtrl.dispose();
    _barcodeCtrl.dispose();
    _descCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _discountCtrl.dispose();
    _stockQtyCtrl.dispose();
    _minStockQtyCtrl.dispose();
    _maxStockQtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _marginPercent {
    if (_purchasePrice > 0 && _sellingPrice > 0) {
      return ((_sellingPrice - _purchasePrice) / _purchasePrice) * 100;
    }
    return 0.0;
  }

  double get _sellingPriceTTC {
    return _sellingPrice * (1 + _tvaRate / 100);
  }

  void _save() {
    if (widget.isReadOnly) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez entrer un nom d\'article'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.existing?.id ?? _uuid.v4(),
        code: widget.existing?.code ?? 'ART-${DateTime.now().millisecondsSinceEpoch % 10000}',
        name: name,
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        productType: _productType,
        familyId: _familyId,
        subFamilyId: _subFamilyId,
        category: _category?.trim().isEmpty == true ? null : _category?.trim(),
        brandId: _brandId?.trim().isEmpty == true ? null : _brandId?.trim(),
        unit: _unit,
        purchasePrice: _purchasePrice,
        sellingPrice: _sellingPrice,
        usualDiscount: _usualDiscount,
        tvaRate: _tvaRate,
        stockQty: _stockQty,
        minStockQty: _minStockQty,
        allowNegativeStock: _allowNegativeStock,
        lowStockAlert: _lowStockAlert,
        lowStockThreshold: _minStockQty > 0 ? _minStockQty : 5.0,
        highStockAlert: _highStockAlert,
        highStockThreshold: _highStockThreshold,
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        privateNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        isActive: widget.existing?.isActive ?? true,
      );

      if (widget.existing == null) {
        context.read<ProductsBloc>().add(AddProduct(product));
      } else {
        context.read<ProductsBloc>().add(UpdateProduct(product));
      }

      Navigator.pop(context, product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing == null ? 'Article créé avec succès' : 'Article mis à jour'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ErrorHandler.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── SEARCHABLE SELECTION DIALOG (Warehouse Picker Style) ─────────────────
  Future<T?> _showSearchableSelectDialog<T>({
    required String title,
    required String searchHint,
    required List<T> items,
    required String Function(T) itemTitle,
    String Function(T)? itemSubtitle,
    required bool Function(T, String query) filter,
    required bool Function(T) isSelected,
    IconData? itemIcon,
    bool allowCustom = false,
    T Function(String)? onAddCustom,
  }) async {
    return showDialog<T?>(
      context: context,
      builder: (context) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = search.trim().toLowerCase();
            final filtered = items.where((item) {
              if (query.isEmpty) return true;
              return filter(item, query);
            }).toList();

            final bool canAddNew = allowCustom &&
                query.isNotEmpty &&
                !items.any((item) => itemTitle(item).toLowerCase() == query);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: AppColors.surface,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 520, maxWidth: 420),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Title & Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search input
                    SizedBox(
                      height: 44,
                      child: TextField(
                        autofocus: false,
                        onChanged: (val) => setDialogState(() => search = val),
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
                    const SizedBox(height: 8),

                    // Items List
                    Flexible(
                      child: filtered.isEmpty && !canAddNew
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              alignment: Alignment.center,
                              child: Text(
                                'Aucun résultat trouvé',
                                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length + (canAddNew ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                if (canAddNew && index == filtered.length) {
                                  return InkWell(
                                    onTap: () {
                                      if (onAddCustom != null) {
                                        Navigator.of(context).pop(onAddCustom(search.trim()));
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Utiliser "${search.trim()}"',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final item = filtered[index];
                                final selected = isSelected(item);
                                final subtitle = itemSubtitle != null ? itemSubtitle(item) : null;

                                return InkWell(
                                  onTap: () => Navigator.of(context).pop(item),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (itemIcon != null) ...[
                                          Icon(
                                            itemIcon,
                                            size: 18,
                                            color: selected ? AppColors.primary : AppColors.textTertiary,
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                itemTitle(item),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                                  color: selected ? AppColors.primary : AppColors.textPrimary,
                                                ),
                                              ),
                                              if (subtitle != null && subtitle.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textTertiary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (selected)
                                          Icon(Icons.check_rounded, size: 20, color: AppColors.primary),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Section 1: Informations Générales
                      _buildGeneralInfoSection(),
                      const SizedBox(height: 16),

                      // Section 2: Tarification
                      _buildPricingSection(),
                      const SizedBox(height: 16),

                      // Section 3: Classification (Famille, Sous-famille, Catégorie, Marque, Unité)
                      _buildClassificationSection(),
                      const SizedBox(height: 16),

                      // Section 4: Stock & Alertes
                      _buildStockSection(),
                      const SizedBox(height: 16),

                      // Section 5: Informations Supplémentaires
                      _buildExtraInfoSection(),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ─── APP BAR ─────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.isReadOnly
            ? 'Détails de l\'article'
            : (_isEditing ? 'Modifier l\'article' : 'Nouvel article'),
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      shape: Border(
        bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6), width: 1),
      ),
    );
  }

  // ─── CARD CONTAINER BUILDER ──────────────────────────────────────────────
  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Body
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ─── SECTION 1: INFORMATIONS GÉNÉRALES ──────────────────────────────────
  Widget _buildGeneralInfoSection() {
    return _buildCard(
      title: 'Informations Générales',
      subtitle: 'Type, références et description',
      icon: Icons.inventory_2_rounded,
      iconColor: const Color(0xFF2563EB),
      iconBgColor: const Color(0xFFEFF6FF),
      isExpanded: _generalExpanded,
      onToggle: () => setState(() => _generalExpanded = !_generalExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Selector (Pill / Segmented)
          _buildFieldLabel('Type d\'article'),
          const SizedBox(height: 8),
          _buildTypeSelector(),
          const SizedBox(height: 16),

          // Nom de l'article
          _buildFieldLabel('Nom de l\'article', isRequired: true),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _nameCtrl,
            hintText: 'Saisissez le nom de l\'article',
            prefixIcon: Icons.drive_file_rename_outline_rounded,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire' : null,
          ),
          const SizedBox(height: 16),

          // Référence & Code-barres (2 columns)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Référence'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _refCtrl,
                      hintText: 'Ex: REF-0012',
                      prefixIcon: Icons.tag_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Code-barres'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _barcodeCtrl,
                      hintText: 'Ex: 619123456789',
                      prefixIcon: Icons.qr_code_scanner_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description (Multiline)
          _buildFieldLabel('Description'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _descCtrl,
            hintText: 'Saisissez la description détaillée de l\'article...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ─── TYPE PILL SELECTOR ──────────────────────────────────────────────────
  Widget _buildTypeSelector() {
    final types = [
      {'value': 'produit', 'label': 'PRODUIT', 'icon': Icons.inventory_2_outlined},
      {'value': 'service', 'label': 'SERVICE', 'icon': Icons.handyman_outlined},
      {'value': 'consommable', 'label': 'CONSOMMABLE', 'icon': Icons.label_outline_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: types.map((t) {
          final isSelected = _productType == t['value'];
          return Expanded(
            child: GestureDetector(
              onTap: widget.isReadOnly
                  ? null
                  : () => setState(() => _productType = t['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 15,
                      color: isSelected ? AppColors.primary : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── SECTION 2: TARIFICATION ─────────────────────────────────────────────
  Widget _buildPricingSection() {
    return _buildCard(
      title: 'Tarification',
      subtitle: 'Prix d\'achat, de vente, taxes et remises',
      icon: Icons.payments_outlined,
      iconColor: const Color(0xFF10B981),
      iconBgColor: const Color(0xFFECFDF5),
      isExpanded: _pricingExpanded,
      onToggle: () => setState(() => _pricingExpanded = !_pricingExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pricing Inputs: Prix d'Achat & Prix de Vente
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Prix d\'Achat (HT)'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _purchasePriceCtrl,
                      hintText: '0,000',
                      suffixText: 'DT',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                        setState(() => _purchasePrice = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Prix de Vente (HT)'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _sellingPriceCtrl,
                      hintText: '0,000',
                      suffixText: 'DT',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                        setState(() => _sellingPrice = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Remise Habituelle (%)
          _buildFieldLabel('% Remise Habituelle'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _discountCtrl,
            hintText: '0',
            suffixText: '%',
            prefixIcon: Icons.discount_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final val = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
              setState(() => _usualDiscount = val);
            },
          ),
          const SizedBox(height: 14),

          // Computed Pricing Insights Card
          _buildPricingInsightCard(),
          const SizedBox(height: 16),

          // TVA Rate Selector
          _buildFieldLabel('Taux de TVA (%)'),
          const SizedBox(height: 8),
          _buildTvaSelector(),
        ],
      ),
    );
  }

  // ─── PRICING INSIGHT CARD ────────────────────────────────────────────────
  Widget _buildPricingInsightCard() {
    final margin = _marginPercent;
    final isProfitable = margin >= 0;
    final ttc = _sellingPriceTTC;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isProfitable ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 18,
                color: isProfitable ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                'Marge: ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${isProfitable ? '+' : ''}${margin.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isProfitable ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Prix TTC: ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                formatCurrencyDT(ttc),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TVA PILL SELECTOR ───────────────────────────────────────────────────
  Widget _buildTvaSelector() {
    final rates = [0.0, 7.0, 13.0, 19.0];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: rates.map((rate) {
          final isSelected = _tvaRate == rate;
          return Expanded(
            child: GestureDetector(
              onTap: widget.isReadOnly ? null : () => setState(() => _tvaRate = rate),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${rate.toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── SECTION 3: CLASSIFICATION ───────────────────────────────────────────
  Widget _buildClassificationSection() {
    return _buildCard(
      title: 'Classification',
      subtitle: 'Famille, sous-famille, catégorie, marque et unité',
      icon: Icons.category_outlined,
      iconColor: const Color(0xFF8B5CF6),
      iconBgColor: const Color(0xFFF5F3FF),
      isExpanded: _classificationExpanded,
      onToggle: () => setState(() => _classificationExpanded = !_classificationExpanded),
      child: BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
        builder: (context, state) {
          List<ProductFamily> rootFamilies = [];
          List<ProductFamily> subFamilies = [];

          if (state is ProductSettingsLoaded) {
            rootFamilies = state.rootFamilies;
            if (_familyId != null && !rootFamilies.any((f) => f.id == _familyId)) {
              _familyId = null;
              _subFamilyId = null;
            }
            if (_familyId != null) {
              subFamilies = state.getSubFamilies(_familyId!);
              if (_subFamilyId != null && !subFamilies.any((sf) => sf.id == _subFamilyId)) {
                _subFamilyId = null;
              }
            }
          }

          final selectedFamily = rootFamilies.where((f) => f.id == _familyId).firstOrNull;
          final selectedSubFamily = subFamilies.where((sf) => sf.id == _subFamilyId).firstOrNull;
          final selectedUnitMap = _unitOptions.firstWhere((u) => u['value'] == _unit, orElse: () => _unitOptions.first);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Famille & Sous-famille (Always visible with Dialog Selectors)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Famille'),
                        const SizedBox(height: 6),
                        _buildDialogSelectorField(
                          text: selectedFamily?.name,
                          hint: 'Sélectionner',
                          prefixIcon: Icons.account_tree_outlined,
                          onTap: widget.isReadOnly
                              ? null
                              : () async {
                                  final res = await _showSearchableSelectDialog<ProductFamily>(
                                    title: 'Sélectionner une famille',
                                    searchHint: 'Rechercher une famille...',
                                    items: rootFamilies,
                                    itemTitle: (f) => f.name,
                                    filter: (f, q) => f.name.toLowerCase().contains(q),
                                    isSelected: (f) => f.id == _familyId,
                                    itemIcon: Icons.folder_open_rounded,
                                  );
                                  if (res != null) {
                                    setState(() {
                                      _familyId = res.id;
                                      _subFamilyId = null;
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Sous-famille'),
                        const SizedBox(height: 6),
                        _buildDialogSelectorField(
                          text: selectedSubFamily?.name,
                          hint: _familyId == null ? 'Choisir famille' : 'Sélectionner',
                          prefixIcon: Icons.subdirectory_arrow_right_rounded,
                          onTap: widget.isReadOnly || _familyId == null
                              ? () {
                                  if (_familyId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Veuillez d\'abord sélectionner une famille'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              : () async {
                                  final res = await _showSearchableSelectDialog<ProductFamily>(
                                    title: 'Sélectionner une sous-famille',
                                    searchHint: 'Rechercher une sous-famille...',
                                    items: subFamilies,
                                    itemTitle: (sf) => sf.name,
                                    filter: (sf, q) => sf.name.toLowerCase().contains(q),
                                    isSelected: (sf) => sf.id == _subFamilyId,
                                    itemIcon: Icons.account_tree_outlined,
                                  );
                                  if (res != null) {
                                    setState(() => _subFamilyId = res.id);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Catégorie & Marque (Dialog Selectors)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Catégorie'),
                        const SizedBox(height: 6),
                        _buildDialogSelectorField(
                          text: _category,
                          hint: 'Sélectionner',
                          prefixIcon: Icons.folder_outlined,
                          onTap: widget.isReadOnly
                              ? null
                              : () async {
                                  final res = await _showSearchableSelectDialog<String>(
                                    title: 'Sélectionner une catégorie',
                                    searchHint: 'Rechercher une catégorie...',
                                    items: _categoryOptions,
                                    itemTitle: (c) => c,
                                    filter: (c, q) => c.toLowerCase().contains(q),
                                    isSelected: (c) => c == _category,
                                    itemIcon: Icons.category_outlined,
                                    allowCustom: true,
                                    onAddCustom: (q) => q,
                                  );
                                  if (res != null) {
                                    setState(() => _category = res);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Marque'),
                        const SizedBox(height: 6),
                        _buildDialogSelectorField(
                          text: _brandId,
                          hint: 'Sélectionner',
                          prefixIcon: Icons.branding_watermark_outlined,
                          onTap: widget.isReadOnly
                              ? null
                              : () async {
                                  final res = await _showSearchableSelectDialog<String>(
                                    title: 'Sélectionner une marque',
                                    searchHint: 'Rechercher une marque...',
                                    items: _brandOptions,
                                    itemTitle: (b) => b,
                                    filter: (b, q) => b.toLowerCase().contains(q),
                                    isSelected: (b) => b == _brandId,
                                    itemIcon: Icons.branding_watermark_outlined,
                                    allowCustom: true,
                                    onAddCustom: (q) => q,
                                  );
                                  if (res != null) {
                                    setState(() => _brandId = res);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Unité (Dialog Selector)
              _buildFieldLabel('Unité de mesure'),
              const SizedBox(height: 6),
              _buildDialogSelectorField(
                text: '${selectedUnitMap['label']} (${selectedUnitMap['code']})',
                hint: 'Sélectionner une unité',
                prefixIcon: Icons.straighten_rounded,
                onTap: widget.isReadOnly
                    ? null
                    : () async {
                        final res = await _showSearchableSelectDialog<Map<String, String>>(
                          title: 'Sélectionner une unité',
                          searchHint: 'Rechercher une unité...',
                          items: _unitOptions,
                          itemTitle: (u) => '${u['label']} (${u['code']})',
                          itemSubtitle: (u) => 'Unité standard: ${u['value']}',
                          filter: (u, q) =>
                              u['label']!.toLowerCase().contains(q) ||
                              u['code']!.toLowerCase().contains(q) ||
                              u['value']!.toLowerCase().contains(q),
                          isSelected: (u) => u['value'] == _unit,
                          itemIcon: Icons.straighten_rounded,
                        );
                        if (res != null) {
                          setState(() => _unit = res['value']!);
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── DIALOG SELECTOR TRIGGER FIELD ───────────────────────────────────────
  Widget _buildDialogSelectorField({
    required String? text,
    required String hint,
    required VoidCallback? onTap,
    IconData? prefixIcon,
  }) {
    final hasValue = text != null && text.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (prefixIcon != null) ...[
              Icon(
                prefixIcon,
                size: 18,
                color: hasValue ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                hasValue ? text : hint,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                  color: hasValue ? AppColors.textPrimary : AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ─── SECTION 4: STOCK & ALERTES ──────────────────────────────────────────
  Widget _buildStockSection() {
    return _buildCard(
      title: 'Stock & Alertes',
      subtitle: 'Quantités initiales, seuils et alertes',
      icon: Icons.warehouse_outlined,
      iconColor: const Color(0xFFF59E0B),
      iconBgColor: const Color(0xFFFFFBEB),
      isExpanded: _stockExpanded,
      onToggle: () => setState(() => _stockExpanded = !_stockExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stock Initial
          _buildFieldLabel('Stock initial'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _stockQtyCtrl,
            hintText: '0',
            suffixText: _unit,
            prefixIcon: Icons.inventory_2_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final val = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
              setState(() => _stockQty = val);
            },
          ),
          const SizedBox(height: 14),

          // Stock Minimum & Stock Maximum (2 columns)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Stock minimum'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _minStockQtyCtrl,
                      hintText: '0',
                      suffixText: _unit,
                      prefixIcon: Icons.arrow_downward_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                        setState(() => _minStockQty = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Stock maximum'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _maxStockQtyCtrl,
                      hintText: '100',
                      suffixText: _unit,
                      prefixIcon: Icons.arrow_upward_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.')) ?? 100.0;
                        setState(() => _highStockThreshold = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggle 1: Autoriser Stock Négatif
          _buildToggleSwitchTile(
            title: 'Autoriser Stock Négatif',
            subtitle: 'Permet la vente et facturation même si le stock est épuisé',
            icon: Icons.remove_shopping_cart_outlined,
            value: _allowNegativeStock,
            onChanged: widget.isReadOnly
                ? null
                : (v) => setState(() => _allowNegativeStock = v),
          ),
          const SizedBox(height: 12),

          // Toggle 2: Alerte Rupture de Stock
          _buildToggleSwitchTile(
            title: 'Alerte Rupture de Stock',
            subtitle: 'Recevoir une alerte lorsque le stock est inférieur au stock minimum',
            icon: Icons.notification_important_outlined,
            value: _lowStockAlert,
            onChanged: widget.isReadOnly
                ? null
                : (v) => setState(() => _lowStockAlert = v),
          ),
          const SizedBox(height: 12),

          // Toggle 3: Alerte Surstockage
          _buildToggleSwitchTile(
            title: 'Alerte Surstockage',
            subtitle: 'Avertir en cas de dépassement du stock maximum configuré',
            icon: Icons.inventory_outlined,
            value: _highStockAlert,
            onChanged: widget.isReadOnly
                ? null
                : (v) => setState(() => _highStockAlert = v),
          ),
        ],
      ),
    );
  }

  // ─── TOGGLE SWITCH TILE ──────────────────────────────────────────────────
  Widget _buildToggleSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: value
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: value ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── SECTION 5: INFORMATIONS SUPPLÉMENTAIRES ─────────────────────────────
  Widget _buildExtraInfoSection() {
    return _buildCard(
      title: 'Informations Supplémentaires',
      subtitle: 'Notes privées et remarques internes',
      icon: Icons.notes_rounded,
      iconColor: const Color(0xFF6366F1),
      iconBgColor: const Color(0xFFEEF2FF),
      isExpanded: _extraExpanded,
      onToggle: () => setState(() => _extraExpanded = !_extraExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Notes Privées'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _notesCtrl,
            hintText: 'Notes internes visibles uniquement par l\'équipe...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ─── STICKY BOTTOM ACTION BAR ────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Annuler Button
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: AppColors.surface,
                ),
                child: Text(
                  'Annuler',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Enregistrer Button
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || widget.isReadOnly) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isLoading
                      ? 'Enregistrement...'
                      : (_isEditing ? 'Enregistrer' : 'Créer l\'article'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── REUSABLE UI HELPERS ─────────────────────────────────────────────────
  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    String? suffixText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: widget.isReadOnly,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: AppColors.textTertiary)
            : null,
        suffixText: suffixText,
        suffixStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

