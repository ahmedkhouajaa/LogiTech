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
import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import 'forms/mobile_stock_transfer_form_screen.dart';
import '../../services/permission_service.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../models/user_management_model.dart';
import '../../models/document_wrapper.dart';
import '../../utils/offline_action_helper.dart';

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
          orElse: () => null,
        );
        if (match != null) return match.name;
      }
      return 'Entrepôt par défaut';
    }

    final String srcName = getWhName(currentTransfer.sourceWarehouseId);
    final String destName = getWhName(currentTransfer.destinationWarehouseId);
    final statusLabel = translateStatus(currentTransfer.status);
    final statusColor = _getStatusColor(currentTransfer.status);

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Entrepôt Source',
            value: srcName,
            icon: Icons.warehouse_outlined,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Entrepôt Destination',
            value: destName,
            icon: Icons.input_outlined,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de transfert',
            value: formatDateTimeLong(currentTransfer.date),
            icon: Icons.calendar_today_outlined,
          ),
          if (currentTransfer.reason != null && currentTransfer.reason!.isNotEmpty)
            PremiumInfoField(
              label: 'Motif',
              value: currentTransfer.reason!,
              icon: Icons.assignment_outlined,
            ),
        ],
      ),
    ];

    final articles = currentTransfer.items.map((item) {
      final product = _getProduct(item.productId);
      final productName = product?.name ?? item.productName ?? 'Article inconnu';
      final refCode = product?.reference ?? product?.code ?? item.productSku;
      final unit = product?.unit ?? 'pièces';

      return PremiumArticleItem(
        reference: refCode ?? '',
        designation: productName,
        unit: unit,
        quantity: item.quantityToTransfer.toDouble(),
      );
    }).toList();

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
          title: Text('BT ${currentTransfer.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentTransfer),
              itemBuilder: (_) {
                final canRead = PermissionService.instance.canRead(UserPermissionResources.stockTransferVouchers);
                final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.stockTransferVouchers);
                final canDelete = PermissionService.instance.canDelete(UserPermissionResources.stockTransferVouchers);

                final entries = <PopupMenuEntry<String>>[];
                void addItem(String val, IconData icon, Color col, String label) {
                  if (entries.isNotEmpty) entries.add(const PopupMenuDivider(height: 1));
                  entries.add(_buildMenuItem(val, icon, col, label));
                }

                if (canRead) {
                  addItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir');
                }
                if (canUpdate) {
                  addItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier');
                }
                if (canDelete) {
                  addItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer');
                }
                if (canRead) {
                  addItem('print', Icons.print_outlined, AppColors.primary, 'Imprimer');
                  addItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Télécharger PDF');
                  addItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email');
                  addItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp');
                }

                return entries;
              },
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: 'Bon de Transfert',
          referenceNumber: currentTransfer.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          notes: currentTransfer.notes,
        ),
      ),
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
    if (OfflineActionHelper.writeActions.contains(action)) {
      OfflineActionHelper.executeAction(
        context: context,
        action: action,
        onConfirmed: () => _executeWriteAction(context, action, transfer),
      );
      return;
    }

    switch (action) {
      case 'view':
      case 'print':
        final doc = DocumentWrapper.fromStockTransfer(transfer);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromStockTransfer(transfer);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromStockTransfer(transfer);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromStockTransfer(transfer);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _executeWriteAction(BuildContext context, String action, StockTransfer transfer) {
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
        context.read<StockTransfersBloc>().add(DeleteStockTransfer(transfer.id));
        if (mounted) {
          Navigator.pop(context);
        }
        break;
    }
  }
}
