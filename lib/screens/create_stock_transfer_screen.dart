import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/stock_transfers/stock_transfers_bloc.dart';
import '../models/stock_transfer.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/stock/stock_bloc.dart';
import '../models/stock_movement.dart';
import 'create_article_screen.dart';

class CreateStockTransferScreen extends StatefulWidget {
  final StockTransfer? existing;
  const CreateStockTransferScreen({super.key, this.existing});

  @override
  State<CreateStockTransferScreen> createState() => _CreateStockTransferScreenState();
}

class _CreateStockTransferScreenState extends State<CreateStockTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _reasonController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _sourceWarehouseId;
  String? _destWarehouseId;

  List<Warehouse> _warehouses = [];

  List<StockTransferItem> _items = [];

  bool get isEdit => widget.existing != null;
  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  String formatAmount(double amount, {String symbol = ''}) {
    if (amount == amount.toInt()) return amount.toInt().toString() + (symbol.isNotEmpty ? ' $symbol' : '');
    return amount.toStringAsFixed(2) + (symbol.isNotEmpty ? ' $symbol' : '');
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
    if (isEdit) {
      final transfer = widget.existing!;
      _selectedDate = transfer.date;
      _sourceWarehouseId = transfer.sourceWarehouseId;
      _destWarehouseId = transfer.destinationWarehouseId;
      _notesController.text = transfer.notes ?? '';
      _reasonController.text = transfer.reason ?? '';
      _items = List.from(transfer.items);
    } else {
      _items = [StockTransferItem(id: const Uuid().v4(), transferId: '', productId: '', quantityToTransfer: 0)];
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    final warehouses = await DatabaseHelper.instance.getWarehouses();
    setState(() {
      _warehouses = warehouses;
      if (!isEdit && warehouses.isNotEmpty) {
        _sourceWarehouseId = warehouses.first.id;
        if (warehouses.length > 1) {
          _destWarehouseId = warehouses[1].id;
        } else {
          _destWarehouseId = warehouses.first.id;
        }
      }
    });
  }

  void _onWarehouseChanged() {
    setState(() {});
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    final validItems = _items.where((i) => i.productId.isNotEmpty).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez ajouter au moins un article valide'), backgroundColor: AppColors.error),
      );
      return;
    }

    final productIds = validItems.map((i) => i.productId).toList();
    if (productIds.toSet().length != productIds.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous ne pouvez pas sélectionner le même produit plusieurs fois'), backgroundColor: AppColors.error),
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

    final number = isEdit ? widget.existing!.number : '';
    final transferId = isEdit ? widget.existing!.id : const Uuid().v4();

    final transfer = StockTransfer(
      id: transferId,
      number: number,
      date: _selectedDate,
      sourceWarehouseId: _sourceWarehouseId!,
      destinationWarehouseId: _destWarehouseId!,
      status: 'validated',
      notes: _notesController.text.trim(),
      reason: _reasonController.text.trim(),
      items: _items.map((item) => StockTransferItem(
        id: item.id.isNotEmpty ? item.id : const Uuid().v4(),
        transferId: transferId,
        productId: item.productId,
        productName: item.productName,
        productSku: item.productSku,
        quantityToTransfer: item.quantityToTransfer,
      )).toList(),
      createdAt: isEdit ? widget.existing!.createdAt : DateTime.now(),
    );

    if (isEdit) {
      context.read<StockTransfersBloc>().add(UpdateStockTransfer(transfer));
    } else {
      context.read<StockTransfersBloc>().add(AddStockTransfer(transfer));
    }
    
    context.read<StockBloc>().add(LoadStock());
    Navigator.pop(context);
  }

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
                    _buildInformationsSection(),
                    SizedBox(height: _isMobile ? AppSpacing.md : AppSpacing.lg),
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
                      icon: Icon(Icons.arrow_back, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? 'Modifier le bon ${widget.existing!.number}' : 'Créer un bon de transfert',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text('Valider'),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  isEdit ? 'Modifier' : 'Créer',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Spacer(),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, size: 18),
                  label: Text('Retour'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary, side: BorderSide(color: AppColors.border)),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: Icon(Icons.check, size: 18),
                  label: Text('Valider'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ],
            ),
    );
  }

  Widget _buildInformationsSection() {
    final dateField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) setState(() => _selectedDate = date);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDateTimeLong(_selectedDate), style: TextStyle(fontSize: 14)),
                Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );

    final sourceField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Entrepôt Source', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              value: _warehouses.any((w) => w.id == _sourceWarehouseId) ? _sourceWarehouseId : null,
              isExpanded: true,
              hint: Text('Sélectionner...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _sourceWarehouseId = newValue;
                });
                _onWarehouseChanged();
              },
            ),
          ),
        ),
      ],
    );

    final destField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Entrepôt Destination', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              value: _warehouses.any((w) => w.id == _destWarehouseId) ? _destWarehouseId : null,
              isExpanded: true,
              hint: Text('Sélectionner...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _destWarehouseId = newValue;
                });
                _onWarehouseChanged();
              },
            ),
          ),
        ),
      ],
    );

    final reasonField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Raison (optionnel)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          decoration: InputDecoration(
            hintText: 'Raison de l\'opération...',
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
          maxLines: 2,
        ),
      ],
    );

    final notesField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes (optionnel)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            hintText: 'Notes additionnelles...',
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
          maxLines: 2,
        ),
      ],
    );

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 16.0 : AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: 16),
            if (_isMobile) ...[
              dateField,
              SizedBox(height: 16),
              sourceField,
              SizedBox(height: 16),
              destField,
              SizedBox(height: 16),
              reasonField,
              SizedBox(height: 16),
              notesField,
            ] else ...[
              Row(
                children: [
                  Expanded(child: dateField),
                  SizedBox(width: 16),
                  Expanded(child: sourceField),
                  SizedBox(width: 16),
                  Expanded(child: destField),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: reasonField),
                  SizedBox(width: 16),
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
    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, productsState) {
        List<Product> products = [];
        if (productsState is ProductsLoaded) {
          products = productsState.products;
        }

        return BlocBuilder<StockBloc, StockState>(
          builder: (context, stockState) {
            return Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: EdgeInsets.all(_isMobile ? 16.0 : AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Articles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    SizedBox(height: 16),
                    
                    if (!_isMobile) ...[
                      // Desktop Header Row
                      Row(
                        children: [
                          Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                          SizedBox(width: 8),
                          Expanded(flex: 1, child: Text('Qté en stock source', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                          SizedBox(width: 8),
                          Expanded(flex: 1, child: Text('Qté à transférer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                          SizedBox(width: 8),
                          Expanded(flex: 1, child: Text('Qté finale source', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                          SizedBox(width: 8),
                          Expanded(flex: 1, child: Text('Qté en stock dest.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                          SizedBox(width: 8),
                          Expanded(flex: 1, child: Text('Qté finale dest.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                          SizedBox(width: 40),
                        ],
                      ),
                      SizedBox(height: 8),
                    ],
                    
                    // Items List
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      
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
                      final isDuplicate = item.productId.isNotEmpty && _items.where((i) => i.productId == item.productId).length > 1;

                      final autocompleteWidget = Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: isDuplicate ? Border.all(color: AppColors.error) : null,
                        ),
                        child: Autocomplete<Product>(
                          initialValue: TextEditingValue(
                            text: item.productName ?? '',
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
                              decoration: InputDecoration(
                                hintText: 'Sélectionner un article',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              style: TextStyle(fontSize: 13),
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
                                        leading: Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
                                        title: Text(option.name, style: TextStyle(fontSize: 13)),
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
                              _items[index] = StockTransferItem(
                                id: item.id,
                                transferId: '',
                                productId: p.id,
                                productName: p.name,
                                productSku: p.reference,
                                quantityToTransfer: 0,
                              );
                            });
                          },
                        ),
                      );

                      if (_isMobile) {
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
                                    onPressed: () => setState(() => _items.removeAt(index)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              autocompleteWidget,
                              if (isDuplicate)
                                Padding(
                                  padding: EdgeInsets.only(top: 4, left: 4),
                                  child: Text('Produit déjà ajouté', style: TextStyle(color: AppColors.error, fontSize: 11)),
                                ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('En stock src', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
                                          child: Center(child: Text(formatAmount(sourceStock, symbol: ''), style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12))),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Qté à transfér.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        SizedBox(height: 4),
                                        TextFormField(
                                          initialValue: item.quantityToTransfer > 0 ? formatAmount(item.quantityToTransfer, symbol: '') : '',
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 12),
                                          decoration: InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                            filled: true,
                                            fillColor: AppColors.surface,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.border)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.border)),
                                          ),
                                          onChanged: (val) {
                                            final qty = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                                            setState(() {
                                              _items[index] = StockTransferItem(
                                                id: item.id, transferId: item.transferId, productId: item.productId, 
                                                productName: item.productName, productSku: item.productSku, 
                                                quantityToTransfer: qty,
                                              );
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
                                        Text('Qté fin. src', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
                                          child: Center(child: Text(formatAmount(finalSourceStock, symbol: ''), style: TextStyle(color: finalSourceStock < 0 ? AppColors.error : AppColors.success, fontWeight: FontWeight.bold, fontSize: 12))),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('En stock dest.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
                                          child: Center(child: Text(formatAmount(destStock, symbol: ''), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Qté fin. dest.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
                                          child: Center(child: Text(formatAmount(finalDestStock, symbol: ''), style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12))),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Spacer(),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Selection
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  autocompleteWidget,
                                  if (isDuplicate)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4, left: 4),
                                      child: Text(
                                        'Produit déjà ajouté',
                                        style: TextStyle(color: AppColors.error, fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            
                            // Stock Source
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                child: Text(
                                  formatAmount(sourceStock, symbol: ''),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            
                            // Qty to Transfer
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: item.quantityToTransfer > 0 ? formatAmount(item.quantityToTransfer, symbol: '') : '',
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.border)),
                                ),
                                onChanged: (val) {
                                  final qty = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                                  setState(() {
                                    _items[index] = StockTransferItem(
                                      id: item.id, transferId: item.transferId, productId: item.productId, 
                                      productName: item.productName, productSku: item.productSku, 
                                      quantityToTransfer: qty,
                                    );
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 8),
                            
                            // Final Stock Source
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppRadius.sm)),
                                child: Text(
                                  formatAmount(finalSourceStock, symbol: ''),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: finalSourceStock < 0 ? AppColors.error : AppColors.success, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            
                            // Stock Dest
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                child: Text(
                                  formatAmount(destStock, symbol: ''),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            
                            // Final Stock Dest
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppRadius.sm)),
                                child: Text(
                                  formatAmount(finalDestStock, symbol: ''),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            
                            // Delete Button
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              onPressed: () => setState(() => _items.removeAt(index)),
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
                          onPressed: () {
                            setState(() {
                              _items.add(StockTransferItem(transferId: '', productId: '', quantityToTransfer: 0));
                            });
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
      },
    );
  }
}
