import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../blocs/stock_withdrawals/stock_withdrawals_bloc.dart';
import '../blocs/exit_vouchers/exit_vouchers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/stock/stock_bloc.dart';
import '../models/stock_withdrawal.dart';
import '../models/product.dart';
import '../utils/constants.dart';

import 'create_article_screen.dart';
import '../models/stock_movement.dart' show Warehouse;

class CreateStockWithdrawalScreen extends StatefulWidget {
  final StockWithdrawal? existing;
  final bool isExitVoucher;
  const CreateStockWithdrawalScreen({super.key, this.existing, this.isExitVoucher = false});

  @override
  State<CreateStockWithdrawalScreen> createState() => _CreateStockWithdrawalScreenState();
}

class _CreateStockWithdrawalScreenState extends State<CreateStockWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  DateTime _date = DateTime.now();
  String? _warehouseId;
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  List<Warehouse> _warehouses = [];

  List<StockWithdrawalItem> _items = [];
  final Map<String, double> _stockQuantities = {}; // to hold current stock of selected products
  
  final Map<String, TextEditingController> _qtyControllers = {};

  TextEditingController _getQtyController(StockWithdrawalItem item) {
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
      _reasonController.text = widget.existing!.conditionsGenerales ?? '';
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

  void _save() {
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

    final entry = StockWithdrawal(
      id: widget.existing?.id,
      number: widget.existing?.number ?? '',
      customerId: '',
      warehouseId: _warehouseId!,
      date: _date,
      conditionsGenerales: _reasonController.text,
      notes: _notesController.text,
      status: 'draft',
      items: validItems,
    );

    final productsBloc = context.read<ProductsBloc>();

    late StreamSubscription subscription;
    
    if (widget.isExitVoucher) {
      final exitVouchersBloc = context.read<ExitVouchersBloc>();
      subscription = exitVouchersBloc.stream.listen((state) {
        if (state is ExitVouchersLoaded || state is ExitVouchersError) {
          productsBloc.add(LoadProducts());
          subscription.cancel();
        }
      });
      if (widget.existing == null) {
        exitVouchersBloc.add(AddExitVoucher(entry));
      } else {
        exitVouchersBloc.add(UpdateExitVoucher(entry));
      }
    } else {
      final withdrawalBloc = context.read<StockWithdrawalsBloc>();
      subscription = withdrawalBloc.stream.listen((state) {
        if (state is StockWithdrawalsLoaded || state is StockWithdrawalsError) {
          productsBloc.add(LoadProducts());
          subscription.cancel();
        }
      });
      if (widget.existing == null) {
        withdrawalBloc.add(AddStockWithdrawal(entry));
      } else {
        withdrawalBloc.add(UpdateStockWithdrawal(entry));
      }
    }
    
    Navigator.pop(context);
  }

  void _addEmptyItem() {
    setState(() {
      _items.add(StockWithdrawalItem(
        id: _uuid.v4(),
        withdrawalId: widget.existing?.id ?? '',
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
      body: Form(
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
                    const SizedBox(height: 24),
                    _buildArticlesSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: _isMobile ? AppSpacing.md : AppSpacing.lg, vertical: AppSpacing.md),
      child: _isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existing == null ? "Créer un bon de prélèvement" : "Modifier le bon de prélèvement",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Valider'),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  widget.existing == null ? 'Créer' : 'Modifier',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Retour'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary, side: BorderSide(color: AppColors.border)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Valider'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
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
        const Text('Date', style: TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('d MMMM yyyy', 'fr').format(_date), style: const TextStyle(fontSize: 13)),
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );

    final warehouseField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Entrepôt', style: TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _warehouseId,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
          ),
          items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _warehouseId = val);
          },
        ),
      ],
    );

    final reasonField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Raison (optionnel)', style: TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: "Raison de l'opération...",
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );

    final notesField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notes (optionnel)', style: TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Notes additionnelles...',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (_isMobile) ...[
              dateField,
              const SizedBox(height: 16),
              warehouseField,
              const SizedBox(height: 16),
              reasonField,
              const SizedBox(height: 16),
              notesField,
            ] else ...[
              Row(
                children: [
                  Expanded(child: dateField),
                  const SizedBox(width: 24),
                  Expanded(child: warehouseField),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: reasonField),
                  const SizedBox(width: 24),
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

        return Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('Articles', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),

            // Items List
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildItemRow(index, item, products);
            }),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _addEmptyItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter une ligne'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 24),
                  tooltip: 'Créer un nouvel article',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateArticleScreen()));
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
}

  
  TextStyle _tableHeaderStyle() {
    return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary);
  }

  
  InputDecoration _itemInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  double _getRealCurrentStock(StockWithdrawalItem currentItem) {
    if (currentItem.productId.isEmpty) return 0;
    double stock = _stockQuantities[currentItem.productId] ?? 0;
    
    // If editing an existing withdrawal, the DB stock already has the old quantity deducted.
    // We must add it back to show the true "stock before withdrawal" preview in the UI.
    if (widget.existing != null) {
      try {
        final originalItem = widget.existing!.items.firstWhere((i) => i.id == currentItem.id);
        if (originalItem.productId == currentItem.productId) {
          stock += originalItem.quantity;
        }
      } catch (e) {
        // Not found (e.g. newly added row)
      }
    }
    return stock;
  }

  Widget _buildItemRow(int index, StockWithdrawalItem item, List<Product> products) {
    double currentStock = _getRealCurrentStock(item);
    double finalStock = currentStock - item.quantity;

    if (_isMobile) {
      return _buildMobileItemCard(index, item, products, currentStock, finalStock);
    }
    return _buildDesktopItemRow(index, item, products, currentStock, finalStock);
  }

  // ─── Mobile: Card-based item layout ────────────────────────────────
  Widget _buildMobileItemCard(int index, StockWithdrawalItem item, List<Product> products, double currentStock, double finalStock) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
              const Text('Produit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => _removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Autocomplete<Product>(
                    initialValue: TextEditingValue(
                      text: item.productId.isNotEmpty ? products.firstWhere((p) => p.id == item.productId, orElse: () => Product(id: '', code: '', name: '', sellingPrice: 0, purchasePrice: 0, tvaRate: 0, unit: '', productType: '')).name : '',
                    ),
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
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: 'Sélectionner un article',
                          hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 13),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(4),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 80),
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
                    onSelected: (Product selection) {
                      _updateItemProduct(index, selection);
                    },
                  ),
                ),
                if (_items.where((i) => i.productId == item.productId && i.productId.isNotEmpty).length > 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text('Ce produit est déjà ajouté dans une autre ligne', style: TextStyle(color: AppColors.error, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
          const SizedBox(height: 12),
          // Quantities row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('En stock', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(currentStock.toStringAsFixed(0), style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Qté à retirer', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 40,
                      child: TextFormField(
                        controller: _getQtyController(item),
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.blue, width: 2)),
                        ),
                        onChanged: (val) {
                          final q = double.tryParse(val) ?? 0;
                          _updateItemQuantity(index, q);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Qté finale', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(finalStock.toStringAsFixed(0), style: TextStyle(fontSize: 13, color: finalStock < 0 ? AppColors.error : Colors.green, fontWeight: FontWeight.bold)),
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
  Widget _buildDesktopItemRow(int index, StockWithdrawalItem item, List<Product> products, double currentStock, double finalStock) {
    return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row for this item
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0, right: 40.0), // 40 for delete button
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                    SizedBox(width: 16),
                    Expanded(flex: 1, child: Text('Qte en stock', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                    SizedBox(width: 16),
                    Expanded(flex: 1, child: Text('Qte a retirer', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                    SizedBox(width: 16),
                    Expanded(flex: 1, child: Text('Qte finale', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              
              // Inputs Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Produit Autocompl
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Autocomplete<Product>(
                              initialValue: TextEditingValue(
                                text: item.productId.isNotEmpty ? products.firstWhere((p) => p.id == item.productId, orElse: () => Product(id: '', code: '', name: '', sellingPrice: 0, purchasePrice: 0, tvaRate: 0, unit: '', productType: '')).name : '',
                              ),
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
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    hintText: 'Sélectionner un article',
                                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(4),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
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
                              onSelected: (Product selection) {
                                _updateItemProduct(index, selection);
                              },
                            ),
                          ),
                          if (_items.where((i) => i.productId == item.productId && i.productId.isNotEmpty).length > 1)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text('Ce produit est déjà ajouté dans une autre ligne', style: TextStyle(color: AppColors.error, fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                  const SizedBox(width: 16),
                  
                  // Qté en stock
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 40,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(currentStock.toStringAsFixed(0), style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Qté à retirer
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 40,
                      child: TextFormField(
                        controller: _getQtyController(item),
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.blue, width: 2)),
                        ),
                        onChanged: (val) {
                          final q = double.tryParse(val) ?? 0;
                          _updateItemQuantity(index, q);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Qté finale
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 40,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(finalStock.toStringAsFixed(0), style: TextStyle(fontSize: 13, color: finalStock < 0 ? AppColors.error : Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  // Delete action
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () => _removeItem(index),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (index < _items.length - 1)
                const Divider(height: 1, color: AppColors.border),
            ],
          ),
        );
  }
}

