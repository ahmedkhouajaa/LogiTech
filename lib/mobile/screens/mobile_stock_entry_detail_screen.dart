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
import '../../models/stock_movement.dart';

import '../../screens/create_stock_entry_screen.dart';
import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

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
    String getWhName(String id) {
      final whState = context.read<WarehousesBloc>().state;
      if (whState is WarehousesLoaded) {
        final match = whState.warehouses.cast<Warehouse?>().firstWhere(
          (w) => w?.id == id, 
          orElse: () => null,
        );
        if (match != null) return match.name;
      }
      return 'Entrepôt par défaut';
    }
    final String warehouseName = getWhName(currentEntry.warehouseId);

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
            label: 'Date d\'entrée',
            value: formatDateTimeLong(currentEntry.date),
            icon: Icons.calendar_today_outlined,
          ),
          if (currentEntry.reason != null && currentEntry.reason!.isNotEmpty)
            PremiumInfoField(
              label: 'Motif',
              value: currentEntry.reason!,
              icon: Icons.description_outlined,
            ),
        ],
      ),
    ];

    final articles = currentEntry.items.map((item) {
      final product = _getProduct(item.productId);
      final productName = product?.name ?? 'Article Inconnu';
      final refCode = product?.reference ?? product?.code;

      return PremiumArticleItem(
        reference: refCode,
        designation: productName,
        description: null,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalHT: item.quantity * item.unitPrice,
      );
    }).toList();

    final totalAmount = currentEntry.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );

    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: 'Total HT',
        amount: totalAmount,
      ),
      PremiumTotalRow(
        label: 'Total TTC',
        amount: totalAmount,
        isGrandTotal: true,
      ),
    ];

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
          title: Text('BE ${currentEntry.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentEntry),
              itemBuilder: (_) => [
                _buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'),
                if (PermissionService.instance.canUpdate(UserPermissionResources.stockEntryVouchers)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                ],
                if (PermissionService.instance.canDelete(UserPermissionResources.stockEntryVouchers)) ...[
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
          documentType: 'Bon d\'Entrée',
          referenceNumber: currentEntry.number,
          statusLabel: 'Validé',
          statusColor: AppColors.success,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentEntry.notes,
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
      case 'pdf':
        final docPdf = _createDocumentWrapper(entry);
        PdfService.instance.downloadDocument(context, docPdf);
        break;
      case 'email':
        final docEmail = _createDocumentWrapper(entry);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = _createDocumentWrapper(entry);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }
}
