import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../blocs/products/products_bloc.dart';

import '../../models/receiving_voucher.dart';
import '../../models/document_wrapper.dart';

import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../database/database_helper.dart';

import '../../screens/document_preview_screen.dart';
import 'forms/mobile_receiving_voucher_form_screen.dart';

class MobileReceivingVoucherDetailScreen extends StatefulWidget {
  final ReceivingVoucher voucher;

  const MobileReceivingVoucherDetailScreen({super.key, required this.voucher});

  @override
  State<MobileReceivingVoucherDetailScreen> createState() => _MobileReceivingVoucherDetailScreenState();
}

class _MobileReceivingVoucherDetailScreenState extends State<MobileReceivingVoucherDetailScreen> {
  late ReceivingVoucher currentVoucher;

  @override
  void initState() {
    super.initState();
    currentVoucher = widget.voucher;
    _loadFullVoucher();
  }

  Future<void> _loadFullVoucher() async {
    final fullVoucherData = await DatabaseHelper.instance.getReceivingVoucher(currentVoucher.id);
    if (fullVoucherData != null && mounted) {
      final itemsMap = fullVoucherData['items'] as List;
      final items = itemsMap.map((m) => ReceivingVoucherItem.fromMap(m)).toList();
      setState(() {
        currentVoucher = ReceivingVoucher.fromMap(fullVoucherData, items);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReceivingVouchersBloc, ReceivingVouchersState>(
      listener: (context, state) {
        if (state is ReceivingVouchersLoaded) {
          try {
            final updatedVoucher = state.vouchers.firstWhere((q) => q.id == currentVoucher.id);
            if (updatedVoucher.id == currentVoucher.id && mounted) {
              setState(() {
                currentVoucher = updatedVoucher.copyWith(items: currentVoucher.items);
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
          title: Text('BR ${currentVoucher.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) => _handleAction(context, val, currentVoucher),
              itemBuilder: (_) => _buildActionMenu(context, currentVoucher),
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
                          Text('Réf: ${currentVoucher.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentVoucher.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(translateStatus(currentVoucher.status), style: TextStyle(color: _getStatusColor(currentVoucher.status), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Date', formatDateTimeLong(currentVoucher.date)),
                      const SizedBox(height: 8),
                      _buildInfoRow('Fournisseur', currentVoucher.supplierName ?? 'Non spécifié'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              if (currentVoucher.items.isEmpty)
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
                ...currentVoucher.items.map((item) => Card(
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
                              Text('Produit: ${item.productId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), // Assuming no product name fetched here easily, could be improved
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Reçu: ${item.quantityReceived} ', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                  if (item.quantityExpected != null)
                                    Text('(Attendu: ${item.quantityExpected})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              if (currentVoucher.notes != null && currentVoucher.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(currentVoucher.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildActionMenu(BuildContext context, ReceivingVoucher voucher) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(_buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('print', Icons.print_outlined, AppColors.textSecondary, 'Imprimer'));
    items.add(const PopupMenuDivider(height: 1));
    items.add(_buildMenuItem('payment', Icons.credit_card_outlined, AppColors.success, 'Ajouter un paiement'));
    items.add(const PopupMenuDivider(height: 1));

    if (voucher.isConvertedToPurchaseInvoice) {
      items.add(_buildMenuItem('view_invoice_created', Icons.visibility_outlined, AppColors.textSecondary, 'Voir la facture créée'));
      items.add(const PopupMenuDivider(height: 1));
    } else if (voucher.isConvertedToSupplierReturn) {
      items.add(_buildMenuItem('view_return_created', Icons.visibility_outlined, AppColors.textSecondary, 'Voir le bon de retour créé'));
      items.add(const PopupMenuDivider(height: 1));
    } else {
      items.add(_buildMenuItem('convert_invoice', Icons.receipt_long_outlined, AppColors.textSecondary, 'Transformer en facture d\'achat'));
      items.add(const PopupMenuDivider(height: 1));
      items.add(_buildMenuItem('convert_return', Icons.assignment_return_outlined, AppColors.textSecondary, 'Transformer en Bon de retour'));
      items.add(const PopupMenuDivider(height: 1));
    }
    
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

  void _handleAction(BuildContext context, String action, ReceivingVoucher voucher) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<ReceivingVouchersBloc>()),
                BlocProvider.value(value: context.read<SuppliersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
              ],
              child: MobileReceivingVoucherFormScreen(existing: voucher),
            ),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer ce bon ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<ReceivingVouchersBloc>().add(DeleteReceivingVoucher(voucher.id));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
      case 'pdf':
        final doc = DocumentWrapper.fromReceivingVoucher(voucher);
        PdfService.instance.generateAndOpenDocument(doc);
        break;
      case 'print':
        final doc = DocumentWrapper.fromReceivingVoucher(voucher);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(document: doc)));
        break;
      case 'payment':
      case 'convert_invoice':
      case 'convert_return':
      case 'view_invoice_created':
      case 'view_return_created':
      case 'email':
      case 'whatsapp':
      case 'duplicate':
      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action sur mobile en cours de développement')));
        break;
      case 'status':
        _showChangeStatusDialog(context, voucher);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action non implémentée')));
    }
  }

  void _showChangeStatusDialog(BuildContext context, ReceivingVoucher voucher) {
    String selectedStatus = voucher.status;

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
                    items: ['draft', 'validated', 'cancelled'].map((s) => DropdownMenuItem(
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
                  final updatedVoucher = voucher.copyWith(status: selectedStatus);
                  context.read<ReceivingVouchersBloc>().add(UpdateReceivingVoucher(updatedVoucher));
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
