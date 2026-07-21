import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../blocs/inventory_sheets/inventory_sheets_state.dart';



import '../database/database_helper.dart';
import '../models/stock_movement.dart';
import '../widgets/custom_date_range_picker.dart';
import '../blocs/products/products_bloc.dart';

import '../models/inventory_sheet.dart';
import '../models/inventory_sheet_item.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'create_inventory_sheet_screen.dart';
import '../models/document_wrapper.dart';
import 'document_preview_screen.dart';


enum InventorySheetStatus {
  draft('Brouillon', AppColors.textSecondary),
  validated('Valide', AppColors.primary),
  cancelled('Annule', AppColors.error);

  final String label;
  final Color color;
  const InventorySheetStatus(this.label, this.color);
}

class InventorySheetsScreen extends StatefulWidget {
  final bool isExitVoucher;
  const InventorySheetsScreen({super.key, this.isExitVoucher = false});

  @override
  State<InventorySheetsScreen> createState() => _InventorySheetsScreenState();
}

class _InventorySheetsScreenState extends State<InventorySheetsScreen> {
  int _rowsPerPage = 20;
  int _currentPage = 0;
  
  String _searchQuery = '';
  String _filterReference = '';
  String? _filterWarehouseId;
  DateTimeRange? _filterDateRange;
  String? _filterEcart;
  List<Warehouse> _warehouses = [];
  bool _showMobileFilters = false;

  @override
  void initState() {
    super.initState();
    context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    final ws = await DatabaseHelper.instance.getWarehouses();
    if (mounted) setState(() => _warehouses = ws);
  }

  String _getWarehouseName(String id) {
    if (id == 'default_warehouse') return 'Entrepôt par défaut';
    try {
      return _warehouses.firstWhere((w) => w.id == id).name;
    } catch (_) {
      return 'Entrepôt par défaut';
    }
  }

  String _getProductName(String id) {
    final state = context.read<ProductsBloc>().state;
    if (state is ProductsLoaded) {
      try {
        return state.products.firstWhere((p) => p.id == id).name;
      } catch (_) {}
    }
    return '';
  }

