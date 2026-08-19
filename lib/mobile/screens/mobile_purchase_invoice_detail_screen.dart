import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:uuid/uuid.dart';

import '../../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/projects/projects_bloc.dart';
import '../../blocs/payments/payments_bloc.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import '../../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../../blocs/stock/stock_bloc.dart';

import '../../models/purchase_invoice.dart';
import '../../models/product.dart';
import '../../models/document_wrapper.dart';
import '../../models/payment_model.dart';
import '../../models/supplier_credit_note.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../database/database_helper.dart';

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import '../../widgets/purchase_invoice_payment_dialog.dart';
import '../utils/mobile_status_colors.dart';
import 'forms/mobile_purchase_invoice_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';
import 'forms/mobile_supplier_credit_note_form_screen.dart';

class MobilePurchaseInvoiceDetailScreen extends StatefulWidget {
  final PurchaseInvoice invoice;

  const MobilePurchaseInvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<MobilePurchaseInvoiceDetailScreen> createState() => _MobilePurchaseInvoiceDetailScreenState();
}

class _MobilePurchaseInvoiceDetailScreenState extends State<MobilePurchaseInvoiceDetailScreen> {
  late PurchaseInvoice currentInvoice;
  Map<String, Product> _dbProducts = {};

  @override
  void initState() {
    super.initState();
    currentInvoice = widget.invoice;
    _loadFullInvoice();
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

  Future<void> _loadFullInvoice() async {
    final fullInvoice = await DatabaseHelper.instance.getPurchaseInvoice(currentInvoice.id);
    if (fullInvoice != null && mounted) {
      setState(() {
        currentInvoice = fullInvoice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = translateStatus(currentInvoice.status.toString().split('.').last);
    final statusColor = _getStatusColor(currentInvoice.status);

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Fournisseur',
            value: currentInvoice.supplierName ?? 'Non spécifié',
            icon: Icons.business_outlined,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de facturation',
            value: formatDateTimeLong(currentInvoice.date),
            icon: Icons.calendar_today_outlined,
          ),
          PremiumInfoField(
            label: 'Date d\'échéance',
            value: formatDateTimeLong(currentInvoice.dueDate),
            icon: Icons.event_available_outlined,
          ),
          if (currentInvoice.projectName != null && currentInvoice.projectName!.isNotEmpty)
            PremiumInfoField(
              label: 'Projet',
              value: currentInvoice.projectName!,
              icon: Icons.folder_outlined,
            ),
        ],
      ),
    ];

    final articles = currentInvoice.items.map((item) {
      final product = _getProduct(item.productId);
      final productName = product?.name ?? item.productName ?? 'Produit Inconnu';
      final refCode = product?.reference ?? product?.code;
      final subtitle = (refCode != null && refCode.isNotEmpty)
          ? refCode
          : ((item.description != null && item.description!.isNotEmpty && item.description != productName)
              ? item.description
              : null);

      return PremiumArticleItem(
        reference: subtitle,
        designation: productName,
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate > 0 ? item.tvaRate : null,
        discountPercent: item.discountPercent > 0 ? item.discountPercent : null,
        totalHT: item.computedTotalHT,
      );
    }).toList();

    final stampTax = (currentInvoice.totalTTC - currentInvoice.totalHT - currentInvoice.totalTva);
    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: 'Total HT',
        amount: currentInvoice.totalHT,
      ),
      PremiumTotalRow(
        label: 'Total TVA',
        amount: currentInvoice.totalTva,
      ),
      if (stampTax > 0.01)
        PremiumTotalRow(
          label: 'Droit de Timbre',
          amount: stampTax,
        ),
      PremiumTotalRow(
        label: 'Total TTC',
        amount: currentInvoice.totalTTC,
        isGrandTotal: true,
      ),
    ];

    return BlocListener<PurchaseInvoicesBloc, PurchaseInvoicesState>(
      listener: (context, state) {
        if (state is PurchaseInvoicesLoaded) {
          try {
            final updatedInvoice = state.purchaseInvoices.firstWhere((q) => q.id == currentInvoice.id);
            if (updatedInvoice.id == currentInvoice.id && mounted) {
              setState(() {
                currentInvoice = updatedInvoice.copyWith(items: currentInvoice.items);
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
          title: Text('Facture ${currentInvoice.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentInvoice),
              itemBuilder: (_) => _buildActionMenu(context, currentInvoice),
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: 'Facture d\'Achat',
          referenceNumber: currentInvoice.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentInvoice.notes,
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

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.unpaid: return AppColors.warning;
      case InvoiceStatus.paid: return AppColors.success;
      case InvoiceStatus.overdue: return AppColors.error;
      case InvoiceStatus.cancelled: return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
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

  List<PopupMenuEntry<String>> _buildActionMenu(BuildContext context, PurchaseInvoice inv) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(_buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'));
    if (PermissionService.instance.canUpdate(UserPermissionResources.purchasesPurchaseInvoices)) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'));
    }
    if (PermissionService.instance.canDelete(UserPermissionResources.purchasesPurchaseInvoices)) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'));
    }
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'));
    items.add(const PopupMenuDivider(height: 1));
    
    if (inv.status != InvoiceStatus.paid) {
      items.add(_buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'));
      items.add(const PopupMenuDivider(height: 1));
    }
    if (inv.creditNoteId != null && inv.creditNoteId!.isNotEmpty) {
      items.add(_buildMenuItem('view_credit_note', Icons.receipt_long_outlined, AppColors.primary, 'Voir l\'avoir'));
    } else {
      items.add(_buildMenuItem('to_credit_note', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Avoir'));
    }
    items.add(const PopupMenuDivider(height: 1));
    
    items.add(_buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Télécharger PDF'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'));
//     items.add(const PopupMenuDivider(height: 1));
//     items.add(_buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'));
//     items.add(const PopupMenuDivider(height: 1));
//     items.add(_buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gérer les pièces jointes'));

    return items;
  }

  void _handleAction(BuildContext context, String action, PurchaseInvoice inv) {
    switch (action) {
      case 'view':
        final viewDoc = DocumentWrapper.fromPurchaseInvoice(inv);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<PurchaseInvoicesBloc>()),
                BlocProvider.value(value: context.read<SuppliersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
                BlocProvider.value(value: context.read<ProjectsBloc>()),
              ],
              child: MobilePurchaseInvoiceFormScreen(existing: inv),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer cette facture ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<PurchaseInvoicesBloc>().add(DeletePurchaseInvoice(inv.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromPurchaseInvoice(inv);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'print':
        final doc = DocumentWrapper.fromPurchaseInvoice(inv);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'add_payment':
        _showAddPaymentDialog(context, inv);
        break;
      case 'to_credit_note':
        _createCreditNoteFromInvoice(context, inv);
        break;
      case 'view_credit_note':
        _openConvertedCreditNote(context, inv.creditNoteId, inv);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromPurchaseInvoice(inv);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromPurchaseInvoice(inv);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      case 'duplicate':
      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action sur mobile en cours de développement')));
        break;
      case 'status':
        _showChangeStatusDialog(context, inv);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, PurchaseInvoice inv) {
    InvoiceStatus selectedStatus = inv.status;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Changer le statut'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nouveau statut:'),
                  SizedBox(height: 8),
                  DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    value: selectedStatus,
                    decoration: InputDecoration(border: OutlineInputBorder()),
                    isExpanded: true,
                    items: InvoiceStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(translateStatus(s.toString().split('.').last), style: TextStyle(fontWeight: FontWeight.bold)),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedStatus = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  final updatedInvoice = inv.copyWith(status: selectedStatus);
                  context.read<PurchaseInvoicesBloc>().add(UpdatePurchaseInvoice(updatedInvoice));
                  Navigator.pop(dialogCtx);
                },
                child: Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, PurchaseInvoice invoice) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<PaymentsBloc>()),
          BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
          BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
          BlocProvider.value(value: context.read<PurchaseInvoicesBloc>()),
        ],
        child: PurchaseInvoicePaymentDialog(purchaseInvoice: invoice),
      ),
    ).then((created) {
      if (created == true && context.mounted) {
        context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Paiement ajouté avec succès', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.success,
        ));
      }
    });
  }

  void _createCreditNoteFromInvoice(BuildContext context, PurchaseInvoice invoice) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirmation'),
        content: Text('Voulez-vous transformer cette facture en avoir fournisseur ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final now = DateTime.now();
              final String cnId = const Uuid().v4();
              final seq = await DatabaseHelper.instance.getNextSupplierCreditNoteSequence();
              final String cnNumber = generateDocNumber(DocPrefix.supplierCreditNote, seq);
              
              final creditNote = SupplierCreditNote(
                id: cnId,
                number: cnNumber,
                supplierId: invoice.supplierId,
                date: now,
                status: 'draft',
                items: invoice.items.map((i) => SupplierCreditNoteItem(
                  id: const Uuid().v4(),
                  supplierCreditNoteId: cnId,
                  productId: i.productId,
                  quantity: i.quantity,
                  unitPrice: i.unitPrice,
                  tvaRate: i.tvaRate,
                  totalHT: i.totalHT,
                )).toList(),
                createdAt: now,
                updatedAt: now,
              );

              context.read<SupplierCreditNotesBloc>().add(AddSupplierCreditNote(creditNote));
              
              final updatedInvoice = invoice.copyWith(creditNoteId: creditNote.id);
              context.read<PurchaseInvoicesBloc>().add(UpdatePurchaseInvoice(updatedInvoice));
              try {
                context.read<StockBloc>().add(LoadStock());
              } catch (_) {}
              try {
                context.read<ProductsBloc>().add(const ResetProductsPagination());
              } catch (_) {}
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Avoir fournisseur $cnNumber créé et stock réajusté avec succès'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _openConvertedCreditNote(BuildContext context, String? creditNoteId, PurchaseInvoice originalInvoice) async {
    if (creditNoteId == null) return;
    final cn = await DatabaseHelper.instance.getSupplierCreditNoteById(creditNoteId);
    if (!mounted) return;
    if (cn != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<SupplierCreditNotesBloc>()),
              BlocProvider.value(value: context.read<SuppliersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
            ],
            child: MobileSupplierCreditNoteFormScreen(existing: cn),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Avoir introuvable'), backgroundColor: AppColors.error));
    }
  }
}
