import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/quotes/quotes_bloc.dart';
import '../blocs/customers/customers_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/invoices/invoices_bloc.dart';
import '../blocs/customer_orders/customer_orders_bloc.dart';
import '../models/quote.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/customer_order.dart';
import '../models/delivery_note.dart';
import '../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';
import 'create_invoice_screen.dart';
import 'create_customer_order_screen.dart';
import 'create_delivery_note_screen.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});
  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  String _search = '';
  @override
  void initState() {
    super.initState();
    context.read<QuotesBloc>().add(LoadQuotes());
    context.read<CustomersBloc>().add(LoadCustomers());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(children: [
            AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
            const Spacer(),
            AppButton(label: 'Nouveau devis', icon: Icons.add_rounded, onPressed: () => _showCreateDialog(context)),
          ]),
        ),
        Expanded(
          child: BlocBuilder<QuotesBloc, QuotesState>(
            builder: (context, state) {
              if (state is QuotesLoading) return const Center(child: CircularProgressIndicator());
              if (state is QuotesError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is QuotesLoaded) {
                final filtered = _search.isEmpty ? state.quotes
                    : state.quotes.where((q) => q.number.toLowerCase().contains(_search) || (q.customerName ?? '').toLowerCase().contains(_search)).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Quote>(
                      columns: const ['N°', 'Client', 'Date', 'Validité', 'Total TTC', 'Statut'],
                      rows: filtered,
                      emptyMessage: 'Aucun devis trouvé',
                      cellBuilder: (q) => [
                        DataCell(Text(q.number, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text(q.customerName ?? '—')),
                        DataCell(Text(formatDate(q.date))),
                        DataCell(Text(formatDate(q.validityDate), style: TextStyle(color: q.isExpired ? AppColors.error : AppColors.textPrimary))),
                        DataCell(Text(formatCurrency(q.totalTTC), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(StatusBadge(label: q.status.label, color: q.status.color)),
                      ],
                      customActionsBuilder: (q) => PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                        tooltip: 'Actions',
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (value) => _handleAction(context, value, q),
                        itemBuilder: (context) => [
                          _buildMenuItem('view', Icons.visibility_outlined, AppColors.info, 'Voir'),
                          const PopupMenuDivider(height: 1),
                          _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                          const PopupMenuDivider(height: 1),
                          _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                          const PopupMenuDivider(height: 1),
                          if (!q.isConverted && !q.isConvertedToOrder && !q.isConvertedToDelivery) ...[
                            _buildMenuItem('to_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Facture'),
                            const PopupMenuDivider(height: 1),
                            _buildMenuItem('to_order', Icons.shopping_cart_outlined, AppColors.textSecondary, 'Transformer en Commande Client'),
                            const PopupMenuDivider(height: 1),
                            _buildMenuItem('to_delivery', Icons.local_shipping_outlined, AppColors.textSecondary, 'Transformer en Bon de Livraison'),
                            const PopupMenuDivider(height: 1),
                          ] else ...[
                            if (q.isConverted && q.convertedTo == 'invoice') ...[
                              _buildMenuItem('view_invoice', Icons.receipt_long_outlined, AppColors.success, 'Voir la facture créée'),
                              const PopupMenuDivider(height: 1),
                            ],
                            if (q.isConvertedToOrder) ...[
                              _buildMenuItem('view_order', Icons.shopping_cart_outlined, AppColors.success, 'Voir la commande client créée'),
                              const PopupMenuDivider(height: 1),
                            ],
                            if (q.isConvertedToDelivery) ...[
                              _buildMenuItem('view_delivery', Icons.local_shipping_outlined, AppColors.success, 'Voir le bon de livraison créé'),
                              const PopupMenuDivider(height: 1),
                            ],
                          ],
                          _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Télécharger PDF'),
                          const PopupMenuDivider(height: 1),
                          _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                          const PopupMenuDivider(height: 1),
                          _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
                          const PopupMenuDivider(height: 1),
                          _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
                          const PopupMenuDivider(height: 1),
                          _buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'),
                          const PopupMenuDivider(height: 1),
                          _buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gérer les pièces jointes'),
                        ],
                      ),
                      onDelete: (q) => context.read<QuotesBloc>().add(DeleteQuote(q.id)),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<QuotesBloc>()),
        BlocProvider.value(value: context.read<CustomersBloc>()),
        BlocProvider.value(value: context.read<ProductsBloc>()),
      ],
      child: const _QuoteDialog(),
    ));
  }

  void _handleAction(BuildContext context, String action, Quote quote) {
    switch (action) {
      case 'view':
        // TODO: View quote details
        break;
      case 'edit':
        // TODO: Edit quote
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modification non implémentée')));
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer cet enregistrement ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<QuotesBloc>().add(DeleteQuote(quote.id));
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
        _showConversionDialog(context, quote);
        break;
      case 'view_invoice':
        _openConvertedInvoice(context, quote.convertedToId);
        break;
      case 'to_order':
        _showOrderConversionDialog(context, quote);
        break;
      case 'view_order':
        _openConvertedOrder(context, quote.convertedToOrderId);
        break;
      case 'to_delivery':
        _showDeliveryConversionDialog(context, quote);
        break;
      case 'view_delivery':
        _openConvertedDelivery(context, quote.convertedToDeliveryId);
        break;
      case 'duplicate':
        // TODO: Duplicate quote
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, Quote quote) {
    DocumentStatus selectedStatus = quote.status;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Changer le statut'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nouveau statut:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<DocumentStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: DocumentStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: StatusBadge(label: s.label, color: s.color),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => selectedStatus = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Notes (optionnel):'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ajouter une note...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Annuler'),
              ),
              AppButton(
                label: 'Enregistrer',
                onPressed: () {
                  final userId = AuthService.instance.currentUserUid ?? 'System';
                  context.read<QuotesBloc>().add(UpdateQuoteStatus(
                    quote.id,
                    quote.status,
                    selectedStatus,
                    userId,
                    notesController.text.isEmpty ? null : notesController.text,
                  ));
                  Navigator.pop(dialogCtx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConversionDialog(BuildContext context, Quote quote) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
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
            const Text('Voulez-vous transformer ce devis en facture ?'),
            const SizedBox(height: 16),
            Text('Devis: ${quote.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${quote.customerName ?? '—'}'),
            Text('Montant: ${formatCurrencyDT(quote.totalTTC)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _convertQuoteToInvoice(context, quote);
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
    
    // Map Quote Items to Invoice Items
    final invoiceItems = quote.items.map((qi) => InvoiceItem(
      id: const Uuid().v4(),
      invoiceId: invoiceId,
      productId: qi.productId,
      productName: qi.productName,
      description: qi.description,
      quantity: qi.quantity,
      unitPrice: qi.unitPrice,
      tvaRate: qi.tvaRate,
      discountPercent: qi.discountPercent,
      totalHT: qi.totalHT,
    )).toList();

    // Create Invoice
    final invoice = Invoice(
      id: invoiceId,
      number: invoiceNumber,
      customerId: quote.customerId,
      customerName: quote.customerName,
      devisId: quote.id,
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid,
      totalHT: quote.totalHT,
      totalTva: quote.totalTva,
      totalTTC: quote.totalTTC,
      notes: quote.notes,
      items: invoiceItems,
      createdAt: DateTime.now(),
    );

    // Add Invoice via BLoC (or insert directly via DatabaseHelper, but BLoC is better)
    // We can't guarantee InvoicesBloc is in this exact context tree if it's not provided globally.
    // Assuming it's provided globally since it's injected via App.
    try {
      final invoicesBloc = context.read<InvoicesBloc>();
      invoicesBloc.add(AddInvoice(invoice));
    } catch (e) {
      // Fallback if bloc isn't available
      await DatabaseHelper.instance.insertInvoice(invoice);
    }

    // Update Quote
    final updatedQuote = quote.copyWith(
      isConverted: true,
      convertedTo: 'invoice',
      convertedToId: invoiceId,
      status: DocumentStatus.accepted,
    );
    context.read<QuotesBloc>().add(UpdateQuote(updatedQuote));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Devis converti en facture avec succès'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _openConvertedInvoice(BuildContext context, String? invoiceId) async {
    if (invoiceId == null) return;
    
    final invoice = await DatabaseHelper.instance.getInvoice(invoiceId);
    if (invoice == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Facture introuvable'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    if (mounted) {
      // In a real app we'd need InvoicesBloc available here to push the screen.
      // If it's global we can just read it, otherwise we'd get it from somewhere.
      // Let's assume global or we skip the bloc if it throws.
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<InvoicesBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
                // BlocProvider.value(value: context.read<ProjectsBloc>()), // might not exist
              ],
              child: CreateInvoiceScreen(existing: invoice),
            ),
          ),
        );
      } catch (e) {
        // Just push if we can't find some blocs
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateInvoiceScreen(existing: invoice),
          ),
        );
      }
    }
  }

  void _showOrderConversionDialog(BuildContext context, Quote quote) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
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
            const Text('Voulez-vous transformer ce devis en commande client ?'),
            const SizedBox(height: 16),
            Text('Devis: ${quote.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${quote.customerName ?? '—'}'),
            Text('Montant: ${formatCurrencyDT(quote.totalTTC)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _convertQuoteToOrder(context, quote);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertQuoteToOrder(BuildContext context, Quote quote) async {
    final orderId = const Uuid().v4();
    final orderNumber = generateDocNumber(DocPrefix.customerOrder, DateTime.now().millisecondsSinceEpoch % 1000000);
    
    // Map Quote Items to CustomerOrder Items
    final orderItems = quote.items.map((qi) => CustomerOrderItem(
      id: const Uuid().v4(),
      orderId: orderId,
      productId: qi.productId,
      description: qi.description,
      quantity: qi.quantity,
      unitPrice: qi.unitPrice,
      tvaRate: qi.tvaRate,
      discountPercent: qi.discountPercent,
    )).toList();

    // Create CustomerOrder
    final order = CustomerOrder(
      id: orderId,
      number: orderNumber,
      customerId: quote.customerId,
      customerName: quote.customerName,
      quoteId: quote.id,
      date: DateTime.now(),
      status: 'created',
      notes: quote.notes,
      items: orderItems,
      createdAt: DateTime.now(),
    );

    try {
      final ordersBloc = context.read<CustomerOrdersBloc>();
      ordersBloc.add(AddCustomerOrder(order));
    } catch (e) {
      await DatabaseHelper.instance.insertCustomerOrder(order);
    }

    // Update Quote
    final updatedQuote = quote.copyWith(
      isConvertedToOrder: true,
      convertedToOrderId: orderId,
      status: DocumentStatus.accepted,
    );
    context.read<QuotesBloc>().add(UpdateQuote(updatedQuote));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Devis converti en commande client avec succès'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _openConvertedOrder(BuildContext context, String? orderId) async {
    if (orderId == null) return;
    
    final order = await DatabaseHelper.instance.getCustomerOrder(orderId);
    if (!mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Commande client introuvable'),
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
              BlocProvider.value(value: context.read<CustomerOrdersBloc>()),
              BlocProvider.value(value: context.read<CustomersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
            ],
            child: CreateCustomerOrderScreen(existing: order),
          ),
        ),
      );
    } catch (e) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateCustomerOrderScreen(existing: order),
        ),
      );
    }
  }

  void _showDeliveryConversionDialog(BuildContext context, Quote quote) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
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
            const Text('Voulez-vous transformer ce devis en bon de livraison ?'),
            const SizedBox(height: 16),
            Text('Devis: ${quote.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${quote.customerName ?? '—'}'),
            Text('Montant: ${formatCurrencyDT(quote.totalTTC)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _convertQuoteToDelivery(context, quote);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertQuoteToDelivery(BuildContext context, Quote quote) async {
    final deliveryId = const Uuid().v4();
    final deliveryNumber = generateDocNumber(DocPrefix.deliveryNote, DateTime.now().millisecondsSinceEpoch % 1000000);
    
    // Map Quote Items to DeliveryNote Items
    final deliveryItems = quote.items.map((qi) => DeliveryNoteItem(
      id: const Uuid().v4(),
      deliveryNoteId: deliveryId,
      productId: qi.productId,
      description: qi.description,
      quantity: qi.quantity,
      unitPrice: qi.unitPrice,
      tvaRate: qi.tvaRate,
      discountPercent: qi.discountPercent,
    )).toList();

    // Create DeliveryNote
    final deliveryNote = DeliveryNote(
      id: deliveryId,
      number: deliveryNumber,
      customerId: quote.customerId,
      customerName: quote.customerName,
      devisId: quote.id,
      date: DateTime.now(),
      status: 'delivered',
      notes: quote.notes,
      items: deliveryItems,
      createdAt: DateTime.now(),
    );

    try {
      final deliveryBloc = context.read<DeliveryNotesBloc>();
      deliveryBloc.add(AddDeliveryNote(deliveryNote));
    } catch (e) {
      await DatabaseHelper.instance.insertDeliveryNote(deliveryNote);
    }

    // Update Quote
    final updatedQuote = quote.copyWith(
      isConvertedToDelivery: true,
      convertedToDeliveryId: deliveryId,
      status: DocumentStatus.accepted,
    );
    if (!mounted) return;
    context.read<QuotesBloc>().add(UpdateQuote(updatedQuote));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Devis converti en bon de livraison avec succès'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _openConvertedDelivery(BuildContext context, String? deliveryId) async {
    if (deliveryId == null) return;
    
    final delivery = await DatabaseHelper.instance.getDeliveryNote(deliveryId);
    if (!mounted) return;
    
    if (delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bon de livraison introuvable'),
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
              BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
              BlocProvider.value(value: context.read<CustomersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
            ],
            child: CreateDeliveryNoteScreen(existing: delivery),
          ),
        ),
      );
    } catch (e) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateDeliveryNoteScreen(existing: delivery),
        ),
      );
    }
  }
}


