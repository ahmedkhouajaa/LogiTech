import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/return_notes/return_notes_bloc.dart';
import '../../blocs/return_notes/return_notes_event.dart';
import '../../blocs/return_notes/return_notes_state.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';

import '../../models/return_note.dart';
import '../../models/product.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../database/database_helper.dart';

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import '../utils/mobile_status_colors.dart';
import 'forms/mobile_return_voucher_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobileReturnNoteDetailScreen extends StatefulWidget {
  final ReturnNote returnNote;

  const MobileReturnNoteDetailScreen({super.key, required this.returnNote});

  @override
  State<MobileReturnNoteDetailScreen> createState() => _MobileReturnNoteDetailScreenState();
}

class _MobileReturnNoteDetailScreenState extends State<MobileReturnNoteDetailScreen> {
  late ReturnNote currentReturnNote;
  Map<String, Product> _dbProducts = {};

  @override
  void initState() {
    super.initState();
    currentReturnNote = widget.returnNote;
    _loadFullReturnNote();
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

  Future<void> _loadFullReturnNote() async {
    final fullReturnNote = await DatabaseHelper.instance.getReturnNote(currentReturnNote.id);
    if (fullReturnNote != null && mounted) {
      setState(() {
        currentReturnNote = fullReturnNote;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = translateStatus(currentReturnNote.status);
    final statusColor = MobileStatusColors.getColorForStatus(statusLabel);

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Client',
            value: currentReturnNote.customerName ?? currentReturnNote.customerCompany ?? 'Non spécifié',
            icon: Icons.person_outline,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de retour',
            value: formatDateTimeLong(currentReturnNote.dateEmission),
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    ];

    final articles = currentReturnNote.items.map((item) {
      final product = item.productId != null ? _getProduct(item.productId!) : null;
      final productName = item.designation.isNotEmpty ? item.designation : (product?.name ?? 'Article non spécifié');
      final refCode = product?.reference ?? product?.code;

      return PremiumArticleItem(
        reference: refCode,
        designation: productName,
        description: item.reason,
        quantity: item.quantity.abs(),
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate > 0 ? item.tvaRate : null,
        totalHT: item.totalHT,
      );
    }).toList();

    final totalTVA = currentReturnNote.totalTTC - currentReturnNote.subtotalHT;
    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: 'Total HT',
        amount: currentReturnNote.subtotalHT,
      ),
      if (totalTVA > 0)
        PremiumTotalRow(
          label: 'Total TVA',
          amount: totalTVA,
        ),
      PremiumTotalRow(
        label: 'Total TTC',
        amount: currentReturnNote.totalTTC,
        isGrandTotal: true,
      ),
    ];

    return BlocListener<ReturnNotesBloc, ReturnNotesState>(
      listener: (context, state) {
        if (state is ReturnNotesLoaded) {
          try {
            final updatedReturnNote = state.notes.firstWhere((q) => q.id == currentReturnNote.id);
            if (mounted) {
              setState(() {
                currentReturnNote = updatedReturnNote.copyWith(items: currentReturnNote.items);
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
          title: Text('Retour ${currentReturnNote.returnNumber}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentReturnNote),
              itemBuilder: (_) => [
                _buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'),
                if (PermissionService.instance.canUpdate(UserPermissionResources.salesReturnVouchers)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                ],
                if (PermissionService.instance.canDelete(UserPermissionResources.salesReturnVouchers)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
                ],
                const PopupMenuDivider(height: 1),
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
          documentType: 'Bon de Retour',
          referenceNumber: currentReturnNote.returnNumber,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentReturnNote.notes,
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

  void _handleAction(BuildContext context, String action, ReturnNote returnNote) {
    switch (action) {
      case 'view':
        final viewDoc = DocumentWrapper.fromReturnNote(returnNote);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'edit':
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
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer ce bon de retour ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<ReturnNotesBloc>().add(DeleteReturnNote(returnNote.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromReturnNote(returnNote);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'print':
        final doc = DocumentWrapper.fromReturnNote(returnNote);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromReturnNote(returnNote);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromReturnNote(returnNote);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      case 'add_payment':
      case 'duplicate':
      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action sur mobile en cours de développement')));
        break;
      case 'status':
        _showChangeStatusDialog(context, returnNote);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, ReturnNote returnNote) {
    String selectedStatus = returnNote.status;

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
                  final updatedNote = returnNote.copyWith(status: selectedStatus);
                  context.read<ReturnNotesBloc>().add(UpdateReturnNote(updatedNote));
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
