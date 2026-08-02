import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../models/product.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/stock_withdrawals/stock_withdrawals_bloc.dart';

import '../../models/stock_withdrawal.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../database/database_helper.dart';

import '../../screens/document_preview_screen.dart';
import 'forms/mobile_exit_voucher_form_screen.dart';

class MobileStockWithdrawalDetailScreen extends StatefulWidget {
  final StockWithdrawal withdrawal;
  final bool isExitVoucher;

  const MobileStockWithdrawalDetailScreen({
    super.key,
    required this.withdrawal,
    this.isExitVoucher = false,
  });

  @override
  State<MobileStockWithdrawalDetailScreen> createState() => _MobileStockWithdrawalDetailScreenState();
}

class _MobileStockWithdrawalDetailScreenState extends State<MobileStockWithdrawalDetailScreen> {
  late StockWithdrawal currentWithdrawal;
  Map<String, Product> _dbProducts = {};
  String? _warehouseName;

  @override
  void initState() {
    super.initState();
    currentWithdrawal = widget.withdrawal;
    _loadFullWithdrawal();
    _loadProducts();
    _loadWarehouseName();
  }

  Future<void> _loadWarehouseName() async {
    try {
      final warehouses = await DatabaseHelper.instance.getWarehouses();
      final match = warehouses.firstWhere(
        (w) => w.id == currentWithdrawal.warehouseId,
        orElse: () => warehouses.firstWhere((w) => w.isDefault, orElse: () => warehouses.first),
      );
      if (mounted) {
        setState(() {
          _warehouseName = match.name;
        });
      }
    } catch (_) {}
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

  Future<void> _loadFullWithdrawal() async {
    final fullWithdrawal = await DatabaseHelper.instance.getStockWithdrawal(currentWithdrawal.id);
    if (fullWithdrawal != null && mounted) {
      setState(() {
        currentWithdrawal = fullWithdrawal;
      });
    }
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

  DocumentWrapper _createDocumentWrapper(StockWithdrawal note) {
    return DocumentWrapper(
      id: note.id,
      number: note.number,
      documentTitle: "BON DE SORTIE",
      date: note.date,
      totalHT: note.totalHTAfterDiscount,
      totalTva: note.totalTVA,
      totalTTC: note.totalTTC,
      notes: note.notes,
      items: note.items.map((item) {
        final product = _getProduct(item.productId);
        return DocumentItemWrapper(
          productName: product?.name ?? 'Article Inconnu',
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: item.tvaRate,
          discountPercent: item.discountPercent,
          totalHT: item.totalHT,
          customFields: {
            'code': (product?.reference != null && product!.reference!.isNotEmpty) 
                ? product.reference 
                : (product?.code ?? ''),
            'unit': product?.unit ?? 'pièce',
            'purchasePrice': product?.purchasePrice ?? 0,
          },
        );
      }).toList(),
      customData: {
        'warehouseId': note.warehouseId,
        'warehouseName': 'Entrepôt par défaut', // or fetch if available
        'createdBy': 'Admin',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StockWithdrawalsBloc, StockWithdrawalsState>(
      listener: (context, state) {
        if (state is StockWithdrawalsLoaded) {
          try {
            final updatedWithdrawal = state.withdrawals.firstWhere((q) => (q as StockWithdrawal).id == currentWithdrawal.id);
            if ((updatedWithdrawal as StockWithdrawal).id == currentWithdrawal.id && mounted) {
              setState(() {
                currentWithdrawal = updatedWithdrawal.copyWith(items: currentWithdrawal.items);
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
          title: Text('BS ${currentWithdrawal.number}', style: TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentWithdrawal),
              itemBuilder: (_) => [
                _buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'),
                PopupMenuDivider(height: 1),
                _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                PopupMenuDivider(height: 1),
                _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                PopupMenuDivider(height: 1),
                _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
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
                          Text('Réf: ${currentWithdrawal.number}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Builder(
                            builder: (context) {
                              final statusEnum = StockWithdrawalStatus.values.firstWhere((s) => s.name == currentWithdrawal.status, orElse: () => StockWithdrawalStatus.draft);
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusEnum.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(statusEnum.label, style: TextStyle(color: statusEnum.color, fontWeight: FontWeight.bold, fontSize: 12)),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildInfoRow('Date', formatDateTimeLong(currentWithdrawal.date)),
                      SizedBox(height: 8),
                      _buildInfoRow('Entrepôt', _warehouseName ?? 'Entrepôt par défaut'),
                      if (currentWithdrawal.projectName != null) ...[
                        SizedBox(height: 8),
                        _buildInfoRow('Projet', currentWithdrawal.projectName!),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              SizedBox(height: 8),
              if (currentWithdrawal.items.isEmpty)
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
                ...currentWithdrawal.items.map((item) {
                  final product = _getProduct(item.productId);
                  final productName = product?.name ?? item.description ?? 'Article non spécifié';
                  final unit = product?.unit ?? 'pièces';
                  final qtyText = widget.isExitVoucher
                      ? '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} x ${formatCurrencyDT(item.unitPrice)}'
                      : '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} $unit';
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                if (widget.isExitVoucher)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                                    child: Text(qtyText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                                  )
                                else
                                  Text(qtyText, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (widget.isExitVoucher)
                            Text(
                              formatCurrencyDT(item.totalHT),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              if (widget.isExitVoucher) ...[
                const SizedBox(height: 16),
                // Totals
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                  color: AppColors.surfaceAlt,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow('Total HT', formatCurrencyDT(currentWithdrawal.subTotalHT)),
                        const SizedBox(height: 8),
                        _buildInfoRow('Total TVA', formatCurrencyDT(currentWithdrawal.totalTVA)),
                        if (currentWithdrawal.timbreFiscal > 0) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('Timbre fiscal', formatCurrencyDT(currentWithdrawal.timbreFiscal)),
                        ],
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total TTC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                            Text(formatCurrencyDT(currentWithdrawal.totalTTC), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (currentWithdrawal.notes != null && currentWithdrawal.notes!.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
                  color: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(currentWithdrawal.notes!, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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

  void _handleAction(BuildContext context, String action, StockWithdrawal withdrawal) {
    switch (action) {
      case 'view':
        final viewDoc = _createDocumentWrapper(withdrawal);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<StockWithdrawalsBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: MobileExitVoucherFormScreen(existing: withdrawal),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer ce bon de sortie ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<StockWithdrawalsBloc>().add(DeleteStockWithdrawal(withdrawal.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'print':
        final doc = _createDocumentWrapper(withdrawal);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }
}
