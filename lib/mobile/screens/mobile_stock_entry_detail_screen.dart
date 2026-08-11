import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/stock_entries/stock_entries_bloc.dart';
import '../../blocs/stock_entries/stock_entries_state.dart';
import '../../blocs/stock_entries/stock_entries_event.dart';
import '../../blocs/products/products_bloc.dart';
import '../../models/stock_entry.dart';
import '../../models/product.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../database/database_helper.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_state.dart';

import '../../screens/create_stock_entry_screen.dart';
import '../../screens/document_preview_screen.dart';

class MobileStockEntryDetailScreen extends StatefulWidget {
  final StockEntry entry;

  const MobileStockEntryDetailScreen({super.key, required this.entry});

  @override
  State<MobileStockEntryDetailScreen> createState() => _MobileStockEntryDetailScreenState();
}

class _MobileStockEntryDetailScreenState extends State<MobileStockEntryDetailScreen> {
  late StockEntry currentEntry;
  Map<String, Product> _dbProducts = {};
  @override
  void initState() {
    super.initState();
    currentEntry = widget.entry;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await DatabaseHelper.instance.getProducts();
      if (mounted) {
        setState(() {
          _dbProducts = {for (var p in products) p.id: p};
        });
      }
    } catch (_) {}
  }

  // removed _loadWarehouseName()

  Product? _getProduct(String id) {
    if (_dbProducts.containsKey(id)) {
      return _dbProducts[id];
    }
    final state = context.read<ProductsBloc>().state;
    if (state is ProductsLoaded) {
      try {
        return state.products.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    return null;
  }

  DocumentWrapper _createDocumentWrapper(StockEntry entry) {
    return DocumentWrapper(
      id: entry.id,
      number: entry.number,
      documentTitle: "BON D'ENTRÉE",
      date: entry.date,
      totalHT: entry.items.fold(0.0, (sum, i) => sum + (i.quantity * i.unitPrice)),
      totalTva: 0.0,
      totalTTC: entry.items.fold(0.0, (sum, i) => sum + (i.quantity * i.unitPrice)),
      notes: entry.notes,
      items: entry.items.map((item) {
        final product = _getProduct(item.productId);
        return DocumentItemWrapper(
          productName: product?.name ?? 'Article Inconnu',
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: 0.0,
          discountPercent: 0.0,
          totalHT: item.quantity * item.unitPrice,
          customFields: {
            'code': (product?.reference != null && product!.reference!.isNotEmpty) 
                ? product.reference 
                : (product?.code ?? ''),
            'unit': product?.unit ?? 'pièce',
          },
        );
      }).toList(),
      customData: {
        'warehouseId': entry.warehouseId,
        'warehouseName': () {
          if (entry.warehouseId == 'default_warehouse') return 'Entrepôt par défaut';
          final wState = context.read<WarehousesBloc>().state;
          if (wState is WarehousesLoaded) {
            final match = wState.warehouses.cast<dynamic>().firstWhere(
              (w) => w.id == entry.warehouseId, 
              orElse: () => null
            );
            if (match != null) return match.name;
          }
          return 'Entrepôt par défaut';
        }(),
        'reason': entry.reason,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wState = context.watch<WarehousesBloc>().state;
    String getWhName(String id) {
      if (id == 'default_warehouse') return 'Entrepôt par défaut';
      if (wState is WarehousesLoaded) {
        final match = wState.warehouses.cast<dynamic>().firstWhere(
          (w) => w.id == id, 
          orElse: () => null
        );
        if (match != null) return match.name;
      }
      return 'Entrepôt par défaut';
    }
    final String warehouseName = getWhName(currentEntry.warehouseId);

    return BlocListener<StockEntriesBloc, StockEntriesState>(
      listener: (context, state) {
        if (state is StockEntriesLoaded) {
          try {
            final updatedEntry = state.entries.firstWhere((e) => e.id == currentEntry.id);
            if (mounted) {
              setState(() {
                currentEntry = updatedEntry;
              });
            }
          } catch (_) {
            if (mounted) {
              Navigator.pop(context);
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('BE ${currentEntry.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentEntry),
              itemBuilder: (_) => [
                _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Réf: ${currentEntry.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Validé',
                              style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Date', formatDateTimeLong(currentEntry.date)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Entrepôt', warehouseName),
                      if (currentEntry.reason != null && currentEntry.reason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Motif', currentEntry.reason!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              if (currentEntry.items.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: Text('Aucun article', style: TextStyle(color: AppColors.textSecondary))),
                  ),
                )
              else
                ...currentEntry.items.map((item) {
                  final product = _getProduct(item.productId);
                  final productName = product?.name ?? 'Article non spécifié';
                  final unit = product?.unit ?? 'pièces';
                  final qtyText = '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} $unit';
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                if (product?.reference != null && product!.reference!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(product.reference!, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                ] else if (product?.code != null && product!.code.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(product.code, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                ],
                                const SizedBox(height: 4),
                                Text(qtyText, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (currentEntry.notes != null && currentEntry.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(currentEntry.notes!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color iconColor, String text) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, StockEntry entry) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<StockEntriesBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: CreateStockEntryScreen(existing: entry),
            ),
          ),
        ).then((_) {
          if (mounted) {
            context.read<StockEntriesBloc>().add(LoadFirstStockEntries());
          }
        });
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer ce bon d\'entrée ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<StockEntriesBloc>().add(DeleteStockEntry(entry.id));
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'print':
        final doc = _createDocumentWrapper(entry);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }
}
