import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../../utils/helpers.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/inventory_sheets/inventory_sheets_bloc.dart';
import '../../blocs/inventory_sheets/inventory_sheets_event.dart';
import '../../blocs/inventory_sheets/inventory_sheets_state.dart';
import '../../services/sync_service.dart';
import 'forms/mobile_inventory_sheet_form_screen.dart';
import 'mobile_inventory_sheet_detail_screen.dart';
import '../../models/inventory_sheet.dart';

class MobileInventorySheetsScreen extends StatefulWidget {
  final AppModule activeModule;
  const MobileInventorySheetsScreen({super.key, this.activeModule = AppModule.inventorySheet});

  @override
  State<MobileInventorySheetsScreen> createState() => _MobileInventorySheetsScreenState();
}

class _MobileInventorySheetsScreenState extends State<MobileInventorySheetsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(widget.activeModule);
    context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());

    _syncSubscription = SyncService.instance.onSyncStatusChanged.listen((status) {
      if (status == SyncStatus.success && mounted) {
        context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventorySheetsBloc, InventorySheetsState>(
      builder: (context, state) {
        bool isLoading = state is InventorySheetsLoading;
        bool isEmpty = false;
        List<Widget> listItems = [];

        if (state is InventorySheetsLoaded) {
          final items = state.sheets;
          final filteredItems = items.where((item) {
            bool matchesSearch = item.number.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (item.reason?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
            
            bool matchesFilter = true;
            String statusStr = 'N/A';
            try {
              final s = item.status;
              statusStr = translateStatus(s.toString());
            } catch (_) {}
            
            if (_selectedFilter != 'Tous') {
               if (statusStr.toLowerCase() != _selectedFilter.toLowerCase()) {
                   matchesFilter = false;
               }
            }
            return matchesSearch && matchesFilter;
          }).toList();
          
          isEmpty = filteredItems.isEmpty;

          listItems = filteredItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InventorySheetCard(
                sheet: item,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MobileInventorySheetDetailScreen(sheet: item),
                    ),
                  ).then((_) {
                    if (context.mounted) {
                      context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());
                    }
                  });
                },
              ),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          isLoading: isLoading,
          isEmpty: isEmpty,
          onSearchChanged: _onSearchChanged,
          filterOptions: _config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          onRefresh: () async {
            await SyncService.instance.triggerSync();
            if (context.mounted) {
              context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());
            }
          },
          emptyMessage: 'Aucune fiche trouvée',
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileInventorySheetFormScreen()),
            ).then((_) {
              if (context.mounted) {
                context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());
              }
            });
          },
          activeModule: widget.activeModule,
          onModuleSelected: (m) {},
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: listItems,
          ),
        );
      },
    );
  }
}

class _InventorySheetCard extends StatelessWidget {
  final InventorySheet sheet;
  final VoidCallback onTap;

  const _InventorySheetCard({required this.sheet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(sheet.status.toString());
    final statusText = translateStatus(sheet.status.toString());
    final dateStr = formatDate(sheet.date);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sheet.number,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(Icons.calendar_today_rounded, dateStr),
                    ),
                    Expanded(
                      child: _buildInfoRow(Icons.person_outline, sheet.countedBy?.isNotEmpty == true ? sheet.countedBy! : 'Non spécifié'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(Icons.inventory_2_outlined, '${sheet.items.length} articles'),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'validated':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }
}
