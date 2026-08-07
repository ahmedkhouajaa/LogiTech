import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product.dart';
import '../../../blocs/products/products_bloc.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../../widgets/searchable_dropdown_field.dart';
import 'mobile_smart_fields.dart';

class MobileArticleFormResult {
  final String productId;
  final String productName;
  final String description;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  final double discountPercent;

  MobileArticleFormResult({
    required this.productId,
    required this.productName,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.tvaRate,
    required this.discountPercent,
  });

  double get computedTotalHT => (quantity * unitPrice) * (1 - (discountPercent / 100));
}

class MobileArticleForm extends StatefulWidget {
  final MobileArticleFormResult? initialData;
  final ValueChanged<MobileArticleFormResult> onSave;
  final bool isPurchase; // if true, uses purchase price instead of selling price

  const MobileArticleForm({
    super.key,
    this.initialData,
    required this.onSave,
    this.isPurchase = false,
  });

  static Future<MobileArticleFormResult?> show(BuildContext context, {
    MobileArticleFormResult? initialData,
    bool isPurchase = false,
  }) {
    return showModalBottomSheet<MobileArticleFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MobileArticleForm(
        initialData: initialData,
        isPurchase: isPurchase,
        onSave: (result) => Navigator.pop(ctx, result),
      ),
    );
  }

  @override
  State<MobileArticleForm> createState() => _MobileArticleFormState();
}

class _MobileArticleFormState extends State<MobileArticleForm> {
  final _uuid = const Uuid();
  
  String _productId = '';
  String _productName = '';
  String _description = '';
  double _quantity = 1;
  double _unitPrice = 0;
  double _tvaRate = 19;
  double _discountPercent = 0;
  bool _showDescription = false;
  bool _applyDiscount = false;

  late final TextEditingController _unitPriceController;

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());

    if (widget.initialData != null) {
      final data = widget.initialData!;
      _productId = data.productId;
      _productName = data.productName;
      _description = data.description;
      _quantity = data.quantity;
      _unitPrice = data.unitPrice;
      _tvaRate = data.tvaRate;
      _discountPercent = data.discountPercent;
      
      _showDescription = _description != _productName && _description.isNotEmpty;
      _applyDiscount = _discountPercent > 0;
    }

    _unitPriceController = TextEditingController(
      text: _unitPrice > 0 ? _unitPrice.toStringAsFixed(3) : '',
    );
  }

  @override
  void dispose() {
    _unitPriceController.dispose();
    super.dispose();
  }

  double get _computedTotalHT => (_quantity * _unitPrice) * (1 - (_discountPercent / 100));

  void _handleSave() {
    if (_productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un article'), backgroundColor: AppColors.error),
      );
      return;
    }

    widget.onSave(MobileArticleFormResult(
      productId: _productId.isNotEmpty ? _productId : _uuid.v4(),
      productName: _productName,
      description: _showDescription ? _description : _productName,
      quantity: _quantity,
      unitPrice: _unitPrice,
      tvaRate: _tvaRate,
      discountPercent: _applyDiscount ? _discountPercent : 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen height to limit bottom sheet
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.symmetric(vertical: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialData == null ? 'Ajouter un article' : 'Modifier l\'article',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          
          // Form content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Designation
                  Text('Désignation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: BlocBuilder<ProductsBloc, ProductsState>(
                          builder: (context, state) {
                            final products = state is ProductsLoaded ? state.products : <Product>[];
                            final selectedProduct = products.cast<Product?>().firstWhere((p) => p?.id == _productId || p?.name == _productName, orElse: () => null);
                            final displayName = selectedProduct != null ? selectedProduct.name : (_productName.isNotEmpty ? _productName : null);

                            return SmartSearchableSelector(
                              label: '',
                              hint: 'Rechercher un article...',
                              selectedText: displayName,
                              onTap: () async {
                                final res = await showProductSelectDialog(context, products, selectedProductId: _productId);
                                if (res != null && mounted) {
                                  final sel = products.firstWhere((p) => p.id == res);
                                  final price = widget.isPurchase ? sel.purchasePrice : sel.sellingPrice;
                                  setState(() {
                                    _productId = sel.id;
                                    _productName = sel.name;
                                    _description = sel.name;
                                    _unitPrice = price;
                                    _tvaRate = sel.tvaRate;
                                    _unitPriceController.text = price.toStringAsFixed(3);
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Options (Show Description / Apply Discount)
                  Row(
                    children: [
                      Expanded(
                        child: SmartCheckbox(
                          label: 'Afficher la description',
                          value: _showDescription,
                          onChanged: (v) => setState(() => _showDescription = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: SmartCheckbox(
                          label: 'Appliquer remise',
                          value: _applyDiscount,
                          onChanged: (v) => setState(() => _applyDiscount = v ?? false),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  if (_showDescription) ...[
                    SmartTextInput(
                      label: 'Description détaillée',
                      initialValue: _description,
                      maxLines: 3,
                      onChanged: (v) => setState(() => _description = v),
                    ),
                    SizedBox(height: 20),
                  ],

                  // Quantity and P.U Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SmartNumberInput(
                          label: 'Quantité',
                          value: _quantity,
                          onChanged: (v) => setState(() => _quantity = v),
                          min: 0.1,
                          step: 1,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: SmartTextInput(
                          label: 'P.U HT',
                          controller: _unitPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          suffixText: 'TND',
                          onChanged: (v) => setState(() => _unitPrice = double.tryParse(v) ?? 0),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Discount and TVA Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _applyDiscount 
                          ? SmartTextInput(
                              label: 'Remise %',
                              initialValue: _discountPercent > 0 ? _discountPercent.toStringAsFixed(0) : '',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              suffixText: '%',
                              onChanged: (v) => setState(() => _discountPercent = double.tryParse(v) ?? 0),
                            )
                          : SizedBox.shrink(),
                      ),
                      if (_applyDiscount) SizedBox(width: 16),
                      Expanded(
                        child: SmartDropdown<double>(
                          label: 'TVA',
                          value: _tvaRate,
                          items: (TvaRates.all.contains(_tvaRate) ? TvaRates.all : [...TvaRates.all, _tvaRate])
                              .map((r) => DropdownMenuItem(value: r, child: Text('${r.toInt()}%', style: TextStyle(fontSize: 16))))
                              .toList(),
                          onChanged: (v) => setState(() => _tvaRate = v ?? 19),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Sticky Bottom Bar
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total HT', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text(
                        formatCurrencyDT(_computedTotalHT),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: Text(
                      widget.initialData == null ? 'Ajouter' : 'Enregistrer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
