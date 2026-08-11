import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../../blocs/inventory_sheets/inventory_sheets_state.dart';
import '../../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../../blocs/products/products_bloc.dart';
import '../../models/inventory_sheet.dart';
import '../../models/product.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../database/database_helper.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_state.dart';

import 'forms/mobile_inventory_sheet_form_screen.dart';

class MobileInventorySheetDetailScreen extends StatefulWidget {
  final InventorySheet sheet;

  const MobileInventorySheetDetailScreen({
    super.key,
    required this.sheet,
  });

  @override
  State<MobileInventorySheetDetailScreen> createState() => _MobileInventorySheetDetailScreenState();
}

class _MobileInventorySheetDetailScreenState extends State<MobileInventorySheetDetailScreen> {
  late InventorySheet currentSheet;
  Map<String, Product> _dbProducts = {};
  @override
  void initState() {
    super.initState();
    currentSheet = widget.sheet;
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

  void _handleAction(BuildContext context, String action, InventorySheet sheet) {
    if (action == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MobileInventorySheetFormScreen(existing: sheet),
        ),
      ).then((_) {
        if (mounted) {
          context.read<InventorySheetsBloc>().add(LoadFirstInventorySheets());
        }
      });
    } else if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer cette fiche ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                context.read<InventorySheetsBloc>().add(InventorySheetDeleted(sheet.id));
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text('Supprimer', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    }
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
    final String warehouseName = getWhName(currentSheet.warehouseId);

    final totalSurplus = currentSheet.items.fold(0.0, (sum, item) {
      final diff = item.actualQty - item.theoreticalQty;
      return diff > 0 ? sum + diff : sum;
    });
    final totalMissing = currentSheet.items.fold(0.0, (sum, item) {
      final diff = item.actualQty - item.theoreticalQty;
      return diff < 0 ? sum + diff.abs() : sum;
    });

    return BlocListener<InventorySheetsBloc, InventorySheetsState>(
      listener: (context, state) {
        if (state is InventorySheetsLoaded) {
          try {
            final updatedSheet = state.sheets.firstWhere((q) => q.id == currentSheet.id);
            if (updatedSheet.id == currentSheet.id && mounted) {
              setState(() {
                currentSheet = updatedSheet;
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
          title: Text('Fiche ${currentSheet.number}', style: TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (currentSheet.status != 'validated')
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (val) => _handleAction(context, val, currentSheet),
                itemBuilder: (_) => [
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                  PopupMenuDivider(height: 1),
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                ],
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                color: AppColors.surface,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Réf: ${currentSheet.number}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Validé', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Date', formatDateTimeLong(currentSheet.date)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Référence', currentSheet.number),
                      const SizedBox(height: 8),
                      _buildInfoRow('Entrepôt', warehouseName),
                      if (currentSheet.reason != null && currentSheet.reason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Motif', currentSheet.reason!),
                      ],
                      if (currentSheet.notes != null && currentSheet.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Notes', currentSheet.notes!),
                      ],
                      if (totalSurplus > 0 || totalMissing > 0) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('Surplus', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  totalSurplus > 0 ? '+${totalSurplus.toStringAsFixed(1)}' : '—',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: totalSurplus > 0 ? AppColors.success : AppColors.textSecondary),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text('Manquant', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  totalMissing > 0 ? '-${totalMissing.toStringAsFixed(1)}' : '—',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: totalMissing > 0 ? AppColors.error : AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              if (currentSheet.items.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                  color: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('Aucun article', style: TextStyle(color: AppColors.textSecondary))),
                  ),
                )
              else
                ...currentSheet.items.map((item) {
                  final product = _getProduct(item.productId);
                  final productName = product?.name ?? item.productName ?? 'Article inconnu';
                  final refCode = product?.reference ?? product?.code ?? item.productSku;
                  final unit = product?.unit ?? 'pièces';
                  final actualQtyText = '${item.actualQty % 1 == 0 ? item.actualQty.toInt() : item.actualQty} $unit';
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
                                if (refCode != null && refCode.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(refCode, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(actualQtyText, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    const Spacer(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color color, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        SizedBox(width: 8),
        Text(text, style: TextStyle(color: const Color(0xFF64748B))),
      ]),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'brouillon':
      case 'draft':
      case 'finalisée':
      case 'validated':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.success;
    }
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
}
