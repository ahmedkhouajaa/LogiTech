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

import '../../models/purchase_invoice.dart';
import '../../models/document_wrapper.dart';
import '../../models/payment_model.dart';
import '../../models/supplier_credit_note.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../database/database_helper.dart';

import '../../screens/document_preview_screen.dart';
import 'forms/mobile_purchase_invoice_form_screen.dart';
import 'forms/mobile_supplier_credit_note_form_screen.dart';

class MobilePurchaseInvoiceDetailScreen extends StatefulWidget {
  final PurchaseInvoice invoice;

  const MobilePurchaseInvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<MobilePurchaseInvoiceDetailScreen> createState() => _MobilePurchaseInvoiceDetailScreenState();
}

class _MobilePurchaseInvoiceDetailScreenState extends State<MobilePurchaseInvoiceDetailScreen> {
  late PurchaseInvoice currentInvoice;

  @override
  void initState() {
    super.initState();
    currentInvoice = widget.invoice;
    _loadFullInvoice();
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
          title: Text('FA ${currentInvoice.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
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
                          Text('Réf: ${currentInvoice.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentInvoice.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(translateStatus(currentInvoice.status.toString().split('.').last), style: TextStyle(color: _getStatusColor(currentInvoice.status), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Date', formatDateTimeLong(currentInvoice.date)),
                      if (currentInvoice.dueDate != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Échéance', formatDateTimeLong(currentInvoice.dueDate!)),
                      ],
                      const SizedBox(height: 8),
                      _buildInfoRow('Fournisseur', currentInvoice.supplierName ?? 'Non spécifié'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              if (currentInvoice.items.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('Aucun article', style: TextStyle(color: AppColors.textSecondary))),
                  ),
                )
              else
                ...currentInvoice.items.map((item) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName ?? 'Article sans nom', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${item.quantity} x ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  Text(formatCurrencyDT(item.unitPrice), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                ],
                              ),
                              if (item.discountPercent > 0) ...[
                                const SizedBox(height: 4),
                                Text('Remise: ${item.discountPercent}%', style: const TextStyle(color: AppColors.error, fontSize: 12)),
                              ]
                            ],
                          ),
                        ),
                        Text(formatCurrencyDT(item.computedTotalHT * (1 + item.tvaRate / 100)), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                )),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                color: AppColors.surfaceAlt,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoRow('Total HT', formatCurrencyDT(currentInvoice.totalHT)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Total TVA', formatCurrencyDT(currentInvoice.totalTva)),
                      if (currentInvoice.timbreFiscal != null && currentInvoice.timbreFiscal! > 0) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Timbre fiscal', formatCurrencyDT(currentInvoice.timbreFiscal!)),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total TTC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formatCurrencyDT(currentInvoice.totalTTC), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (currentInvoice.notes != null && currentInvoice.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(currentInvoice.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildActionMenu(BuildContext context, PurchaseInvoice inv) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(_buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'));
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
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gérer les pièces jointes'));

    return items;
  }

  void _handleAction(BuildContext context, String action, PurchaseInvoice inv) {
    switch (action) {
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
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer cette facture ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<PurchaseInvoicesBloc>().add(DeletePurchaseInvoice(inv.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromPurchaseInvoice(inv);
        PdfService.instance.generateAndOpenDocument(doc);
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
      case 'whatsapp':
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
            title: const Text('Changer le statut'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nouveau statut:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<InvoiceStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    isExpanded: true,
                    items: InvoiceStatus.values.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(translateStatus(s.toString().split('.').last), style: const TextStyle(fontWeight: FontWeight.bold)),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedStatus = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  final updatedInvoice = inv.copyWith(status: selectedStatus);
                  context.read<PurchaseInvoicesBloc>().add(UpdatePurchaseInvoice(updatedInvoice));
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

  void _showAddPaymentDialog(BuildContext context, PurchaseInvoice invoice) {
    final amountCtrl = TextEditingController(text: invoice.totalTTC.toStringAsFixed(3));
    final methodNotifier = ValueNotifier<String>('especes');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter un paiement pour FA ${invoice.number}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Montant (DT)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: methodNotifier,
              builder: (context, val, child) => DropdownButtonFormField<String>(
                value: val,
                decoration: const InputDecoration(
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
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
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
                  contactId: invoice.supplierId,
                  contactType: 'supplier',
                  contactName: invoice.supplierName,
                  amount: amount,
                  method: methodNotifier.value,
                  reference: invoice.number,
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Paiement ajouté avec succès'),
                    backgroundColor: AppColors.success,
                  ));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Veuillez entrer un montant valide'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _createCreditNoteFromInvoice(BuildContext context, PurchaseInvoice invoice) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous transformer cette facture en avoir fournisseur ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final now = DateTime.now();
              final String cnId = const Uuid().v4();
              final String cnNumber = 'AVF-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0');
              
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

              try {
                context.read<SupplierCreditNotesBloc>().add(AddSupplierCreditNote(creditNote));
              } catch (e) {
                await DatabaseHelper.instance.insertSupplierCreditNote(creditNote);
              }
              
              final updatedInvoice = invoice.copyWith(creditNoteId: cnId);
              if (context.mounted) {
                context.read<PurchaseInvoicesBloc>().add(UpdatePurchaseInvoice(updatedInvoice));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Avoir $cnNumber créé avec succès'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Confirmer'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avoir introuvable'), backgroundColor: AppColors.error));
    }
  }
}
