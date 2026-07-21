import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/payments/payments_bloc.dart';
import '../../blocs/credit_notes/credit_notes_bloc.dart';

import '../../models/invoice.dart';
import '../../models/payment_model.dart';
import '../../models/credit_note.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/auth_service.dart';
import '../../database/database_helper.dart';

import '../../screens/document_preview_screen.dart';
import 'forms/mobile_invoice_form_screen.dart';
import 'forms/mobile_credit_note_form_screen.dart';

class MobileInvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const MobileInvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<MobileInvoiceDetailScreen> createState() => _MobileInvoiceDetailScreenState();
}

class _MobileInvoiceDetailScreenState extends State<MobileInvoiceDetailScreen> {
  late Invoice currentInvoice;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    currentInvoice = widget.invoice;
    _loadFullInvoice();
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
    return BlocListener<InvoicesBloc, InvoicesState>(
      listener: (context, state) {
        if (state is InvoicesLoaded) {
          try {
            final updatedInvoice = state.invoices.firstWhere((q) => q.id == currentInvoice.id);
            if (updatedInvoice.id == currentInvoice.id && mounted) {
              setState(() {
                currentInvoice = updatedInvoice.copyWith(items: currentInvoice.items);
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
          title: Text('Facture ${currentInvoice.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentInvoice),
              itemBuilder: (_) => [
                _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'),
                const PopupMenuDivider(height: 1),
                if (currentInvoice.status != InvoiceStatus.paid) ...[
                  _buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'),
                  const PopupMenuDivider(height: 1),
                ],
                if (currentInvoice.creditNoteId != null && currentInvoice.creditNoteId!.isNotEmpty)
                  _buildMenuItem('view_credit_note', Icons.receipt_long_outlined, AppColors.primary, 'Voir l\'avoir')
                else
                  _buildMenuItem('to_credit_note', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en Avoir'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('pdf', Icons.picture_as_pdf_outlined, AppColors.error, 'Télécharger PDF'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('email', Icons.email_outlined, AppColors.primary, 'Envoyer par email'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('whatsapp', Icons.chat_outlined, AppColors.success, 'Envoyer par WhatsApp'),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('status', Icons.swap_horiz_outlined, AppColors.warning, 'Changer le statut'),
//                 const PopupMenuDivider(height: 1),
//                 _buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'),
//                 const PopupMenuDivider(height: 1),
//                 _buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gérer les pièces jointes'),
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
                          Text('Réf: ${currentInvoice.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Builder(
                            builder: (context) {
                              final statusEnum = currentInvoice.status;
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
                      _buildInfoRow('Client', currentInvoice.customerName ?? 'Inconnu'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Date', formatDateTimeLong(currentInvoice.date)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Date d\'échéance', formatDateTimeLong(currentInvoice.dueDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (currentInvoice.items.isNotEmpty) ...[
                const Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ...currentInvoice.items.map((item) => Card(
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
                        Text(item.productName ?? item.description ?? 'Produit Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        if (item.description != null && item.description!.isNotEmpty && item.productName != null) ...[
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
                      _buildInfoRow('Total HT', formatCurrencyDT(currentInvoice.totalHT)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Total TVA', formatCurrencyDT(currentInvoice.totalTva)),
                      if ((currentInvoice.totalTTC - currentInvoice.totalHT - currentInvoice.totalTva) > 0.01) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow('Timbre fiscal', formatCurrencyDT(currentInvoice.totalTTC - currentInvoice.totalHT - currentInvoice.totalTva)),
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

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color iconColor, String text) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, Invoice invoice) {
    switch (action) {
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
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer ce facture ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<InvoicesBloc>().add(DeleteInvoice(invoice.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
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
      case 'whatsapp':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fonctionnalité en cours de développement')));
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
                  final updatedInvoice = invoice.copyWith(
                    status: selectedStatus,
                    notes: notesController.text.isNotEmpty ? '${invoice.notes ?? ''}\n${notesController.text}' : invoice.notes,
                  );
                  context.read<InvoicesBloc>().add(UpdateInvoice(updatedInvoice));
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

  void _showAddPaymentDialog(BuildContext context, Invoice inv) {
    final amountCtrl = TextEditingController(text: (inv.totalTTC + inv.timbreFiscal - inv.amountPaid).toStringAsFixed(3));
    final methodNotifier = ValueNotifier<String>('especes');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajouter un paiement pour la facture ${inv.number}'),
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
                  direction: 'encaissement',
                  contactId: inv.customerId,
                  contactType: 'customer',
                  contactName: inv.customerName,
                  amount: amount,
                  method: methodNotifier.value,
                  reference: inv.number,
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
                
                // On mobile we don't automatically update the invoice total paid here for simplicity,
                // but doing it is better:
                final updatedInvoice = inv.copyWith(
                  amountPaid: inv.amountPaid + amount,
                  status: (inv.amountPaid + amount) >= (inv.totalTTC + inv.timbreFiscal) ? InvoiceStatus.paid : InvoiceStatus.partial,
                );
                context.read<InvoicesBloc>().add(UpdateInvoice(updatedInvoice));
                
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

  void _createCreditNoteFromInvoice(BuildContext context, Invoice inv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            const Text('Voulez-vous transformer cette facture en avoir ?'),
            const SizedBox(height: 16),
            Text('Facture: ${inv.number}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Client: ${inv.customerName ?? 'Inconnu'}'),
            Text('Montant: ${formatCurrencyDT(inv.totalTTC + inv.timbreFiscal)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              final now = DateTime.now();
              final String cnId = const Uuid().v4();

              final String cnNumber = 'AV-${now.year}-${now.millisecondsSinceEpoch % 1000000}'.padRight(6, '0');
              
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

              try {
                context.read<CreditNotesBloc>().add(AddCreditNote(creditNote));
              } catch (e) {
                await DatabaseHelper.instance.insertCreditNote(creditNote);
              }
              
              final updatedInvoice = inv.copyWith(creditNoteId: cnId);
              if (!mounted) return;
              context.read<InvoicesBloc>().add(UpdateInvoice(updatedInvoice));
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Avoir $cnNumber créé avec succès'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
