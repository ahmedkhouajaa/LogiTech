import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../blocs/stock_transfers/stock_transfers_bloc.dart';
import '../../../../blocs/products/products_bloc.dart';
import '../../../../models/stock_transfer.dart';
import '../../../../models/product.dart';
import '../../../../models/stock_movement.dart';
import '../../../../database/database_helper.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';

import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

class MobileStockTransferFormScreen extends StatefulWidget {
  final StockTransfer? existing;

  const MobileStockTransferFormScreen({super.key, this.existing});

  @override
  State<MobileStockTransferFormScreen> createState() => _MobileStockTransferFormScreenState();
}

class _MobileStockTransferFormScreenState extends State<MobileStockTransferFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  DateTime _date = DateTime.now();
  String? _sourceWarehouseId;
  String? _destWarehouseId;
  String _notes = '';
  String _reason = '';
  List<StockTransferItem> _items = [];

  List<Warehouse> _warehouses = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (context.read<ProductsBloc>().state is! ProductsLoaded) {
      context.read<ProductsBloc>().add(LoadProducts());
    }
    _loadWarehouses();

    if (widget.existing != null) {
      final t = widget.existing!;
      _date = t.date;
      _sourceWarehouseId = t.sourceWarehouseId;
      _destWarehouseId = t.destinationWarehouseId;
      _notes = t.notes ?? '';
      _reason = t.reason ?? '';
      _items = List.from(t.items);
    }
  }

  Future<void> _loadWarehouses() async {
    final warehouses = await DatabaseHelper.instance.getWarehouses();
    setState(() {
      _warehouses = warehouses;
      if (!_isEditing && warehouses.isNotEmpty) {
        _sourceWarehouseId = warehouses.first.id;
        if (warehouses.length > 1) {
          _destWarehouseId = warehouses[1].id;
        } else {
          _destWarehouseId = warehouses.first.id;
        }
      }
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un article'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_sourceWarehouseId == null || _destWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner les entrepôts'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_sourceWarehouseId == _destWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'entrepôt source et destination doivent être différents'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<StockTransfersBloc>();
      
      String number = widget.existing?.number ?? '';

      final transferId = widget.existing?.id ?? _uuid.v4();
      final transfer = StockTransfer(
        id: transferId,
        number: number,
        date: _date,
        sourceWarehouseId: _sourceWarehouseId!,
        destinationWarehouseId: _destWarehouseId!,
        status: 'validated', // Default status for transfer
        notes: _notes.isNotEmpty ? _notes : null,
        reason: _reason.isNotEmpty ? _reason : null,
        items: _items.map((item) => StockTransferItem(
          id: item.id.isNotEmpty ? item.id : _uuid.v4(),
          transferId: transferId,
          productId: item.productId,
          productName: item.productName,
          productSku: item.productSku,
          quantityToTransfer: item.quantityToTransfer,
        )).toList(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        bloc.add(UpdateStockTransfer(transfer));
      } else {
        bloc.add(AddStockTransfer(transfer));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Bon mis à jour' : 'Bon créé avec succès'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddArticleDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddTransferArticleSheet(
          onAdd: (item) {
            setState(() {
              _items.add(item);
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: _isEditing ? 'Modifier le transfert' : 'Nouveau transfert',
      statusLabel: 'Validé',
      statusColor: AppColors.success,
      isLoading: _isLoading,
      saveLabel: 'Valider',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      children: [
        MobileFormSection(
          title: 'Informations',
          icon: Icons.info_outline_rounded,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmartDatePicker(
                  label: 'Date',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v),
                ),
                const SizedBox(height: 16),
                SmartDropdown<String>(
                  label: 'Entrepôt Source',
                  value: _sourceWarehouseId,
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (v) => setState(() => _sourceWarehouseId = v),
                  hint: 'Sélectionner l\'entrepôt source...',
                ),
                const SizedBox(height: 16),
                SmartDropdown<String>(
                  label: 'Entrepôt Destination',
                  value: _destWarehouseId,
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (v) => setState(() => _destWarehouseId = v),
                  hint: 'Sélectionner l\'entrepôt destination...',
                ),
                const SizedBox(height: 16),
                SmartTextInput(
                  label: 'Raison',
                  initialValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                ),
                const SizedBox(height: 16),
                SmartTextInput(
                  label: 'Notes',
                  initialValue: _notes,
                  maxLines: 2,
                  onChanged: (v) => setState(() => _notes = v),
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
                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: const Text('Aucun article ajouté', style: TextStyle(color: AppColors.textTertiary)),
                  )
                else
                  ..._items.asMap().entries.map((e) {
                    final index = e.key;
                    final item = e.value;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName ?? 'Article', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (item.productSku != null && item.productSku!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(item.productSku!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text('Qté à transférer: ${item.quantityToTransfer}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () => setState(() => _items.removeAt(index)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showAddArticleDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter un article'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTransferArticleSheet extends StatefulWidget {
  final Function(StockTransferItem) onAdd;

  const _AddTransferArticleSheet({required this.onAdd});

  @override
  State<_AddTransferArticleSheet> createState() => _AddTransferArticleSheetState();
}

class _AddTransferArticleSheetState extends State<_AddTransferArticleSheet> {
  Product? _selectedProduct;
  double _quantity = 1.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ajouter un article', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              List<Product> products = [];
              if (state is ProductsLoaded) {
                products = state.products;
              }
              return Autocomplete<Product>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                  final search = textEditingValue.text.toLowerCase();
                  return products.where((p) => 
                    p.name.toLowerCase().contains(search) || 
                    p.code.toLowerCase().contains(search) ||
                    (p.reference?.toLowerCase().contains(search) ?? false)
                  );
                },
                displayStringForOption: (Product option) => option.name,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Rechercher un produit',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  );
                },
                onSelected: (p) => setState(() => _selectedProduct = p),
              );
            },
          ),
          const SizedBox(height: 16),
          SmartTextInput(
            label: 'Quantité à transférer',
            initialValue: '1',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => setState(() => _quantity = double.tryParse(v) ?? 1.0),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_selectedProduct == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un produit')));
                return;
              }
              if (_quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantité invalide')));
                return;
              }
              
              widget.onAdd(StockTransferItem(
                id: const Uuid().v4(),
                transferId: '',
                productId: _selectedProduct!.id,
                productName: _selectedProduct!.name,
                productSku: _selectedProduct!.reference,
                quantityToTransfer: _quantity,
              ));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
