import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/customer_orders/customer_orders_bloc.dart';
import '../../blocs/delivery_notes/delivery_notes_bloc.dart';

import '../../models/invoice.dart';
import '../../models/customer_order.dart';
import '../../models/delivery_note.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../database/database_helper.dart';
import '../../screens/document_preview_screen.dart';
import 'forms/mobile_customer_order_form_screen.dart';
import 'forms/mobile_invoice_form_screen.dart';
import 'forms/mobile_delivery_note_form_screen.dart';

class MobileCustomerOrderDetailScreen extends StatefulWidget {
  final CustomerOrder order;

  const MobileCustomerOrderDetailScreen({super.key, required this.order});

  @override
  State<MobileCustomerOrderDetailScreen> createState() => _MobileCustomerOrderDetailScreenState();
}

class _MobileCustomerOrderDetailScreenState extends State<MobileCustomerOrderDetailScreen> {
  late CustomerOrder currentCustomerOrder;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    currentCustomerOrder = widget.order;
    _loadFullOrder();
  }

  Future<void> _loadFullOrder() async {
    final fullOrder = await DatabaseHelper.instance.getCustomerOrder(currentCustomerOrder.id);
    if (fullOrder != null && mounted) {
      setState(() {
        currentCustomerOrder = fullOrder;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomerOrdersBloc, CustomerOrdersState>(
      listener: (context, state) {
        if (state is CustomerOrdersLoaded) {
          try {
            final updatedOrder = state.orders.firstWhere((q) => q.id == currentCustomerOrder.id);
            if (updatedOrder.id == currentCustomerOrder.id && mounted) {
              setState(() {
                currentCustomerOrder = updatedOrder.copyWith(items: currentCustomerOrder.items);
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
          title: Text('Commande ${currentCustomerOrder.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentCustomerOrder),
              itemBuilder: (_) => [
                _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
                const PopupMenuDivider(height: 1),
                if (!currentCustomerOrder.isConvertedToInvoice && !currentCustomerOrder.isConvertedToDelivery) ...[
                  _buildMenuItem('to_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Facture'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('to_delivery', Icons.local_shipping_outlined, AppColors.textSecondary, 'Transformer en Bon de Livraison'),
                  const PopupMenuDivider(height: 1),
                ] else ...[
                  if (currentCustomerOrder.isConvertedToInvoice) ...[
                    _buildMenuItem('view_invoice', Icons.receipt_long_outlined, AppColors.success, 'Voir la facture créée'),
                    const PopupMenuDivider(height: 1),
                  ],
                  if (currentCustomerOrder.isConvertedToDelivery) ...[
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
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                          Text('Réf: ${currentCustomerOrder.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Builder(
                            builder: (context) {
                              final statusEnum = CustomerOrderStatus.values.firstWhere((s) => s.name == currentCustomerOrder.status, orElse: () => CustomerOrderStatus.draft);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusEnum.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusEnum.label,
                                  style: TextStyle(color: statusEnum.color, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Client', currentCustomerOrder.customerName ?? 'Inconnu'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Date', formatDateTimeLong(currentCustomerOrder.date)),
                      if (currentCustomerOrder.deliveryDate != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Date de livraison', formatDateTimeLong(currentCustomerOrder.deliveryDate!)),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (currentCustomerOrder.items.isNotEmpty) ...[
                const Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ...currentCustomerOrder.items.map((item) => Card(
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
                        Text(item.description ?? 'Produit Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                              child: Text('${item.quantity} x ${formatCurrencyDT(item.unitPrice)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                            ),
                            Text(formatCurrencyDT(item.totalHT), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 16),
              ],
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                color: AppColors.surfaceAlt,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoRow('Total HT', formatCurrencyDT(currentCustomerOrder.totalHTAfterDiscount)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Total TVA', formatCurrencyDT(currentCustomerOrder.totalTVA)),
                      if ((currentCustomerOrder.totalTTC - currentCustomerOrder.totalHTAfterDiscount - currentCustomerOrder.totalTVA) > 0.01) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Timbre fiscal', formatCurrencyDT(currentCustomerOrder.totalTTC - currentCustomerOrder.totalHTAfterDiscount - currentCustomerOrder.totalTVA)),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total TTC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formatCurrencyDT(currentCustomerOrder.totalTTC), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (currentCustomerOrder.notes != null && currentCustomerOrder.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(currentCustomerOrder.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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

  void _handleAction(BuildContext context, String action, CustomerOrder order) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<CustomerOrdersBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: MobileCustomerOrderFormScreen(existing: order),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer ce commande ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<CustomerOrdersBloc>().add(DeleteCustomerOrder(order.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'status':
        _showChangeStatusDialog(context, order);
        break;
      case 'to_invoice':
        _showConversionDialog(context, order);
        break;
      case 'view_invoice':
        _openConvertedInvoice(context, order.convertedToInvoiceId);
        break;
      case 'to_delivery':
        _showDeliveryConversionDialog(context, order);
        break;
      case 'view_delivery':
        _openConvertedDelivery(context, order.convertedToDeliveryId);
        break;
      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action sur mobile en cours de développement')));
        break;
      case 'duplicate':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplication en cours de développement')));
        break;
      case 'print':
        final doc = DocumentWrapper.fromCustomerOrder(order);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromCustomerOrder(order);
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

  void _showChangeStatusDialog(BuildContext context, CustomerOrder order) {
    CustomerOrderStatus selectedStatus = CustomerOrderStatus.values.firstWhere((s) => s.name == order.status, orElse: () => CustomerOrderStatus.draft);
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
                  DropdownButtonFormField<CustomerOrderStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    isExpanded: true,
                    items: CustomerOrderStatus.values.map((s) => DropdownMenuItem(
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
                  final updatedOrder = order.copyWith(
                    status: selectedStatus.name,
                    notes: notesController.text.isNotEmpty ? '${order.notes ?? ''}\n${notesController.text}' : order.notes,
                  );
                  context.read<CustomerOrdersBloc>().add(UpdateCustomerOrder(updatedOrder));
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

  void _showConversionDialog(BuildContext context, CustomerOrder order) {
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
            const Text('Voulez-vous transformer cette commande en facture ?'),
            const SizedBox(height: 16),
            Text('Commande: ${order.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${order.customerName ?? '—'}'),
            Text('Montant: ${formatCurrencyDT(order.totalTTC)}', style: const TextStyle(fontWeight: FontWeight.w600)),
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
              _convertOrderToInvoice(context, order);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertOrderToInvoice(BuildContext context, CustomerOrder order) async {
    final invoiceId = const Uuid().v4();
    final invoiceNumber = generateDocNumber(DocPrefix.invoice, DateTime.now().millisecondsSinceEpoch % 1000000);
    
    final invoiceItems = order.items.map((qi) => InvoiceItem(
      id: const Uuid().v4(),
      invoiceId: invoiceId,
      productId: qi.productId,
      description: qi.description,
      quantity: qi.quantity,
      unitPrice: qi.unitPrice,
      tvaRate: qi.tvaRate,
      discountPercent: qi.discountPercent,
      totalHT: qi.totalHT,
    )).toList();

    final invoice = Invoice(
      id: invoiceId,
      number: invoiceNumber,
      customerId: order.customerId,
      customerName: order.customerName,
      orderId: order.id,
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid,
      totalHT: order.totalHTAfterDiscount,
      totalTva: order.totalTVA,
      totalTTC: order.totalTTC,
      notes: order.notes,
      items: invoiceItems,
      createdAt: DateTime.now(),
    );

    try {
      final invoicesBloc = context.read<InvoicesBloc>();
      invoicesBloc.add(AddInvoice(invoice));
    } catch (e) {
      await DatabaseHelper.instance.insertInvoice(invoice);
    }

    final updatedOrder = order.copyWith(
      isConvertedToInvoice: true,
      convertedToInvoiceId: invoiceId,
      status: CustomerOrderStatus.validatedAndInvoiced.name,
    );
    if (!mounted) return;
    context.read<CustomerOrdersBloc>().add(UpdateCustomerOrder(updatedOrder));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Commande convertie en facture avec succès'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _openConvertedInvoice(BuildContext context, String? invoiceId) async {
    if (invoiceId == null) return;
    
    final invoice = await DatabaseHelper.instance.getInvoice(invoiceId);
    if (!mounted) return;
    if (invoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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

  void _showDeliveryConversionDialog(BuildContext context, CustomerOrder order) {
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
            const Text('Voulez-vous transformer cette commande en bon de livraison ?'),
            const SizedBox(height: 16),
            Text('Commande: ${order.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Client: ${order.customerName ?? '—'}'),
            Text('Montant: ${formatCurrencyDT(order.totalTTC)}', style: const TextStyle(fontWeight: FontWeight.w600)),
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
              _convertOrderToDelivery(context, order);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _convertOrderToDelivery(BuildContext context, CustomerOrder order) async {
    final deliveryId = const Uuid().v4();
    final deliveryNumber = generateDocNumber(DocPrefix.deliveryNote, DateTime.now().millisecondsSinceEpoch % 1000000);
    
    final deliveryItems = order.items.map((qi) => DeliveryNoteItem(
      id: const Uuid().v4(),
      deliveryNoteId: deliveryId,
      productId: qi.productId,
      description: qi.description,
      quantity: qi.quantity,
      unitPrice: qi.unitPrice,
      tvaRate: qi.tvaRate,
      discountPercent: qi.discountPercent,
    )).toList();

    final deliveryNote = DeliveryNote(
      id: deliveryId,
      number: deliveryNumber,
      customerId: order.customerId,
      customerName: order.customerName,
      orderId: order.id,
      date: DateTime.now(),
      status: 'delivered',
      notes: order.notes,
      items: deliveryItems,
      createdAt: DateTime.now(),
    );

    try {
      final deliveryBloc = context.read<DeliveryNotesBloc>();
      deliveryBloc.add(AddDeliveryNote(deliveryNote));
    } catch (e) {
      await DatabaseHelper.instance.insertDeliveryNote(deliveryNote);
    }

    final updatedOrder = order.copyWith(
      isConvertedToDelivery: true,
      convertedToDeliveryId: deliveryId,
      status: CustomerOrderStatus.validated.name,
    );
    if (!mounted) return;
    context.read<CustomerOrdersBloc>().add(UpdateCustomerOrder(updatedOrder));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Commande convertie en bon de livraison avec succès'),
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<DeliveryNotesBloc>()),
            BlocProvider.value(value: context.read<CustomersBloc>()),
            BlocProvider.value(value: context.read<ProductsBloc>()),
          ],
          child: MobileDeliveryNoteFormScreen(existing: delivery),
        ),
      ),
    );
  }
}
