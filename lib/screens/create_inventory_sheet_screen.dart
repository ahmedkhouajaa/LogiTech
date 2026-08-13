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
import '../../models/product.dart';
import '../../models/stock_movement.dart' show Warehouse;
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../database/database_helper.dart';
import '../../services/enterprise_service.dart';
import '../mobile/screens/forms/mobile_product_form_screen.dart';
import '../widgets/article_selection_modal.dart';
import 'create_article_screen.dart';
import '../widgets/searchable_dropdown_field.dart';
import '../mobile/widgets/forms/mobile_smart_fields.dart';

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
      _number = '';
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

  Future<void> _save({bool isDraft = false}) async {
    if (_warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un entrepôt.')));
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter au moins un article.')));
      return;
    }

    final uniqueProductIds = _items.map((i) => i.productId).toSet();
    if (uniqueProductIds.length != _items.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Un article ne peut pas être sélectionné plusieurs fois.')));
      return;
    }

    String sheetNumber = _number;
    if (sheetNumber.isEmpty) {
      final seq = await DatabaseHelper.instance.getNextInventorySheetSequence();
      sheetNumber = generateDocNumber(DocPrefix.inventorySheet, seq);
    }

    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final newSheet = InventorySheet(
      id: _id,
      number: sheetNumber,
      date: _date,
      inventoryDate: _inventoryDate,
      warehouseId: _warehouseId!,
      countedBy: _countedByController.text,
      reason: _reasonController.text,
      notes: _notesController.text,
      status: isDraft ? 'draft' : 'validated',
      enterpriseId: currentEntId,
      items: _items,
      createdAt: widget.sheet?.createdAt,
    );

    if (widget.sheet == null) {
      context.read<InventorySheetsBloc>().add(InventorySheetAdded(newSheet));
    } else {
      context.read<InventorySheetsBloc>().add(InventorySheetUpdated(newSheet));
    }

    if (mounted) {
      context.read<StockBloc>().add(LoadStock());
      context.read<ProductsBloc>().add(LoadProducts());
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isViewOnly ? 'Fiche d\'inventaire' : (widget.sheet == null ? 'Créer une fiche d\'inventaire' : 'Modifier la fiche d\'inventaire'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Validé',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocListener<WarehousesBloc, WarehousesState>(
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
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      SizedBox(height: 16),
                      _buildItemsSection(),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.isViewOnly)
              Container(
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
                        onPressed: () => _save(isDraft: false),
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
              ),
          ],
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  TextFormField(
                    initialValue: DateFormat('dd MMMM yyyy', 'fr_FR').format(_date),
                    readOnly: true,
                    enabled: !widget.isViewOnly,
                    decoration: InputDecoration(
                      suffixIcon: Icon(Icons.calendar_today, size: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  SizedBox(height: 16),
                  SmartSearchableSelector(
                    label: 'Entrepôt',
                    hint: 'Sélectionner un entrepôt',
                    selectedText: _warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _warehouseId, orElse: () => _warehouses.cast<Warehouse?>().firstWhere((w) => w?.isDefault == true, orElse: () => _warehouses.isNotEmpty ? _warehouses.first : null))?.name,
                    onTap: () async {
                      if (widget.isViewOnly) return;
                      final res = await showWarehouseSelectDialog(context, _warehouses, selectedWarehouseId: _warehouseId);
                      if (res != null && mounted) {
                        setState(() => _warehouseId = res);
                      }
                    },
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        SizedBox(height: 4),
                        TextFormField(
                          initialValue: DateFormat('dd MMMM yyyy', 'fr_FR').format(_date),
                          readOnly: true,
                          enabled: !widget.isViewOnly,
                          decoration: InputDecoration(
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SmartSearchableSelector(
                      label: 'Entrepôt',
                      hint: 'Sélectionner un entrepôt',
                      selectedText: _warehouses.cast<Warehouse?>().firstWhere((w) => w?.id == _warehouseId, orElse: () => _warehouses.cast<Warehouse?>().firstWhere((w) => w?.isDefault == true, orElse: () => _warehouses.isNotEmpty ? _warehouses.first : null))?.name,
                      onTap: () async {
                        if (widget.isViewOnly) return;
                        final res = await showWarehouseSelectDialog(context, _warehouses, selectedWarehouseId: _warehouseId);
                        if (res != null && mounted) {
                          setState(() => _warehouseId = res);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date d\'inventaire', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
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
                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(_inventoryDate)),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Date de saisie', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  TextFormField(
                    initialValue: DateFormat('dd MMMM yyyy', 'fr_FR').format(widget.sheet?.createdAt ?? DateTime.now()),
                    readOnly: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Compté par', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  TextFormField(
                    controller: _countedByController,
                    readOnly: widget.isViewOnly,
                    decoration: InputDecoration(
                      hintText: 'Nom du responsable',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date d\'inventaire', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        SizedBox(height: 4),
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
                              suffixIcon: Icon(Icons.calendar_today, size: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(_inventoryDate)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date de saisie', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        SizedBox(height: 4),
                        TextFormField(
                          initialValue: DateFormat('dd MMMM yyyy', 'fr_FR').format(widget.sheet?.createdAt ?? DateTime.now()),
                          readOnly: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compté par', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        SizedBox(height: 4),
                        TextFormField(
                          controller: _countedByController,
                          readOnly: widget.isViewOnly,
                          decoration: InputDecoration(
                            hintText: 'Nom du responsable',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Raison (optionnel)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      TextFormField(
                        controller: _reasonController,
                        readOnly: widget.isViewOnly,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Raison de l\'opération...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notes (optionnel)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      TextFormField(
                        controller: _notesController,
                        readOnly: widget.isViewOnly,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Notes additionnelles...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Articles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            
            if (!isMobile) ...[
              // Desktop Header
              Row(
                children: [
                  Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                  SizedBox(width: 8),
                  Expanded(flex: 1, child: Text('Théorique', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  SizedBox(width: 8),
                  Expanded(flex: 1, child: Text('Réel', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  SizedBox(width: 8),
                  Expanded(flex: 1, child: Text('Surplus', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  SizedBox(width: 8),
                  Expanded(flex: 1, child: Text('Manquant', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  if (!widget.isViewOnly) SizedBox(width: 40),
                ],
              ),
              Divider(),
            ],
            
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

                        if (isMobile) {
                          // Mobile Card matching image 3 (transfer / withdrawal style)
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
                                    if (!widget.isViewOnly)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                        onPressed: () => setState(() => _items.removeAt(index)),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                InkWell(
                                  onTap: widget.isViewOnly ? null : () async {
                                    final selectedProduct = await ArticleSelectionModal.show(context, warehouseId: _warehouseId);
                                    if (selectedProduct != null) {
                                      setState(() {
                                        _items[index] = item.copyWith(
                                          productId: selectedProduct.id,
                                          productName: selectedProduct.name,
                                          productSku: selectedProduct.reference,
                                          actualQty: 0,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                      border: Border.all(color: isDuplicate ? AppColors.error : AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (item.productName != null && item.productName!.isNotEmpty)
                                                ? item.productName!
                                                : 'Sélectionner un article',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: (item.productName != null && item.productName!.isNotEmpty) ? AppColors.textPrimary : AppColors.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!widget.isViewOnly)
                                          Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isDuplicate)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4, left: 4),
                                    child: Text('Article déjà sélectionné', style: TextStyle(color: AppColors.error, fontSize: 11)),
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
                                            child: Center(child: Text(formatAmount(theoreticalStock, symbol: ''), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
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
                                            initialValue: item.actualQty > 0 ? formatAmount(item.actualQty, symbol: '') : '',
                                            readOnly: widget.isViewOnly,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.border)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.border)),
                                            ),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            onChanged: (val) {
                                              final qty = double.tryParse(val.replaceAll(',', '.')) ?? 0;
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
                                            child: Center(child: Text(surplus > 0 ? formatAmount(surplus, symbol: '') : '—', style: TextStyle(color: surplus > 0 ? AppColors.success : AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 12))),
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
                                            child: Center(child: Text(missing > 0 ? formatAmount(missing, symbol: '') : '—', style: TextStyle(color: missing > 0 ? AppColors.error : AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 12))),
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

                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(color: widget.isViewOnly ? AppColors.surfaceAlt : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: widget.isViewOnly 
                                  ? Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text(item.productName ?? ''),
                                    )
                                  : Column(
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
                                              selectedText: selectedProd?.name ?? (item.productName?.isNotEmpty == true ? item.productName : null),
                                              hasError: isDuplicate,
                                              onTap: () async {
                                                final stockMap = <String, double>{};
                                                if (stockState is StockLoaded) {
                                                  bool isDefault = false;
                                                  try {
                                                    isDefault = _warehouses.firstWhere((Warehouse w) => w.id == _warehouseId).isDefault;
                                                  } catch (_) {}
                                                  for (var p in products) {
                                                    double pStock = 0.0;
                                                    for (var m in stockState.movements) {
                                                      if (m.productId == p.id) {
                                                        if (m.warehouseId == _warehouseId || (m.warehouseId == 'default_warehouse' && isDefault)) {
                                                          if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) pStock += m.quantity;
                                                          else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) pStock -= m.quantity;
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
                                                  warehouseId: _warehouseId,
                                                  warehouseStockMap: stockMap,
                                                );
                                                if (res != null) {
                                                  final p = products.firstWhere((prod) => prod.id == res);
                                                  setState(() {
                                                    _items[index] = item.copyWith(
                                                      productId: p.id,
                                                      productName: p.name,
                                                      productSku: p.reference,
                                                      actualQty: 0,
                                                    );
                                                  });
                                                }
                                              },
                                            );
                                          },
                                        ),
                                        if (isDuplicate)
                                          Padding(
                                            padding: EdgeInsets.only(top: 4, left: 4),
                                            child: Text('Article déjà sélectionné', style: TextStyle(color: AppColors.error, fontSize: 11)),
                                          ),
                                      ],
                                    ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: Text(formatAmount(theoreticalStock, symbol: ''), textAlign: TextAlign.right),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  initialValue: item.actualQty > 0 ? formatAmount(item.actualQty, symbol: '') : '',
                                  readOnly: widget.isViewOnly,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                              SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: surplus > 0 ? AppColors.successLight : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: Text(surplus > 0 ? formatAmount(surplus, symbol: '') : '—', textAlign: TextAlign.right, style: TextStyle(color: surplus > 0 ? AppColors.success : AppColors.textTertiary, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: missing > 0 ? AppColors.errorLight : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: Text(missing > 0 ? formatAmount(missing, symbol: '') : '—', textAlign: TextAlign.right, style: TextStyle(color: missing > 0 ? AppColors.error : AppColors.textTertiary, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              if (!widget.isViewOnly) ...[
                                SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
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
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (isMobile) {
                        final selectedProduct = await ArticleSelectionModal.show(context, warehouseId: _warehouseId);
                        if (selectedProduct != null) {
                          setState(() {
                            _items.add(InventorySheetItem(
                              id: _uuid.v4(),
                              inventoryId: _id,
                              productId: selectedProduct.id,
                              productName: selectedProduct.name,
                              productSku: selectedProduct.reference,
                              theoreticalQty: selectedProduct.stockQty,
                              actualQty: 0,
                            ));
                          });
                        }
                      } else {
                        setState(() {
                          _items.add(InventorySheetItem(id: _uuid.v4(), inventoryId: _id, productId: '', theoreticalQty: 0, actualQty: 0));
                        });
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
                      if (isMobile) {
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
          ],
        ),
      ),
    );
  }
}
