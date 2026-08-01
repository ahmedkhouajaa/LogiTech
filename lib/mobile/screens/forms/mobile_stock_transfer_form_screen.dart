import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../blocs/stock/stock_bloc.dart';
import '../../../../blocs/stock_transfers/stock_transfers_bloc.dart';
import '../../../../blocs/products/products_bloc.dart';
import '../../../../models/stock_transfer.dart';
import '../../../../models/product.dart';
import '../../../../models/stock_movement.dart';
import '../../../../database/database_helper.dart';
import '../../../../utils/constants.dart';

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
    if (context.read<StockBloc>().state is! StockLoaded) {
      context.read<StockBloc>().add(LoadStock());
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
        SnackBar(content: Text('Veuillez ajouter au moins un article'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_sourceWarehouseId == null || _destWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner les entrepôts'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_sourceWarehouseId == _destWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('L\'entrepôt source et destination doivent être différents'), backgroundColor: AppColors.error),
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
          sourceWarehouseId: _sourceWarehouseId,
          destWarehouseId: _destWarehouseId,
          warehouses: _warehouses,
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
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmartDatePicker(
                  label: 'Date',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v),
                ),
                SizedBox(height: 16),
                SmartDropdown<String>(
                  label: 'Entrepôt Source',
                  value: _sourceWarehouseId,
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (v) => setState(() => _sourceWarehouseId = v),
                  hint: 'Sélectionner l\'entrepôt source...',
                ),
                SizedBox(height: 16),
                SmartDropdown<String>(
                  label: 'Entrepôt Destination',
                  value: _destWarehouseId,
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (v) => setState(() => _destWarehouseId = v),
                  hint: 'Sélectionner l\'entrepôt destination...',
                ),
                SizedBox(height: 16),
                SmartTextInput(
                  label: 'Raison',
                  initialValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                ),
                SizedBox(height: 16),
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
            padding: EdgeInsets.all(16),
            child: BlocBuilder<StockBloc, StockState>(
              builder: (context, stockState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_items.isEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Text('Aucun article ajouté', style: TextStyle(color: AppColors.textTertiary)),
                      )
                    else
                      ..._items.asMap().entries.map((e) {
                        final index = e.key;
                        final item = e.value;

                        double sourceStock = 0.0;
                        double destStock = 0.0;
                        if (stockState is StockLoaded) {
                          bool sourceIsDefault = false;
                          bool destIsDefault = false;
                          try {
                            sourceIsDefault = _warehouses.firstWhere((w) => w.id == _sourceWarehouseId).isDefault;
                          } catch (_) {}
                          try {
                            destIsDefault = _warehouses.firstWhere((w) => w.id == _destWarehouseId).isDefault;
                          } catch (_) {}

                          for (var m in stockState.movements) {
                            if (m.productId == item.productId) {
                              final isSourceMatch = m.warehouseId == _sourceWarehouseId || (m.warehouseId == 'default_warehouse' && sourceIsDefault);
                              final isDestMatch = m.warehouseId == _destWarehouseId || (m.warehouseId == 'default_warehouse' && destIsDefault);

                              if (isSourceMatch) {
                                if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
                                  sourceStock += m.quantity;
                                } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
                                  sourceStock -= m.quantity;
                                }
                              }
                              if (isDestMatch) {
                                if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
                                  destStock += m.quantity;
                                } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
                                  destStock -= m.quantity;
                                }
                              }
                            }
                          }
                        }

                        final finalSourceStock = sourceStock - item.quantityToTransfer;
                        final finalDestStock = destStock + item.quantityToTransfer;

                        return Card(
                          elevation: 0,
                          margin: EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                          color: AppColors.surface,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                                      child: Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 18),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.productName ?? 'Article', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          if (item.productSku != null && item.productSku!.isNotEmpty)
                                            Text(item.productSku!, style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                      onPressed: () => setState(() => _items.removeAt(index)),
                                    ),
                                  ],
                                ),
                                Divider(height: 16, color: AppColors.border),

                                // Source Stock metrics
                                Text('Stock Source', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Qté stock src', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                                            SizedBox(height: 2),
                                            Text('${sourceStock.toInt() == sourceStock ? sourceStock.toInt() : sourceStock.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Qté à transfér.', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                                            SizedBox(height: 2),
                                            Text('${item.quantityToTransfer.toInt() == item.quantityToTransfer ? item.quantityToTransfer.toInt() : item.quantityToTransfer.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Qté fin. src', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                                            SizedBox(height: 2),
                                            Text('${finalSourceStock.toInt() == finalSourceStock ? finalSourceStock.toInt() : finalSourceStock.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: finalSourceStock < 0 ? AppColors.error : AppColors.success)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),

                                // Destination Stock metrics
                                Text('Stock Destination', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Qté stock dest.', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                                            SizedBox(height: 2),
                                            Text('${destStock.toInt() == destStock ? destStock.toInt() : destStock.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Qté fin. dest.', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                                            SizedBox(height: 2),
                                            Text('${finalDestStock.toInt() == finalDestStock ? finalDestStock.toInt() : finalDestStock.toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showAddArticleDialog,
                      icon: Icon(Icons.add_rounded),
                      label: Text('Ajouter un article'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTransferArticleSheet extends StatefulWidget {
  final String? sourceWarehouseId;
  final String? destWarehouseId;
  final List<Warehouse> warehouses;
  final Function(StockTransferItem) onAdd;

  const _AddTransferArticleSheet({
    required this.sourceWarehouseId,
    required this.destWarehouseId,
    required this.warehouses,
    required this.onAdd,
  });

  @override
  State<_AddTransferArticleSheet> createState() => _AddTransferArticleSheetState();
}

class _AddTransferArticleSheetState extends State<_AddTransferArticleSheet> {
  Product? _selectedProduct;
  double _quantity = 1.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              Text('Ajouter un article', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16),
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
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                },
                onSelected: (p) => setState(() => _selectedProduct = p),
              );
            },
          ),
          SizedBox(height: 16),

          if (_selectedProduct != null)
            BlocBuilder<StockBloc, StockState>(
              builder: (context, stockState) {
                double sourceStock = 0.0;
                double destStock = 0.0;

                if (stockState is StockLoaded) {
                  bool sourceIsDefault = false;
                  bool destIsDefault = false;
                  try {
                    sourceIsDefault = widget.warehouses.firstWhere((w) => w.id == widget.sourceWarehouseId).isDefault;
                  } catch (_) {}
                  try {
                    destIsDefault = widget.warehouses.firstWhere((w) => w.id == widget.destWarehouseId).isDefault;
                  } catch (_) {}

                  for (var m in stockState.movements) {
                    if (m.productId == _selectedProduct!.id) {
                      final isSourceMatch = m.warehouseId == widget.sourceWarehouseId || (m.warehouseId == 'default_warehouse' && sourceIsDefault);
                      final isDestMatch = m.warehouseId == widget.destWarehouseId || (m.warehouseId == 'default_warehouse' && destIsDefault);

                      if (isSourceMatch) {
                        if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
                          sourceStock += m.quantity;
                        } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
                          sourceStock -= m.quantity;
                        }
                      }
                      if (isDestMatch) {
                        if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
                          destStock += m.quantity;
                        } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
                          destStock -= m.quantity;
                        }
                      }
                    }
                  }
                }

                final finalSourceStock = sourceStock - _quantity;
                final finalDestStock = destStock + _quantity;

                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Qté stock source:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text('${sourceStock.toInt() == sourceStock ? sourceStock.toInt() : sourceStock.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Qté finale source:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text('${finalSourceStock.toInt() == finalSourceStock ? finalSourceStock.toInt() : finalSourceStock.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: finalSourceStock < 0 ? AppColors.error : AppColors.success)),
                        ],
                      ),
                      Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Qté stock dest.:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text('${destStock.toInt() == destStock ? destStock.toInt() : destStock.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Qté finale dest.:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text('${finalDestStock.toInt() == finalDestStock ? finalDestStock.toInt() : finalDestStock.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          SmartTextInput(
            label: 'Quantité à transférer',
            initialValue: '1',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => setState(() => _quantity = double.tryParse(v) ?? 1.0),
          ),
          SizedBox(height: 24),
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
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
