import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_state.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../blocs/products/products_bloc.dart';

import '../../models/supplier_credit_note.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../database/database_helper.dart';

import '../../screens/document_preview_screen.dart';
import 'forms/mobile_supplier_credit_note_form_screen.dart';

class MobileSupplierCreditNoteDetailScreen extends StatefulWidget {
  final SupplierCreditNote note;

  const MobileSupplierCreditNoteDetailScreen({super.key, required this.note});

  @override
  State<MobileSupplierCreditNoteDetailScreen> createState() => _MobileSupplierCreditNoteDetailScreenState();
}

class _MobileSupplierCreditNoteDetailScreenState extends State<MobileSupplierCreditNoteDetailScreen> {
  late SupplierCreditNote currentNote;

  @override
  void initState() {
    super.initState();
    currentNote = widget.note;
    _loadFullNote();
  }

  Future<void> _loadFullNote() async {
    final fullNote = await DatabaseHelper.instance.getSupplierCreditNoteById(currentNote.id);
    if (fullNote != null && mounted) {
      setState(() {
        currentNote = fullNote;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupplierCreditNotesBloc, SupplierCreditNotesState>(
      listener: (context, state) {
        if (state is SupplierCreditNotesLoaded) {
          try {
            final updatedNote = state.creditNotes.firstWhere((q) => q.id == currentNote.id);
            if (updatedNote.id == currentNote.id && mounted) {
              setState(() {
                currentNote = updatedNote.copyWith(items: currentNote.items);
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
          title: Text('Avoir ${currentNote.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentNote),
              itemBuilder: (_) => _buildActionMenu(context, currentNote),
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
                          Text('Réf: ${currentNote.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentNote.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(translateStatus(currentNote.status), style: TextStyle(color: _getStatusColor(currentNote.status), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Date', formatDateTimeLong(currentNote.date)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Fournisseur', currentNote.supplierId ?? 'Non spécifié'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              if (currentNote.items.isEmpty)
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
                ...currentNote.items.map((item) => Card(
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
                              Text('Produit: ${item.productId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${item.quantity} x ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  Text(formatCurrencyDT(item.unitPrice), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(formatCurrencyDT(item.totalHT * (1 + item.tvaRate / 100)), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                      _buildInfoRow('Total HT', formatCurrencyDT(currentNote.totalHT)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Total TVA', formatCurrencyDT(currentNote.totalTVA)),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total TTC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formatCurrencyDT(currentNote.totalTTC), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft': return AppColors.info;
      case 'validated': return AppColors.success;
      case 'refunded': return AppColors.primary;
      case 'cancelled': return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
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

  List<PopupMenuEntry<String>> _buildActionMenu(BuildContext context, SupplierCreditNote note) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(_buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('add_payment', Icons.payment_outlined, AppColors.success, 'Ajouter un paiement'));
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

  void _handleAction(BuildContext context, String action, SupplierCreditNote note) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<SupplierCreditNotesBloc>()),
                BlocProvider.value(value: context.read<SuppliersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: MobileSupplierCreditNoteFormScreen(existing: note),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer cet avoir ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<SupplierCreditNotesBloc>().add(DeleteSupplierCreditNote(note.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromSupplierCreditNote(note);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'print':
        final doc = DocumentWrapper.fromSupplierCreditNote(note);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'add_payment':
      case 'email':
      case 'whatsapp':
      case 'duplicate':
      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action sur mobile en cours de développement')));
        break;
      case 'status':
        _showChangeStatusDialog(context, note);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, SupplierCreditNote note) {
    String selectedStatus = note.status;

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
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    isExpanded: true,
                    items: ['draft', 'validated', 'refunded', 'cancelled'].map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(translateStatus(s), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  final updatedNote = note.copyWith(status: selectedStatus);
                  context.read<SupplierCreditNotesBloc>().add(UpdateSupplierCreditNote(updatedNote));
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
}
