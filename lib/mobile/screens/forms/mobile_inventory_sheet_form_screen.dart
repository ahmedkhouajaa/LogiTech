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
        const SnackBar(content: Text('Veuillez sélectionner un entrepôt'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un article'), backgroundColor: AppColors.error),
      );
      return;
    }
    
    for (var item in _items) {
      if (item.productId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Un ou plusieurs articles n\'ont pas été sélectionnés'), backgroundColor: AppColors.error),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final number = widget.existing?.number ?? 'FI-${DateTime.now().year}-${_uuid.v4().substring(0, 6).toUpperCase()}';

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

  void _addItem() {
    setState(() {
      _items.add(InventorySheetItem(
        id: _uuid.v4(),
        inventoryId: widget.existing?.id ?? '', // Will be updated on save if empty
        productId: '',
        theoreticalQty: 0,
        actualQty: 0,
      ));
    });
  }

  void _showProductPicker(int index) {
    if (_products.isEmpty) {
      final productsState = context.read<ProductsBloc>().state;
      if (productsState is ProductsLoaded) {
        _products = productsState.products.where((p) => !p.isDeleted).toList();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sélectionner un article', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, i) {
                    final p = _products[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.code),
                      onTap: () {
                        setState(() {
                          // Copy current item to maintain ID, update product details
                          final oldItem = _items[index];
                          _items[index] = oldItem.copyWith(
                            productId: p.id,
                            theoreticalQty: p.stockQty,
                            actualQty: p.stockQty, // Default actual to theoretical
                          );
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SmartDatePicker(
                    label: 'Date',
                    value: _date,
                    onChanged: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 16),
                  SmartDropdown<String>(
                    label: 'Entrepôt',
                    value: _selectedWarehouseId,
                    items: _warehouses.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text(w.name));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedWarehouseId = v),
                    hint: 'Sélectionner l\'entrepôt...',
                  ),
                  const SizedBox(height: 16),
                  SmartTextInput(
                    label: 'Compté par',
                    initialValue: _countedByCtrl.text,
                    onChanged: (v) => _countedByCtrl.text = v,
                  ),
                  const SizedBox(height: 16),
                  SmartTextInput(
                    label: 'Motif (Optionnel)',
                    initialValue: _reasonCtrl.text,
                    onChanged: (v) => _reasonCtrl.text = v,
                  ),
                  const SizedBox(height: 16),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter un article'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Aucun article ajouté', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  // Find product name for display
                  String productName = item.productId.isNotEmpty ? 'Produit sélectionné' : 'Sélectionner un produit';
                  if (_products.isNotEmpty && item.productId.isNotEmpty) {
                    try {
                      productName = _products.firstWhere((p) => p.id == item.productId).name;
                    } catch (_) {}
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showProductPicker(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          productName,
                                          style: TextStyle(
                                            color: item.productId.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                                            fontWeight: item.productId.isEmpty ? FontWeight.normal : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () {
                                setState(() {
                                  _items.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),

                        if (item.productId.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Qté théorique', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.theoreticalQty.toString(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Qté physique', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      initialValue: item.actualQty.toString(),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
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
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
