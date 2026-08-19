import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:uuid/uuid.dart';

import '../../blocs/supplier_orders/supplier_orders_bloc.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/projects/projects_bloc.dart';
import '../../blocs/payments/payments_bloc.dart';
import '../../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';

import '../../models/supplier_order.dart';
import '../../models/product.dart';
import '../../models/document_wrapper.dart';
import '../../models/payment_model.dart';
import '../../models/purchase_invoice.dart';
import '../../models/receiving_voucher.dart';
import '../../models/supplier_credit_note.dart';

import 'forms/mobile_purchase_invoice_form_screen.dart';
import 'forms/mobile_receiving_voucher_form_screen.dart';
import 'forms/mobile_supplier_credit_note_form_screen.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';
import '../../database/database_helper.dart';

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import '../../widgets/supplier_order_payment_dialog.dart';
import 'forms/mobile_supplier_order_form_screen.dart';

class MobileSupplierOrderDetailScreen extends StatefulWidget {
  final SupplierOrder order;

  const MobileSupplierOrderDetailScreen({super.key, required this.order});

  @override
  State<MobileSupplierOrderDetailScreen> createState() => _MobileSupplierOrderDetailScreenState();
}

class _MobileSupplierOrderDetailScreenState extends State<MobileSupplierOrderDetailScreen> {
  late SupplierOrder currentOrder;
  Map<String, Product> _dbProducts = {};

