import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product.dart';
import '../../models/stock_movement.dart' show Warehouse, StockMovement;
import '../../models/inventory_sheet.dart';
import '../../models/inventory_sheet_item.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_state.dart';
import '../../blocs/warehouses/warehouses_event.dart';
import '../../blocs/stock/stock_bloc.dart';
import '../../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../../services/enterprise_service.dart';
import '../../database/database_helper.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/blank_inventory_pdf_service.dart';
import '../../screens/history_pdf_preview_screen.dart';

class PrintBlankInventoryDialog extends StatefulWidget {
  const PrintBlankInventoryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<InventorySheetsBloc>()),
          BlocProvider.value(value: context.read<ProductsBloc>()),
          BlocProvider.value(value: context.read<WarehousesBloc>()),
          BlocProvider.value(value: context.read<StockBloc>()),
        ],
        child: const PrintBlankInventoryDialog(),
      ),
    );
  }

  @override
  State<PrintBlankInventoryDialog> createState() => _PrintBlankInventoryDialogState();
}

class _PrintBlankInventoryDialogState extends State<PrintBlankInventoryDialog> {
  String? _selectedWarehouseId;
  String _selectedFamily = 'Toutes les familles';
  String _searchQuery = '';
  bool _hideZeroStock = false;
  final Set<String> _selectedProductIds = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<WarehousesBloc>().add(LoadWarehouses());
    context.read<StockBloc>().add(LoadStock());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _getProductStockInWarehouse(
    Product product,
    String? warehouseId,
    List<Warehouse> warehouses,
    List<StockMovement> movements,
  ) {
    if (warehouseId == null) return product.stockQty;

    bool isDefault = false;
    try {
      isDefault = warehouses.firstWhere((w) => w.id == warehouseId).isDefault;
    } catch (_) {}

    double stock = 0.0;
    bool hasMovements = false;

    for (final m in movements) {
      if (m.productId == product.id) {
        final matches = m.warehouseId == warehouseId || (isDefault && m.warehouseId == 'default_warehouse');
        if (matches) {
          hasMovements = true;
          if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
            stock += m.quantity;
          } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
            stock -= m.quantity;
          }
        }
      }
    }

    if (!hasMovements && isDefault) {
      return product.stockQty;
    }
    return stock;
  }

  String _formatStock(double stock) {
    if (stock == stock.roundToDouble()) {
      return stock.toInt().toString();
    }
    return stock.toStringAsFixed(1);
  }

  Future<void> _handlePrint(
    List<Product> allProducts,
    List<Warehouse> warehouses,
    List<StockMovement> movements,
  ) async {
    if (_selectedProductIds.isEmpty) return;

    final inventoryBloc = context.read<InventorySheetsBloc>();
    final selectedProducts = allProducts.where((p) => _selectedProductIds.contains(p.id)).toList();

    String warehouseName = context.tr('Entrepôt par défaut');
    if (_selectedWarehouseId != null) {
      try {
        warehouseName = warehouses.firstWhere((w) => w.id == _selectedWarehouseId).name;
      } catch (_) {}
    }

    // Generate sheet reference sequence
    String reference;
    try {
      final seq = await DatabaseHelper.instance.getNextInventorySheetSequence();
      reference = generateDocNumber(DocPrefix.inventorySheet, seq);
    } catch (_) {
      reference = 'FI-${DateTime.now().year}-000001';
    }

    final sheetId = const Uuid().v4();
    final now = DateTime.now();
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;

    // Create items for the inventory sheet
    final items = selectedProducts.map((p) {
      final theoretical = _getProductStockInWarehouse(p, _selectedWarehouseId, warehouses, movements);
      return InventorySheetItem(
        id: const Uuid().v4(),
        inventoryId: sheetId,
        productId: p.id,
        productName: p.name,
        productSku: (p.reference != null && p.reference!.trim().isNotEmpty) ? p.reference!.trim() : p.code.trim(),
        theoreticalQty: theoretical,
        actualQty: theoretical,
      );
    }).toList();

    final newSheet = InventorySheet(
      id: sheetId,
      number: reference,
      date: now,
      inventoryDate: now,
      warehouseId: _selectedWarehouseId ?? 'default_warehouse',
      notes: warehouseName,
      status: 'draft',
      enterpriseId: currentEntId,
      items: items,
    );

    // Add to InventorySheetsBloc so it is saved to database and displayed in the list
    try {
      inventoryBloc.add(InventorySheetAdded(newSheet));
    } catch (e) {
      debugPrint('Error adding inventory sheet to bloc: $e');
    }

    if (!mounted) return;

    // Close dialog and open PDF Preview
    Navigator.of(context).pop();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryPdfPreviewScreen(
          title: context.tr("Fiche d'inventaire vierge"),
          pdfFileName: 'Fiche_Inventaire_Vierge_${reference}_${warehouseName.replaceAll(' ', '_')}.pdf',
          buildPdf: (format) => BlankInventoryPdfService.instance.generateBlankInventoryPdf(
            warehouseName: warehouseName,
            products: selectedProducts,
            reference: reference,
            date: now,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 700;

    return BlocBuilder<WarehousesBloc, WarehousesState>(
      builder: (context, warehousesState) {
        List<Warehouse> warehouses = [];
        if (warehousesState is WarehousesLoaded) {
          warehouses = warehousesState.warehouses;
          if (_selectedWarehouseId == null && warehouses.isNotEmpty) {
            _selectedWarehouseId = warehouses.firstWhere((w) => w.isDefault, orElse: () => warehouses.first).id;
          }
        }

        return BlocBuilder<StockBloc, StockState>(
          builder: (context, stockState) {
            List<StockMovement> movements = [];
            if (stockState is StockLoaded) {
              movements = stockState.movements;
            }

            return BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, productsState) {
                List<Product> products = [];
                if (productsState is ProductsLoaded) {
                  products = productsState.products.where((p) => p.isActive && !p.isDeleted && !p.isService).toList();
                }

                // Collect distinct families
                final Set<String> families = {'Toutes les familles'};
                for (final p in products) {
                  if (p.category != null && p.category!.trim().isNotEmpty) {
                    families.add(p.category!.trim());
                  } else {
                    families.add('Famille par défaut');
                  }
                }

                // Filter products
                final filteredProducts = products.where((product) {
                  final family = (product.category != null && product.category!.trim().isNotEmpty)
                      ? product.category!.trim()
                      : 'Famille par défaut';

                  if (_selectedFamily != 'Toutes les familles' && family != _selectedFamily) {
                    return false;
                  }

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final ref = (product.reference ?? product.code).toLowerCase();
                    final name = product.name.toLowerCase();
                    if (!ref.contains(q) && !name.contains(q)) {
                      return false;
                    }
                  }

                  if (_hideZeroStock) {
                    final stock = _getProductStockInWarehouse(product, _selectedWarehouseId, warehouses, movements);
                    if (stock == 0) return false;
                  }

                  return true;
                }).toList();

                final isAllFilteredSelected = filteredProducts.isNotEmpty &&
                    filteredProducts.every((p) => _selectedProductIds.contains(p.id));
                final isSomeFilteredSelected = filteredProducts.any((p) => _selectedProductIds.contains(p.id)) &&
                    !isAllFilteredSelected;

                final dialogWidth = isMobile ? screenWidth * 0.96 : screenWidth.clamp(650.0, 850.0);
                final dialogMaxHeight = screenHeight * 0.90;

                return Dialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dialogWidth,
                      maxHeight: dialogMaxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ─── Header ─────────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr("Imprimer une fiche d'inventaire vierge"),
                                      style: TextStyle(
                                        fontSize: isMobile ? 17 : 19,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      context.tr("Sélectionnez le dépôt et les articles à inclure dans la fiche vierge à imprimer."),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                color: AppColors.textTertiary,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ─── Dépôt Dropdown ──────────────────────
                          Text(
                            context.tr('Dépôt'),
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedWarehouseId,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                                items: warehouses.map((w) {
                                  return DropdownMenuItem<String>(
                                    value: w.id,
                                    child: Text(
                                      w.isDefault ? context.tr('Entrepôt par défaut') : w.name,
                                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedWarehouseId = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ─── Familles Dropdown ────────────────────
                          Text(
                            context.tr('Familles'),
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: families.contains(_selectedFamily) ? _selectedFamily : 'Toutes les familles',
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                                items: families.map((f) {
                                  return DropdownMenuItem<String>(
                                    value: f,
                                    child: Text(
                                      context.tr(f),
                                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedFamily = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ─── Search Bar & Zero Stock Toggle ───────
                          if (isMobile) ...[
                            TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: context.tr('Rechercher par référence ou nom...'),
                                hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                                prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Switch(
                                  value: _hideZeroStock,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) => setState(() => _hideZeroStock = val),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    context.tr('Masquer les articles à stock zéro'),
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: context.tr('Rechercher par référence ou nom...'),
                                      hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                                      prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                                    ),
                                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Switch(
                                  value: _hideZeroStock,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) => setState(() => _hideZeroStock = val),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.tr('Masquer les articles à stock zéro'),
                                  style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),

                          // ─── Table of Articles ────────────────────
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                      border: Border(bottom: BorderSide(color: AppColors.border)),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          child: Checkbox(
                                            value: isAllFilteredSelected ? true : (isSomeFilteredSelected ? null : false),
                                            tristate: true,
                                            activeColor: AppColors.primary,
                                            onChanged: (val) {
                                              setState(() {
                                                if (isAllFilteredSelected) {
                                                  for (final p in filteredProducts) {
                                                    _selectedProductIds.remove(p.id);
                                                  }
                                                } else {
                                                  for (final p in filteredProducts) {
                                                    _selectedProductIds.add(p.id);
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            context.tr('Référence'),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            context.tr('Nom'),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            context.tr('Famille'),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            context.tr('Stock disponible'),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Table Body
                                  Expanded(
                                    child: filteredProducts.isEmpty
                                        ? Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(24.0),
                                              child: Text(
                                                context.tr('Aucun article trouvé'),
                                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            itemCount: filteredProducts.length,
                                            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                                            itemBuilder: (context, index) {
                                              final product = filteredProducts[index];
                                              final isSelected = _selectedProductIds.contains(product.id);
                                              final ref = (product.reference != null && product.reference!.trim().isNotEmpty)
                                                  ? product.reference!.trim()
                                                  : product.code.trim();
                                              final family = (product.category != null && product.category!.trim().isNotEmpty)
                                                  ? product.category!.trim()
                                                  : context.tr('Famille par défaut');
                                              final stock = _getProductStockInWarehouse(
                                                  product, _selectedWarehouseId, warehouses, movements);

                                              return InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    if (isSelected) {
                                                      _selectedProductIds.remove(product.id);
                                                    } else {
                                                      _selectedProductIds.add(product.id);
                                                    }
                                                  });
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 32,
                                                        child: Checkbox(
                                                          value: isSelected,
                                                          activeColor: AppColors.primary,
                                                          onChanged: (val) {
                                                            setState(() {
                                                              if (val == true) {
                                                                _selectedProductIds.add(product.id);
                                                              } else {
                                                                _selectedProductIds.remove(product.id);
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          ref,
                                                          style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          product.name,
                                                          style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 3,
                                                        child: Text(
                                                          family,
                                                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          _formatStock(stock),
                                                          textAlign: TextAlign.right,
                                                          style: TextStyle(
                                                            fontSize: 12.5,
                                                            fontWeight: FontWeight.w600,
                                                            color: stock < 0
                                                                ? AppColors.error
                                                                : (stock == 0 ? AppColors.textTertiary : AppColors.textPrimary),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ─── Footer ───────────────────────────────
                          Row(
                            children: [
                              Text(
                                '${_selectedProductIds.length} ${context.tr('article(s) sélectionné(s)')}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: BorderSide(color: AppColors.border),
                                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: Text(context.tr('Annuler')),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: _selectedProductIds.isNotEmpty
                                    ? () => _handlePrint(products, warehouses, movements)
                                    : null,
                                icon: const Icon(Icons.print_outlined, size: 18),
                                label: Text(context.tr("Imprimer fiche d'inventaire vierge")),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedProductIds.isNotEmpty ? AppColors.primary : Colors.grey.shade300,
                                  foregroundColor: _selectedProductIds.isNotEmpty ? Colors.white : Colors.grey.shade500,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade500,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
