import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/product_settings/product_settings_bloc.dart';
import '../blocs/product_settings/product_settings_state.dart';
import '../blocs/product_settings/product_settings_event.dart';
import '../models/product.dart';
import '../models/product_family.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import 'package:business_manager_pro/services/error_handler.dart';

class CreateArticleScreen extends StatefulWidget {
  final Product? existing;
  const CreateArticleScreen({super.key, this.existing});

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  
  // Controllers
  late final TextEditingController _nameCtrl, _refCtrl, _descCtrl;
  late final TextEditingController _purchCtrl, _sellCtrl, _discountCtrl;
  late final TextEditingController _barcodeCtrl, _privateNotesCtrl;
  
  // State variables
  String _destination = 'Vente et Achat';
  String _productType = 'produit';
  double _tvaRate = 19;
  String _unit = 'Piece';
  String? _family; 
  String? _subFamily;
  String? _category;
  String? _brand;
  String? _priceList;
  
  bool _allowNegativeStock = false;
  bool _lowStockAlert = false;
  bool _highStockAlert = false;
  
  late TabController _tabController;

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

  static const List<String> _priceListOptions = [
    'Prix de Gros',
    'Prix Détaillant',
    'Client VIP',
    'Tarif Spécial',
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    context.read<ProductSettingsBloc>().add(LoadFamilies());

    final p = widget.existing;
    
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _refCtrl = TextEditingController(text: p?.reference ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    
    _purchCtrl = TextEditingController(text: p?.purchasePrice.toString() ?? '0');
    _sellCtrl = TextEditingController(text: p?.sellingPrice.toString() ?? '0');
    _discountCtrl = TextEditingController(text: p?.usualDiscount.toString() ?? '0');
    
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _privateNotesCtrl = TextEditingController(text: p?.privateNotes ?? '');
    
    _productType = ['produit', 'service', 'consommable'].contains(p?.productType) ? p!.productType : 'produit';
    _tvaRate = p?.tvaRate ?? 19;
    
    // Safely load unit
    String rawUnit = p?.unit ?? 'Piece';
    if (rawUnit == 'Pièce' || rawUnit == 'Unite') rawUnit = 'Piece';
    _unit = _unitOptions.any((u) => u['value'] == rawUnit) ? rawUnit : 'Piece';
    
    _family = p?.familyId;
    _subFamily = p?.subFamilyId;
    _category = p?.category;
    _brand = p?.brandId;
    
    _allowNegativeStock = p?.allowNegativeStock ?? false;
    _lowStockAlert = p?.lowStockAlert ?? false;
    _highStockAlert = p?.highStockAlert ?? false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose(); _refCtrl.dispose(); _descCtrl.dispose();
    _purchCtrl.dispose(); _sellCtrl.dispose(); _discountCtrl.dispose();
    _barcodeCtrl.dispose(); _privateNotesCtrl.dispose();
    super.dispose();
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
              child: Container(
                width: 480,
                constraints: const BoxConstraints(maxHeight: 540),
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
                      height: 40,
                      child: TextField(
                        autofocus: false,
                        onChanged: (val) => setDialogState(() => search = val),
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    const SizedBox(height: 12),
                    Divider(height: 1, color: AppColors.border),
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
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(AppRadius.md),
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
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
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
                                                  fontSize: 13,
                                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                                  color: selected ? AppColors.primary : AppColors.textPrimary,
                                                ),
                                              ),
                                              if (subtitle != null && subtitle.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textTertiary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (selected)
                                          Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (prefixIcon != null) ...[
              Icon(
                prefixIcon,
                size: 16,
                color: hasValue ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                hasValue ? text : hint,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  widget.existing == null ? 'Creer un Nouvel Article' : 'Modifier l\'Article',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Spacer(),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                  label: Text('Retour', style: TextStyle(color: AppColors.textSecondary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(widget.existing == null ? 'Creer' : 'Enregistrer',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // TabBar Header
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'General', icon: Icon(Icons.info_outline_rounded, size: 20)),
                Tab(text: 'Prix & TVA', icon: Icon(Icons.attach_money_rounded, size: 20)),
                Tab(text: 'Classification', icon: Icon(Icons.category_outlined, size: 20)),
                Tab(text: 'Stock & Alertes', icon: Icon(Icons.inventory_2_outlined, size: 20)),
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildMainSection()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildPricingSection()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildClassificationSection()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildStockSection()),
                ],
              ),
            ),
          ),

          // Bottom Step Navigation Footer
          _buildBottomNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final currentIndex = _tabController.index;
    final isFirstTab = currentIndex == 0;
    final isLastTab = currentIndex == 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Précédent / Annuler Button
          if (!isFirstTab)
            OutlinedButton.icon(
              onPressed: () {
                _tabController.animateTo(currentIndex - 1);
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
              label: Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),

          // Step Progress Dots & Text
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Étape ${currentIndex + 1}/4',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (index) {
                  final isActive = currentIndex == index;
                  final isPassed = currentIndex > index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : (isPassed
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),

          // Suivant / Terminer Button
          if (!isLastTab)
            ElevatedButton.icon(
              onPressed: () {
                if (currentIndex == 0 && _nameCtrl.text.trim().isEmpty) {
                  _formKey.currentState?.validate();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Veuillez saisir le nom de l\'article pour continuer'),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                _tabController.animateTo(currentIndex + 1);
              },
              icon: const Text('Suivant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              label: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              label: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.existing == null ? 'Terminer & Créer' : 'Terminer & Enregistrer',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Destination', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSelectableButton('Vente', Icons.attach_money, _destination == 'Vente', () => setState(() => _destination = 'Vente'))),
              SizedBox(width: 12),
              Expanded(child: _buildSelectableButton('Achat', Icons.shopping_cart_outlined, _destination == 'Achat', () => setState(() => _destination = 'Achat'))),
              SizedBox(width: 12),
              Expanded(child: _buildSelectableButton('Vente et Achat', null, _destination == 'Vente et Achat', () => setState(() => _destination = 'Vente et Achat'))),
            ],
          ),
          SizedBox(height: 24),
          Text('Type d\'Article', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSelectableButton('Produit', Icons.inventory_2_outlined, _productType == 'produit', () => setState(() => _productType = 'produit'))),
              SizedBox(width: 12),
              Expanded(child: _buildSelectableButton('Service', Icons.settings_outlined, _productType == 'service', () => setState(() => _productType = 'service'))),
            ],
          ),
          SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    AppTextField(label: 'Nom de l\'Article', controller: _nameCtrl, hint: 'Saisissez le nom de l\'article', validator: (v) => v!.isEmpty ? 'Requis' : null),
                    SizedBox(height: 16),
                    AppTextField(label: 'Reference', controller: _refCtrl, hint: 'Saisissez la reference de l\'article'),
                    SizedBox(height: 16),
                    AppTextField(label: 'Description', controller: _descCtrl, hint: 'Saisissez la description de l\'article', maxLines: 4),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text('TVA', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Row(
            children: [
              _buildTvaButton(0),
              SizedBox(width: 12),
              _buildTvaButton(7),
              SizedBox(width: 12),
              _buildTvaButton(13),
              SizedBox(width: 12),
              _buildTvaButton(19),
              SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.add, size: 16),
                label: Text('Ajouter TVA'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Taxes Supplementaires', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.add, size: 16),
                label: Text('Ajouter Taxe', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: AppTextField(label: 'Prix de Vente', controller: _sellCtrl, suffix: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('DT')]), keyboardType: TextInputType.number)),
              SizedBox(width: 24),
              Expanded(child: AppTextField(label: 'Prix d\'Achat', controller: _purchCtrl, suffix: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('DT')]), keyboardType: TextInputType.number)),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.attach_money, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Listes de Prix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          SizedBox(height: 4),
          Text('Configurez des tarifs speciaux pour differents groupes de clients ou quantites d\'achat', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          SizedBox(height: 16),
          _buildDialogSelectorField(
            text: _priceList,
            hint: 'Sélectionnez une liste de prix',
            prefixIcon: Icons.sell_outlined,
            onTap: () async {
              final res = await _showSearchableSelectDialog<String>(
                title: 'Sélectionner une liste de prix',
                searchHint: 'Rechercher une liste...',
                items: _priceListOptions,
                itemTitle: (p) => p,
                filter: (p, q) => p.toLowerCase().contains(q),
                isSelected: (p) => p == _priceList,
                itemIcon: Icons.sell_outlined,
                allowCustom: true,
                onAddCustom: (q) => q,
              );
              if (res != null) {
                setState(() => _priceList = res);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Famille et Marque', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          SizedBox(height: 16),
          BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
            builder: (context, state) {
              List<ProductFamily> rootFamilies = [];
              List<ProductFamily> subFamilies = [];

              if (state is ProductSettingsLoaded) {
                rootFamilies = state.rootFamilies;
                if (_family != null && !rootFamilies.any((f) => f.id == _family)) {
                  _family = null;
                  _subFamily = null;
                }
                if (_family != null) {
                  subFamilies = state.getSubFamilies(_family!);
                  if (_subFamily != null && !subFamilies.any((sf) => sf.id == _subFamily)) {
                    _subFamily = null;
                  }
                }
              }

              final selectedFamily = rootFamilies.where((f) => f.id == _family).firstOrNull;
              final selectedSubFamily = subFamilies.where((sf) => sf.id == _subFamily).firstOrNull;

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Famille', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        _buildDialogSelectorField(
                          text: selectedFamily?.name,
                          hint: 'Sélectionner',
                          prefixIcon: Icons.account_tree_outlined,
                          onTap: () async {
                            final res = await _showSearchableSelectDialog<ProductFamily>(
                              title: 'Sélectionner une famille',
                              searchHint: 'Rechercher une famille...',
                              items: rootFamilies,
                              itemTitle: (f) => f.name,
                              filter: (f, q) => f.name.toLowerCase().contains(q),
                              isSelected: (f) => f.id == _family,
                              itemIcon: Icons.folder_open_rounded,
                            );
                            if (res != null) {
                              setState(() {
                                _family = res.id;
                                _subFamily = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sous-famille', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        _buildDialogSelectorField(
                          text: selectedSubFamily?.name,
                          hint: _family == null ? 'Choisir famille' : 'Sélectionner',
                          prefixIcon: Icons.subdirectory_arrow_right_rounded,
                          onTap: _family == null
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Veuillez d\'abord sélectionner une famille'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              : () async {
                                  final res = await _showSearchableSelectDialog<ProductFamily>(
                                    title: 'Sélectionner une sous-famille',
                                    searchHint: 'Rechercher une sous-famille...',
                                    items: subFamilies,
                                    itemTitle: (sf) => sf.name,
                                    filter: (sf, q) => sf.name.toLowerCase().contains(q),
                                    isSelected: (sf) => sf.id == _subFamily,
                                    itemIcon: Icons.account_tree_outlined,
                                  );
                                  if (res != null) {
                                    setState(() => _subFamily = res.id);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Categorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    _buildDialogSelectorField(
                      text: _category,
                      hint: 'Sélectionner',
                      prefixIcon: Icons.folder_outlined,
                      onTap: () async {
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
              SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    _buildDialogSelectorField(
                      text: _brand,
                      hint: 'Sélectionner',
                      prefixIcon: Icons.branding_watermark_outlined,
                      onTap: () async {
                        final res = await _showSearchableSelectDialog<String>(
                          title: 'Sélectionner une marque',
                          searchHint: 'Rechercher une marque...',
                          items: _brandOptions,
                          itemTitle: (b) => b,
                          filter: (b, q) => b.toLowerCase().contains(q),
                          isSelected: (b) => b == _brand,
                          itemIcon: Icons.branding_watermark_outlined,
                          allowCustom: true,
                          onAddCustom: (q) => q,
                        );
                        if (res != null) {
                          setState(() => _brand = res);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 6),
                    _buildDialogSelectorField(
                      text: _unitOptions.firstWhere((u) => u['value'] == _unit, orElse: () => _unitOptions.first)['label'],
                      hint: 'Sélectionner une unité',
                      prefixIcon: Icons.straighten_rounded,
                      onTap: () async {
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
                ),
              ),
              SizedBox(width: 24),
              Expanded(child: Container()), // Empty space to align
            ],
          ),
          SizedBox(height: 24),
          AppTextField(label: 'Code-barres', controller: _barcodeCtrl, hint: 'Entrez le code-barres'),
          SizedBox(height: 16),
          AppTextField(label: 'Notes Privees', controller: _privateNotesCtrl, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Parametres de Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.textSecondary),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _allowNegativeStock,
                onChanged: (v) => setState(() => _allowNegativeStock = v ?? false),
                activeColor: AppColors.primary,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Autoriser Stock Vide', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('Autoriser la vente de cet article quand il est en rupture de stock', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          Text('Alerte rupture de stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Definissez des seuils d\'alerte pour etre notifie quand le stock est faible dans chaque entrepot', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.warehouse_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Entrepot par defaut', style: TextStyle(fontSize: 14)),
                Spacer(),
                Switch(
                  value: _lowStockAlert,
                  onChanged: (v) => setState(() => _lowStockAlert = v),
                  activeThumbColor: AppColors.primary,
                ),
                Text('Alerte activee', style: TextStyle(fontSize: 13, color: _lowStockAlert ? AppColors.textPrimary : AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text('Alertes de Stock Maximum (surstockage)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Definissez des seuils max pour etre alerte quand le stock depasse le maximum dans chaque entrepot', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.warehouse_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Entrepot par defaut', style: TextStyle(fontSize: 14)),
                Spacer(),
                Switch(
                  value: _highStockAlert,
                  onChanged: (v) => setState(() => _highStockAlert = v),
                  activeThumbColor: AppColors.primary,
                ),
                Text('Alerte max activee', style: TextStyle(fontSize: 13, color: _highStockAlert ? AppColors.textPrimary : AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Text('% Remise Habituelle', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Switch(value: false, onChanged: (v) {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableButton(String title, IconData? icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, size: 16, color: AppColors.primary),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTvaButton(double rate) {
    final isSelected = _tvaRate == rate;
    return InkWell(
      onTap: () => setState(() => _tvaRate = rate),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          '${rate.toInt()}%',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final product = Product(
        id: widget.existing?.id ?? const Uuid().v4(),
        code: widget.existing?.code ?? 'ART-${DateTime.now().millisecondsSinceEpoch % 10000}',
        name: _nameCtrl.text.trim(),
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        productType: _productType,
        familyId: _family,
        subFamilyId: _subFamily,
        category: _category,
        brandId: _brand,
        unit: _unit,
        purchasePrice: double.tryParse(_purchCtrl.text) ?? 0,
        sellingPrice: double.tryParse(_sellCtrl.text) ?? 0,
        tvaRate: _tvaRate,
        allowNegativeStock: _allowNegativeStock,
        lowStockAlert: _lowStockAlert,
        highStockAlert: _highStockAlert,
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        privateNotes: _privateNotesCtrl.text.trim().isEmpty ? null : _privateNotesCtrl.text.trim(),
        isActive: widget.existing?.isActive ?? true,
      );

      if (widget.existing == null) {
        context.read<ProductsBloc>().add(AddProduct(product));
      } else {
        context.read<ProductsBloc>().add(UpdateProduct(product));
      }

      nav.pop(product);
      messenger.showSnackBar(SnackBar(
        content: Text(widget.existing == null ? 'Article cree avec succes' : 'Article mis a jour'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }
}
