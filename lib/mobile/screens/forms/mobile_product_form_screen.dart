import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/products/products_bloc.dart';
import '../../../../models/product.dart';
import '../../../../utils/constants.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

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

  String _name = '';
  String _reference = '';
  String _description = '';
  String _productType = 'produit';
  double _tvaRate = 19.0;
  String _unit = 'Piece';
  String? _familyId;
  String? _subFamilyId;
  String? _category;
  String? _brandId;
  
  double _purchasePrice = 0.0;
  double _sellingPrice = 0.0;
  
  bool _allowNegativeStock = false;
  bool _lowStockAlert = false;
  bool _highStockAlert = false;
  
  String _barcode = '';
  String _privateNotes = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final p = widget.existing!;
      _name = p.name;
      _reference = p.reference ?? '';
      _description = p.description ?? '';
      _productType = p.productType;
      _tvaRate = p.tvaRate;
      _unit = p.unit;
      _familyId = p.familyId;
      _subFamilyId = p.subFamilyId;
      _category = p.category;
      _brandId = p.brandId;
      _purchasePrice = p.purchasePrice;
      _sellingPrice = p.sellingPrice;
      _allowNegativeStock = p.allowNegativeStock;
      _lowStockAlert = p.lowStockAlert;
      _highStockAlert = p.highStockAlert;
      _barcode = p.barcode ?? '';
      _privateNotes = p.privateNotes ?? '';
    }
  }

  void _save() {
    if (widget.isReadOnly) return;
    if (!_formKey.currentState!.validate()) return;
    
    if (_name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer un nom d\'article'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.existing?.id ?? _uuid.v4(),
        code: widget.existing?.code ?? 'ART-${DateTime.now().millisecondsSinceEpoch % 10000}',
        name: _name.trim(),
        reference: _reference.trim().isEmpty ? null : _reference.trim(),
        description: _description.trim().isEmpty ? null : _description.trim(),
        productType: _productType,
        familyId: _familyId,
        subFamilyId: _subFamilyId,
        category: _category,
        brandId: _brandId,
        unit: _unit,
        purchasePrice: _purchasePrice,
        sellingPrice: _sellingPrice,
        tvaRate: _tvaRate,
        allowNegativeStock: _allowNegativeStock,
        lowStockAlert: _lowStockAlert,
        highStockAlert: _highStockAlert,
        barcode: _barcode.trim().isEmpty ? null : _barcode.trim(),
        privateNotes: _privateNotes.trim().isEmpty ? null : _privateNotes.trim(),
        isActive: widget.existing?.isActive ?? true,
      );

      if (widget.existing == null) {
        context.read<ProductsBloc>().add(AddProduct(product));
      } else {
        context.read<ProductsBloc>().add(UpdateProduct(product));
      }
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.existing == null ? 'Article créé avec succès' : 'Article mis à jour'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: ${e.toString()}'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: widget.isReadOnly ? 'Détails de l\'article' : (_isEditing ? 'Modifier l\'article' : 'Nouvel article'),
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: () {
        if (!widget.isReadOnly) _save();
      },
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              MobileFormSection(
                title: 'Informations Générales',
                icon: Icons.info_outline_rounded,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: 'Nom de l\'article *',
                        initialValue: _name,
                        onChanged: (v) { if (!widget.isReadOnly) _name = v; },
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Référence',
                        initialValue: _reference,
                        onChanged: (v) { if (!widget.isReadOnly) _reference = v; },
                      ),
                      const SizedBox(height: 16),
                      AbsorbPointer(
                        absorbing: widget.isReadOnly,
                        child: SmartToggleChips<String>(
                          label: 'Type',
                          value: _productType,
                          options: const ['produit', 'service', 'consommable'],
                          labelBuilder: (v) => v.toUpperCase(),
                          onChanged: (v) => setState(() => _productType = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Description',
                        initialValue: _description,
                        maxLines: 3,
                        onChanged: (v) { if (!widget.isReadOnly) _description = v; },
                      ),
                    ],
                  ),
                ),
              ),
              
              MobileFormSection(
                title: 'Tarification',
                icon: Icons.attach_money_rounded,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SmartTextInput(
                              label: 'Prix d\'Achat (HT)',
                              initialValue: _purchasePrice > 0 ? _purchasePrice.toString() : '',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) { if (!widget.isReadOnly) _purchasePrice = double.tryParse(v) ?? 0; },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SmartTextInput(
                              label: 'Prix de Vente (HT)',
                              initialValue: _sellingPrice > 0 ? _sellingPrice.toString() : '',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) { if (!widget.isReadOnly) _sellingPrice = double.tryParse(v) ?? 0; },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AbsorbPointer(
                        absorbing: widget.isReadOnly,
                        child: SmartToggleChips<double>(
                          label: 'TVA (%)',
                          value: _tvaRate,
                          options: const [0, 7, 13, 19],
                          labelBuilder: (v) => '${v.toInt()}%',
                          onChanged: (v) => setState(() => _tvaRate = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              MobileFormSection(
                title: 'Classification',
                icon: Icons.category_outlined,
                isInitiallyExpanded: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: 'Catégorie',
                        initialValue: _category ?? '',
                        onChanged: (v) { if (!widget.isReadOnly) _category = v; },
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Marque',
                        initialValue: _brandId ?? '',
                        onChanged: (v) { if (!widget.isReadOnly) _brandId = v; },
                      ),
                      const SizedBox(height: 16),
                      AbsorbPointer(
                        absorbing: widget.isReadOnly,
                        child: SmartToggleChips<String>(
                          label: 'Unité',
                          value: _unit,
                          options: const ['Piece', 'Kilogramme', 'Litre', 'Metre'],
                          labelBuilder: (v) => v,
                          onChanged: (v) => setState(() => _unit = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              MobileFormSection(
                title: 'Stock & Alertes',
                icon: Icons.inventory_2_outlined,
                isInitiallyExpanded: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartCheckbox(
                        label: 'Autoriser Stock Négatif',
                        value: _allowNegativeStock,
                        onChanged: widget.isReadOnly ? null : (v) => setState(() => _allowNegativeStock = v ?? false),
                      ),
                      const SizedBox(height: 8),
                      SmartCheckbox(
                        label: 'Alerte Rupture de Stock',
                        value: _lowStockAlert,
                        onChanged: widget.isReadOnly ? null : (v) => setState(() => _lowStockAlert = v ?? false),
                      ),
                      const SizedBox(height: 8),
                      SmartCheckbox(
                        label: 'Alerte Surstockage',
                        value: _highStockAlert,
                        onChanged: widget.isReadOnly ? null : (v) => setState(() => _highStockAlert = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              
              MobileFormSection(
                title: 'Informations Supplémentaires',
                icon: Icons.qr_code_scanner_rounded,
                isInitiallyExpanded: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: 'Code-barres',
                        initialValue: _barcode,
                        onChanged: (v) { if (!widget.isReadOnly) _barcode = v; },
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Notes Privées',
                        initialValue: _privateNotes,
                        maxLines: 2,
                        onChanged: (v) { if (!widget.isReadOnly) _privateNotes = v; },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
