import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/stock_entries/stock_entries_bloc.dart';
import '../blocs/stock_entries/stock_entries_event.dart';
import '../blocs/stock_entries/stock_entries_state.dart';
import '../blocs/products/products_bloc.dart';
import '../models/product.dart';
import '../models/stock_entry.dart';
import '../services/sync_service.dart';
import '../widgets/pending_sync_badge.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_date_range_picker.dart';
import '../models/stock_movement.dart';
import '../models/document_wrapper.dart';
import 'create_stock_entry_screen.dart';
import 'document_detail_screen.dart';
import '../mobile/screens/mobile_stock_entry_detail_screen.dart';
import '../widgets/searchable_dropdown_field.dart';
import '../blocs/warehouses/warehouses_bloc.dart';
import '../utils/offline_action_helper.dart';
import '../blocs/warehouses/warehouses_state.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_table_row.dart';
import '../l10n/app_localizations.dart';

enum StockEntryStatus {
  draft('Brouillon'),
  validated('Validé'),
  cancelled('Annulé');

  final String label;
  const StockEntryStatus(this.label);

  String localized(BuildContext context) => context.tr(label);

  Color get color {
    switch (this) {
      case draft: return AppColors.warning;
      case validated: return AppColors.success;
      case cancelled: return AppColors.error;
    }
  }
}

class StockEntriesScreen extends StatefulWidget {
  const StockEntriesScreen({super.key});

  @override
  State<StockEntriesScreen> createState() => _StockEntriesScreenState();
}

class _StockEntriesScreenState extends State<StockEntriesScreen> {
  int _rowsPerPage = 20;
  int _currentPage = 0;
  
  String _searchQuery = '';
  String _filterReference = '';
  String? _filterWarehouseId;
  DateTimeRange? _filterDateRange;
  List<Warehouse> _warehouses = [];
  bool _showMobileFilters = false;

  StreamSubscription<int>? _syncSub;

