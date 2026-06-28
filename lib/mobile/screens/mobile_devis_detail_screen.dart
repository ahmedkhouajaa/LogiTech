import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/quotes/quotes_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/customer_orders/customer_orders_bloc.dart';
import '../../blocs/delivery_notes/delivery_notes_bloc.dart';

import '../../models/quote.dart';
import '../../models/invoice.dart';
import '../../models/customer_order.dart';
import '../../models/delivery_note.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/auth_service.dart';
import '../../database/database_helper.dart';

import '../../screens/create_quote_screen.dart';
import '../../screens/create_invoice_screen.dart';
import '../../screens/create_customer_order_screen.dart';
import '../../screens/create_delivery_note_screen.dart';
import '../../screens/document_preview_screen.dart';

class MobileDevisDetailScreen extends StatefulWidget {
  final Quote quote;

  const MobileDevisDetailScreen({super.key, required this.quote});

  @override
  State<MobileDevisDetailScreen> createState() => _MobileDevisDetailScreenState();
}

class _MobileDevisDetailScreenState extends State<MobileDevisDetailScreen> {
  late Quote currentQuote;

  @override
  void initState() {
    super.initState();
    currentQuote = widget.quote;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<QuotesBloc, QuotesState>(
      listener: (context, state) {
        if (state is QuotesLoaded) {
          try {
            final updated = state.quotes.firstWhere((q) => q.id == currentQuote.id);
            setState(() {
              currentQuote = updated;
            });
          } catch (_) {
            // Quote might have been deleted, pop the screen
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Devis ${currentQuote.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentQuote),
              itemBuilder: (_) => [
                _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                const PopupMenuDivider(height: 1),
                if (!currentQuote.isConverted && !currentQuote.isConvertedToOrder && !currentQuote.isConvertedToDelivery) ...[
                  _buildMenuItem('to_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Facture'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('to_order', Icons.shopping_cart_outlined, AppColors.textSecondary, 'Transformer en Commande Client'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('to_delivery', Icons.local_shipping_outlined, AppColors.textSecondary, 'Transformer en Bon de Livraison'),
                  const PopupMenuDivider(height: 1),
                ] else ...[
                  if (currentQuote.isConverted && currentQuote.convertedTo == 'invoice') ...[
                    _buildMenuItem('view_invoice', Icons.receipt_long_outlined, AppColors.success, 'Voir la facture créée'),
                    const PopupMenuDivider(height: 1),
                  ],
                  if (currentQuote.isConvertedToOrder) ...[
                    _buildMenuItem('view_order', Icons.shopping_cart_outlined, AppColors.success, 'Voir la commande client créée'),
                    const PopupMenuDivider(height: 1),
                  ],
                  if (currentQuote.isConvertedToDelivery) ...[
                    _buildMenuItem('view_delivery', Icons.local_shipping_outlined, AppColors.success, 'Voir le bon de livraison créé'),
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
                const PopupMenuDivider(height: 1),
                _buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Réf: ${currentQuote.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentQuote.status.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              currentQuote.status.label,
                              style: TextStyle(color: currentQuote.status.color, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Client', currentQuote.customerName ?? 'Inconnu'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Date', formatDateTimeLong(currentQuote.date)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Date de validité', formatDateTimeLong(currentQuote.validityDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Articles
              if (currentQuote.items.isNotEmpty) ...[
                const Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ...currentQuote.items.map((item) => Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border.withOpacity(0.5))),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName ?? 'Produit Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        if (item.description != null && item.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.description!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                              child: Text('${item.quantity} x ${formatCurrencyDT(item.unitPrice)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                            ),
                            Text(formatCurrencyDT(item.computedTotalHT), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 16),
              ],
              // Totals
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                color: AppColors.surfaceAlt,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoRow('Total HT', formatCurrencyDT(currentQuote.totalHT)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Total TVA', formatCurrencyDT(currentQuote.totalTva)),
                      if ((currentQuote.totalTTC - currentQuote.totalHT - currentQuote.totalTva) > 0.01) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Timbre fiscal', formatCurrencyDT(currentQuote.totalTTC - currentQuote.totalHT - currentQuote.totalTva)),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total TTC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formatCurrencyDT(currentQuote.totalTTC), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (currentQuote.notes != null && currentQuote.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(currentQuote.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                ),
              ],
              const SizedBox(height: 32),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color iconColor, String text) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, Quote quote) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<QuotesBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: CreateQuoteScreen(existing: quote),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer ce devis ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<QuotesBloc>().add(DeleteQuote(quote.id));
                  Navigator.pop(context); // close details screen
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'status':
        _showChangeStatusDialog(context, quote);
        break;
      case 'to_invoice':
        _showConversionDialog(context, quote, 'Facture', _convertQuoteToInvoice);
        break;
      case 'view_invoice':
        _openConvertedInvoice(context, quote.convertedToId);
        break;
      case 'to_order':
        _showConversionDialog(context, quote, 'Commande Client', _convertQuoteToOrder);
        break;
      case 'view_order':
        _openConvertedOrder(context, quote.convertedToOrderId);
        break;
      case 'to_delivery':
        _showConversionDialog(context, quote, 'Bon de Livraison', _convertQuoteToDelivery);
        break;
      case 'view_delivery':
        _openConvertedDelivery(context, quote.convertedToDeliveryId);
        break;
      case 'duplicate':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplication en cours de développement')));
        break;
      case 'print':
        final doc = DocumentWrapper.fromQuote(quote);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromQuote(quote);
        PdfService.instance.generateAndOpenDocument(doc);
        break;
      case 'email':
      case 'whatsapp':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fonctionnalité en cours de développement')));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, Quote quote) {
    DocumentStatus selectedStatus = quote.status;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Changer le statut'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nouveau statut:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<DocumentStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    isExpanded: true,
                    items: DocumentStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label, style: TextStyle(color: s.color, fontWeight: FontWeight.bold)),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedStatus = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Notes (optionnel)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  final userId = AuthService.instance.currentUserUid ?? 'System';
                  context.read<QuotesBloc>().add(UpdateQuoteStatus(
                    quote.id, quote.status, selectedStatus, userId, notesController.text.isEmpty ? null : notesController.text,
                  ));
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConversionDialog(BuildContext context, Quote quote, String targetName, Function(BuildContext, Quote) onConfirm) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: AppColors.warning), SizedBox(width: 8), Text('Confirmation')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous transformer ce devis en $targetName ?'),
            const SizedBox(height: 16),
            Text('Devis: ${quote.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${quote.customerName ?? '—'}'),
            Text('Montant: ${formatCurrencyDT(quote.totalTTC)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onConfirm(context, quote);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertQuoteToInvoice(BuildContext context, Quote quote) async {
    final invoiceId = const Uuid().v4();
    final invoiceNumber = generateDocNumber(DocPrefix.invoice, DateTime.now().millisecondsSinceEpoch % 1000000);
    final invoiceItems = quote.items.map((qi) => InvoiceItem(
      id: const Uuid().v4(), invoiceId: invoiceId, productId: qi.productId, productName: qi.productName,
      description: qi.description, quantity: qi.quantity, unitPrice: qi.unitPrice, tvaRate: qi.tvaRate,
      discountPercent: qi.discountPercent, totalHT: qi.totalHT,
    )).toList();
    final invoice = Invoice(
      id: invoiceId, number: invoiceNumber, customerId: quote.customerId, customerName: quote.customerName,
      devisId: quote.id, date: DateTime.now(), dueDate: DateTime.now().add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid, totalHT: quote.totalHT, totalTva: quote.totalTva, totalTTC: quote.totalTTC,
      notes: quote.notes, items: invoiceItems, createdAt: DateTime.now(),
    );
    try { context.read<InvoicesBloc>().add(AddInvoice(invoice)); } catch (e) { await DatabaseHelper.instance.insertInvoice(invoice); }
    final updatedQuote = quote.copyWith(isConverted: true, convertedTo: 'invoice', convertedToId: invoiceId, status: DocumentStatus.accepted);
    context.read<QuotesBloc>().add(UpdateQuote(updatedQuote));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis converti en facture avec succes'), backgroundColor: AppColors.success));
  }

  Future<void> _convertQuoteToOrder(BuildContext context, Quote quote) async {
    final orderId = const Uuid().v4();
    final orderNumber = generateDocNumber(DocPrefix.customerOrder, DateTime.now().millisecondsSinceEpoch % 1000000);
    final orderItems = quote.items.map((qi) => CustomerOrderItem(
      id: const Uuid().v4(), orderId: orderId, productId: qi.productId, description: qi.description,
      quantity: qi.quantity, unitPrice: qi.unitPrice, tvaRate: qi.tvaRate, discountPercent: qi.discountPercent,
    )).toList();
    final order = CustomerOrder(
      id: orderId, number: orderNumber, customerId: quote.customerId, customerName: quote.customerName,
      quoteId: quote.id, date: DateTime.now(), status: 'created', notes: quote.notes, items: orderItems, createdAt: DateTime.now(),
    );
    try { context.read<CustomerOrdersBloc>().add(AddCustomerOrder(order)); } catch (e) { await DatabaseHelper.instance.insertCustomerOrder(order); }
    final updatedQuote = quote.copyWith(isConvertedToOrder: true, convertedToOrderId: orderId, status: DocumentStatus.accepted);
    context.read<QuotesBloc>().add(UpdateQuote(updatedQuote));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis converti en commande client avec succes'), backgroundColor: AppColors.success));
  }

  Future<void> _convertQuoteToDelivery(BuildContext context, Quote quote) async {
    final deliveryId = const Uuid().v4();
    final deliveryNumber = generateDocNumber(DocPrefix.deliveryNote, DateTime.now().millisecondsSinceEpoch % 1000000);
    final deliveryItems = quote.items.map((qi) => DeliveryNoteItem(
      id: const Uuid().v4(), deliveryNoteId: deliveryId, productId: qi.productId, description: qi.description,
      quantity: qi.quantity, unitPrice: qi.unitPrice, tvaRate: qi.tvaRate, discountPercent: qi.discountPercent,
    )).toList();
    final deliveryNote = DeliveryNote(
      id: deliveryId, number: deliveryNumber, customerId: quote.customerId, customerName: quote.customerName,
      devisId: quote.id, date: DateTime.now(), status: 'delivered', notes: quote.notes, items: deliveryItems, createdAt: DateTime.now(),
    );
    try { context.read<DeliveryNotesBloc>().add(AddDeliveryNote(deliveryNote)); } catch (e) { await DatabaseHelper.instance.insertDeliveryNote(deliveryNote); }
    final updatedQuote = quote.copyWith(isConvertedToDelivery: true, convertedToDeliveryId: deliveryId, status: DocumentStatus.accepted);
    context.read<QuotesBloc>().add(UpdateQuote(updatedQuote));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devis converti en bon de livraison avec succes'), backgroundColor: AppColors.success));
  }

  Future<void> _openConvertedInvoice(BuildContext context, String? invoiceId) async {
    if (invoiceId == null) return;
    final invoice = await DatabaseHelper.instance.getInvoice(invoiceId);
    if (!mounted) return;
    if (invoice == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Facture introuvable'), backgroundColor: AppColors.error)); return; }
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<InvoicesBloc>()),
          BlocProvider.value(value: context.read<CustomersBloc>()),
          BlocProvider.value(value: context.read<ProductsBloc>()),
        ],
        child: CreateInvoiceScreen(existing: invoice),
      )));
    } catch (e) { Navigator.push(context, MaterialPageRoute(builder: (_) => CreateInvoiceScreen(existing: invoice))); }
  }

  Future<void> _openConvertedOrder(BuildContext context, String? orderId) async {
    if (orderId == null) return;
    final order = await DatabaseHelper.instance.getCustomerOrder(orderId);
    if (!mounted) return;
    if (order == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande introuvable'), backgroundColor: AppColors.error)); return; }
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<CustomerOrdersBloc>()),
          BlocProvider.value(value: context.read<CustomersBloc>()),
          BlocProvider.value(value: context.read<ProductsBloc>()),
        ],
        child: CreateCustomerOrderScreen(existing: order),
      )));
    } catch (e) { Navigator.push(context, MaterialPageRoute(builder: (_) => CreateCustomerOrderScreen(existing: order))); }
  }

  Future<void> _openConvertedDelivery(BuildContext context, String? deliveryId) async {
    if (deliveryId == null) return;
    final delivery = await DatabaseHelper.instance.getDeliveryNote(deliveryId);
    if (!mounted) return;
    if (delivery == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bon de livraison introuvable'), backgroundColor: AppColors.error)); return; }
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
          BlocProvider.value(value: context.read<CustomersBloc>()),
          BlocProvider.value(value: context.read<ProductsBloc>()),
        ],
        child: CreateDeliveryNoteScreen(existing: delivery),
      )));
    } catch (e) { Navigator.push(context, MaterialPageRoute(builder: (_) => CreateDeliveryNoteScreen(existing: delivery))); }
  }
}