class _QuoteDialog extends StatefulWidget {
  const _QuoteDialog();
  @override
  State<_QuoteDialog> createState() => _QuoteDialogState();
}class _QuoteDialogState extends State<_QuoteDialog> {
  final Uuid _uuid = const Uuid();
  Customer? _selectedCustomer;
  String? _selectedProject;
  final List<String> _projects = [];
  DateTime _date = DateTime.now();
  DateTime _validityDate = DateTime.now().add(const Duration(days: 30));
  String _priceType = 'Hors taxes';
  final List<QuoteItem> _items = [];

  @override
  void initState() {
    super.initState();
    // TODO: Load projects if needed
  }

  void _showAddArticleDialog() async {
    final ctx = context;
    final product = await showDialog<Product>(
      context: ctx,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('Ajouter un article'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogCtx,
              Product(id: '1', code: 'PRD-A', name: 'Produit A', sellingPrice: 10.0, tvaRate: 19),
            ),
            child: const Text('Produit A'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              dialogCtx,
              Product(id: '2', code: 'PRD-B', name: 'Produit B', sellingPrice: 20.0, tvaRate: 19),
            ),
            child: const Text('Produit B'),
          ),
        ],
      ),
    );
    if (product != null) {
      setState(() {
        _items.add(QuoteItem(
          id: _uuid.v4(),
          quoteId: '',
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: product.sellingPrice,
          tvaRate: product.tvaRate,
          totalHT: product.sellingPrice,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau devis'),
      content: SizedBox(
        width: 1200,
        child: SingleChildScrollView(
          child: BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              final customers = state is CustomersLoaded ? state.customers : <Customer>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: client and project
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdown<String>(
                          label: 'Client *',
                          value: _selectedCustomer?.id,
                          hint: 'Rechercher des clients...',
                          items: customers
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCustomer = customers.firstWhere((c) => c.id == v)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppDropdown<String>(
                          label: 'Projet',
                          value: _selectedProject,
                          hint: 'Projet par défaut',
                          items: _projects.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (v) => setState(() => _selectedProject = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Dates row
                  Row(
                    children: [
                      Expanded(
                        child: Text('Date d\'émission: ${formatDate(_date)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setState(() => _date = d);
                        },
                        child: const Text('Changer'),
                      ),
                      const Spacer(),
                      Expanded(
                        child: Text('Date d\'échéance: ${formatDate(_validityDate)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _validityDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) setState(() => _validityDate = d);
                        },
                        child: const Text('Changer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Price type radio group
                  Row(
                    children: [
                      const Text('Les prix des articles sont en:'),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 160,
                        child: RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hors taxes'),
                          value: 'Hors taxes',
                          groupValue: _priceType,
                          onChanged: (v) => setState(() => _priceType = v!),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Taxe incluse'),
                          value: 'Taxe incluse',
                          groupValue: _priceType,
                          onChanged: (v) => setState(() => _priceType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Articles table
                  const Text('Articles', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Produit')),
                        DataColumn(label: Text('Qté')),
                        DataColumn(label: Text('Prix U')),
                        DataColumn(label: Text('TVA %')),
                        DataColumn(label: Text('Total HT')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: _items.asMap().entries.map((e) {
                        final item = e.value;
                        return DataRow(cells: [
                          DataCell(Text(item.productName ?? '—')),
                          DataCell(Text(item.quantity.toString())),
                          DataCell(Text(item.unitPrice.toStringAsFixed(2))),
                          DataCell(Text(item.tvaRate.toString())),
                          DataCell(Text(item.totalHT.toStringAsFixed(2))),
                          DataCell(IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => setState(() => _items.removeAt(e.key)),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddArticleDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un article'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        AppButton(
          label: 'Créer',
          onPressed: () {
            if (_selectedCustomer == null) return;
            final quote = Quote(
              id: _uuid.v4(),
              number: generateDocNumber(DocPrefix.quote, DateTime.now().millisecondsSinceEpoch % 100000),
              customerId: _selectedCustomer!.id,
              customerName: _selectedCustomer!.name,
              date: _date,
              validityDate: _validityDate,
              // Additional fields can be added here: project, priceType, items
            );
            context.read<QuotesBloc>().add(AddQuote(quote));
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
