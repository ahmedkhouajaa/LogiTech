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

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import '../../models/document_wrapper.dart';
import 'forms/mobile_inventory_sheet_form_screen.dart';
import '../../services/permission_service.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../models/user_management_model.dart';

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
      if (wState is WarehousesLoaded) {
        final match = wState.warehouses.cast<dynamic>().firstWhere(
          (w) => w.id == id, 
          orElse: () => null,
        );
        if (match != null) return match.name;
      }
      return 'Entrepôt';
    }
    final String warehouseName = getWhName(currentSheet.warehouseId);

    double totalSurplus = 0;
    double totalMissing = 0;
    for (var item in currentSheet.items) {
      final diff = item.actualQty - item.theoreticalQty;
      if (diff > 0) totalSurplus += diff;
      if (diff < 0) totalMissing += diff.abs();
    }

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Entrepôt',
            value: warehouseName,
            icon: Icons.warehouse_outlined,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de la fiche',
            value: formatDateTimeLong(currentSheet.date),
            icon: Icons.calendar_today_outlined,
          ),
          if (currentSheet.reason != null && currentSheet.reason!.isNotEmpty)
            PremiumInfoField(
              label: 'Motif',
              value: currentSheet.reason!,
              icon: Icons.assignment_outlined,
            ),
          if (totalSurplus > 0 || totalMissing > 0)
            PremiumInfoField(
              label: 'Écarts détectés',
              value: '${totalSurplus > 0 ? "+$totalSurplus surplus " : ""}${totalMissing > 0 ? "-$totalMissing manquant" : ""}',
              icon: Icons.compare_arrows_outlined,
              isHighlight: true,
            ),
        ],
      ),
    ];

    final articles = currentSheet.items.map((item) {
      final product = _getProduct(item.productId);
      final productName = product?.name ?? item.productName ?? 'Article inconnu';
      final refCode = product?.reference ?? product?.code ?? item.productSku;
      final unit = product?.unit ?? 'pièces';

      final diff = item.actualQty - item.theoreticalQty;
      final diffText = diff > 0 ? ' (+$diff)' : (diff < 0 ? ' ($diff)' : '');

      return PremiumArticleItem(
        reference: refCode ?? '',
        designation: productName,
        description: 'Théorique: ${item.theoreticalQty} $unit | Réel: ${item.actualQty} $unit$diffText',
        unit: unit,
        quantity: item.actualQty,
      );
    }).toList();

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
          title: Text('Fiche ${currentSheet.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentSheet),
              itemBuilder: (_) => [
                _buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'),
                if (currentSheet.status != 'validated' && PermissionService.instance.canUpdate(UserPermissionResources.stockInventorySheets)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                ],
                if (currentSheet.status != 'validated' && PermissionService.instance.canDelete(UserPermissionResources.stockInventorySheets)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                ],
                const PopupMenuDivider(height: 1),
                _buildMenuItem('print', Icons.print_outlined, AppColors.primary, 'Imprimer'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Télécharger PDF'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
              ],
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: 'Fiche d\'Inventaire',
          referenceNumber: currentSheet.number,
          statusLabel: currentSheet.status == 'validated' ? 'Validé' : (currentSheet.status == 'cancelled' ? 'Annulé' : 'Brouillon'),
          statusColor: currentSheet.status == 'validated' ? AppColors.success : (currentSheet.status == 'cancelled' ? AppColors.error : AppColors.warning),
          infoSections: infoSections,
          articles: articles,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color color, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Color(0xFF64748B))),
      ]),
    );
  }

  void _handleAction(BuildContext context, String action, InventorySheet sheet) {
    switch (action) {
      case 'view':
      case 'print':
        final doc = DocumentWrapper.fromInventorySheet(sheet);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromInventorySheet(sheet);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromInventorySheet(sheet);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromInventorySheet(sheet);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<InventorySheetsBloc>()),
              ],
              child: MobileInventorySheetFormScreen(existing: sheet),
            ),
          ),
        ).then((_) {
          if (mounted) {
            context.read<InventorySheetsBloc>().add(LoadFirstInventorySheets());
          }
        });
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer cette fiche d\'inventaire ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<InventorySheetsBloc>().add(InventorySheetDeleted(sheet.id));
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
