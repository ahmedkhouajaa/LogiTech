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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../../../services/enterprise_service.dart';
import '../../../../widgets/searchable_dropdown_field.dart';
import '../../../../blocs/warehouses/warehouses_bloc.dart';
import '../../../../blocs/warehouses/warehouses_state.dart';
import '../../../../blocs/warehouses/warehouses_event.dart';
import '../../../../services/enterprise_service.dart';
import '../../../../widgets/searchable_dropdown_field.dart';

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
  List<StockTransferItem> _items = [StockTransferItem(transferId: '', productId: '', quantityToTransfer: 0)];

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
    if (context.read<WarehousesBloc>().state is! WarehousesLoaded) {
      context.read<WarehousesBloc>().add(LoadWarehouses());
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
    List<Warehouse> warehouses = [];
    try {
      final stockState = context.read<StockBloc>().state;
      if (stockState is StockLoaded && stockState.warehouses.isNotEmpty) {
        warehouses = stockState.warehouses;
      } else {
        final entId = EnterpriseService.instance.currentEnterpriseId;
        Query query = FirebaseFirestore.instance.collection('warehouses');
        if (entId != null && entId.isNotEmpty) {
          query = query.where('enterprise_id', isEqualTo: entId);
        }
        final snap = await query.get();
        warehouses = snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return Warehouse.fromMap(data);
        }).where((w) => !w.isDeleted).toList();
      }
    } catch (_) {
      warehouses = await DatabaseHelper.instance.getWarehouses();
    }

    if (warehouses.isEmpty) {
      warehouses = [
        Warehouse(id: 'default_warehouse', name: 'Entrepôt principal', isDefault: true)
      ];
    }

    if (mounted) {
      setState(() {
        _warehouses = warehouses;
        if (!_isEditing) {
          if (_sourceWarehouseId == null && warehouses.isNotEmpty) {
            _sourceWarehouseId = warehouses.first.id;
          }
          if (_destWarehouseId == null || _destWarehouseId == _sourceWarehouseId) {
            final otherWarehouses = warehouses.where((w) => w.id != _sourceWarehouseId).toList();
            _destWarehouseId = otherWarehouses.isNotEmpty ? otherWarehouses.first.id : null;
          }
        }
      });
    }
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
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextStockTransferSequence();
        number = generateDocNumber(DocPrefix.stockTransfer, seq);
      }

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

  Widget _buildMetricBox(String label, double value, {bool isInput = false, ValueChanged<String>? onChanged, bool isError = false}) {
    if (isInput) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: TextFormField(
              initialValue: value == 0 ? '' : (value.toInt() == value ? value.toInt().toString() : value.toStringAsFixed(2)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        SizedBox(height: 4),
        Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isInput ? AppColors.background : (isError ? AppColors.error.withValues(alpha: 0.05) : AppColors.surfaceAlt),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isInput ? AppColors.border : Colors.transparent),
          ),
          child: Text(
            value.toInt() == value ? value.toInt().toString() : value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.bold, 
              color: isError ? AppColors.error : (isInput ? AppColors.primary : AppColors.success),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WarehousesBloc, WarehousesState>(
      builder: (context, whState) {
        final currentWarehouses = whState is WarehousesLoaded && whState.warehouses.isNotEmpty ? whState.warehouses : _warehouses;

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
                SmartSearchableSelector(
                  label: 'Entrepôt Source',
                  hint: 'Sélectionner l\'entrepôt source...',
                  selectedText: currentWarehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _sourceWarehouseId, orElse: () => null)?.name ?? 'Sélectionner l\'entrepôt source...',
                  onTap: () async {
                    final available = currentWarehouses.where((w) => w.id != _destWarehouseId).toList();
                    if (available.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Aucun autre entrepôt disponible')),
                      );
                      return;
                    }
                    final res = await showWarehouseSelectDialog(context, available, selectedWarehouseId: _sourceWarehouseId);
                    if (res != null && mounted) {
                      setState(() => _sourceWarehouseId = res);
                    }
                  },
                ),
                SizedBox(height: 16),
                SmartSearchableSelector(
                  label: 'Entrepôt Destination',
                  hint: 'Sélectionner l\'entrepôt destination...',
                  selectedText: currentWarehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _destWarehouseId, orElse: () => null)?.name ?? 'Sélectionner l\'entrepôt destination...',
                  onTap: () async {
                    final available = currentWarehouses.where((w) => w.id != _sourceWarehouseId).toList();
                    if (available.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Aucun autre entrepôt disponible pour la destination')),
                      );
                      return;
                    }
                    final res = await showWarehouseSelectDialog(context, available, selectedWarehouseId: _destWarehouseId);
                    if (res != null && mounted) {
                      setState(() => _destWarehouseId = res);
                    }
                  },
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
                        if (stockState is StockLoaded && item.productId.isNotEmpty) {
                          bool sourceIsDefault = false;
                          bool destIsDefault = false;
                          try {
                            sourceIsDefault = currentWarehouses.firstWhere((w) => w.id == _sourceWarehouseId).isDefault;
                          } catch (_) {}
                          try {
                            destIsDefault = currentWarehouses.firstWhere((w) => w.id == _destWarehouseId).isDefault;
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Produit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                      onPressed: () => setState(() => _items.removeAt(index)),
                                      constraints: BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                SearchableSelectorField(
                                  hint: 'Sélectionner un article',
                                  selectedText: item.productId.isNotEmpty ? (item.productName ?? 'Article') : null,
                                  onTap: () async {
                                    final productsState = context.read<ProductsBloc>().state;
                                    List<Product> products = [];
                                    if (productsState is ProductsLoaded) {
                                      products = productsState.products;
                                    }

                                    final stockMap = <String, double>{};
                                    if (stockState is StockLoaded) {
                                      bool sourceIsDefault = false;
                                      try {
                                        sourceIsDefault = currentWarehouses.firstWhere((w) => w.id == _sourceWarehouseId).isDefault;
                                      } catch (_) {}
                                      for (var p in products) {
                                        double pStock = 0.0;
                                        for (var m in stockState.movements) {
                                          if (m.productId == p.id) {
                                            final isSourceMatch = m.warehouseId == _sourceWarehouseId || (m.warehouseId == 'default_warehouse' && sourceIsDefault);
                                            if (isSourceMatch) {
                                              if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
                                                pStock += m.quantity;
                                              } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
                                                pStock -= m.quantity;
                                              }
                                            }
                                          }
                                        }
                                        stockMap[p.id] = pStock;
                                      }
                                    }

                                    final res = await showProductSelectDialog(
                                      context, 
                                      products, 
                                      selectedProductId: item.productId,
                                      warehouseId: _sourceWarehouseId,
                                      warehouseStockMap: stockMap,
                                    );
                                    if (res != null) {
                                      final p = products.firstWhere((element) => element.id == res);
                                      setState(() {
                                        _items[index] = StockTransferItem(
                                          id: item.id,
                                          transferId: item.transferId,
                                          productId: p.id,
                                          productName: p.name,
                                          productSku: p.reference,
                                          quantityToTransfer: item.quantityToTransfer,
                                        );
                                      });
                                    }
                                  },
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricBox('En stock', sourceStock, isInput: false)),
                                    SizedBox(width: 8),
                                    Expanded(child: _buildMetricBox('Qté à transférer', item.quantityToTransfer, isInput: true, onChanged: (v) {
                                      setState(() {
                                        _items[index] = StockTransferItem(
                                          id: item.id,
                                          transferId: item.transferId,
                                          productId: item.productId,
                                          productName: item.productName,
                                          productSku: item.productSku,
                                          quantityToTransfer: double.tryParse(v) ?? 0.0,
                                        );
                                      });
                                    })),
                                    SizedBox(width: 8),
                                    Expanded(child: _buildMetricBox('Qté fin. src', finalSourceStock, isInput: false, isError: finalSourceStock < 0)),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricBox('En stock dest.', destStock, isInput: false)),
                                    SizedBox(width: 8),
                                    Expanded(child: _buildMetricBox('Qté fin. dest.', finalDestStock, isInput: false)),
                                    SizedBox(width: 8),
                                    Expanded(child: SizedBox()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _items.add(StockTransferItem(transferId: '', productId: '', quantityToTransfer: 0));
                            });
                          },
                          icon: Icon(Icons.add, size: 18),
                          label: Text('Ajouter une ligne'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
                          onPressed: () {
                             setState(() {
                               _items.add(StockTransferItem(transferId: '', productId: '', quantityToTransfer: 0));
                             });
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
      },
    );
  }
}


