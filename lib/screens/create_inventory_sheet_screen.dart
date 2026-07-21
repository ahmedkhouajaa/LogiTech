import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/stock/stock_bloc.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_event.dart';
import '../../blocs/warehouses/warehouses_state.dart';
import '../../models/inventory_sheet.dart';
import '../../models/inventory_sheet_item.dart';
import '../../models/stock_movement.dart'; // Contains Warehouse
import '../../models/product.dart';
import '../../utils/constants.dart';

class CreateInventorySheetScreen extends StatefulWidget {
  final InventorySheet? sheet;
  final bool isViewOnly;

  const CreateInventorySheetScreen({
    super.key,
    this.sheet,
    this.isViewOnly = false,
  });

  @override
  State<CreateInventorySheetScreen> createState() => _CreateInventorySheetScreenState();
}

class _CreateInventorySheetScreenState extends State<CreateInventorySheetScreen> {
  final _uuid = const Uuid();
  late String _id;
  late String _number;
  late DateTime _date;
  late DateTime _inventoryDate;
  String? _warehouseId;
  final _countedByController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'draft';

  List<InventorySheetItem> _items = [];
  List<Warehouse> _warehouses = [];

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<StockBloc>().add(LoadStock());
    context.read<WarehousesBloc>().add(LoadWarehouses());

    final warehousesState = context.read<WarehousesBloc>().state;
    if (warehousesState is WarehousesLoaded) {
      _warehouses = warehousesState.warehouses;
      if (_warehouseId == null && _warehouses.isNotEmpty) {
        _warehouseId = _warehouses.firstWhere((w) => w.isDefault, orElse: () => _warehouses.first).id;
      }
    }
    
