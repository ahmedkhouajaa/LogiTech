import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/credit_notes/credit_notes_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';

import '../../models/credit_note.dart';
import '../../models/customer.dart';
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
import 'forms/mobile_credit_note_form_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobileCreditNoteDetailScreen extends StatefulWidget {
  final CreditNote creditNote;

  const MobileCreditNoteDetailScreen({super.key, required this.creditNote});

  @override
  State<MobileCreditNoteDetailScreen> createState() => _MobileCreditNoteDetailScreenState();
}

class _MobileCreditNoteDetailScreenState extends State<MobileCreditNoteDetailScreen> {
  late CreditNote currentCreditNote;
  String? _customerName;
  Map<String, Product> _dbProducts = {};

  @override
  void initState() {
    super.initState();
    currentCreditNote = widget.creditNote;
    _loadCustomerName();
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

  Future<void> _loadCustomerName() async {
    if (currentCreditNote.customerId == null || currentCreditNote.customerId!.isEmpty) return;
    try {
      final customers = await DatabaseHelper.instance.getCustomers();
      final customer = customers.firstWhere(
        (c) => c.id == currentCreditNote.customerId,
        orElse: () => Customer(id: '', code: '', name: '', country: ''),
      );
      if (customer.id.isNotEmpty && mounted) {
        setState(() {
          _customerName = (customer.companyName != null && customer.companyName!.isNotEmpty)
              ? customer.companyName
              : customer.name;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = currentCreditNote.status.label;
    final statusColor = _getStatusColor(currentCreditNote.status);

    final infoSections = [
      PremiumInfoSection(
        title: 'Informations Générales',
        icon: Icons.info_outline,
        fields: [
          PremiumInfoField(
            label: 'Client',
            value: _customerName ?? (currentCreditNote.customerName != null && currentCreditNote.customerName!.isNotEmpty ? currentCreditNote.customerName! : 'Non spécifié'),
            icon: Icons.person_outline,
            isHighlight: true,
          ),
          PremiumInfoField(
            label: 'Date de l\'avoir',
            value: formatDateTimeLong(currentCreditNote.date),
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    ];

    final articles = currentCreditNote.items.map((item) {
      final product = _getProduct(item.productId);
      final productName = product?.name ?? item.productName ?? item.description ?? 'Article non spécifié';
      final refCode = product?.reference ?? product?.code;

      return PremiumArticleItem(
        reference: refCode,
        designation: productName,
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        tvaRate: item.tvaRate > 0 ? item.tvaRate : null,
        discountPercent: item.discountPercent > 0 ? item.discountPercent : null,
        totalHT: item.computedTotalHT,
      );
    }).toList();

    final totals = <PremiumTotalRow>[
      PremiumTotalRow(
        label: 'Total HT',
        amount: currentCreditNote.totalHT,
      ),
      PremiumTotalRow(
        label: 'Total TVA',
        amount: currentCreditNote.totalTva,
      ),
      PremiumTotalRow(
        label: 'Total TTC',
        amount: currentCreditNote.totalTTC,
        isGrandTotal: true,
      ),
    ];

    return BlocListener<CreditNotesBloc, CreditNotesState>(
      listener: (context, state) {
        if (state is CreditNotesLoaded) {
          try {
            final updatedNote = state.creditNotes.firstWhere((q) => q.id == currentCreditNote.id);
            if (updatedNote.id == currentCreditNote.id && mounted) {
              setState(() {
                currentCreditNote = updatedNote.copyWith(items: currentCreditNote.items);
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
          title: Text('Avoir ${currentCreditNote.number}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentCreditNote),
              itemBuilder: (_) => [
                _buildMenuItem('view', Icons.visibility_outlined, AppColors.primary, 'Voir'),
                if (PermissionService.instance.canUpdate(UserPermissionResources.salesCreditNotes)) ...[
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                ],
                if (PermissionService.instance.canDelete(UserPermissionResources.salesCreditNotes)) ...[
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
          documentType: 'Avoir Client',
          referenceNumber: currentCreditNote.number,
          statusLabel: statusLabel,
          statusColor: statusColor,
          infoSections: infoSections,
          articles: articles,
          totals: totals,
          notes: currentCreditNote.notes,
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

  Color _getStatusColor(CreditNoteStatus status) {
    switch (status) {
      case CreditNoteStatus.unused: return AppColors.info;
      case CreditNoteStatus.partiallyUsed: return AppColors.warning;
      case CreditNoteStatus.used: return AppColors.success;
      case CreditNoteStatus.cancelled: return AppColors.error;
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

  void _handleAction(BuildContext context, String action, CreditNote creditNote) {
    switch (action) {
      case 'view':
        final viewDoc = DocumentWrapper.fromCreditNote(creditNote);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: viewDoc)));
        break;
      case 'edit':
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
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('Confirmer la suppression'),
            content: Text('Voulez-vous vraiment supprimer cet avoir client ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<CreditNotesBloc>().add(DeleteCreditNote(creditNote.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromCreditNote(creditNote);
        PdfService.instance.downloadDocument(context, doc);
        break;
      case 'email':
        final docEmail = DocumentWrapper.fromCreditNote(creditNote);
        DocumentShareService.shareDocument(docEmail, isEmail: true);
        break;
      case 'whatsapp':
        final docWa = DocumentWrapper.fromCreditNote(creditNote);
        DocumentShareService.shareDocument(docWa, isEmail: false);
        break;
      case 'print':
        final doc = DocumentWrapper.fromCreditNote(creditNote);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }
}
