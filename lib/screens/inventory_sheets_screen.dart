import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../../blocs/inventory_sheets/inventory_sheets_state.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_state.dart';
import '../../utils/constants.dart';
import '../../widgets/data_table_widget.dart';
import '../../models/inventory_sheet.dart';
import 'create_inventory_sheet_screen.dart';

class InventorySheetsScreen extends StatelessWidget {
  const InventorySheetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              const Text(
                'Fiches d\'inventaire',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Créer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateInventorySheetScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<InventorySheetsBloc, InventorySheetsState>(
            builder: (context, state) {
              if (state is InventorySheetsLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (state is InventorySheetsError) {
                return Center(child: Text('Erreur: ${state.message}', style: const TextStyle(color: AppColors.error)));
              }
              
              if (state is InventorySheetsLoaded) {
                return _buildDataTable(context, state);
              }
              
              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(BuildContext context, InventorySheetsLoaded state) {
    return DataTableWidget<InventorySheet>(
      columns: const ['Référence', 'Date inventaire', 'Entrepôt', 'Articles', 'Surplus', 'Manquant', 'Actions'],
      rows: state.sheets,
      cellBuilder: (sheet) {
        final totalSurplus = sheet.items.fold(0.0, (sum, item) {
          final diff = item.actualQty - item.theoreticalQty;
          return diff > 0 ? sum + diff : sum;
        });
        
        final totalMissing = sheet.items.fold(0.0, (sum, item) {
          final diff = item.actualQty - item.theoreticalQty;
          return diff < 0 ? sum + diff.abs() : sum;
        });

        return [
          // Référence
          DataCell(
            Text(sheet.number, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          
          // Date inventaire
          DataCell(Text(DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(sheet.inventoryDate))),
          
          // Entrepôt
          DataCell(
            BlocBuilder<WarehousesBloc, WarehousesState>(
              builder: (context, whState) {
                String whName = sheet.warehouseId;
                if (whState is WarehousesLoaded) {
                  try {
                    final wh = whState.warehouses.firstWhere((w) => w.id == sheet.warehouseId);
                    whName = wh.name;
                  } catch (_) {}
                }
                return Text(whName);
              },
            ),
          ),
          
          // Articles
          DataCell(Text(sheet.items.length.toString())),
          
          // Surplus
          DataCell(
            Text(
              totalSurplus > 0 ? '+$totalSurplus' : '—',
              style: TextStyle(color: totalSurplus > 0 ? AppColors.success : AppColors.textTertiary, fontWeight: totalSurplus > 0 ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          
          // Manquant
          DataCell(
            Text(
              totalMissing > 0 ? '-$totalMissing' : '—',
              style: TextStyle(color: totalMissing > 0 ? AppColors.error : AppColors.textTertiary, fontWeight: totalMissing > 0 ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          
          // Actions
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sheet.status != 'Finalisée')
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateInventorySheetScreen(sheet: sheet),
                        ),
                      );
                    },
                    tooltip: 'Modifier',
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: AppColors.textSecondary, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateInventorySheetScreen(sheet: sheet, isViewOnly: true),
                        ),
                      );
                    },
                    tooltip: 'Voir',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () => _confirmDelete(context, sheet.id),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette fiche d\'inventaire ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<InventorySheetsBloc>().add(InventorySheetDeleted(id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