    if (widget.sheet != null) {
      _id = widget.sheet!.id;
      _number = widget.sheet!.number;
      _date = widget.sheet!.date;
      _inventoryDate = widget.sheet!.inventoryDate;
      _warehouseId = widget.sheet!.warehouseId;
      _countedByController.text = widget.sheet!.countedBy ?? '';
      _reasonController.text = widget.sheet!.reason ?? '';
      _notesController.text = widget.sheet!.notes ?? '';
      _status = widget.sheet!.status;
      _items = List.from(widget.sheet!.items);
    } else {
      _id = _uuid.v4();
      _number = 'FI-${DateTime.now().year}-${_uuid.v4().substring(0, 6).toUpperCase()}';
      _date = DateTime.now();
      _inventoryDate = DateTime.now();
      _items = [
        InventorySheetItem(
          id: _uuid.v4(),
          inventoryId: _id,
          productId: '',
          productName: null,
          productSku: null,
          theoreticalQty: 0,
          actualQty: 0,
        )
      ];
    }
  }

  @override
  void dispose() {
    _countedByController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save(bool isDraft) {
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un entrepôt')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter au moins un article')));
      return;
    }
    for (var item in _items) {
      if (item.productId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un produit pour chaque ligne')));
        return;
      }
    }

    final uniqueProductIds = _items.map((i) => i.productId).toSet();
    if (uniqueProductIds.length != _items.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Un article ne peut pas être sélectionné plusieurs fois.')));
      return;
    }

    final newSheet = InventorySheet(
      id: _id,
      number: _number,
      date: _date,
      inventoryDate: _inventoryDate,
      warehouseId: _warehouseId!,
      countedBy: _countedByController.text,
      reason: _reasonController.text,
      notes: _notesController.text,
      status: isDraft ? 'Brouillon' : 'Finalisée',
      items: _items,
      createdAt: widget.sheet?.createdAt,
    );

    if (widget.sheet == null) {
      context.read<InventorySheetsBloc>().add(InventorySheetAdded(newSheet));
    } else {
      context.read<InventorySheetsBloc>().add(InventorySheetUpdated(newSheet));
    }

    if (!isDraft) {
      // Reload stock to reflect adjustments
      context.read<StockBloc>().add(LoadStock());
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isViewOnly ? 'Fiche d\'inventaire' : (widget.sheet == null ? 'Créer une fiche d\'inventaire' : 'Modifier la fiche d\'inventaire')),
        actions: [
          if (!widget.isViewOnly)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _save(true),
                    child: const Text('Brouillon'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _save(false),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: BlocListener<WarehousesBloc, WarehousesState>(
        listener: (context, state) {
          if (state is WarehousesLoaded) {
            setState(() {
              _warehouses = state.warehouses;
              if (_warehouseId == null && _warehouses.isNotEmpty) {
                _warehouseId = _warehouses.firstWhere((w) => w.isDefault, orElse: () => _warehouses.first).id;
              }
            });
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 24),
              _buildItemsSection(),
            ],
          ),
        ),
      ),
    );
  }

  String formatAmount(double amount, {String symbol = ''}) {
    if (amount == amount.toInt()) {
      return '${amount.toInt()} $symbol'.trim();
    }
    return '${amount.toStringAsFixed(2)} $symbol'.trim();
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: DateFormat('dd MMMM yyyy', 'fr_FR').format(_date),
                        readOnly: true,
                        enabled: !widget.isViewOnly,
                        decoration: InputDecoration(
                          suffixIcon: const Icon(Icons.calendar_today, size: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Entrepôt', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                        value: _warehouseId,
                        items: _warehouses.map((Warehouse w) => DropdownMenuItem<String>(value: w.id, child: Text(w.name))).toList(),
                        onChanged: widget.isViewOnly ? null : (v) {
                          setState(() => _warehouseId = v);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date d\'inventaire', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: widget.isViewOnly ? null : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _inventoryDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _inventoryDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            suffixIcon: const Icon(Icons.calendar_today, size: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(_inventoryDate)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de saisie', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: DateFormat('dd MMMM yyyy', 'fr_FR').format(widget.sheet?.createdAt ?? DateTime.now()),
                        readOnly: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compté par', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _countedByController,
                        readOnly: widget.isViewOnly,
                        decoration: InputDecoration(
                          hintText: 'Nom du responsable',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Raison (optionnel)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _reasonController,
                        readOnly: widget.isViewOnly,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Raison de l\'opération...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Notes (optionnel)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _notesController,
                        readOnly: widget.isViewOnly,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Notes additionnelles...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Articles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Header
            Row(
              children: [
                const Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                const Expanded(flex: 1, child: Text('Théorique', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                const SizedBox(width: 8),
                const Expanded(flex: 1, child: Text('Réel', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                const SizedBox(width: 8),
                const Expanded(flex: 1, child: Text('Surplus', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                const SizedBox(width: 8),
                const Expanded(flex: 1, child: Text('Manquant', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                if (!widget.isViewOnly) const SizedBox(width: 40),
              ],
            ),
            const Divider(),
            
            // Items
            BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, productsState) {
                List<Product> products = [];
                if (productsState is ProductsLoaded) {
                  products = productsState.products;
                }
                
                return BlocBuilder<StockBloc, StockState>(
                  builder: (context, stockState) {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        
                        // Calculate theoretical stock
                        double theoreticalStock = item.theoreticalQty;
                        if (!widget.isViewOnly && item.productId.isNotEmpty && stockState is StockLoaded) {
                          theoreticalStock = 0.0;
                          bool isDefault = false;
                          try {
                            isDefault = _warehouses.firstWhere((Warehouse w) => w.id == _warehouseId).isDefault;
                          } catch (_) {}
                          for (var m in stockState.movements) {
                            if (m.productId == item.productId) {
                              if (m.warehouseId == _warehouseId || (m.warehouseId == 'default_warehouse' && isDefault)) {
                                if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) theoreticalStock += m.quantity;
                                else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) theoreticalStock -= m.quantity;
                              }
                            }
                          }
                          // Only update if changed to avoid unnecessary rebuilds
                          if (item.theoreticalQty != theoreticalStock) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _items[index] = item.copyWith(theoreticalQty: theoreticalStock);
                              });
                            });
                          }
                        }

                        final diff = item.actualQty - theoreticalStock;
                        final surplus = diff > 0 ? diff : 0.0;
                        final missing = diff < 0 ? diff.abs() : 0.0;
                        bool isDuplicate = false;
                        if (!widget.isViewOnly && item.productId.isNotEmpty) {
                          isDuplicate = _items.where((i) => i.productId == item.productId).length > 1;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(color: widget.isViewOnly ? AppColors.surfaceAlt : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: widget.isViewOnly 
                                  ? Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text(item.productName ?? ''),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 44,
                                          child: Autocomplete<Product>(
                                    key: ValueKey('autocomplete_${item.id}'),
                                    initialValue: TextEditingValue(text: item.productName ?? ''),
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                                      final search = textEditingValue.text.toLowerCase();
                                      return products.where((Product p) => 
                                        p.name.toLowerCase().contains(search) || 
                                        p.code.toLowerCase().contains(search) ||
                                        (p.reference?.toLowerCase().contains(search) ?? false)
                                      ).toList();
                                    },
                                    displayStringForOption: (Product option) => option.name,
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          hintText: 'Sélectionner un article',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onChanged: (v) {
                                          if (item.productName != v) {
                                            _items[index] = item.copyWith(productName: v, productId: '');
                                          }
                                        },
                                      );
                                    },
                                    optionsViewBuilder: (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(4),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder: (context, i) {
                                                final option = options.elementAt(i);
                                                return ListTile(
                                                  leading: const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
                                                  title: Text(option.name, style: const TextStyle(fontSize: 13)),
                                                  onTap: () => onSelected(option),
                                                  dense: true,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    onSelected: (p) {
                                      setState(() {
                                        _items[index] = item.copyWith(
                                          productId: p.id,
                                          productName: p.name,
                                          productSku: p.reference,
                                          actualQty: 0,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                if (isDuplicate)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4, left: 12),
                                    child: Text('Article déjà sélectionné', style: TextStyle(color: AppColors.error, fontSize: 11)),
                                  ),
                              ],
                            ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: Text(formatAmount(theoreticalStock, symbol: ''), textAlign: TextAlign.right),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  initialValue: item.actualQty > 0 ? formatAmount(item.actualQty, symbol: '') : '',
                                  readOnly: widget.isViewOnly,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  ),
                                  onChanged: (val) {
                                    final qty = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                                    setState(() {
                                      _items[index] = item.copyWith(actualQty: qty);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: surplus > 0 ? AppColors.successLight : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: Text(surplus > 0 ? formatAmount(surplus, symbol: '') : '—', textAlign: TextAlign.right, style: TextStyle(color: surplus > 0 ? AppColors.success : AppColors.textTertiary, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: missing > 0 ? AppColors.errorLight : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: Text(missing > 0 ? formatAmount(missing, symbol: '') : '—', textAlign: TextAlign.right, style: TextStyle(color: missing > 0 ? AppColors.error : AppColors.textTertiary, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              if (!widget.isViewOnly) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                  onPressed: () => setState(() => _items.removeAt(index)),
                                ),
                              ]
                            ],
                          ),
                        );
                      },
                    );
                  }
                );
              }
            ),
            
            if (!widget.isViewOnly) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _items.add(InventorySheetItem(id: _uuid.v4(), inventoryId: _id, productId: '', theoreticalQty: 0, actualQty: 0));
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter une ligne'),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
