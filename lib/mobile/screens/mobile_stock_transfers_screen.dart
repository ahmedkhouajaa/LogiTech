import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../utils/helpers.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/stock_transfers/stock_transfers_bloc.dart';
import '../../services/sync_service.dart';
import 'forms/mobile_stock_transfer_form_screen.dart';
import 'mobile_stock_transfer_detail_screen.dart';
import '../../models/stock_transfer.dart';
import '../../services/firestore_pagination_service.dart';

class MobileStockTransfersScreen extends StatefulWidget {
  final AppModule activeModule;
  const MobileStockTransfersScreen({super.key, this.activeModule = AppModule.stockTransfer});

  @override
  State<MobileStockTransfersScreen> createState() => _MobileStockTransfersScreenState();
}

class _MobileStockTransfersScreenState extends State<MobileStockTransfersScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _selectedStatus;
  late MobileModuleConfig _config;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(widget.activeModule);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredTransfers();
    _scrollController.addListener(_onScroll);

    _syncSubscription = SyncService.instance.onSyncStatusChanged.listen((status) {
      if (status == SyncStatus.success && mounted) {
        _fetchFilteredTransfers();
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
      context.read<StockTransfersBloc>().add(LoadNextStockTransfers(
        searchQuery: _searchQuery,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredTransfers() {
    context.read<StockTransfersBloc>().add(LoadFirstStockTransfers(
      searchQuery: _searchQuery,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _selectedStatus,
    ));
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredTransfers();
  }

  void _handleDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet élément ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              context.read<StockTransfersBloc>().add(DeleteStockTransfer(id));
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StockTransfersBloc, StockTransfersState>(
      builder: (context, state) {
        bool isLoading = state is StockTransfersLoading || state is StockTransfersInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        if (state is StockTransfersLoaded) {
          final items = state.transfers;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((item) {
            String reference = item.number;
            String reason = item.reason ?? '';
            String notes = item.notes ?? '';

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              if (!reference.toLowerCase().contains(query) &&
                  !reason.toLowerCase().contains(query) &&
                  !notes.toLowerCase().contains(query)) {
                return false;
              }
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
          
          cards = filteredItems.map((item) {
            return _MobileStockTransferCard(
              transfer: item,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileStockTransferDetailScreen(transfer: item)),
                ).then((_) {
                  _fetchFilteredTransfers();
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileStockTransferFormScreen(existing: item)),
                ).then((_) {
                  _fetchFilteredTransfers();
                });
              },
              onDelete: () => _handleDelete(item.id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: widget.activeModule,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<StockTransfersBloc>().add(ResetStockTransfersPagination(
              searchQuery: _searchQuery,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              status: _selectedStatus,
            ));
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const [],
          selectedFilter: _selectedStatus ?? 'Tous',
          onFilterChanged: (val) {
            setState(() => _selectedStatus = val == 'Tous' ? null : val);
            _fetchFilteredTransfers();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            entityLabel: null,
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredTransfers();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredTransfers();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Validé', 'Annulé'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredTransfers();
            },
            onResetFilters: () {
              setState(() {
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredTransfers();
            },
            itemCount: totalMatchingCount,
          ),
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun bon de transfert trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileStockTransferFormScreen()),
            ).then((_) {
              _fetchFilteredTransfers();
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...cards,
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

class _MobileStockTransferCard extends StatelessWidget {
  final StockTransfer transfer;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileStockTransferCard({
    required this.transfer,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(transfer.status);
    final statusText = translateStatus(transfer.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      transfer.number.isNotEmpty ? transfer.number : 'BT-${transfer.date.year}-00000',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (transfer.reason != null && transfer.reason!.isNotEmpty) ...[
                Text(
                  transfer.reason!,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    formatDate(transfer.date),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '${transfer.items.length} article${transfer.items.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
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