  void _navigate(BuildContext context, [InventorySheet? entry]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateInventorySheetScreen(sheet: entry),
      ),
    );
  }

  void _previewDocument(InventorySheet entry) {
    final wrapper = DocumentWrapper.fromInventorySheet(entry);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(document: wrapper),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventorySheetsBloc, InventorySheetsState>(
      builder: (context, state) {
        List<InventorySheet> entries = [];
        if (state is InventorySheetsLoaded) {
          entries = state.sheets.where((e) {
            final matchesRef = _filterReference.isEmpty || e.number.toLowerCase().contains(_filterReference.toLowerCase());
            final matchesWarehouse = _filterWarehouseId == null || e.warehouseId == _filterWarehouseId || (e.warehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault));
            final matchesArticle = _searchQuery.isEmpty || e.items.any((item) => _getProductName(item.productId).toLowerCase().contains(_searchQuery.toLowerCase()));
            final matchesDate = _filterDateRange == null || (e.inventoryDate.isAfter(_filterDateRange!.start.subtract(const Duration(days: 1))) && e.inventoryDate.isBefore(_filterDateRange!.end.add(const Duration(days: 1))));
            
            final totalSurplus = e.items.fold(0.0, (sum, item) {
              final diff = item.actualQty - item.theoreticalQty;
              return diff > 0 ? sum + diff : sum;
            });
            final totalMissing = e.items.fold(0.0, (sum, item) {
              final diff = item.actualQty - item.theoreticalQty;
              return diff < 0 ? sum + diff.abs() : sum;
            });

            bool matchesEcart = true;
            if (_filterEcart == 'Surplus') matchesEcart = totalSurplus > 0;
            if (_filterEcart == 'Manquant') matchesEcart = totalMissing > 0;
            if (_filterEcart == 'Équilibré') matchesEcart = totalSurplus == 0 && totalMissing == 0;

            return matchesRef && matchesWarehouse && matchesArticle && matchesDate && matchesEcart;
          }).toList();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            return isMobile ? _buildMobileLayout(context, state, entries) : _buildDesktopLayout(context, state, entries);
          },
        );
      },
    );
  }

  // ─── Mobile Layout ─────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, InventorySheetsState state, List<InventorySheet> entries) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mobile header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Fiches d'inventaire",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter toggle button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showMobileFilters = !_showMobileFilters),
                    icon: Icon(_showMobileFilters ? Icons.filter_list_off : Icons.filter_list, size: 18),
                    label: Text(_showMobileFilters ? 'Masquer filtres' : 'Filtres'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            
            // Collapsible filters
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0, width: double.infinity),
              secondChild: Container(
                margin: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher article...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _filterWarehouseId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Entrepôt', style: TextStyle(fontSize: 12))),
                              ..._warehouses.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _filterWarehouseId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Référence',
                              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              prefixIcon: const Icon(Icons.numbers, size: 16, color: AppColors.textSecondary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (v) => setState(() => _filterReference = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () async {
                          final range = await CustomDateRangePicker.show(
                            context,
                            initialRange: _filterDateRange,
                          );
                          if (range != null) setState(() => _filterDateRange = range);
                        },
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _filterDateRange != null
                                    ? '${formatDate(_filterDateRange!.start)} - ${formatDate(_filterDateRange!.end)}'
                                    : 'Toutes les dates',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _filterDateRange != null ? AppColors.textPrimary : AppColors.textTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_filterDateRange != null)
                              InkWell(
                                onTap: () => setState(() => _filterDateRange = null),
                                child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _showMobileFilters ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),

            // Active filters indicator + reset
            if (_filterWarehouseId != null || _searchQuery.isNotEmpty || _filterReference.isNotEmpty || _filterDateRange != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${entries.length} résultat${entries.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _filterWarehouseId = null;
                        _searchQuery = '';
                        _filterReference = '';
                        _filterDateRange = null;
                        _filterEcart = null;
                        _currentPage = 0;
                      }),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Réinitialiser', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    ),
                  ],
                ),
              ),

            // Cards list
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state is InventorySheetsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is InventorySheetsError) {
                    return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
                  }
                  if (state is InventorySheetsLoaded) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text("Aucun bon d'entrée", style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text("Appuyez sur + pour en créer un", style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 80),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _buildMobileCard(context, entries[index]);
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
        // Floating Action Button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _navigate(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCard(BuildContext context, InventorySheet entry) {
    final totalSurplus = entry.items.fold(0.0, (sum, item) {
      final diff = item.actualQty - item.theoreticalQty;
      return diff > 0 ? sum + diff : sum;
    });
    final totalMissing = entry.items.fold(0.0, (sum, item) {
      final diff = item.actualQty - item.theoreticalQty;
      return diff < 0 ? sum + diff.abs() : sum;
    });

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(
                      children: [
                        _buildStatusChip(entry.status),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          color: AppColors.surface,
                          onSelected: (val) {
                            if (val == 'voir') _previewDocument(entry);
                            if (val == 'edit') _navigate(context, entry);
                            if (val == 'delete') _confirmDelete(entry);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'voir',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 20, color: AppColors.textSecondary),
                                  SizedBox(width: 12),
                                  Text('Voir', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                  SizedBox(width: 12),
                                  Text('Modifier', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                  SizedBox(width: 12),
                                  Text('Supprimer', style: TextStyle(fontSize: 13, color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(Icons.date_range_rounded, formatDateTime(entry.inventoryDate)),
                    ),
                    _buildInfoItem(Icons.warehouse_rounded, _getWarehouseName(entry.warehouseId)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildArticlesDisplay(entry.items),
                    ),
                    if (totalSurplus > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text('+${totalSurplus.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    if (totalMissing > 0)
                      Text('-${totalMissing.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticlesDisplay(List<InventorySheetItem> items) {
    if (items.isEmpty) return const Text('0 article', style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    
    final summaryText = items.map((item) {
      final pName = _getProductName(item.productId);
      return '${item.actualQty.toInt()}x $pName';
    }).join(', ');

    return Tooltip(
      message: summaryText,
      preferBelow: false,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      showDuration: const Duration(seconds: 3),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
      child: Text('${items.length} article${items.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final InventorySheetStatus entryStatus;
    switch (status) {
      case 'validated':
        entryStatus = InventorySheetStatus.validated;
        break;
      case 'cancelled':
        entryStatus = InventorySheetStatus.cancelled;
        break;
      default:
        entryStatus = InventorySheetStatus.draft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: entryStatus.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        entryStatus.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: entryStatus.color,
        ),
      ),
    );
  }

  // ─── Desktop Layout ────────────────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context, InventorySheetsState state, List<InventorySheet> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.play_arrow, color: Colors.red, size: 28), // The YouTube-like icon from mockup
              const SizedBox(width: 8),
              const Text(
                "Fiche d'inventaire",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _navigate(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Créer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Matching the blue 'Créer' button
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ),

        // Filters Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              // Warehouse
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Entrepôt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: DropdownButtonFormField<String?>(
                        value: _filterWarehouseId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Tous les Entrepôts', style: TextStyle(fontSize: 13))),
                          ..._warehouses.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() => _filterWarehouseId = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Article
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Article', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher produit...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Reference
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Référence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher réf...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                          prefixIcon: const Icon(Icons.numbers_rounded, size: 18, color: AppColors.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) => setState(() => _filterReference = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Période', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () async {
                          final range = await CustomDateRangePicker.show(
                            context,
                            initialRange: _filterDateRange,
                          );
                          if (range != null) {
                            setState(() => _filterDateRange = range);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _filterDateRange != null
                                    ? '${formatDate(_filterDateRange!.start)} - ${formatDate(_filterDateRange!.end)}'
                                    : 'Toutes les dates',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _filterDateRange != null ? AppColors.textPrimary : AppColors.textTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_filterDateRange != null)
                              InkWell(
                                onTap: () => setState(() => _filterDateRange = null),
                                child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Active filters indicator + reset
        if (_filterWarehouseId != null || _searchQuery.isNotEmpty || _filterReference.isNotEmpty || _filterDateRange != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg).copyWith(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entries.length} résultat${entries.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _filterWarehouseId = null;
                    _searchQuery = '';
                    _filterReference = '';
                    _filterDateRange = null;
                        _filterEcart = null;
                    _currentPage = 0;
                  }),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Réinitialiser les filtres', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ),
          ),

        // List
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.border),
            ),
            child: Builder(
              builder: (context) {
                if (state is InventorySheetsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is InventorySheetsError) {
                  return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
                }
                if (state is InventorySheetsLoaded) {
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text("Aucun bon d'entrée trouvé", style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }

                  final totalItems = entries.length;
                  final totalPages = (totalItems / _rowsPerPage).ceil();
                  final startIndex = _currentPage * _rowsPerPage;
                  final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                  final currentPageItems = entries.sublist(startIndex, endIndex);

                  return Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('Référence', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 2, child: Text('Entrepôt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 1, child: Text('Articles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 1, child: Text('Surplus', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            Expanded(flex: 1, child: Text('Manquant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                            SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                          ],
                        ),
                      ),
                      
                      // Table body
                      Expanded(
                        child: ListView.builder(
                          itemCount: currentPageItems.length,
                          itemBuilder: (context, index) {
                            return _buildRow(context, currentPageItems[index], index);
                          },
                        ),
                      ),

                      // Pagination
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            const Text('Lignes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButton<int>(
                                value: _rowsPerPage,
                                underline: const SizedBox(),
                                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                items: [10, 20, 50].map((v) => DropdownMenuItem(value: v, child: Text('$v', style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _rowsPerPage = v;
                                      _currentPage = 0;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 24),
                            Text('Page ${_currentPage + 1} sur $totalPages', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(width: 24),
                            Text('Affichage de ${startIndex + 1} a $endIndex sur $totalItems resultats', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const Spacer(),
                            Row(
                              children: [
                                _pageButton(
                                  icon: Icons.chevron_left,
                                  enabled: _currentPage > 0,
                                  onTap: () => setState(() => _currentPage--),
                                ),
                                const SizedBox(width: 8),
                                _pageButton(
                                  icon: Icons.chevron_right,
                                  enabled: _currentPage < totalPages - 1,
                                  onTap: () => setState(() => _currentPage++),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, InventorySheet entry, int index) {
    final totalSurplus = entry.items.fold(0.0, (sum, item) {
      final diff = item.actualQty - item.theoreticalQty;
      return diff > 0 ? sum + diff : sum;
    });
    final totalMissing = entry.items.fold(0.0, (sum, item) {
      final diff = item.actualQty - item.theoreticalQty;
      return diff < 0 ? sum + diff.abs() : sum;
    });

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(entry.number, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(formatDateTimeLong(entry.inventoryDate), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(_getWarehouseName(entry.warehouseId), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: _buildArticlesDisplay(entry.items),
          ),
          Expanded(
            flex: 1,
            child: Text(totalSurplus > 0 ? '+${totalSurplus.toStringAsFixed(1)}' : '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: totalSurplus > 0 ? AppColors.success : AppColors.textSecondary)),
          ),
          Expanded(
            flex: 1,
            child: Text(totalMissing > 0 ? '-${totalMissing.toStringAsFixed(1)}' : '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: totalMissing > 0 ? AppColors.error : AppColors.textSecondary)),
          ),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'voir') _previewDocument(entry);
                  if (val == 'edit') _navigate(context, entry);
                  if (val == 'delete') _confirmDelete(entry);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'voir',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 12),
                        Text('Voir', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                        SizedBox(width: 12),
                        Text('Modifier', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                        SizedBox(width: 12),
                        Text('Supprimer', style: TextStyle(fontSize: 13, color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageButton({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
          color: AppColors.surface,
        ),
        child: Icon(icon, size: 20, color: enabled ? AppColors.textPrimary : AppColors.textTertiary),
      ),
    );
  }

  void _confirmDelete(InventorySheet entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text("Voulez-vous vraiment supprimer la Fiche d'inventaire ${entry.number} ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InventorySheetsBloc>().add(InventorySheetDeleted(entry.id));
              // Refresh products list so stock quantities are updated immediately
              // context.read<ProductsBloc>().add(LoadProducts());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