  @override
  void initState() {
    super.initState();
    context.read<StockEntriesBloc>().add(const LoadFirstStockEntries());
    _loadWarehouses();

    _syncSub = SyncService.instance.onDocumentSyncCompleted.listen((count) {
      if (mounted && count > 0) {
        context.read<StockEntriesBloc>().add(const LoadFirstStockEntries());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('$count document(s) synchronisé(s) avec succès !'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
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
    if (id == 'default_warehouse') return context.tr('Entrepôt par défaut');
    try {
      final name = _warehouses.firstWhere((w) => w.id == id).name;
      if (name.toLowerCase() == 'entrepôt par défaut' || name.toLowerCase() == 'entrepot par defaut') {
        return context.tr('Entrepôt par défaut');
      }
      return name;
    } catch (_) {
      return context.tr('Entrepôt par défaut');
    }
  }

  Product? _getProduct(String id) {
    final state = context.read<ProductsBloc>().state;
    if (state is ProductsLoaded) {
      try {
        return state.products.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    return null;
  }

  String _getProductName(String id) {
    return _getProduct(id)?.name ?? '';
  }

  void _previewDocument(StockEntry entry) {
    final String resolvedWarehouse = _getWarehouseName(entry.warehouseId);
    final wrapper = DocumentWrapper(
      id: entry.id,
      number: entry.number,
      documentTitle: "BON D'ENTRÉE",
      documentType: "stock_entry",
      customerName: null,
      date: entry.date,
      totalHT: 0,
      totalTva: 0,
      totalTTC: 0,
      notes: entry.notes,
      items: entry.items.map((item) {
        final product = _getProduct(item.productId);
        final refCode = (product?.reference != null && product!.reference!.trim().isNotEmpty)
            ? product.reference!.trim()
            : (product?.code ?? '');
        return DocumentItemWrapper(
          productId: item.productId,
          reference: refCode,
          productName: product?.name ?? context.tr('Article Inconnu'),
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          tvaRate: 0,
          discountPercent: 0,
          totalHT: item.quantity * item.unitPrice,
          customFields: {
            'code': refCode,
            'unit': product?.unit ?? 'pièce',
            'purchasePrice': product?.purchasePrice ?? 0,
          },
        );
      }).toList(),
      customData: {
        'warehouseId': entry.warehouseId,
        'warehouseName': resolvedWarehouse,
        'reason': entry.reason,
        'createdBy': 'Admin',
        'status': entry.status,
      },
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          document: wrapper,
          status: entry.status == 'cancelled' ? context.tr('Annulé') : context.tr('Validé'),
          statusColor: entry.status == 'cancelled' ? AppColors.error : AppColors.success,
        ),
      ),
    );
  }

  void _navigate(BuildContext context, [StockEntry? entry]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateStockEntryScreen(existing: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StockEntriesBloc, StockEntriesState>(
      builder: (context, state) {
        List<StockEntry> entries = [];
        if (state is StockEntriesLoaded) {
          entries = state.filteredEntries.where((e) {
            final matchesRef = _filterReference.isEmpty || e.number.toLowerCase().contains(_filterReference.toLowerCase());
            final matchesWarehouse = _filterWarehouseId == null || e.warehouseId == _filterWarehouseId || (e.warehouseId == 'default_warehouse' && _warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault));
            final matchesArticle = _searchQuery.isEmpty || e.items.any((item) => _getProductName(item.productId).toLowerCase().contains(_searchQuery.toLowerCase()));
            final matchesDate = _filterDateRange == null || (e.date.isAfter(_filterDateRange!.start.subtract(const Duration(days: 1))) && e.date.isBefore(_filterDateRange!.end.add(const Duration(days: 1))));
            return matchesRef && matchesWarehouse && matchesArticle && matchesDate;
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
  Widget _buildMobileLayout(BuildContext context, StockEntriesState state, List<StockEntry> entries) {
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
                      context.tr("Bons d'entrée"),
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
                    label: Text(_showMobileFilters ? context.tr('Masquer filtres') : context.tr('Filtres')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.textPrimary, width: 1.5),
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
                        hintText: context.tr('Rechercher un article...'),
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
                            initialValue: _filterWarehouseId,
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
                              DropdownMenuItem<String?>(value: null, child: Text(context.tr('Entrepôt'), style: const TextStyle(fontSize: 12))),
                              ..._warehouses.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (v) => setState(() => _filterWarehouseId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: context.tr('Référence'),
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
                          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
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
                                    : context.tr('Toutes les dates'),
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
                        '${entries.length} ${entries.length > 1 ? context.tr('résultats') : context.tr('résultat')}',
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
                        _currentPage = 0;
                      }),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: Text(context.tr('Réinitialiser'), style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    ),
                  ],
                ),
              ),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<StockEntriesBloc>().add(LoadStockEntries());
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          if (state is StockEntriesLoading) {
                            return const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (state is StockEntriesError) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(child: Text(state.message, style: TextStyle(color: AppColors.error))),
                            );
                          }
                          if (state is StockEntriesLoaded) {
                            if (entries.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(48.0),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inbox_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                                      const SizedBox(height: 12),
                                      Text(context.tr("Aucun bon d'entrée"), style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text(context.tr("Appuyez sur + pour en créer un"), style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
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
        if (PermissionService.instance.canCreate(UserPermissionResources.stockEntryVouchers))
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

  Widget _buildMobileCard(BuildContext context, StockEntry entry) {
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
                    BlocProvider.value(value: context.read<StockEntriesBloc>()),
                    BlocProvider.value(value: context.read<ProductsBloc>()),
                  ],
                  child: MobileStockEntryDetailScreen(entry: entry),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Ref Badge + Status Chip + Chevron + Actions
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
                
                // Row 1: Date & Time
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      formatDateTimeLong(entry.date),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 2: Warehouse + Article Count on the right
                Row(
                  children: [
                    Icon(Icons.store_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _getWarehouseName(entry.warehouseId),
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.items.length} ${entry.items.length > 1 ? context.tr('articles') : context.tr('article')}',
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

  Widget _buildStatusChip(String status) {
    final StockEntryStatus entryStatus;
    switch (status) {
      case 'validated':
        entryStatus = StockEntryStatus.validated;
        break;
      case 'cancelled':
        entryStatus = StockEntryStatus.cancelled;
        break;
      default:
        entryStatus = StockEntryStatus.draft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: entryStatus.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: entryStatus.color.withValues(alpha: 0.2)),
      ),
      child: Text(
        entryStatus.localized(context),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: entryStatus.color),
      ),
    );
  }

  Widget _buildArticlesDisplay(List<StockEntryItem> items) {
    if (items.isEmpty) return Text('0 ${context.tr('article')}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
    
    final summaryText = items.map((item) {
      final pName = _getProductName(item.productId);
      return '${item.quantity.toInt()}x $pName';
    }).join(', ');

    return Tooltip(
      message: summaryText,
      preferBelow: false,
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 20),
      showDuration: Duration(seconds: 3),
      decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
      child: Text('${items.length} ${items.length > 1 ? context.tr('articles') : context.tr('article')}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }

  // ─── Desktop Layout ────────────────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context, StockEntriesState state, List<StockEntry> entries) {
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
                    context.tr("Bons d'entrée"),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(context.tr("Gérer vos bons d'entrée de stock"), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              if (PermissionService.instance.canCreate(UserPermissionResources.stockEntryVouchers))
                ElevatedButton.icon(
                  onPressed: () => _navigate(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.tr('Créer')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                      Text(context.tr('Entrepôt'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: Builder(
                          builder: (context) {
                            final selectedWh = _warehouses.cast<Warehouse?>().firstWhere(
                              (w) => w?.id == _filterWarehouseId,
                              orElse: () => null,
                            );
                            final isSelected = _filterWarehouseId != null;
                            return InkWell(
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
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isSelected
                                            ? (selectedWh?.name ?? context.tr('Tous les Entrepôts'))
                                            : context.tr('Tous les Entrepôts'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
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
                      Text(context.tr('Article'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: context.tr('Rechercher un produit...'),
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary)),
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

                // Date range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.tr('Date'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: InkWell(
                          onTap: () async {
                            final range = await CustomDateRangePicker.show(
                              context,
                              initialRange: _filterDateRange,
                            );
                            if (range != null) {
                              setState(() => _filterDateRange = range);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _filterDateRange != null
                                        ? '${formatDate(_filterDateRange!.start)} - ${formatDate(_filterDateRange!.end)}'
                                        : context.tr('Toutes les dates'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _filterDateRange != null ? AppColors.textPrimary : AppColors.textSecondary,
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
                      ),
                    ],
                  ),
                ),
                if (_filterWarehouseId != null || _searchQuery.isNotEmpty || _filterReference.isNotEmpty || _filterDateRange != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: IconButton(
                      onPressed: () => setState(() {
                        _filterWarehouseId = null;
                        _searchQuery = '';
                        _filterReference = '';
                        _filterDateRange = null;
                        _currentPage = 0;
                      }),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: context.tr('Réinitialiser les filtres'),
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
                  if (state is StockEntriesLoading || state is StockEntriesInitial) {
                    return ShimmerTable(
                      headerColumns: [
                        Expanded(flex: 2, child: Text(context.tr('Référence'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text(context.tr('Date'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text(context.tr('Entrepôt'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text(context.tr('Articles'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text(context.tr('Créé par'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                        SizedBox(width: 60, child: Text(context.tr('Actions'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                      ],
                    );
                  }
                  if (state is StockEntriesError) {
                    return AppErrorWidget(message: state.message);
                  }
                  if (state is StockEntriesLoaded) {
                    if (entries.isEmpty) {
                      return Center(
                        child: Text(context.tr("Aucun bon d'entrée trouvé"), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                              Expanded(flex: 2, child: Text(context.tr('Référence'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text(context.tr('Date'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text(context.tr('Entrepôt'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 1, child: Text(context.tr('Articles'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              Expanded(flex: 2, child: Text(context.tr('Créé par'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
                              SizedBox(width: 60, child: Text(context.tr('Actions'), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary))),
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
                              Text(context.tr('Lignes'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                              Text('${context.tr('Page')} ${_currentPage + 1} ${context.tr('sur')} $totalPages', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                totalItems == 0 ? '${context.tr('Affichage de')} 0 ${context.tr('sur')} 0 ${context.tr('résultats')}' : '${context.tr('Affichage de')} ${startIndex + 1} à $endIndex ${context.tr('sur')} $totalItems ${context.tr('résultats')}',
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

  Widget _buildRow(BuildContext context, StockEntry entry, int index) {
    return Material(
      color: index % 2 == 0 ? AppColors.surface : AppColors.background.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => _previewDocument(entry),
        hoverColor: AppColors.primary.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(entry.number, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (!entry.isSynced || entry.number.startsWith('BROUILLON-')) ...[
                  const SizedBox(width: 6),
                  const PendingSyncBadge(),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(formatDateTimeLong(entry.date), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text(_getWarehouseName(entry.warehouseId), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: _buildArticlesDisplay(entry.items),
          ),
          Expanded(
            flex: 2,
            child: Text('Admin', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                  OfflineActionHelper.executeAction(
                    context: context,
                    action: val,
                    onConfirmed: () {
                      if (val == 'voir') _previewDocument(entry);
                      if (val == 'edit') _navigate(context, entry);
                      if (val == 'delete') context.read<StockEntriesBloc>().add(DeleteStockEntry(entry.id));
                    },
                  );
                },
                itemBuilder: (_) {
                  final canRead = PermissionService.instance.canRead(UserPermissionResources.stockEntryVouchers);
                  final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.stockEntryVouchers);
                  final canDelete = PermissionService.instance.canDelete(UserPermissionResources.stockEntryVouchers);

                  final entries = <PopupMenuEntry<String>>[];

                  if (canRead) {
                    entries.add(
                      PopupMenuItem(
                        value: 'voir',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(context.tr('Voir')),
                          ],
                        ),
                      ),
                    );
                  }
                  if (canUpdate) {
                    if (entries.isNotEmpty) entries.add(const PopupMenuDivider(height: 1));
                    entries.add(
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(context.tr('Modifier')),
                          ],
                        ),
                      ),
                    );
                  }
                  if (canDelete) {
                    if (entries.isNotEmpty) entries.add(const PopupMenuDivider(height: 1));
                    entries.add(
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text(context.tr('Supprimer'), style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    );
                  }
                  return entries;
                },
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
}

}
