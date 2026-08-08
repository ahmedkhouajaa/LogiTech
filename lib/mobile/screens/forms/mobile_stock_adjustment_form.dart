import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../blocs/stock/stock_bloc.dart';
import '../../../blocs/products/products_bloc.dart';
import '../../../models/stock_movement.dart';
import '../../../models/product.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';
import '../../../widgets/searchable_dropdown_field.dart';

class MobileStockAdjustmentForm extends StatefulWidget {
  const MobileStockAdjustmentForm({super.key});

  @override
  State<MobileStockAdjustmentForm> createState() => _MobileStockAdjustmentFormState();
}

class _MobileStockAdjustmentFormState extends State<MobileStockAdjustmentForm> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  Product? _selectedProduct;
  String? _selectedWarehouseId;
  String _adjustmentAction = 'add'; // add, exit, correct
  final _quantityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<StockBloc>().add(LoadStock());
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  double _getWarehouseStockForProduct(Product product, StockState stockState) {
    if (_selectedWarehouseId == null) return product.stockQty;
    if (stockState is! StockLoaded) return product.stockQty;
    
    double stock = 0.0;
    bool isWarehouseDefault = false;
    try {
      final warehouses = stockState.warehouses;
      isWarehouseDefault = warehouses.firstWhere((w) => w.id == _selectedWarehouseId).isDefault;
    } catch (_) {}

    for (var m in stockState.movements) {
      if (m.productId == product.id) {
        final isWarehouseMatch = m.warehouseId == _selectedWarehouseId || (m.warehouseId == 'default_warehouse' && isWarehouseDefault);
        if (isWarehouseMatch) {
          if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
            stock += m.quantity;
          } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
            stock -= m.quantity;
          }
        }
      }
    }
    return stock;
  }

  void _save() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un article'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un entrepôt'), backgroundColor: AppColors.error),
      );
      return;
    }
    final qtyText = _quantityCtrl.text.trim();
    if (qtyText.isEmpty || double.tryParse(qtyText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez entrer une quantité valide'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stockState = context.read<StockBloc>().state;
      if (stockState is! StockLoaded) return;

      final currentStock = _getWarehouseStockForProduct(_selectedProduct!, stockState);
      final qtyInput = double.parse(qtyText);
      double qtyToRegister = 0;
      MovementType type = MovementType.adjustment;

      if (_adjustmentAction == 'correct') {
        final diff = qtyInput - currentStock;
        qtyToRegister = diff;
        type = MovementType.adjustment;
      } else if (_adjustmentAction == 'add') {
        qtyToRegister = qtyInput;
        type = MovementType.adjustment;
      } else {
        qtyToRegister = -qtyInput;
        type = MovementType.adjustment;
      }

      if (qtyToRegister == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La quantité d\'ajustement ne peut pas être nulle.'), backgroundColor: AppColors.warning),
        );
        setState(() => _isLoading = false);
        return;
      }

      final warehouse = stockState.warehouses.firstWhere((w) => w.id == _selectedWarehouseId);

      final movement = StockMovement(
        id: _uuid.v4(),
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        warehouseId: _selectedWarehouseId!,
        warehouseName: warehouse.name,
        type: type,
        quantity: qtyToRegister,
        referenceType: 'Ajustement',
        date: DateTime.now(),
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : 'Ajustement manuel',
      );

      context.read<StockBloc>().add(AddStockMovement(movement));
      context.read<ProductsBloc>().add(LoadProducts());

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajustement de stock enregistré avec succès'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: 'Nouvel ajustement de stock',
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      children: [
        // ── Section 1: Article ──
        MobileFormSection(
          title: 'Article',
          icon: Icons.inventory_2_outlined,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: BlocBuilder<StockBloc, StockState>(
              builder: (context, stockState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlocBuilder<ProductsBloc, ProductsState>(
                      builder: (context, pState) {
                        if (pState is! ProductsLoaded) {
                          return Center(child: CircularProgressIndicator());
                        }
                        return SmartSearchableSelector(
                          label: 'Désignation',
                          hint: 'Rechercher un article...',
                          selectedText: _selectedProduct?.name,
                          onTap: () async {
                            final res = await showProductSelectDialog(context, pState.products, warehouseId: _selectedWarehouseId);
                            if (res != null && mounted) {
                              final p = pState.products.cast<Product?>().firstWhere((item) => item?.id == res, orElse: () => null);
                              if (p != null) {
                                setState(() {
                                  _selectedProduct = p;
                                  if (_adjustmentAction == 'correct') {
                                    _quantityCtrl.text = _getWarehouseStockForProduct(p, stockState).toStringAsFixed(0);
                                  }
                                });
                              }
                            }
                          },
                        );
                      },
                    ),
                    if (_selectedProduct != null) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.primary.withValues(alpha: 0.03)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedProduct!.name,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Stock actuel: ${formatQuantity(_getWarehouseStockForProduct(_selectedProduct!, stockState))} ${_selectedProduct!.unit}',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),

        // ── Section 2: Entrepôt & Action ──
        MobileFormSection(
          title: 'Entrepôt & Action',
          icon: Icons.warehouse_rounded,
          isInitiallyExpanded: true,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: BlocBuilder<StockBloc, StockState>(
              builder: (context, stockState) {
                if (stockState is! StockLoaded) {
                  return Center(child: CircularProgressIndicator());
                }

                // Auto-select default warehouse
                if (_selectedWarehouseId == null && stockState.warehouses.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedWarehouseId == null) {
                      setState(() => _selectedWarehouseId = stockState.warehouses.first.id);
                    }
                  });
                }

                final selectedWarehouse = stockState.warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _selectedWarehouseId, orElse: () => null);
                final warehouseName = selectedWarehouse != null ? selectedWarehouse.name : 'Entrepôt Principal';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmartSearchableSelector(
                      label: 'Entrepôt',
                      hint: 'Sélectionner un entrepôt',
                      selectedText: warehouseName,
                      onTap: () async {
                        final res = await showWarehouseSelectDialog(context, stockState.warehouses, selectedWarehouseId: _selectedWarehouseId);
                        if (res != null && mounted) {
                          setState(() => _selectedWarehouseId = res);
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Type d'action", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _adjustmentAction,
                                  dropdownColor: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'add',
                                      child: Row(
                                        children: [
                                          Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.success),
                                          SizedBox(width: 8),
                                          Expanded(child: Text('Ajouter au stock', style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'exit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.error),
                                          SizedBox(width: 8),
                                          Expanded(child: Text('Retirer du stock', style: TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'correct',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_note_rounded, size: 18, color: AppColors.warning),
                                          SizedBox(width: 8),
                                          Expanded(child: Text('Corriger (Remplacer)', style: TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _adjustmentAction = v;
                                        if (v == 'correct' && _selectedProduct != null) {
                                          _quantityCtrl.text = _getWarehouseStockForProduct(_selectedProduct!, stockState).toStringAsFixed(0);
                                        } else {
                                          _quantityCtrl.clear();
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _adjustmentAction == 'correct' ? 'Nouveau stock' : 'Quantité',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              SizedBox(height: 6),
                              TextFormField(
                                controller: _quantityCtrl,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 15),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // ── Section 3: Notes / Motif ──
        MobileFormSection(
          title: 'Notes / Motif d\'ajustement',
          icon: Icons.notes_rounded,
          isInitiallyExpanded: true,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: SmartTextInput(
              label: 'Ex: Inventaire du mois, produit cassé...',
              controller: _notesCtrl,
              hint: 'Ex: Inventaire du mois, produit cassé...',
              maxLines: 3,
            ),
          ),
        ),
      ],
    );
  }
}