  @override
  void initState() {
    super.initState();
    currentOrder = widget.order;
    _loadFullOrder();
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

  Future<void> _loadFullOrder() async {
    final fullOrder = await DatabaseHelper.instance.getSupplierOrderById(currentOrder.id);
    if (fullOrder != null && mounted) {
      setState(() {
        currentOrder = fullOrder;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = translateStatus(currentOrder.status);
    final statusColor = _getStatusColor(currentOrder.status);

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Fournisseur',
            value: currentOrder.supplierName ?? 'Inconnu',
            icon: Icons.business_outlined,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de commande',
            value: formatDateTimeLong(currentOrder.date),
            icon: Icons.calendar_today_outlined,
          ),
          if (currentOrder.expectedDate != null)
            PremiumInfoField(
              label: 'Livraison prévue',
              value: formatDateTimeLong(currentOrder.expectedDate!),
              icon: Icons.local_shipping_outlined,
            ),
          if (currentOrder.projectName != null && currentOrder.projectName!.isNotEmpty)
            PremiumInfoField(
              label: 'Projet',
              value: currentOrder.projectName!,
              icon: Icons.folder_outlined,
            ),
        ],
      ),
    ];

    final articles = currentOrder.items.map((item) {
      final product = _getProduct(item.productId);
      final productName = product?.name ?? ((item.description != null && item.description!.isNotEmpty) ? item.description! : 'Article sans nom');
      final refCode = product?.reference ?? product?.code;

      return PremiumArticleItem(
        reference: refCode,
        designation: productName,
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate > 0 ? item.tvaRate : null,
        discountPercent: item.discountPercent > 0 ? item.discountPercent : null,
        totalHT: item.totalHT,
      );
    }).toList();

    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: 'Total HT',
        amount: currentOrder.subTotalHT,
      ),
      PremiumTotalRow(
        label: 'Total TVA',
        amount: currentOrder.totalTVA,
      ),
      PremiumTotalRow(
        label: 'Total TTC',
        amount: currentOrder.totalTTC,
        isGrandTotal: true,
      ),
    ];

    return BlocListener<SupplierOrdersBloc, SupplierOrdersState>(
      listener: (context, state) {
        if (state is SupplierOrdersLoaded) {
          try {
            final updatedOrder = state.orders.firstWhere((q) => q.id == currentOrder.id);
            if (mounted) {
              setState(() {
                currentOrder = updatedOrder.copyWith(items: currentOrder.items);
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
          title: Text('Commande ${currentOrder.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentOrder),
              itemBuilder: (_) => _buildActionMenu(context, currentOrder),
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: 'Commande Fournisseur',
          referenceNumber: currentOrder.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentOrder.notes,
          termsAndConditions: currentOrder.conditionsGenerales,
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft': return AppColors.info;
      case 'validated': return AppColors.success;
      case 'cancelled': return AppColors.error;
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

  List<PopupMenuEntry<String>> _buildActionMenu(BuildContext context, SupplierOrder order) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(_buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'));
    if (PermissionService.instance.canUpdate(UserPermissionResources.purchasesSupplierOrders)) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'));
    }
    if (PermissionService.instance.canDelete(UserPermissionResources.purchasesSupplierOrders)) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'));
    }
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'));
    items.add(const PopupMenuDivider(height: 1));

    if (!order.isConvertedToInvoice && !order.isConvertedToReceipt) {
      items.add(_buildMenuItem('to_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en facture d\'achat'));
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('to_receipt', Icons.local_shipping_outlined, AppColors.textSecondary, 'Transformer en bon de réception'));
      items.add(const PopupMenuDivider(height: 1));
    }
    if (order.isConvertedToInvoice) {
      items.add(_buildMenuItem('view_invoice', Icons.visibility_outlined, AppColors.textSecondary, 'Voir la facture d\'achat créée'));
      items.add(const PopupMenuDivider(height: 1));
    }
    if (order.isConvertedToReceipt) {
      items.add(_buildMenuItem('view_receipt', Icons.visibility_outlined, AppColors.textSecondary, 'Voir le bon de réception créé'));
      items.add(const PopupMenuDivider(height: 1));
    }
    
    items.add(_buildMenuItem('credit_note', Icons.receipt_outlined, AppColors.textSecondary, 'Transformer en Avoir'));
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

  void _handleAction(BuildContext context, String action, SupplierOrder order) {
    switch (action) {
      case 'view':
        final viewDoc = DocumentWrapper.fromSupplierOrder(order);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<SupplierOrdersBloc>()),
                BlocProvider.value(value: context.read<SuppliersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
                BlocProvider.value(value: context.read<ProjectsBloc>()),
              ],
              child: MobileSupplierOrderFormScreen(existing: order),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer cette commande ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<SupplierOrdersBloc>().add(DeleteSupplierOrder(order.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromSupplierOrder(order);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'print':
        final doc = DocumentWrapper.fromSupplierOrder(order);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'payment':
        _showAddPaymentDialog(context, order);
        break;
      case 'to_invoice':
        _showConversionDialog(context, order, true);
        break;
      case 'to_receipt':
        _showConversionDialog(context, order, false);
        break;
      case 'view_invoice':
        _openConvertedInvoice(context, order.convertedToInvoiceId, order);
        break;
      case 'view_receipt':
        _openConvertedReceipt(context, order.convertedToReceiptId, order);
        break;
      case 'credit_note':
        _createCreditNoteFromOrder(context, order);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromSupplierOrder(order);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromSupplierOrder(order);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      case 'duplicate':
      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action sur mobile en cours de développement')));
        break;
      case 'status':
        _showChangeStatusDialog(context, order);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, SupplierOrder order) {
    String selectedStatus = order.status;

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
                    items: ['draft', 'validated', 'cancelled'].map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(translateStatus(s), style: TextStyle(fontWeight: FontWeight.bold)),
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
                  final updatedOrder = order.copyWith(status: selectedStatus);
                  context.read<SupplierOrdersBloc>().add(UpdateSupplierOrder(updatedOrder));
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

  void _showAddPaymentDialog(BuildContext context, SupplierOrder order) {
    final amountCtrl = TextEditingController(text: order.subTotalTTC.toStringAsFixed(3));
    final methodNotifier = ValueNotifier<String>('especes');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter un paiement pour la commande ${order.number}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(
                labelText: 'Montant (DT)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: methodNotifier,
              builder: (context, val, child) => DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                value: val,
                decoration: InputDecoration(
                  labelText: 'Méthode de paiement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                  DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                  DropdownMenuItem(value: 'virement', child: Text('Virement')),
                  DropdownMenuItem(value: 'carte', child: Text('Carte')),
                ],
                onChanged: (v) {
                  if (v != null) methodNotifier.value = v;
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final amountStr = amountCtrl.text.replaceAll(',', '.');
              final amount = double.tryParse(amountStr) ?? 0.0;
              if (amount > 0) {
                final payment = Payment(
                  id: const Uuid().v4(),
                  paymentNumber: 'PAI-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 1000000}'.padRight(6, '0'),
                  direction: 'decaissement',
                  contactId: order.supplierId,
                  contactType: 'supplier',
                  contactName: order.supplierName,
                  amount: amount,
                  method: methodNotifier.value,
                  reference: order.number,
                  paymentDate: DateTime.now(),
                  status: 'paid',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                
                try {
                  context.read<PaymentsBloc>().add(AddPayment(payment));
                } catch (e) {
                  await DatabaseHelper.instance.insertPayment(payment);
                }
                
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Paiement ajouté avec succès'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Veuillez entrer un montant valide'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showConversionDialog(BuildContext context, SupplierOrder order, bool toInvoice) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(toInvoice ? 'Transformer en facture d\'achat' : 'Transformer en bon de réception'),
        content: Text('Voulez-vous transformer la commande ${order.number} en ${toInvoice ? 'facture d\'achat' : 'bon de réception'} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (toInvoice) {
                _convertToInvoice(context, order);
              } else {
                _convertToReceipt(context, order);
              }
            },
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _convertToInvoice(BuildContext context, SupplierOrder order) {
    final invoiceId = const Uuid().v4();
    final newInvoice = PurchaseInvoice(
      id: invoiceId,
      number: 'FA-${order.number.replaceAll("CMD-", "")}',
      supplierId: order.supplierId,
      supplierName: order.supplierName,
      orderId: order.id,
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      status: InvoiceStatus.unpaid,
      totalHT: order.subTotalHT,
      totalTva: order.totalTVA,
      totalTTC: order.subTotalTTC,
      items: order.items.map((i) => PurchaseInvoiceItem(
        id: const Uuid().v4(),
        purchaseInvoiceId: invoiceId,
        productId: i.productId,
        productName: i.description,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        totalHT: i.totalHT,
      )).toList(),
    );

    try {
      context.read<PurchaseInvoicesBloc>().add(AddPurchaseInvoice(newInvoice));
    } catch (e) {
      DatabaseHelper.instance.insertPurchaseInvoice(newInvoice);
    }

    final updatedOrder = order.copyWith(
      isConvertedToInvoice: true,
      convertedToInvoiceId: invoiceId,
      status: 'validated',
    );
    context.read<SupplierOrdersBloc>().add(UpdateSupplierOrder(updatedOrder));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Commande transformée en facture d'achat"), backgroundColor: AppColors.success),
    );
  }

  Future<void> _convertToReceipt(BuildContext context, SupplierOrder order) async {
    final receiptId = const Uuid().v4();
    final seq = await DatabaseHelper.instance.getNextReceivingVoucherSequence();
    final newReceipt = ReceivingVoucher(
      id: receiptId,
      number: generateDocNumber(DocPrefix.receivingVoucher, seq),
      supplierId: order.supplierId,
      supplierName: order.supplierName,
      orderId: order.id,
      date: DateTime.now(),
      status: 'validated',
      pricingMode: order.pricingMode,
      globalDiscountPercent: order.globalDiscountPercent,
      globalDiscountAmount: order.globalDiscountAmount,
      timbreFiscal: order.timbreFiscal,
      conditionsGenerales: order.conditionsGenerales,
      items: order.items.map((i) => ReceivingVoucherItem(
        id: const Uuid().v4(),
        voucherId: receiptId,
        productId: i.productId,
        productName: i.description,
        quantityExpected: i.quantity,
        quantityReceived: i.quantity,
        unitPrice: i.unitPrice,
        tvaRate: i.tvaRate,
        discountPercent: i.discountPercent,
      )).toList(),
    );

    try {
      context.read<ReceivingVouchersBloc>().add(AddReceivingVoucher(newReceipt));
    } catch (e) {
      DatabaseHelper.instance.insertReceivingVoucher(newReceipt.toMap(), newReceipt.items.map((i) => i.toMap()).toList());
    }

    final updatedOrder = order.copyWith(
      isConvertedToReceipt: true,
      convertedToReceiptId: receiptId,
      status: 'validated',
    );
    context.read<SupplierOrdersBloc>().add(UpdateSupplierOrder(updatedOrder));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Commande transformée en bon de réception"), backgroundColor: AppColors.success),
    );
  }

  void _openConvertedInvoice(BuildContext context, String? invoiceId, SupplierOrder originalOrder) async {
    if (invoiceId == null) return;
    final invoice = await DatabaseHelper.instance.getPurchaseInvoice(invoiceId);
    if (!mounted) return;
    if (invoice != null) {
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
            child: MobilePurchaseInvoiceFormScreen(existing: invoice),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Facture introuvable'), backgroundColor: AppColors.error));
    }
  }

  void _openConvertedReceipt(BuildContext context, String? receiptId, SupplierOrder originalOrder) async {
    if (receiptId == null) return;
    final receiptData = await DatabaseHelper.instance.getReceivingVoucher(receiptId);
    if (!mounted) return;
    if (receiptData != null) {
      final receipt = ReceivingVoucher.fromMap(receiptData);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<ReceivingVouchersBloc>()),
              BlocProvider.value(value: context.read<SuppliersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
            ],
            child: MobileReceivingVoucherFormScreen(existing: receipt),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bon de réception introuvable'), backgroundColor: AppColors.error));
    }
  }

  void _createCreditNoteFromOrder(BuildContext context, SupplierOrder order) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirmation'),
        content: Text('Voulez-vous transformer cette commande en avoir fournisseur ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final now = DateTime.now();
              final String cnId = const Uuid().v4();
              final String cnNumber = 'AVF-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0');
              
              final creditNote = SupplierCreditNote(
                id: cnId,
                number: cnNumber,
                supplierId: order.supplierId,
                date: now,
                status: 'draft',
                items: order.items.map((i) => SupplierCreditNoteItem(
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

              try {
                context.read<SupplierCreditNotesBloc>().add(AddSupplierCreditNote(creditNote));
              } catch (e) {
                await DatabaseHelper.instance.insertSupplierCreditNote(creditNote);
              }
              
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Avoir $cnNumber créé avec succès'), backgroundColor: AppColors.success),
              );
            },
            child: Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}
