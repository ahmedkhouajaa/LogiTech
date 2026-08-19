import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../../blocs/payments/payments_bloc.dart';
import '../../blocs/return_notes/return_notes_bloc.dart';
import '../../blocs/return_notes/return_notes_event.dart';
import '../../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../../blocs/treasury_transactions/treasury_transactions_bloc.dart';

import '../../models/invoice.dart';
import '../../models/delivery_note.dart';
import '../../models/product.dart';
import '../../models/payment_model.dart';
import '../../models/return_note.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../services/auth_service.dart';
import '../../database/database_helper.dart';

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import '../../widgets/delivery_note_payment_dialog.dart';
import 'forms/mobile_delivery_note_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';
import 'forms/mobile_invoice_form_screen.dart';
import 'forms/mobile_return_voucher_form_screen.dart';

class MobileDeliveryNoteDetailScreen extends StatefulWidget {
  final DeliveryNote deliveryNote;

  const MobileDeliveryNoteDetailScreen({super.key, required this.deliveryNote});

  @override
  State<MobileDeliveryNoteDetailScreen> createState() => _MobileDeliveryNoteDetailScreenState();
}

class _MobileDeliveryNoteDetailScreenState extends State<MobileDeliveryNoteDetailScreen> {
  late DeliveryNote currentDeliveryNote;
  bool _isPopping = false;
  Map<String, Product> _dbProducts = {};

  @override
  void initState() {
    super.initState();
    currentDeliveryNote = widget.deliveryNote;
    _loadFullDeliveryNote();
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

  Future<void> _loadFullDeliveryNote() async {
    final fullDeliveryNote = await DatabaseHelper.instance.getDeliveryNote(currentDeliveryNote.id);
    if (fullDeliveryNote != null && mounted) {
      setState(() {
        currentDeliveryNote = fullDeliveryNote;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusEnum = DeliveryNoteStatus.values.firstWhere(
      (s) => s.name == currentDeliveryNote.status,
      orElse: () => DeliveryNoteStatus.draft,
    );
    final statusLabel = statusEnum.label;
    final statusColor = statusEnum.color;

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Client',
            value: currentDeliveryNote.customerName ?? 'Inconnu',
            icon: Icons.person_outline,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de livraison',
            value: formatDateTimeLong(currentDeliveryNote.date),
            icon: Icons.calendar_today_outlined,
          ),
          if (currentDeliveryNote.projectName != null && currentDeliveryNote.projectName!.isNotEmpty)
            PremiumInfoField(
              label: 'Projet',
              value: currentDeliveryNote.projectName!,
              icon: Icons.folder_outlined,
            ),
        ],
      ),
    ];

    final articles = currentDeliveryNote.items.map((item) {
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
        totalHT: item.totalHT,
      );
    }).toList();

