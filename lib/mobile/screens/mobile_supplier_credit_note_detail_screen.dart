import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_state.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../blocs/products/products_bloc.dart';

import '../../models/supplier_credit_note.dart';
import '../../models/supplier.dart';
import '../../models/product.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../database/database_helper.dart';

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import 'forms/mobile_supplier_credit_note_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobileSupplierCreditNoteDetailScreen extends StatefulWidget {
  final SupplierCreditNote note;

  const MobileSupplierCreditNoteDetailScreen({super.key, required this.note});

  @override
  State<MobileSupplierCreditNoteDetailScreen> createState() => _MobileSupplierCreditNoteDetailScreenState();
}

class _MobileSupplierCreditNoteDetailScreenState extends State<MobileSupplierCreditNoteDetailScreen> {
  late SupplierCreditNote currentNote;
  String? _supplierName;
  Map<String, Product> _dbProducts = {};

  @override
  void initState() {
    super.initState();
    currentNote = widget.note;
    _loadFullNote();
    _loadSupplierName();
    _loadProducts();
  }

  Future<void> _loadFullNote() async {
    try {
      final notes = await DatabaseHelper.instance.getSupplierCreditNotes();
      final n = notes.firstWhere((x) => x.id == currentNote.id);
      if (mounted) {
        setState(() => currentNote = n);
      }
    } catch (_) {}
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

  Future<void> _loadSupplierName() async {
    if (currentNote.supplierId == null || currentNote.supplierId!.isEmpty) return;
    try {
      final suppliers = await DatabaseHelper.instance.getSuppliers();
      final supplier = suppliers.firstWhere(
        (s) => s.id == currentNote.supplierId,
        orElse: () => Supplier(id: '', code: '', name: '', country: ''),
      );
      if (supplier.id.isNotEmpty && mounted) {
        setState(() {
          _supplierName = (supplier.companyName != null && supplier.companyName!.isNotEmpty)
              ? supplier.companyName
              : supplier.name;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = translateStatus(currentNote.status);
    final statusColor = _getStatusColor(currentNote.status);

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Fournisseur',
            value: _supplierName ?? currentNote.supplierId ?? 'Non spécifié',
            icon: Icons.business_outlined,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de l\'avoir',
            value: formatDateTimeLong(currentNote.date),
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    ];

    final articles = currentNote.items.map((item) {
      final product = _getProduct(item.productId);
      final productName = product?.name ?? 'Article non spécifié';
      final refCode = product?.reference ?? product?.code;

      return PremiumArticleItem(
        reference: refCode,
        designation: productName,
        description: null,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate > 0 ? item.tvaRate : null,
        totalHT: item.totalHT,
      );
    }).toList();

    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: 'Total HT',
        amount: currentNote.totalHT,
      ),
      PremiumTotalRow(
        label: 'Total TVA',
        amount: currentNote.totalTVA,
      ),
      PremiumTotalRow(
        label: 'Total TTC',
        amount: currentNote.totalTTC,
        isGrandTotal: true,
      ),
    ];

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
          title: Text('Avoir ${currentNote.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
        body: PremiumDetailShell(
          documentType: 'Avoir Fournisseur',
          referenceNumber: currentNote.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentNote.reason,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
          Icon(icon, size: 18, color: Color(0xFF64748B)),
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildActionMenu(BuildContext context, SupplierCreditNote note) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(_buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'));
    if (PermissionService.instance.canUpdate(UserPermissionResources.purchasesSupplierCreditNotes)) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'));
    }
    if (PermissionService.instance.canDelete(UserPermissionResources.purchasesSupplierCreditNotes)) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'));
    }
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
//     items.add(const PopupMenuDivider(height: 1));
//     items.add(_buildMenuItem('duplicate', Icons.content_copy_outlined, AppColors.textSecondary, 'Dupliquer'));
//     items.add(const PopupMenuDivider(height: 1));
//     items.add(_buildMenuItem('attachments', Icons.attach_file_outlined, AppColors.textSecondary, 'Gérer les pièces jointes'));

    return items;
  }

  void _handleAction(BuildContext context, String action, SupplierCreditNote note) {
    switch (action) {
      case 'view':
        final viewDoc = DocumentWrapper.fromSupplierCreditNote(note);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
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
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer cet avoir ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<SupplierCreditNotesBloc>().add(DeleteSupplierCreditNote(note.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
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
      case 'email':
        final docEmail = DocumentWrapper.fromSupplierCreditNote(note);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromSupplierCreditNote(note);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      case 'add_payment':
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
                    items: ['draft', 'validated', 'refunded', 'cancelled'].map((s) => DropdownMenuItem(
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
                  final updatedNote = note.copyWith(status: selectedStatus);
                  context.read<SupplierCreditNotesBloc>().add(UpdateSupplierCreditNote(updatedNote));
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
}
