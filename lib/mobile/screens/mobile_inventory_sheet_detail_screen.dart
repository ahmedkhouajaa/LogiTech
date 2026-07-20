import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../../blocs/inventory_sheets/inventory_sheets_state.dart';
import '../../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../../models/inventory_sheet.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../database/database_helper.dart';

import 'forms/mobile_inventory_sheet_form_screen.dart';

class MobileInventorySheetDetailScreen extends StatefulWidget {
  final InventorySheet sheet;

  const MobileInventorySheetDetailScreen({
    super.key,
    required this.sheet,
  });

  @override
  State<MobileInventorySheetDetailScreen> createState() => _MobileInventorySheetDetailScreenState();
}

class _MobileInventorySheetDetailScreenState extends State<MobileInventorySheetDetailScreen> {
  late InventorySheet currentSheet;

  @override
  void initState() {
    super.initState();
    currentSheet = widget.sheet;
  }

  void _handleAction(BuildContext context, String action, InventorySheet sheet) {
    if (action == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MobileInventorySheetFormScreen(existing: sheet),
        ),
      ).then((_) {
        if (mounted) {
          context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());
        }
      });
    } else if (action == 'delete') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette fiche ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                context.read<InventorySheetsBloc>().add(InventorySheetDeleted(sheet.id));
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventorySheetsBloc, InventorySheetsState>(
      listener: (context, state) {
        if (state is InventorySheetsLoaded) {
          try {
            final updatedSheet = state.sheets.firstWhere((q) => q.id == currentSheet.id);
            if (updatedSheet.id == currentSheet.id && mounted) {
              setState(() {
                currentSheet = updatedSheet;
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
          title: Text('Fiche ${currentSheet.number}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: AppColors.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (currentSheet.status != 'validated')
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (val) => _handleAction(context, val, currentSheet),
                itemBuilder: (_) => [
                  _buildMenuItem('edit', Icons.edit_outlined, AppColors.primary, 'Modifier'),
                  const PopupMenuDivider(height: 1),
                  _buildMenuItem('delete', Icons.delete_outline, AppColors.error, 'Supprimer'),
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
                          Text('Réf: ${currentSheet.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(currentSheet.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(translateStatus(currentSheet.status), style: TextStyle(color: _getStatusColor(currentSheet.status), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('Date', formatDate(currentSheet.date)),
                      _buildDetailRow('Statut', translateStatus(currentSheet.status)),
                      if (currentSheet.reason != null && currentSheet.reason!.isNotEmpty)
                        _buildDetailRow('Motif', currentSheet.reason!),
                      if (currentSheet.notes != null && currentSheet.notes!.isNotEmpty)
                        _buildDetailRow('Notes', currentSheet.notes!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Articles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              if (currentSheet.items.isEmpty)
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
                ...currentSheet.items.map((item) => Card(
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
                              Text(item.productName ?? 'Article inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (item.productSku != null && item.productSku!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(item.productSku!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                              ],
                              const SizedBox(height: 4),
                              Text('Qté Théorique: ${item.theoreticalQty}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              Text('Qté Physique: ${item.actualQty}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, Color color, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: const Color(0xFF64748B))),
      ]),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Brouillon':
      case 'draft':
        return AppColors.warning;
      case 'Finalisée':
      case 'validated':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
