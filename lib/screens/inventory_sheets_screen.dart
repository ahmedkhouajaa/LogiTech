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
import 'document_detail_screen.dart';
import '../mobile/screens/mobile_inventory_sheet_detail_screen.dart';
import '../widgets/searchable_dropdown_field.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';

enum InventorySheetStatus {
  draft('Validé'),
  validated('Validé'),
  cancelled('Annulé');

  final String label;
  const InventorySheetStatus(this.label);

  Color get color {
    switch (this) {
      case draft:
      case validated: return AppColors.success;
      case cancelled: return AppColors.error;
    }
  }
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
    final bloc = context.read<WarehousesBloc>();
    if (bloc.state is WarehousesLoaded) {
      if (mounted) setState(() => _warehouses = (bloc.state as WarehousesLoaded).warehouses.cast<Warehouse>());
    }
    bloc.stream.listen((state) {
      if (state is WarehousesLoaded && mounted) {
        setState(() => _warehouses = state.warehouses.cast<Warehouse>());
      }
    });
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
    final statusLabel = entry.status == 'validated' ? 'Validé' : (entry.status == 'cancelled' ? 'Annulé' : 'Brouillon');
    final statusColor = entry.status == 'validated' ? AppColors.success : (entry.status == 'cancelled' ? AppColors.error : AppColors.warning);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          document: wrapper,
          status: statusLabel,
          statusColor: statusColor,
        ),
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
              padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
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
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showMobileFilters = !_showMobileFilters),
                    icon: Icon(_showMobileFilters ? Icons.filter_list_off : Icons.filter_list, size: 18),
                    label: Text(_showMobileFilters ? 'Masquer filtres' : 'Filtres'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField(
                            dropdownColor: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            value: _filterWarehouseId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
                            ),
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
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
                              hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              prefixIcon: Icon(Icons.numbers, size: 16, color: AppColors.textSecondary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                              filled: true,
                              fillColor: AppColors.surfaceAlt,
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
                          backgroundColor: AppColors.surface,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
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
                                child: Icon(Icons.close, size: 14, color: AppColors.textSecondary),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
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

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          if (state is InventorySheetsLoading) {
                            return const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (state is InventorySheetsError) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(child: Text(state.message, style: TextStyle(color: AppColors.error))),
                            );
                          }
                          if (state is InventorySheetsLoaded) {
                            if (entries.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(48.0),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inbox_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                                      const SizedBox(height: 12),
                                      Text("Aucune fiche d'inventaire", style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text("Appuyez sur + pour en créer une", style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                return _buildMobileCard(context, entries[index]);
                              },
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Floating Action Button
        if (PermissionService.instance.canCreate(UserPermissionResources.stockInventorySheets))
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: context.read<InventorySheetsBloc>()),
                    BlocProvider.value(value: context.read<ProductsBloc>()),
                  ],
                  child: MobileInventorySheetDetailScreen(sheet: entry),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Blue Ref Badge Chip + Status Chip + Chevron
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.number,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(entry.status),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Row 1: Long Date & Time
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      formatDateTimeLong(entry.inventoryDate),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 2: Warehouse Name on left + Article Count on the right (Image 3 exact match)
                Row(
                  children: [
                    Icon(Icons.store_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (entry.notes != null && entry.notes!.isNotEmpty)
                            ? entry.notes!
                            : _getWarehouseName(entry.warehouseId),
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.items.length} article${entry.items.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
    if (items.isEmpty) return Text('0 article', style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    
    final summaryText = items.map((item) {
      final pName = _getProductName(item.productId);
      return '${item.actualQty.toInt()}x $pName';
    }).join(', ');

    return Tooltip(
      message: summaryText,
      preferBelow: false,
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 20),
      showDuration: Duration(seconds: 3),
      decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
      child: Text('${items.length} article${items.length > 1 ? 's' : ''}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Fiches d'inventaire",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text("Gérer vos fiches d'inventaire", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              if (PermissionService.instance.canCreate(UserPermissionResources.stockInventorySheets))
                ElevatedButton.icon(
                  onPressed: () => _navigate(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Créer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Filters Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Warehouse
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Entrepôt', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: Builder(
                          builder: (context) {
                            final selectedWh = _warehouses.cast<Warehouse?>().firstWhere(
                              (w) => w?.id == _filterWarehouseId,
                              orElse: () => null,
                            );
                            return SearchableSelectorField(
                              hint: 'Tous les Entrepôts',
                              selectedText: selectedWh?.name ?? 'Tous les Entrepôts',
                              onTap: () async {
                                final res = await showWarehouseSelectDialog(
                                  context,
                                  _warehouses,
                                  selectedWarehouseId: _filterWarehouseId,
                                  includeAll: true,
                                );
                                if (res != null) {
                                  setState(() => _filterWarehouseId = (res == '__all__' ? null : res));
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                
                // Article
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Article', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Rechercher produit...',
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                            prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: (v) => setState(() {
                            _searchQuery = v;
                            _currentPage = 0;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Période', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
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
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
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
                                  child: Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_filterWarehouseId != null || _searchQuery.isNotEmpty || _filterReference.isNotEmpty || _filterDateRange != null || _filterEcart != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: IconButton(
                      onPressed: () => setState(() {
                        _filterWarehouseId = null;
                        _searchQuery = '';
                        _filterReference = '';
                        _filterDateRange = null;
                        _filterEcart = null;
                        _currentPage = 0;
                      }),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: 'Réinitialiser les filtres',
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.error,
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // List
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Builder(
                builder: (context) {
                  if (state is InventorySheetsLoading || state is InventorySheetsInitial) {
                    return ShimmerTable(
                      headerColumns: [
                        Expanded(flex: 2, child: Text('Référence', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Entrepôt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text('Articles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text('Surplus', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text('Manquant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      ],
                    );
                  }
                  if (state is InventorySheetsError) {
                    return AppErrorWidget(message: state.message);
                  }
                  if (state is InventorySheetsLoaded) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Text("Aucune fiche d'inventaire trouvée", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      );
                    }

                    final totalItems = entries.length;
                    final totalPages = (totalItems / _rowsPerPage).ceil() == 0 ? 1 : (totalItems / _rowsPerPage).ceil();
                    final startIndex = _currentPage * _rowsPerPage;
                    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                    final currentPageItems = entries.sublist(startIndex, endIndex);

                    return Column(
                      children: [
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text('Référence', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text('Entrepôt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text('Articles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text('Surplus', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text('Manquant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              SizedBox(width: 60, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                        
                        // Table body
                        Expanded(
                          child: ListView.separated(
                            itemCount: currentPageItems.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              return _buildRow(context, currentPageItems[index], index);
                            },
                          ),
                        ),

                        // Pagination
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Text('Lignes', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                  color: AppColors.surface,
                                ),
                                child: DropdownButton<int>(
                                  value: _rowsPerPage,
                                  underline: const SizedBox(),
                                  icon: Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                                  items: [20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v', style: const TextStyle(fontSize: 12)))).toList(),
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
                              const SizedBox(width: 20),
                              Text('Page ${_currentPage + 1} sur $totalPages', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                totalItems == 0 ? 'Affichage de 0 à 0 sur 0 résultats' : 'Affichage de ${startIndex + 1} à $endIndex sur $totalItems résultats',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_left, size: 18, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: _currentPage < totalPages - 1 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.surface,
                                      ),
                                      child: Icon(Icons.chevron_right, size: 18, color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                                    ),
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
        ),
        const SizedBox(height: 10),
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
      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(entry.number, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(formatDateTimeLong(entry.inventoryDate), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text(_getWarehouseName(entry.warehouseId), style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: _buildArticlesDisplay(entry.items),
          ),
          Expanded(
            flex: 1,
            child: Text(totalSurplus > 0 ? '+${totalSurplus.toStringAsFixed(1)}' : '—', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: totalSurplus > 0 ? AppColors.success : AppColors.textSecondary)),
          ),
          Expanded(
            flex: 1,
            child: Text(totalMissing > 0 ? '-${totalMissing.toStringAsFixed(1)}' : '—', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: totalMissing > 0 ? AppColors.error : AppColors.textSecondary)),
          ),
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, size: 18, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'voir') _previewDocument(entry);
                  if (val == 'edit') _navigate(context, entry);
                  if (val == 'delete') _confirmDelete(entry);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'voir',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        const Text('Voir', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (PermissionService.instance.canUpdate(UserPermissionResources.stockInventorySheets))
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text('Modifier', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  if (PermissionService.instance.canDelete(UserPermissionResources.stockInventorySheets))
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
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
        padding: EdgeInsets.all(4),
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
        title: Text('Confirmer la suppression'),
        content: Text("Voulez-vous vraiment supprimer la Fiche d'inventaire ${entry.number} ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InventorySheetsBloc>().add(InventorySheetDeleted(entry.id));
              // Refresh products list so stock quantities are updated immediately
              // context.read<ProductsBloc>().add(LoadProducts());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

