import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../blocs/stock_entries/stock_entries_bloc.dart';
import '../blocs/stock_entries/stock_entries_event.dart';
import '../blocs/stock_entries/stock_entries_state.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/stock/stock_bloc.dart';
import '../models/stock_entry.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';

import '../models/stock_movement.dart' show Warehouse;
import 'create_article_screen.dart';
import '../mobile/screens/forms/mobile_product_form_screen.dart';
import '../widgets/article_selection_modal.dart';
import '../widgets/searchable_dropdown_field.dart';
import '../mobile/widgets/forms/mobile_smart_fields.dart';
class CreateStockEntryScreen extends StatefulWidget {
  final StockEntry? existing;
  const CreateStockEntryScreen({super.key, this.existing});

  @override
  State<CreateStockEntryScreen> createState() => _CreateStockEntryScreenState();
}

class _CreateStockEntryScreenState extends State<CreateStockEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  DateTime _date = DateTime.now();
  String? _warehouseId;
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  List<Warehouse> _warehouses = [];

  List<StockEntryItem> _items = [];
  final Map<String, double> _stockQuantities = {}; // to hold current stock of selected products
  
  final Map<String, TextEditingController> _qtyControllers = {};

  TextEditingController _getQtyController(StockEntryItem item) {
    if (!_qtyControllers.containsKey(item.id)) {
      _qtyControllers[item.id] = TextEditingController(text: item.quantity > 0 ? item.quantity.toStringAsFixed(0) : '');
    }
    return _qtyControllers[item.id]!;
  }
  

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
    // Note: Assuming there is a WarehousesBloc or similar if needed. If not, just ProductsBloc.
    if (widget.existing != null) {
      _date = widget.existing!.date;
      _warehouseId = widget.existing!.warehouseId;
      _reasonController.text = widget.existing!.reason ?? '';
      _notesController.text = widget.existing!.notes ?? '';
      _items = List.from(widget.existing!.items);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un entrepôt')));
      return;
    }
    final validItems = _items.where((i) => i.productId.isNotEmpty).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un article')),
      );
      return;
    }

    final seenProducts = <String>{};
    for (var item in validItems) {
      if (seenProducts.contains(item.productId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Ce produit est déjà ajouté dans une autre ligne')),
        );
        return;
      }
      seenProducts.add(item.productId);
    }

    String number = widget.existing?.number ?? '';
    if (number.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextStockEntrySequence();
      number = generateDocNumber(DocPrefix.stockEntry, seq);
    }

    final entry = StockEntry(
      id: widget.existing?.id,
      number: number,
      warehouseId: _warehouseId!,
      date: _date,
      reason: _reasonController.text,
      notes: _notesController.text,
      status: 'validated',
      items: validItems,
    );

    final entryBloc = context.read<StockEntriesBloc>();
    final productsBloc = context.read<ProductsBloc>();

    late StreamSubscription subscription;
    subscription = entryBloc.stream.listen((state) {
      if (state is StockEntriesLoaded || state is StockEntriesError) {
        productsBloc.add(LoadProducts());
        subscription.cancel();
      }
    });

    if (widget.existing == null) {
      entryBloc.add(AddStockEntry(entry));
    } else {
      entryBloc.add(UpdateStockEntry(entry));
    }
    
    if (mounted) {
      context.read<StockBloc>().add(LoadStock());
      context.read<ProductsBloc>().add(LoadProducts());
      Navigator.pop(context);
    }
  }

  void _addEmptyItem() {
    setState(() {
      _items.add(StockEntryItem(
        id: _uuid.v4(),
        entryId: widget.existing?.id ?? '',
        productId: '',
        quantity: 0,
        unitPrice: 0,
      ));
    });
  }

  void _updateItemProduct(int index, Product product) {
    setState(() {
      _items[index] = _items[index].copyWith(
        productId: product.id,
        unitPrice: product.purchasePrice,
      );
      _stockQuantities[product.id] = product.stockQty;
    });
  }

  void _updateItemQuantity(int index, double quantity) {
    setState(() {
      _items[index] = _items[index].copyWith(quantity: quantity);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(_isMobile ? AppSpacing.md : AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(),
                      SizedBox(height: 24),
                      _buildArticlesSection(),
                    ],
                  ),
                ),
              ),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _isMobile ? AppSpacing.md : AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, size: 22, color: AppColors.textPrimary),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.existing == null ? "Créer un bon d'entrée" : "Modifier le bon d'entrée",
              style: TextStyle(
                fontSize: _isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Validé',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text('Annuler', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                elevation: 0,
              ),
              child: Text('Valider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadWarehouses() async {
    final state = context.read<StockBloc>().state;
    if (state is StockLoaded) {
      setState(() {
        _warehouses = state.warehouses;
        if (widget.existing == null && _warehouses.isNotEmpty) {
          _warehouseId = _warehouses.first.id;
        }
      });
    }
  }

  Widget _buildInfoSection() {
    final dateField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('d MMMM yyyy', 'fr').format(_date), style: TextStyle(fontSize: 13)),
                Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );

    final defaultWh = _warehouses.cast<Warehouse?>().firstWhere(
      (w) => w?.isDefault == true,
      orElse: () => _warehouses.cast<Warehouse?>().firstWhere((w) => w?.name.toLowerCase().contains('défaut') == true || w?.name.toLowerCase().contains('defaut') == true, orElse: () => _warehouses.isNotEmpty ? _warehouses.first : null),
    );
    final selectedWarehouse = _warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _warehouseId, orElse: () => defaultWh);
    final warehouseName = selectedWarehouse?.name;

    final warehouseField = SmartSearchableSelector(
      label: 'Entrepôt',
      hint: 'Sélectionner un entrepôt',
      selectedText: warehouseName,
      onTap: () async {
        final res = await showWarehouseSelectDialog(context, _warehouses, selectedWarehouseId: _warehouseId ?? defaultWh?.id);
        if (res != null && mounted) {
          setState(() => _warehouseId = res);
        }
      },
    );

    final reasonField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Raison (optionnel)', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: "Raison de l'opération...",
            hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );

    final notesField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes (optionnel)', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Notes additionnelles...',
            hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            SizedBox(height: 16),
            if (_isMobile) ...[
              dateField,
              SizedBox(height: 16),
              warehouseField,
              SizedBox(height: 16),
              reasonField,
              SizedBox(height: 16),
              notesField,
            ] else ...[
              Row(
                children: [
                  Expanded(child: dateField),
                  SizedBox(width: 24),
                  Expanded(child: warehouseField),
                ],
              ),
              SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: reasonField),
                  SizedBox(width: 24),
                  Expanded(child: notesField),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArticlesSection() {
    if (_items.isEmpty) {
      // Initialize with one empty line if list is empty
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addEmptyItem();
      });
    }

    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        List<Product> products = [];
        if (state is ProductsLoaded) {
          products = state.products;
        }

        return BlocBuilder<StockBloc, StockState>(
          builder: (context, stockState) {
            return Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Articles', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    SizedBox(height: 24),

                    // Items List
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildItemRow(index, item, products, stockState);
                    }),

                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            if (_isMobile) {
                              final selectedProduct = await ArticleSelectionModal.show(context, warehouseId: _warehouseId);
                              if (selectedProduct != null) {
                                setState(() {
                                  _items.add(StockEntryItem(
                                    id: _uuid.v4(),
                                    entryId: widget.existing?.id ?? '',
                                    productId: selectedProduct.id,
                                    quantity: 0,
                                    unitPrice: selectedProduct.purchasePrice,
                                  ));
                                  _stockQuantities[selectedProduct.id] = selectedProduct.stockQty;
                                });
                              }
                            } else {
                              _addEmptyItem();
                            }
                          },
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
                            if (_isMobile) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileProductFormScreen()));
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateArticleScreen()));
                            }
                          },
                          splashRadius: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _getRealCurrentStock(StockEntryItem currentItem, StockState stockState) {
    if (currentItem.productId.isEmpty) return 0;
    
    double stock = 0.0;
    bool isWarehouseDefault = false;
    try {
      isWarehouseDefault = _warehouses.firstWhere((w) => w.id == _warehouseId).isDefault;
    } catch (_) {}

    bool foundMovements = false;
    if (stockState is StockLoaded) {
      for (var m in stockState.movements) {
        if (m.productId == currentItem.productId) {
          final isWarehouseMatch = _warehouseId == null || _warehouseId!.isEmpty || m.warehouseId == _warehouseId || (m.warehouseId == 'default_warehouse' && isWarehouseDefault);
          if (isWarehouseMatch) {
            foundMovements = true;
            if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
              stock += m.quantity;
            } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
              stock -= m.quantity;
            }
          }
        }
      }
    }

    if (!foundMovements || stock == 0.0) {
      try {
        final pState = context.read<ProductsBloc>().state;
        if (pState is ProductsLoaded) {
          final prod = pState.products.cast<Product?>().firstWhere((p) => p?.id == currentItem.productId, orElse: () => null);
          if (prod != null && prod.stockQty > 0) {
            stock = prod.stockQty;
          }
        }
      } catch (_) {}
    }
    
    // If editing an existing entry, the DB stock already has the old quantity added.
    // We must subtract it to show the true "stock before entry" preview in the UI.
    if (widget.existing != null) {
      try {
        final originalItem = widget.existing!.items.firstWhere((i) => i.id == currentItem.id);
        if (originalItem.productId == currentItem.productId) {
          stock -= originalItem.quantity;
        }
      } catch (e) {
        // Not found (e.g. newly added row)
      }
    }
    return stock;
  }

  Widget _buildItemRow(int index, StockEntryItem item, List<Product> products, StockState stockState) {
    double currentStock = _getRealCurrentStock(item, stockState);
    double finalStock = currentStock + item.quantity;

    if (_isMobile) {
      return _buildMobileItemCard(index, item, products, currentStock, finalStock);
    }
    return _buildDesktopItemRow(index, item, products, currentStock, finalStock, stockState);
  }

  
  // ─── Mobile: Card-based item layout ────────────────────────────────
  Widget _buildMobileItemCard(int index, StockEntryItem item, List<Product> products, double currentStock, double finalStock) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product selector + delete
          Row(
            children: [
              Text('Produit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => _removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () async {
                        final selectedProduct = await ArticleSelectionModal.show(context, warehouseId: _warehouseId);
                        if (selectedProduct != null) {
                          _updateItemProduct(index, selectedProduct);
                        }
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.productId.isNotEmpty
                                    ? products.firstWhere((p) => p.id == item.productId, orElse: () => Product(id: '', code: '', name: '', sellingPrice: 0, purchasePrice: 0, tvaRate: 0, unit: '', productType: '')).name
                                    : 'Sélectionner un article',
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
                if (_items.where((i) => i.productId == item.productId && i.productId.isNotEmpty).length > 1)
                  Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text('Ce produit est déjà ajouté dans une autre ligne', style: TextStyle(color: AppColors.error, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      // Quantities row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('En stock', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    SizedBox(height: 4),
                    Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(currentStock.toStringAsFixed(0), style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qté à entrer', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    SizedBox(height: 4),
                    SizedBox(
                      height: 40,
                      child: TextFormField(
                        controller: _getQtyController(item),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.blue, width: 2)),
                        ),
                        onChanged: (val) {
                          final q = double.tryParse(val) ?? 0;
                          _updateItemQuantity(index, q);
                        },
                      ),
                    ),
                    if (_items.where((i) => i.productId == item.productId && i.productId.isNotEmpty).length > 1)
                      Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text('Ce produit est déjà ajouté dans une autre ligne', style: TextStyle(color: AppColors.error, fontSize: 11)),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qté finale', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    SizedBox(height: 4),
                    Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(finalStock.toStringAsFixed(0), style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Desktop: Original row-based layout ────────────────────────────
  Widget _buildDesktopItemRow(int index, StockEntryItem item, List<Product> products, double currentStock, double finalStock, StockState stockState) {
    return Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row for this item
              Padding(
                padding: EdgeInsets.only(bottom: 8.0, right: 40.0), // 40 for delete button
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                    SizedBox(width: 16),
                    Expanded(flex: 1, child: Text('Qte en stock', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                    SizedBox(width: 16),
                    Expanded(flex: 1, child: Text('Qte a entrer', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                    SizedBox(width: 16),
                    Expanded(flex: 1, child: Text('Qte finale', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              
              // Inputs Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Produit dropdown
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final selectedProd = products.cast<Product?>().firstWhere(
                              (p) => p?.id == item.productId,
                              orElse: () => null,
                            );
                            return SearchableSelectorField(
                              hint: 'Sélectionner un article',
                              selectedText: selectedProd?.name,
                              onTap: () async {
                                final stockMap = <String, double>{};
                                for (var p in products) {
                                  stockMap[p.id] = _getRealCurrentStock(StockEntryItem(id: '', entryId: '', productId: p.id, quantity: 0, unitPrice: 0), stockState);
                                }
                                final res = await showProductSelectDialog(
                                  context,
                                  products,
                                  selectedProductId: item.productId,
                                  warehouseId: _warehouseId,
                                  warehouseStockMap: stockMap,
                                );
                                if (res != null) {
                                  final selectedProduct = products.firstWhere((p) => p.id == res);
                                  _updateItemProduct(index, selectedProduct);
                                }
                              },
                            );
                          },
                        ),
                        if (_items.where((i) => i.productId == item.productId && i.productId.isNotEmpty).length > 1)
                          Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text('Ce produit est déjà ajouté dans une autre ligne', style: TextStyle(color: AppColors.error, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  
                  // Qté en stock
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 40,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(currentStock.toStringAsFixed(0), style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Qté à entrer
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 40,
                      child: TextFormField(
                        controller: _getQtyController(item),
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.blue, width: 2)),
                        ),
                        onChanged: (val) {
                          final q = double.tryParse(val) ?? 0;
                          _updateItemQuantity(index, q);
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Qté finale
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 40,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(finalStock.toStringAsFixed(0), style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  // Delete action
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () => _removeItem(index),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (index < _items.length - 1)
                Divider(height: 1, color: AppColors.border),
            ],
          ),
        );
  }
}
