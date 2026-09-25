import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../database/database_helper.dart';
import '../models/document_wrapper.dart';
import '../models/product.dart';
import '../models/user_management_model.dart';
import '../services/permission_service.dart';
import '../services/pdf_service.dart';
import '../services/document_share_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/premium_detail_shell.dart';
import 'document_preview_screen.dart';

/// Universal enterprise document detail screen for Desktop and Mobile.
class DocumentDetailScreen extends StatefulWidget {
  final DocumentWrapper document;
  final String? status;
  final Color? statusColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final List<PremiumDetailAction>? additionalActions;
  final List<PremiumInfoField>? extraInfoFields;

  const DocumentDetailScreen({
    super.key,
    required this.document,
    this.status,
    this.statusColor,
    this.onEdit,
    this.onDelete,
    this.additionalActions,
    this.extraInfoFields,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Map<String, Product> _dbProducts = {};

  @override
  void initState() {
    super.initState();
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

  Product? _getProduct(String? id, String name) {
    if (id != null && id.isNotEmpty && _dbProducts.containsKey(id)) {
      return _dbProducts[id];
    }
    final trimmedName = name.trim().toLowerCase();
    if (trimmedName.isNotEmpty && trimmedName != 'produit inconnu') {
      for (final p in _dbProducts.values) {
        if (p.name.trim().toLowerCase() == trimmedName ||
            (p.reference != null && p.reference!.trim().toLowerCase() == trimmedName) ||
            p.code.trim().toLowerCase() == trimmedName) {
          return p;
        }
      }
    }
    try {
      final state = context.read<ProductsBloc>().state;
      if (state is ProductsLoaded) {
        if (id != null && id.isNotEmpty) {
          final match = state.products.cast<Product?>().firstWhere(
            (p) => p?.id == id,
            orElse: () => null,
          );
          if (match != null) return match;
        }
        if (trimmedName.isNotEmpty && trimmedName != 'produit inconnu') {
          return state.products.cast<Product?>().firstWhere(
            (p) => p != null && (
              p.name.trim().toLowerCase() == trimmedName ||
              (p.reference != null && p.reference!.trim().toLowerCase() == trimmedName) ||
              p.code.trim().toLowerCase() == trimmedName
            ),
            orElse: () => null,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  String? _getResourceKey(String title) {
    final t = title.toUpperCase().trim();
    if (t.contains('DEVIS')) return UserPermissionResources.salesQuotes;
    if (t.contains('COMMANDE FOURNISSEUR')) return UserPermissionResources.purchasesSupplierOrders;
    if (t.contains('COMMANDE')) return UserPermissionResources.salesOrders;
    if (t.contains('LIVRAISON')) return UserPermissionResources.salesDeliveryNotes;
    if (t.contains('ACHAT') || t.contains('FOURNISSEUR')) {
      if (t.contains('AVOIR')) return UserPermissionResources.purchasesSupplierCreditNotes;
      if (t.contains('RETOUR')) return UserPermissionResources.purchasesSupplierReturns;
      if (t.contains('RECEPTION')) return UserPermissionResources.purchasesReceivingVouchers;
      if (t.contains('FACTURE')) return UserPermissionResources.purchasesPurchaseInvoices;
    }
    if (t.contains('AVOIR')) return UserPermissionResources.salesCreditNotes;
    if (t.contains('RETOUR')) return UserPermissionResources.salesReturnVouchers;
    if (t.contains('SORTIE')) return UserPermissionResources.salesExitVouchers;
    if (t.contains('RETENUE')) return UserPermissionResources.withholdingTax;
    if (t.contains('FACTURE')) return UserPermissionResources.salesInvoices;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final docStatus = widget.status ?? 'Validé';
    final resKey = _getResourceKey(document.documentTitle);
    final canUpdate = resKey != null ? PermissionService.instance.canUpdate(resKey) : PermissionService.instance.isAdmin;
    final canDelete = resKey != null ? PermissionService.instance.canDelete(resKey) : PermissionService.instance.isAdmin;
    final hasAnyAccess = resKey != null ? PermissionService.instance.hasAnyPermission(resKey) : PermissionService.instance.isAdmin;
    final isInventorySheet = document.documentType == 'inventory_sheet' ||
        document.documentTitle.toUpperCase().contains('INVENTAIRE');
    final isStockTransfer = document.documentType == 'stock_transfer' ||
        document.documentTitle.toUpperCase().contains('TRANSFERT');
    final isStockWithdrawal = document.documentType == 'stock_withdrawal' ||
        document.documentTitle.toUpperCase().contains('PRÉLÈVEMENT') ||
        document.documentTitle.toUpperCase().contains('PRELEVEMENT');
    final isStockEntry = document.documentType == 'stock_entry' ||
        document.documentTitle.toUpperCase().contains('ENTRÉE') ||
        document.documentTitle.toUpperCase().contains('ENTREE');

    final String warehouseName = document.customData['warehouseName']?.toString() ??
        (document.notes != null && document.notes!.isNotEmpty && document.notes!.length < 50
            ? document.notes!
            : 'Entrepôt par défaut');

    // Build Information Sections
    final infoFields = <PremiumInfoField>[
      if (isInventorySheet) ...[
        PremiumInfoField(
          label: 'Magasin',
          value: warehouseName,
          icon: Icons.warehouse_outlined,
          isHighlight: true,
        ),
        PremiumInfoField(
          label: 'Date de création',
          value: formatDateTimeLong(document.date),
          icon: Icons.calendar_today_outlined,
        ),
        if (document.customData['inventoryDate'] != null)
          PremiumInfoField(
            label: "Date d'inventaire",
            value: formatDateTimeLong(document.customData['inventoryDate'] as DateTime),
            icon: Icons.event_note_outlined,
          ),
        if (document.customData['countedBy'] != null && document.customData['countedBy'].toString().isNotEmpty)
          PremiumInfoField(
            label: 'Compté par',
            value: document.customData['countedBy'].toString(),
            icon: Icons.badge_outlined,
          ),
      ] else if (isStockTransfer) ...[
        PremiumInfoField(
          label: 'Entrepôt Source',
          value: document.customData['sourceWarehouseName']?.toString() ?? 'Entrepôt Source',
          icon: Icons.warehouse_outlined,
          isHighlight: true,
        ),
        PremiumInfoField(
          label: 'Entrepôt Destination',
          value: document.customData['destinationWarehouseName']?.toString() ?? 'Entrepôt Destination',
          icon: Icons.input_outlined,
          isHighlight: true,
        ),
        PremiumInfoField(
          label: 'Date de transfert',
          value: formatDateTimeLong(document.date),
          icon: Icons.calendar_today_outlined,
        ),
        if (document.customData['reason'] != null && document.customData['reason'].toString().isNotEmpty)
          PremiumInfoField(
            label: 'Motif',
            value: document.customData['reason'].toString(),
            icon: Icons.assignment_outlined,
          ),
      ] else if (isStockWithdrawal) ...[
        PremiumInfoField(
          label: 'Entrepôt',
          value: warehouseName,
          icon: Icons.warehouse_outlined,
          isHighlight: true,
        ),
        PremiumInfoField(
          label: 'Date de prélèvement',
          value: formatDateTimeLong(document.date),
          icon: Icons.calendar_today_outlined,
        ),
        if (document.customData['reason'] != null && document.customData['reason'].toString().isNotEmpty)
          PremiumInfoField(
            label: 'Motif',
            value: document.customData['reason'].toString(),
            icon: Icons.assignment_outlined,
          ),
        if (document.customData['createdBy'] != null && document.customData['createdBy'].toString().isNotEmpty)
          PremiumInfoField(
            label: 'Demandeur',
            value: document.customData['createdBy'].toString(),
            icon: Icons.person_outline,
          ),
      ] else if (isStockEntry) ...[
        PremiumInfoField(
          label: 'Entrepôt',
          value: warehouseName,
          icon: Icons.warehouse_outlined,
          isHighlight: true,
        ),
        PremiumInfoField(
          label: 'Date d\'entrée',
          value: formatDateTimeLong(document.date),
          icon: Icons.calendar_today_outlined,
        ),
        if (document.customData['reason'] != null && document.customData['reason'].toString().isNotEmpty)
          PremiumInfoField(
            label: 'Motif',
            value: document.customData['reason'].toString(),
            icon: Icons.assignment_outlined,
          ),
        if (document.customData['createdBy'] != null && document.customData['createdBy'].toString().isNotEmpty)
          PremiumInfoField(
            label: 'Enregistré par',
            value: document.customData['createdBy'].toString(),
            icon: Icons.person_outline,
          ),
      ] else ...[
        if (document.customerName != null && document.customerName!.isNotEmpty)
          PremiumInfoField(
            label: document.documentTitle.contains('FOURNISSEUR') ||
                    document.documentTitle.contains('ACHAT') ||
                    document.documentTitle.contains('RECEPTION')
                ? 'Fournisseur'
                : 'Client',
            value: document.customerName!,
            icon: Icons.person_outline,
            isHighlight: true,
          ),
        PremiumInfoField(
          label: 'Date d\'émission',
          value: formatDateTimeLong(document.date),
          icon: Icons.calendar_today_outlined,
        ),
        if (document.dueDate != null)
          PremiumInfoField(
            label: document.documentTitle.contains('DEVIS')
                ? 'Date de validité'
                : 'Date d\'échéance',
            value: formatDateTimeLong(document.dueDate!),
            icon: Icons.event_available_outlined,
          ),
        if (document.customData['projectName'] != null &&
            document.customData['projectName'].toString().isNotEmpty)
          PremiumInfoField(
            label: 'Projet',
            value: document.customData['projectName'].toString(),
            icon: Icons.folder_outlined,
          ),
      ],
      if (widget.extraInfoFields != null) ...widget.extraInfoFields!,
    ];

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: infoFields,
      ),
    ];

    // Build Articles with full product reference resolution
    final articles = document.items.map((item) {
      final product = _getProduct(item.productId, item.productName);
      final refCode = (product?.reference != null && product!.reference!.trim().isNotEmpty)
          ? product.reference!.trim()
          : (product?.code.trim().isNotEmpty == true
              ? product!.code.trim()
              : (item.reference ??
                  (item.customFields['code'] as String?) ??
                  (item.customFields['reference'] as String?) ??
                  (item.customFields['ref'] as String?)));
      final designation = (product?.name != null && product!.name.trim().isNotEmpty)
          ? product.name
          : item.productName;
      final unit = product?.unit ?? item.unit ?? (item.customFields['unit'] as String?);

      return PremiumArticleItem(
        reference: refCode,
        designation: designation,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate > 0 ? item.tvaRate : null,
        discountPercent: item.discountPercent > 0 ? item.discountPercent : null,
        totalHT: item.totalHT,
        unit: unit,
      );
    }).toList();

    // Build Totaux
    final totals = <PremiumTotalRow>[
      if (isInventorySheet) ...[
        PremiumTotalRow(
          label: 'Nombre d\'articles',
          formattedValue: '${document.items.length}',
        ),
        PremiumTotalRow(
          label: 'Total unités comptées',
          formattedValue: '${document.items.fold(0.0, (sum, i) => sum + i.quantity).toInt()}',
          isGrandTotal: true,
        ),
      ] else if (isStockTransfer) ...[
        PremiumTotalRow(
          label: 'Nombre d\'articles',
          formattedValue: '${document.items.length}',
        ),
        PremiumTotalRow(
          label: 'Total unités transférées',
          formattedValue: '${document.items.fold(0.0, (sum, i) => sum + i.quantity).toInt()}',
          isGrandTotal: true,
        ),
      ] else if (isStockWithdrawal) ...[
        PremiumTotalRow(
          label: 'Nombre d\'articles',
          formattedValue: '${document.items.length}',
        ),
        PremiumTotalRow(
          label: 'Total unités prélevées',
          formattedValue: '${document.items.fold(0.0, (sum, i) => sum + i.quantity).toInt()}',
          isGrandTotal: true,
        ),
      ] else if (isStockEntry) ...[
        PremiumTotalRow(
          label: 'Nombre d\'articles',
          formattedValue: '${document.items.length}',
        ),
        PremiumTotalRow(
          label: 'Total unités entrées',
          formattedValue: '${document.items.fold(0.0, (sum, i) => sum + i.quantity).toInt()}',
          isGrandTotal: true,
        ),
      ] else ...[
        if (document.totalHT > 0)
          PremiumTotalRow(
            label: 'Total HT',
            amount: document.totalHT,
          ),
        if (document.totalTva > 0)
          PremiumTotalRow(
            label: 'Total TVA',
            amount: document.totalTva,
          ),
        if (document.stampTax > 0)
          PremiumTotalRow(
            label: 'Droit de Timbre',
            amount: document.stampTax,
          ),
        PremiumTotalRow(
          label: 'Total TTC',
          amount: document.totalTTC,
          isGrandTotal: true,
        ),
      ],
    ];

    final String? displayNotes = (isInventorySheet &&
            document.notes != null &&
            document.notes!.trim().toLowerCase() == warehouseName.toLowerCase())
        ? null
        : ((isStockWithdrawal || isStockEntry) &&
                document.notes != null &&
                document.customData['reason'] != null &&
                document.notes!.trim().toLowerCase() == document.customData['reason'].toString().trim().toLowerCase())
            ? null
            : document.notes;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: '${document.documentTitle} ${document.number}',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              switch (val) {
                case 'preview':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentPreviewScreen(document: document),
                    ),
                  );
                  break;
                case 'pdf':
                  PdfService.instance.downloadDocument(context, document);
                  break;
                case 'email':
                  DocumentShareService.shareDocument(document, isEmail: true);
                  break;
                case 'whatsapp':
                  DocumentShareService.shareDocument(document, isEmail: false);
                  break;
                case 'edit':
                  if (widget.onEdit != null) widget.onEdit!();
                  break;
                case 'delete':
                  if (widget.onDelete != null) widget.onDelete!();
                  break;
                default:
                  if (widget.additionalActions != null) {
                    for (var a in widget.additionalActions!) {
                      if (a.label == val) {
                        a.onPressed();
                        break;
                      }
                    }
                  }
              }
            },
            itemBuilder: (_) {
              final entries = <PopupMenuEntry<String>>[];
              void addEntry(String val, IconData icon, Color col, String label) {
                if (entries.isNotEmpty) entries.add(const PopupMenuDivider(height: 1));
                entries.add(
                  PopupMenuItem(
                    value: val,
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: col),
                        const SizedBox(width: 12),
                        Text(label),
                      ],
                    ),
                  ),
                );
              }

              if (hasAnyAccess) {
                addEntry('preview', Icons.print_outlined, AppColors.primary, 'Aperçu & Imprimer');
                addEntry('pdf', Icons.download_rounded, AppColors.error, 'Télécharger PDF');
                addEntry('email', Icons.email_outlined, const Color(0xFF64748B), 'Envoyer par email');
                addEntry('whatsapp', Icons.chat_outlined, const Color(0xFF64748B), 'Envoyer par WhatsApp');
              }
              if (widget.onEdit != null && canUpdate) {
                addEntry('edit', Icons.edit_outlined, AppColors.primary, 'Modifier');
              }
              if (widget.onDelete != null && canDelete) {
                addEntry('delete', Icons.delete_outline, AppColors.error, 'Supprimer');
              }
              if (widget.additionalActions != null) {
                for (var a in widget.additionalActions!) {
                  addEntry(a.label, a.icon, a.customColor ?? (a.isDanger ? AppColors.error : AppColors.primary), a.label);
                }
              }
              return entries;
            },
          ),
        ],
      ),
      body: PremiumDetailShell(
        documentType: document.documentTitle,
        referenceNumber: document.number,
        statusLabel: docStatus,
        statusColor: widget.statusColor,
        infoSections: infoSections,
        articles: articles,
        totals: totals,
        notes: displayNotes,
        termsAndConditions: (isStockWithdrawal || isStockEntry) ? null : document.conditionsGenerales,
        hidePricing: isInventorySheet || isStockTransfer || isStockWithdrawal || isStockEntry,
      ),
    );
  }
}
