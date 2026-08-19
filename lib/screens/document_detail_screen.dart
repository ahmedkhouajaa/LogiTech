import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../database/database_helper.dart';
import '../models/document_wrapper.dart';
import '../models/product.dart';
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

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final docStatus = widget.status ?? 'Validé';

    // Build Information Sections
    final infoFields = <PremiumInfoField>[
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
    ];

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
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.print_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text('Aperçu & Imprimer'),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18, color: AppColors.error),
                    const SizedBox(width: 12),
                    const Text('Télécharger PDF'),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'email',
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, size: 18, color: const Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    const Text('Envoyer par email'),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'whatsapp',
                child: Row(
                  children: [
                    Icon(Icons.chat_outlined, size: 18, color: const Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    const Text('Envoyer par WhatsApp'),
                  ],
                ),
              ),
              if (widget.onEdit != null) ...[
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      const Text('Modifier'),
                    ],
                  ),
                ),
              ],
              if (widget.onDelete != null) ...[
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      const SizedBox(width: 12),
                      const Text('Supprimer'),
                    ],
                  ),
                ),
              ],
              if (widget.additionalActions != null) ...[
                for (var a in widget.additionalActions!) ...[
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: a.label,
                    child: Row(
                      children: [
                        Icon(a.icon, size: 18, color: a.customColor ?? (a.isDanger ? AppColors.error : AppColors.primary)),
                        const SizedBox(width: 12),
                        Text(a.label),
                      ],
                    ),
                  ),
                ],
              ],
            ],
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
        notes: document.notes,
        termsAndConditions: document.conditionsGenerales,
      ),
    );
  }
}
