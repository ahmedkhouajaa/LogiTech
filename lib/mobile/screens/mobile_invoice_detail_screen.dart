import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/payments/payments_bloc.dart';
import '../../blocs/credit_notes/credit_notes_bloc.dart';
import '../../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../../blocs/stock/stock_bloc.dart';

import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../models/payment_model.dart';
import '../../models/credit_note.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../services/auth_service.dart';
import '../../database/database_helper.dart';

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import '../../widgets/invoice_payment_dialog.dart';
import '../utils/mobile_status_colors.dart';
import 'forms/mobile_invoice_form_screen.dart';
import 'forms/mobile_credit_note_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobileInvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const MobileInvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<MobileInvoiceDetailScreen> createState() => _MobileInvoiceDetailScreenState();
}

class _MobileInvoiceDetailScreenState extends State<MobileInvoiceDetailScreen> {
  late Invoice currentInvoice;
  bool _isPopping = false;
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
    final fullInvoice = await DatabaseHelper.instance.getInvoice(currentInvoice.id);
    if (fullInvoice != null && mounted) {
      setState(() {
        currentInvoice = fullInvoice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = translateStatus(currentInvoice.status.name);
    final statusColor = currentInvoice.status.color;

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Client',
            value: currentInvoice.customerName ?? 'Inconnu',
            icon: Icons.person_outline,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date d\'émission',
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

    return BlocListener<InvoicesBloc, InvoicesState>(
      listener: (context, state) {
        if (state is InvoicesLoaded) {
          try {
            final updated = state.invoices.firstWhere((i) => i.id == currentInvoice.id);
            setState(() {
              currentInvoice = updated;
            });
          } catch (_) {
            if (!_isPopping) {
              _isPopping = true;
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
              itemBuilder: (_) => [
                _buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'),
                if (PermissionService.instance.canUpdate(UserPermissionResources.salesInvoices)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                ],
                if (PermissionService.instance.canDelete(UserPermissionResources.salesInvoices)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                ],
                const PopupMenuDivider(height: 1),
                _buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter Paiement'),
                const PopupMenuDivider(height: 1),
                if (currentInvoice.creditNoteId == null || currentInvoice.creditNoteId!.isEmpty) ...[
                  _buildMenuItem('to_credit_note', Icons.receipt_long_outlined, AppColors.textSecondary, 'Créer un Avoir'),
                  const PopupMenuDivider(height: 1),
                ] else ...[
                  _buildMenuItem('view_credit_note', Icons.receipt_long_outlined, AppColors.success, 'Voir l\'Avoir créé'),
                  const PopupMenuDivider(height: 1),
                ],
                _buildMenuItem('print', Icons.print_outlined, AppColors.primary, 'Imprimer'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Télécharger PDF'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
              ],
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: 'Facture',
          referenceNumber: currentInvoice.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentInvoice.notes,
          termsAndConditions: currentInvoice.conditionsGenerales,
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

  void _handleAction(BuildContext context, String action, Invoice invoice) {
    switch (action) {
      case 'view':
        final viewDoc = DocumentWrapper.fromInvoice(invoice);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<InvoicesBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: MobileInvoiceFormScreen(existing: invoice),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer ce facture ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<InvoicesBloc>().add(DeleteInvoice(invoice.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'status':
        _showChangeStatusDialog(context, invoice);
        break;
      case 'add_payment':
        _showAddPaymentDialog(context, invoice);
        break;
      case 'to_credit_note':
        _createCreditNoteFromInvoice(context, invoice);
        break;
      case 'view_credit_note':
        _openConvertedCreditNote(context, invoice.creditNoteId);
        break;
      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action sur mobile en cours de développement')));
        break;
      case 'duplicate':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplication en cours de développement')));
        break;
      case 'print':
        final doc = DocumentWrapper.fromInvoice(invoice);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromInvoice(invoice);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromInvoice(invoice);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromInvoice(invoice);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, Invoice invoice) {
    InvoiceStatus selectedStatus = invoice.status;
    final notesController = TextEditingController();

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
                      child: Text(s.label, style: TextStyle(color: s.color, fontWeight: FontWeight.bold)),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedStatus = v);
                    },
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(border: OutlineInputBorder(), hintText: 'Notes (optionnel)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  final updatedInvoice = invoice.copyWith(
                    status: selectedStatus,
                    notes: notesController.text.isNotEmpty ? '${invoice.notes ?? ''}\n${notesController.text}' : invoice.notes,
                  );
                  context.read<InvoicesBloc>().add(UpdateInvoice(updatedInvoice));
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

  void _showAddPaymentDialog(BuildContext context, Invoice inv) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<PaymentsBloc>()),
          BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
          BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
          BlocProvider.value(value: context.read<InvoicesBloc>()),
        ],
        child: InvoicePaymentDialog(invoice: inv),
      ),
    ).then((created) {
      if (created == true && context.mounted) {
        context.read<InvoicesBloc>().add(LoadInvoices());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Paiement ajouté avec succès', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.success,
        ));
      }
    });
  }

  void _createCreditNoteFromInvoice(BuildContext context, Invoice inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Confirmation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous transformer cette facture en avoir ?'),
            SizedBox(height: 16),
            Text('Facture: ${inv.number}', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Client: ${inv.customerName ?? 'Inconnu'}'),
            Text('Montant: ${formatCurrencyDT(inv.totalTTC + inv.timbreFiscal)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              final now = DateTime.now();
              final String cnId = const Uuid().v4();
              final seq = await DatabaseHelper.instance.getNextCreditNoteSequence();
              final String cnNumber = generateDocNumber(DocPrefix.creditNote, seq);
              
              final creditNoteItems = inv.items.map((i) => CreditNoteItem(
                id: const Uuid().v4(),
                productId: i.productId,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                tvaRate: i.tvaRate,
                totalHT: i.totalHT,
              )).toList();

              final creditNote = CreditNote(
                id: cnId,
                number: cnNumber,
                invoiceId: inv.id,
                customerId: inv.customerId,
                customerName: inv.customerName,
                date: now,
                status: CreditNoteStatus.unused,
                totalHT: inv.totalHT,
                totalTva: inv.totalTva,
                totalTTC: inv.totalTTC,
                items: creditNoteItems,
                createdAt: now,
                updatedAt: now,
              );

              context.read<CreditNotesBloc>().add(AddCreditNote(creditNote));
              
              final updatedInvoice = inv.copyWith(creditNoteId: creditNote.id);
              context.read<InvoicesBloc>().add(UpdateInvoice(updatedInvoice));

              if (!mounted) return;
              try {
                context.read<StockBloc>().add(LoadStock());
              } catch (_) {}
              try {
                context.read<ProductsBloc>().add(const ResetProductsPagination());
              } catch (_) {}
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Avoir $cnNumber créé et stock réajusté avec succès'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openConvertedCreditNote(BuildContext context, String? creditNoteId) async {
    if (creditNoteId == null) return;
    
    final creditNote = await DatabaseHelper.instance.getCreditNote(creditNoteId);
    if (!mounted) return;
    if (creditNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Avoir introuvable'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<CreditNotesBloc>()),
            BlocProvider.value(value: context.read<CustomersBloc>()),
            BlocProvider.value(value: context.read<ProductsBloc>()),
          ],
          child: MobileCreditNoteFormScreen(existing: creditNote),
        ),
      ),
    );
  }
}
