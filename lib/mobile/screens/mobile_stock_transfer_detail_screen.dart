import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/stock_transfers/stock_transfers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../models/stock_transfer.dart';
import '../../models/product.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../database/database_helper.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_state.dart';
import 'forms/mobile_stock_transfer_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobileStockTransferDetailScreen extends StatefulWidget {
  final StockTransfer transfer;

  const MobileStockTransferDetailScreen({super.key, required this.transfer});

  @override
  State<MobileStockTransferDetailScreen> createState() => _MobileStockTransferDetailScreenState();
}

class _MobileStockTransferDetailScreenState extends State<MobileStockTransferDetailScreen> {
  late StockTransfer currentTransfer;
  Map<String, Product> _dbProducts = {};
  @override
  void initState() {
    super.initState();
    currentTransfer = widget.transfer;
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

    final String srcName = getWhName(currentTransfer.sourceWarehouseId);
    final String destName = getWhName(currentTransfer.destinationWarehouseId);

    return BlocListener<StockTransfersBloc, StockTransfersState>(
      listener: (context, state) {
        if (state is StockTransfersLoaded) {
          try {
            final updatedTransfer = state.transfers.firstWhere((q) => q.id == currentTransfer.id);
            if (updatedTransfer.id == currentTransfer.id && mounted) {
              setState(() {
                currentTransfer = updatedTransfer;
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
          title: Text('Bon de transfert ${currentTransfer.number}', style: TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentTransfer),
              itemBuilder: (_) => [
                if (PermissionService.instance.canUpdate(UserPermissionResources.stockTransferVouchers))
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                if (PermissionService.instance.canUpdate(UserPermissionResources.stockTransferVouchers) &&
                    PermissionService.instance.canDelete(UserPermissionResources.stockTransferVouchers))
                  const PopupMenuDivider(height: 1),
                if (PermissionService.instance.canDelete(UserPermissionResources.stockTransferVouchers))
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
                          Text('Réf: ${currentTransfer.number}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentTransfer.status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(translateStatus(currentTransfer.status), style: TextStyle(color: _getStatusColor(currentTransfer.status), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildInfoRow('Date', formatDateTimeLong(currentTransfer.date)),
                      SizedBox(height: 8),
                      _buildInfoRow('Source', srcName),
                      SizedBox(height: 8),
                      _buildInfoRow('Destination', destName),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              if (currentTransfer.items.isEmpty)
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
                ...currentTransfer.items.map((item) {
                  final product = _getProduct(item.productId);
                  final productName = product?.name ?? item.productName ?? 'Article inconnu';
                  final refCode = product?.reference ?? product?.code ?? item.productSku;
                  final unit = product?.unit ?? 'pièces';
                  final qtyText = '${item.quantityToTransfer % 1 == 0 ? item.quantityToTransfer.toInt() : item.quantityToTransfer} $unit';
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
                                Text(qtyText, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (currentTransfer.reason != null && currentTransfer.reason!.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Raison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                  color: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(currentTransfer.reason!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                ),
              ],
              if (currentTransfer.notes != null && currentTransfer.notes!.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                  color: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(currentTransfer.notes!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                ),
              ],
              SizedBox(height: 32),
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
          Icon(icon, size: 18, color: Color(0xFF64748B)),
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'validated':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  void _handleAction(BuildContext context, String action, StockTransfer transfer) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<StockTransfersBloc>()),
              ],
              child: MobileStockTransferFormScreen(existing: transfer),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer ce bon de transfert ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<StockTransfersBloc>().add(DeleteStockTransfer(transfer.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }
}
