import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../utils/helpers.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../../blocs/inventory_sheets/inventory_sheets_state.dart';
import '../../database/database_helper.dart';
import '../../services/sync_service.dart';
import 'forms/mobile_inventory_sheet_form_screen.dart';
import 'mobile_inventory_sheet_detail_screen.dart';
import '../../models/inventory_sheet.dart';
import '../../services/firestore_pagination_service.dart';

class MobileInventorySheetsScreen extends StatefulWidget {
  final AppModule activeModule;
  const MobileInventorySheetsScreen({super.key, this.activeModule = AppModule.inventorySheet});

  @override
  State<MobileInventorySheetsScreen> createState() => _MobileInventorySheetsScreenState();
}

class _MobileInventorySheetsScreenState extends State<MobileInventorySheetsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _selectedStatus;
  late MobileModuleConfig _config;
  StreamSubscription<SyncStatus>? _syncSubscription;
  List<dynamic> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(widget.activeModule);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredSheets();
    _loadWarehouses();
    _scrollController.addListener(_onScroll);

    _syncSubscription = SyncService.instance.onSyncStatusChanged.listen((status) {
      if (status == SyncStatus.success && mounted) {
        _fetchFilteredSheets();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<InventorySheetsBloc>().add(LoadNextInventorySheets(
        searchQuery: _searchQuery,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredSheets() {
    context.read<InventorySheetsBloc>().add(LoadFirstInventorySheets(
      searchQuery: _searchQuery,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _selectedStatus,
    ));
  }

  Future<void> _loadWarehouses() async {
    final ws = await DatabaseHelper.instance.getWarehouses();
    if (mounted) setState(() => _warehouses = ws);
  }

  String _getWarehouseName(String id) {
    if (id == 'default_warehouse') return 'Entrepôt par défaut';
    try {
      final match = _warehouses.firstWhere((w) => w.id == id, orElse: () => null);
      if (match != null) return match.name;
    } catch (_) {}
    return 'Entrepôt par défaut';
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredSheets();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventorySheetsBloc, InventorySheetsState>(
      builder: (context, state) {
        bool isLoading = state is InventorySheetsLoading || state is InventorySheetsInitial;
        bool isEmpty = false;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> listItems = [];

        if (state is InventorySheetsLoaded) {
          final items = state.sheets;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((item) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final numMatch = item.number.toLowerCase().contains(query);
              final reasonMatch = (item.reason?.toLowerCase().contains(query) ?? false);
              final countedMatch = (item.countedBy?.toLowerCase().contains(query) ?? false);
              if (!numMatch && !reasonMatch && !countedMatch) return false;
            }
            
            if (_dateFrom != null) {
              final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
              final fDate = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
              if (itemDate.isBefore(fDate)) return false;
            }

            if (_dateTo != null) {
              final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
              final tDate = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
              if (itemDate.isAfter(tDate)) return false;
            }

            if (_selectedStatus != null && _selectedStatus != 'Tous' && _selectedStatus!.isNotEmpty) {
              final statusStr = translateStatus(item.status).toLowerCase();
              final rawStatus = item.status.toLowerCase();
              final filterLower = _selectedStatus!.toLowerCase();
              if (statusStr != filterLower && rawStatus != filterLower) return false;
            }

            return true;
          }).toList();
          
          isEmpty = filteredItems.isEmpty;

          listItems = filteredItems.map((item) {
            return _InventorySheetCard(
              sheet: item,
              warehouseName: _getWarehouseName(item.warehouseId),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MobileInventorySheetDetailScreen(sheet: item),
                  ),
                ).then((_) {
                  _fetchFilteredSheets();
                });
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          isLoading: isLoading,
          isEmpty: isEmpty,
          onSearchChanged: _onSearchChanged,
          filterOptions: const [],
          selectedFilter: _selectedStatus ?? 'Tous',
          onFilterChanged: (val) {
            setState(() => _selectedStatus = val == 'Tous' ? null : val);
            _fetchFilteredSheets();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            entityLabel: null,
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredSheets();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredSheets();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Validé', 'Annulé'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredSheets();
            },
            onResetFilters: () {
              setState(() {
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredSheets();
            },
            itemCount: totalMatchingCount,
          ),
          onRefresh: () async {
            context.read<InventorySheetsBloc>().add(ResetInventorySheetsPagination(
              searchQuery: _searchQuery,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              status: _selectedStatus,
            ));
            _loadWarehouses();
          },
          scrollController: _scrollController,
          emptyMessage: 'Aucune fiche trouvée.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileInventorySheetFormScreen()),
            ).then((_) {
              _fetchFilteredSheets();
            });
          },
          activeModule: widget.activeModule,
          onModuleSelected: (m) {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...listItems,
              if (isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InventorySheetCard extends StatelessWidget {
  final InventorySheet sheet;
  final String warehouseName;
  final VoidCallback onTap;

  const _InventorySheetCard({
    required this.sheet,
    required this.warehouseName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(sheet.status.toString());
    final statusText = translateStatus(sheet.status.toString());
    
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Ref Badge + Status Chip + Chevron Right Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sheet.number,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                // Row 1: Long Date & Time
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      formatDateTimeLong(sheet.date),
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 2: Warehouse / Agent Name on left + Article count on right
                Row(
                  children: [
                    Icon(Icons.store_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (sheet.countedBy != null && sheet.countedBy!.isNotEmpty)
                            ? sheet.countedBy!
                            : warehouseName,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${sheet.items.length} article${sheet.items.length > 1 ? 's' : ''}',
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'validated':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'draft':
      default:
        return AppColors.textSecondary;
    }
  }
}
