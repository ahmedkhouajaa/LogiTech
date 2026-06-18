import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/product_settings/product_settings_bloc.dart';
import '../blocs/product_settings/product_settings_state.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class CreateArticleScreen extends StatefulWidget {
  final Product? existing;
  const CreateArticleScreen({super.key, this.existing});

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
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
  
  bool _allowNegativeStock = false;
  bool _lowStockAlert = false;
  bool _highStockAlert = false;
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    _unit = ['Piece', 'Kilogramme', 'Litre', 'Metre'].contains(rawUnit) ? rawUnit : 'Piece';
    
    // Load family, subFamily, category, brand without constraints
    _family = p?.familyId;
    _subFamily = p?.subFamilyId;
    _category = p?.category;
    _brand = ['Samsung', 'Apple', 'Dell', 'HP'].contains(p?.brandId) ? p!.brandId : null;
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  widget.existing == null ? 'Creer un Nouvel Article' : 'Modifier l\'Article',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                  label: const Text('Retour', style: TextStyle(color: AppColors.textSecondary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: const Text('Creer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // TabBar Header
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF7C3AED),
              unselectedLabelColor: AppColors.textTertiary,
              indicatorColor: const Color(0xFF7C3AED),
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
        ],
      ),
    );
  }

  Widget _buildMainSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Destination', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSelectableButton('Vente', Icons.attach_money, _destination == 'Vente', () => setState(() => _destination = 'Vente'))),
              const SizedBox(width: 12),
              Expanded(child: _buildSelectableButton('Achat', Icons.shopping_cart_outlined, _destination == 'Achat', () => setState(() => _destination = 'Achat'))),
              const SizedBox(width: 12),
              Expanded(child: _buildSelectableButton('Vente et Achat', null, _destination == 'Vente et Achat', () => setState(() => _destination = 'Vente et Achat'))),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Type d\'Article', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSelectableButton('Produit', Icons.inventory_2_outlined, _productType == 'produit', () => setState(() => _productType = 'produit'))),
              const SizedBox(width: 12),
              Expanded(child: _buildSelectableButton('Service', Icons.settings_outlined, _productType == 'service', () => setState(() => _productType = 'service'))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    AppTextField(label: 'Nom de l\'Article', controller: _nameCtrl, hint: 'Saisissez le nom de l\'article', validator: (v) => v!.isEmpty ? 'Requis' : null),
                    const SizedBox(height: 16),
                    AppTextField(label: 'Reference', controller: _refCtrl, hint: 'Saisissez la reference de l\'article'),
                    const SizedBox(height: 16),
                    AppTextField(label: 'Description', controller: _descCtrl, hint: 'Saisissez la description de l\'article', maxLines: 4),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /* const Text('Image de l\'Article', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt.withOpacity(0.5),
                        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_rounded, size: 32, color: AppColors.textSecondary),
                            SizedBox(height: 8),
                            Text('Cliquez, glissez ou collez une image', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ), */
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('TVA', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTvaButton(0),
              const SizedBox(width: 12),
              _buildTvaButton(7),
              const SizedBox(width: 12),
              _buildTvaButton(13),
              const SizedBox(width: 12),
              _buildTvaButton(19),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter TVA'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Taxes Supplementaires', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter Taxe', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: AppTextField(label: 'Prix de Vente', controller: _sellCtrl, suffix: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('DT')]), keyboardType: TextInputType.number)),
              const SizedBox(width: 24),
              Expanded(child: AppTextField(label: 'Prix d\'Achat', controller: _purchCtrl, suffix: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('DT')]), keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Icon(Icons.attach_money, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Listes de Prix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Configurez des tarifs speciaux pour differents groupes de clients ou quantites d\'achat', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: null,
            hint: const Text('Selectionnez une liste de prix'),
            items: ['Prix de Gros', 'Prix Detaillant', 'Client VIP'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {},
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Famille et Marque', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
                  builder: (context, state) {
                    if (state is ProductSettingsLoaded) {
                      final families = state.rootFamilies;
                      // Si la famille actuelle n'est plus dans la liste, on la reinitialise
                      if (_family != null && !families.any((f) => f.id == _family)) {
                        _family = null;
                        _subFamily = null;
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Famille', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _family,
                            hint: const Text('Selectionner'),
                            items: families.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                            onChanged: (v) {
                              setState(() {
                                _family = v;
                                _subFamily = null; // Reset sub-family quand on change de famille
                              });
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: BlocBuilder<ProductSettingsBloc, ProductSettingsState>(
                  builder: (context, state) {
                    if (state is ProductSettingsLoaded) {
                      List<DropdownMenuItem<String>> items = [];
                      if (_family != null) {
                        final subFamilies = state.getSubFamilies(_family!);
                        items = subFamilies.map((sf) => DropdownMenuItem(value: sf.id, child: Text(sf.name))).toList();
                        
                        // Reset if not found
                        if (_subFamily != null && !subFamilies.any((sf) => sf.id == _subFamily)) {
                          _subFamily = null;
                        }
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sous-famille', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _subFamily,
                            hint: const Text('Selectionner'),
                            items: items,
                            onChanged: _family == null ? null : (v) => setState(() => _subFamily = v),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Categorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _category,
                    hint: const Text('Selectionner'),
                    items: ['Standard', 'Premium'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _category = v),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              )),
              const SizedBox(width: 24),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Marque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _brand,
                    hint: const Text('Selectionner'),
                    items: ['Samsung', 'Apple', 'Dell', 'HP'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _brand = v),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _unit,
                    items: ['Piece', 'Kilogramme', 'Litre', 'Metre'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              )),
              const SizedBox(width: 24),
              Expanded(child: Container()), // Empty space to align
            ],
          ),
          const SizedBox(height: 24),
          AppTextField(label: 'Code-barres', controller: _barcodeCtrl, hint: 'Entrez le code-barres'),
          const SizedBox(height: 16),
          AppTextField(label: 'Notes Privees', controller: _privateNotesCtrl, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parametres de Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _allowNegativeStock,
                onChanged: (v) => setState(() => _allowNegativeStock = v ?? false),
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Autoriser Stock Vide', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('Autoriser la vente de cet article quand il est en rupture de stock', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Alerte rupture de stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Definissez des seuils d\'alerte pour etre notifie quand le stock est faible dans chaque entrepot', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.warehouse_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Entrepot par defaut', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Switch(
                  value: _lowStockAlert,
                  onChanged: (v) => setState(() => _lowStockAlert = v),
                  activeColor: AppColors.primary,
                ),
                Text('Alerte activee', style: TextStyle(fontSize: 13, color: _lowStockAlert ? AppColors.textPrimary : AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Alertes de Stock Maximum (surstockage)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Definissez des seuils max pour etre alerte quand le stock depasse le maximum dans chaque entrepot', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.warehouse_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Entrepot par defaut', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Switch(
                  value: _highStockAlert,
                  onChanged: (v) => setState(() => _highStockAlert = v),
                  activeColor: AppColors.primary,
                ),
                Text('Alerte max activee', style: TextStyle(fontSize: 13, color: _highStockAlert ? AppColors.textPrimary : AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Text('% Remise Habituelle', style: TextStyle(fontSize: 14)),
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
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
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
              const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
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
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
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
    
    Navigator.pop(context);
  }
}