    final stampTax = currentDeliveryNote.timbreFiscal;
    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: 'Total HT',
        amount: currentDeliveryNote.subTotalHT,
      ),
      PremiumTotalRow(
        label: 'Total TVA',
        amount: currentDeliveryNote.totalTVA,
      ),
      if (stampTax > 0.01)
        PremiumTotalRow(
          label: 'Droit de Timbre',
          amount: stampTax,
        ),
      PremiumTotalRow(
        label: 'Total TTC',
        amount: currentDeliveryNote.totalTTC,
        isGrandTotal: true,
      ),
    ];

    return BlocListener<DeliveryNotesBloc, DeliveryNotesState>(
      listener: (context, state) {
        if (state is DeliveryNotesLoaded) {
          try {
            final updatedNote = state.notes.firstWhere((q) => q.id == currentDeliveryNote.id);
            if (updatedNote.id == currentDeliveryNote.id && mounted) {
              setState(() {
                currentDeliveryNote = updatedNote.copyWith(items: currentDeliveryNote.items);
              });
            }
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
          title: Text('BL ${currentDeliveryNote.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentDeliveryNote),
              itemBuilder: (_) => [
                _buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'),
                if (PermissionService.instance.canUpdate(UserPermissionResources.salesDeliveryNotes)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                ],
                if (PermissionService.instance.canDelete(UserPermissionResources.salesDeliveryNotes)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                ],
                const PopupMenuDivider(height: 1),
                _buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter Paiement'),
                const PopupMenuDivider(height: 1),
                if (!currentDeliveryNote.isConvertedToInvoice && !currentDeliveryNote.isConvertedToReturn) ...[
                  _buildMenuItem('to_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Facture'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('to_return', Icons.assignment_return_outlined, AppColors.textSecondary, 'Créer un Bon de Retour'),
                  const PopupMenuDivider(height: 1),
                ] else ...[
                  if (currentDeliveryNote.isConvertedToInvoice) ...[
                    _buildMenuItem('view_invoice', Icons.receipt_long_outlined, AppColors.success, 'Voir la facture créée'),
                    const PopupMenuDivider(height: 1),
                  ],
                  if (currentDeliveryNote.isConvertedToReturn) ...[
                    _buildMenuItem('view_return', Icons.assignment_return_outlined, AppColors.success, 'Voir le bon de retour créé'),
                    const PopupMenuDivider(height: 1),
                  ],
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
          documentType: 'Bon de Livraison',
          referenceNumber: currentDeliveryNote.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentDeliveryNote.notes,
          termsAndConditions: currentDeliveryNote.conditionsGenerales,
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
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, DeliveryNote deliveryNote) {
    switch (action) {
      case 'view':
        final viewDoc = DocumentWrapper.fromDeliveryNote(deliveryNote);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: MobileDeliveryNoteFormScreen(existing: deliveryNote),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer ce bon de livraison ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<DeliveryNotesBloc>().add(DeleteDeliveryNote(deliveryNote.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'status':
        _showChangeStatusDialog(context, deliveryNote);
        break;
      case 'to_invoice':
        _showInvoiceConversionDialog(context, deliveryNote);
        break;
      case 'view_invoice':
        _openConvertedInvoice(context, deliveryNote.convertedToInvoiceId);
        break;
      case 'add_payment':
        _showAddPaymentDialog(context, deliveryNote);
        break;
      case 'to_return':
        _showReturnConversionDialog(context, deliveryNote);
        break;
      case 'view_return':
        _openConvertedReturn(context, deliveryNote.convertedToReturnId);
        break;
      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action sur mobile en cours de développement')));
        break;
      case 'duplicate':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplication en cours de développement')));
        break;
      case 'print':
        final doc = DocumentWrapper.fromDeliveryNote(deliveryNote);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromDeliveryNote(deliveryNote);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromDeliveryNote(deliveryNote);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromDeliveryNote(deliveryNote);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, DeliveryNote deliveryNote) {
    DeliveryNoteStatus selectedStatus = DeliveryNoteStatus.values.firstWhere((s) => s.name == deliveryNote.status, orElse: () => DeliveryNoteStatus.draft);
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
                    items: DeliveryNoteStatus.values.map((s) => DropdownMenuItem(
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
                  final updatedNote = deliveryNote.copyWith(
                    status: selectedStatus.name,
                    notes: notesController.text.isNotEmpty ? '${deliveryNote.notes ?? ''}\n${notesController.text}' : deliveryNote.notes,
                  );
                  context.read<DeliveryNotesBloc>().add(UpdateDeliveryNote(updatedNote));
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

  void _showAddPaymentDialog(BuildContext context, DeliveryNote note) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<PaymentsBloc>()),
          BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
          BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
          BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
        ],
        child: DeliveryNotePaymentDialog(deliveryNote: note),
      ),
    ).then((created) {
      if (created == true && context.mounted) {
        context.read<DeliveryNotesBloc>().add(LoadDeliveryNotes());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Paiement ajouté avec succès', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.success,
        ));
      }
    });
  }

  void _showInvoiceConversionDialog(BuildContext context, DeliveryNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            Text('Voulez-vous transformer ce bon de livraison en facture ?'),
            SizedBox(height: 16),
            Text('BL: ${note.number}', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${note.customerName ?? note.customerCompany ?? "Inconnu"}'),
            Text('Montant: ${formatCurrencyDT(note.totalTTC)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _convertDeliveryToInvoice(context, note);
            },
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertDeliveryToInvoice(BuildContext context, DeliveryNote note) async {
    final now = DateTime.now();
    final seq = await DatabaseHelper.instance.getNextInvoiceSequence();
    final invoiceNumber = generateDocNumber('FA', seq);

    final invoiceItems = note.items.map((i) => InvoiceItem(
      id: const Uuid().v4(),
      invoiceId: '', // Will be set in DB
      productId: i.productId,
      description: i.description,
      quantity: i.quantity,
      unitPrice: i.unitPrice,
      tvaRate: i.tvaRate,
      discountPercent: i.discountPercent,
      totalHT: i.totalHT,
      showDescription: i.showDescription,
      showDiscount: i.showDiscount,
    )).toList();

    final newInvoice = Invoice(
      id: const Uuid().v4(),
      number: invoiceNumber,
      customerId: note.customerId,
      customerName: note.customerName,
      orderId: note.orderId,
      deliveryNoteId: note.id,
      projectId: note.projectId,
      projectName: note.projectName,
      date: now,
      dueDate: now.add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid,
      totalHT: note.totalHTAfterDiscount,
      totalTva: note.totalTVA,
      totalTTC: note.totalTTC,
      pricingMode: note.pricingMode,
      globalDiscountPercent: note.globalDiscountPercent,
      globalDiscountAmount: note.globalDiscountAmount,
      timbreFiscal: note.timbreFiscal,
      notes: note.notes,
      conditionsGenerales: note.conditionsGenerales,
      items: invoiceItems,
    );

    context.read<InvoicesBloc>().add(AddInvoice(newInvoice));

    final updatedNote = note.copyWith(
      isConvertedToInvoice: true,
      convertedToInvoiceId: newInvoice.id,
      status: DeliveryNoteStatus.invoiced.name,
    );
    context.read<DeliveryNotesBloc>().add(UpdateDeliveryNote(updatedNote));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Facture $invoiceNumber creee avec succes'),
      backgroundColor: AppColors.success,
    ));
  }

  void _showReturnConversionDialog(BuildContext context, DeliveryNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            Text('Voulez-vous transformer ce bon de livraison en bon de retour ?'),
            SizedBox(height: 16),
            Text('BL: ${note.number}', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${note.customerName ?? note.customerCompany ?? "Inconnu"}'),
            Text('Montant: ${formatCurrencyDT(note.totalTTC)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _convertDeliveryToReturn(context, note);
            },
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _convertDeliveryToReturn(BuildContext context, DeliveryNote note) async {
    final now = DateTime.now();
    final year = now.year;
    
    final seq = await DatabaseHelper.instance.getNextReturnNoteSequence();
    final returnNumber = 'RET-$year-${seq.toString().padLeft(5, '0')}';

    final returnItems = note.items.map((i) => ReturnNoteItem(
      id: const Uuid().v4(),
      returnNoteId: '',
      productId: i.productId,
      designation: i.description ?? '',
      quantity: -i.quantity, // Negative for returns
      unitPrice: i.unitPrice,
      tvaRate: i.tvaRate,
      totalHT: -i.totalHT, // Negative for returns
    )).toList();

    final newReturn = ReturnNote(
      id: const Uuid().v4(),
      returnNumber: returnNumber,
      customerId: note.customerId,
      customerName: note.customerName,
      customerCompany: note.customerCompany,
      deliveryNoteId: note.id,
      dateEmission: now,
      status: ReturnNoteStatus.validated.name,
      subtotalHT: -note.subTotalHT,
      totalTTC: -note.totalTTC,
      notes: note.notes,
      conditions: note.conditionsGenerales,
      items: returnItems,
    );

    final finalItems = returnItems.map((i) => i.copyWith(returnNoteId: newReturn.id)).toList();
    final returnWithItems = newReturn.copyWith(items: finalItems);

    if (!context.mounted) return;
    context.read<ReturnNotesBloc>().add(AddReturnNote(returnWithItems));

    final updatedNote = note.copyWith(
      isConvertedToReturn: true,
      convertedToReturnId: returnWithItems.id,
      status: DeliveryNoteStatus.returned.name,
    );
    context.read<DeliveryNotesBloc>().add(UpdateDeliveryNote(updatedNote));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Bon de retour $returnNumber cree avec succes'),
      backgroundColor: AppColors.success,
    ));
  }

  Future<void> _openConvertedReturn(BuildContext context, String? returnId) async {
    if (returnId == null) return;
    
    final returnNote = await DatabaseHelper.instance.getReturnNote(returnId);
    if (!context.mounted) return;
    if (returnNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bon de retour introuvable'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<ReturnNotesBloc>()),
              BlocProvider.value(value: context.read<CustomersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
            ],
            child: MobileReturnVoucherFormScreen(existing: returnNote),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Impossible d\'ouvrir le bon de retour'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _openConvertedInvoice(BuildContext context, String? invoiceId) async {
    if (invoiceId == null) return;
    
    final invoice = await DatabaseHelper.instance.getInvoice(invoiceId);
    if (!context.mounted) return;
    if (invoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Facture introuvable'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

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
  }
}
