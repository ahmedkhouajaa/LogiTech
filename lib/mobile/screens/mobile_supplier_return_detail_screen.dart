import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/supplier_returns/supplier_returns_bloc.dart';
import '../../blocs/supplier_returns/supplier_returns_event.dart';
import '../../blocs/supplier_returns/supplier_returns_state.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../blocs/products/products_bloc.dart';

import '../../models/supplier_return.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../services/document_share_service.dart';
import '../../database/database_helper.dart';

import '../../widgets/premium_detail_shell.dart';
import '../../screens/document_preview_screen.dart';
import '../utils/mobile_status_colors.dart';
import 'forms/mobile_supplier_return_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobileSupplierReturnDetailScreen extends StatefulWidget {
  final SupplierReturn returnNote;

  const MobileSupplierReturnDetailScreen({super.key, required this.returnNote});

  @override
  State<MobileSupplierReturnDetailScreen> createState() => _MobileSupplierReturnDetailScreenState();
}

class _MobileSupplierReturnDetailScreenState extends State<MobileSupplierReturnDetailScreen> {
  late SupplierReturn currentReturn;

  @override
  void initState() {
    super.initState();
    currentReturn = widget.returnNote;
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = translateStatus(currentReturn.status);
    final statusColor = _getStatusColor(currentReturn.status);

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Fournisseur',
            value: currentReturn.supplierName ?? 'Non spécifié',
            icon: Icons.business_outlined,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de retour',
            value: formatDateTimeLong(currentReturn.date),
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    ];

    final articles = currentReturn.items.map((item) {
      return PremiumArticleItem(
        designation: item.designation,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate > 0 ? item.tvaRate : null,
        totalHT: item.totalHT,
      );
    }).toList();

    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: 'Total HT',
        amount: currentReturn.totalHT,
      ),
      PremiumTotalRow(
        label: 'Total TVA',
        amount: currentReturn.totalTVA,
      ),
      PremiumTotalRow(
        label: 'Total TTC',
        amount: currentReturn.totalTTC,
        isGrandTotal: true,
      ),
    ];

    return BlocListener<SupplierReturnsBloc, SupplierReturnsState>(
      listener: (context, state) {
        if (state is SupplierReturnsLoaded) {
          try {
            final updatedReturn = state.returns.firstWhere((q) => q.id == currentReturn.id);
            if (mounted) {
              setState(() {
                currentReturn = updatedReturn;
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
          title: Text('Retour ${currentReturn.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentReturn),
              itemBuilder: (_) => _buildActionMenu(context, currentReturn),
            ),
          ],
        ),
        body: PremiumDetailShell(
          documentType: 'Retour Fournisseur',
          referenceNumber: currentReturn.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentReturn.reason,
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

  List<PopupMenuEntry<String>> _buildActionMenu(BuildContext context, SupplierReturn note) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(_buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'));
    if (PermissionService.instance.canUpdate(UserPermissionResources.purchasesSupplierReturns)) {
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'));
    }
    if (PermissionService.instance.canDelete(UserPermissionResources.purchasesSupplierReturns)) {
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

  void _handleAction(BuildContext context, String action, SupplierReturn note) {
    switch (action) {
      case 'view':
        final viewDoc = DocumentWrapper.fromSupplierReturn(note);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<SupplierReturnsBloc>()),
                BlocProvider.value(value: context.read<SuppliersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: MobileSupplierReturnFormScreen(existing: note),
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
                  context.read<SupplierReturnsBloc>().add(DeleteSupplierReturn(note.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromSupplierReturn(note);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'print':
        final doc = DocumentWrapper.fromSupplierReturn(note);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromSupplierReturn(note);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromSupplierReturn(note);
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

  void _showChangeStatusDialog(BuildContext context, SupplierReturn note) {
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
                  final updatedNote = note.copyWith(status: selectedStatus);
                  context.read<SupplierReturnsBloc>().add(UpdateSupplierReturn(updatedNote));
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
