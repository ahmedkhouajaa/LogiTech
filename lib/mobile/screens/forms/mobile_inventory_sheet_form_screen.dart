import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../../../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../../../blocs/products/products_bloc.dart';
import '../../../blocs/warehouses/warehouses_bloc.dart';
import '../../../blocs/warehouses/warehouses_event.dart';
import '../../../blocs/warehouses/warehouses_state.dart';
import '../../../models/inventory_sheet.dart';
import '../../../models/inventory_sheet_item.dart';
import '../../../models/product.dart';
import '../../../models/stock_movement.dart'; // Contains Warehouse
import '../../../database/database_helper.dart';
import '../../../utils/constants.dart';
import '../../../services/enterprise_service.dart';
import '../../../widgets/article_selection_modal.dart';
import 'mobile_product_form_screen.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

class MobileInventorySheetFormScreen extends StatefulWidget {
  final InventorySheet? existing;

  const MobileInventorySheetFormScreen({
    super.key,
    this.existing,
  });

  @override
  State<MobileInventorySheetFormScreen> createState() => _MobileInventorySheetFormScreenState();
}

class _MobileInventorySheetFormScreenState extends State<MobileInventorySheetFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  late DateTime _date;
  String? _selectedWarehouseId;
  final _countedByCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<InventorySheetItem> _items = [];
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<WarehousesBloc>().add(LoadWarehouses());

    if (widget.existing != null) {
      _date = widget.existing!.date;
      _selectedWarehouseId = widget.existing!.warehouseId;
      _countedByCtrl.text = widget.existing!.countedBy ?? '';
      _reasonCtrl.text = widget.existing!.reason ?? '';
      _notesCtrl.text = widget.existing!.notes ?? '';
      _items = List.from(widget.existing!.items.map((e) => e.copyWith()));
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _countedByCtrl.dispose();
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner un entrepôt'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez ajouter au moins un article'), backgroundColor: AppColors.error),
      );
      return;
    }
    
    for (var item in _items) {
      if (item.productId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Un ou plusieurs articles n\'ont pas été sélectionnés'), backgroundColor: AppColors.error),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final number = widget.existing?.number ?? 'FI-${DateTime.now().year}-${_uuid.v4().substring(0, 6).toUpperCase()}';

      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      final sheet = InventorySheet(
        id: widget.existing?.id ?? _uuid.v4(),
        number: number,
        date: _date,
        inventoryDate: _date,
        warehouseId: _selectedWarehouseId!,
        countedBy: _countedByCtrl.text.trim(),
        reason: _reasonCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        status: widget.existing?.status ?? 'draft',
        enterpriseId: currentEntId,
        items: _items,
        firebaseUid: widget.existing?.firebaseUid,
        createdAt: widget.existing?.createdAt,
      );

      if (!mounted) return;

      if (widget.existing != null) {
        context.read<InventorySheetsBloc>().add(InventorySheetUpdated(sheet));
      } else {
        context.read<InventorySheetsBloc>().add(InventorySheetAdded(sheet));
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addItem() async {
    final selectedProduct = await ArticleSelectionModal.show(context, warehouseId: _selectedWarehouseId);
    if (selectedProduct != null) {
      setState(() {
        _items.add(InventorySheetItem(
          id: _uuid.v4(),
          inventoryId: widget.existing?.id ?? '',
          productId: selectedProduct.id,
          theoreticalQty: selectedProduct.stockQty,
          actualQty: selectedProduct.stockQty,
        ));
      });
    }
  }

  Future<void> _showProductPicker(int index) async {
    final selectedProduct = await ArticleSelectionModal.show(context, warehouseId: _selectedWarehouseId);
    if (selectedProduct != null) {
      setState(() {
        final oldItem = _items[index];
        _items[index] = oldItem.copyWith(
          productId: selectedProduct.id,
          theoreticalQty: selectedProduct.stockQty,
          actualQty: selectedProduct.stockQty,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WarehousesBloc, WarehousesState>(
      listener: (context, state) {
        if (state is WarehousesLoaded) {
          setState(() {
            _warehouses = state.warehouses.where((w) => w.isActive).toList();
          });
        }
      },
      child: MobileFormScreen(
        title: widget.existing != null ? 'Modifier la fiche' : 'Nouvelle fiche',
        isLoading: _isLoading,
        onSave: _save,
        onCancel: () => Navigator.pop(context),
        children: [
          MobileFormSection(
            title: 'Général',
            icon: Icons.info_outline_rounded,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SmartDatePicker(
                    label: 'Date',
                    value: _date,
                    onChanged: (d) => setState(() => _date = d),
                  ),
                  SizedBox(height: 16),
                  SmartDropdown<String>(
                    label: 'Entrepôt',
                    value: _selectedWarehouseId,
                    items: _warehouses.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text(w.name));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedWarehouseId = v),
                    hint: 'Sélectionner l\'entrepôt...',
                  ),
                  SizedBox(height: 16),
                  SmartTextInput(
                    label: 'Compté par',
                    initialValue: _countedByCtrl.text,
                    onChanged: (v) => _countedByCtrl.text = v,
                  ),
                  SizedBox(height: 16),
                  SmartTextInput(
                    label: 'Motif (Optionnel)',
                    initialValue: _reasonCtrl.text,
                    onChanged: (v) => _reasonCtrl.text = v,
                  ),
                  SizedBox(height: 16),
                  SmartTextInput(
                    label: 'Notes (Optionnel)',
                    initialValue: _notesCtrl.text,
                    maxLines: 3,
                    onChanged: (v) => _notesCtrl.text = v,
                  ),
                ],
              ),
            ),
          ),
          MobileFormSection(
            title: 'Articles',
            icon: Icons.inventory_2_outlined,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_items.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text('Aucun article ajouté', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (index) {
                      final item = _items[index];
                      String productName = item.productId.isNotEmpty ? 'Produit sélectionné' : 'Sélectionner un produit';
                      if (_products.isNotEmpty && item.productId.isNotEmpty) {
                        try {
                          productName = _products.firstWhere((p) => p.id == item.productId).name;
                        } catch (_) {}
                      }

                      final diff = item.actualQty - item.theoreticalQty;
                      final surplus = diff > 0 ? diff : 0.0;
                      final missing = diff < 0 ? diff.abs() : 0.0;

                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Produit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                Spacer(),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _items.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            InkWell(
                              onTap: () => _showProductPicker(index),
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.productId.isNotEmpty ? productName : 'Sélectionner un article',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: item.productId.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Théorique', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
                                        child: Center(child: Text(item.theoreticalQty.toInt().toString(), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Réel', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      SizedBox(height: 4),
                                      TextFormField(
                                        initialValue: item.actualQty > 0 ? item.actualQty.toInt().toString() : '',
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.border)),
                                        ),
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        onChanged: (v) {
                                          final qty = double.tryParse(v) ?? 0;
                                          setState(() {
                                            _items[index] = item.copyWith(actualQty: qty);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Surplus', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: surplus > 0 ? AppColors.successLight : AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
                                        child: Center(child: Text(surplus > 0 ? surplus.toInt().toString() : '—', style: TextStyle(color: surplus > 0 ? AppColors.success : AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 12))),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Manquant', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: missing > 0 ? AppColors.errorLight : AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
                                        child: Center(child: Text(missing > 0 ? missing.toInt().toString() : '—', style: TextStyle(color: missing > 0 ? AppColors.error : AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 12))),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: Icon(Icons.add, size: 16),
                        label: Text('Ajouter une ligne'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 24),
                        tooltip: 'Créer un nouvel article',
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileProductFormScreen()));
                        },
                        splashRadius: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
