import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/stock/stock_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../models/stock_movement.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../utils/mobile_module_config.dart';
import 'forms/mobile_stock_adjustment_form.dart';

class MobileStockMovementsScreen extends StatefulWidget {
  const MobileStockMovementsScreen({super.key});

  @override
  State<MobileStockMovementsScreen> createState() => _MobileStockMovementsScreenState();
}

class _MobileStockMovementsScreenState extends State<MobileStockMovementsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.stockMovements);
    context.read<StockBloc>().add(LoadStock());
    context.read<ProductsBloc>().add(LoadProducts());
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
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, state) {
        bool isLoading = state is StockLoading || state is StockInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is StockLoaded) {
          final movements = List<StockMovement>.from(state.movements);
          // Sort by date descending
          movements.sort((a, b) => b.date.compareTo(a.date));
          
          final filteredItems = movements.where((item) {
            bool matchesSearch = true;
            bool matchesFilter = true;

            // Search filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final pName = item.productName?.toLowerCase() ?? '';
              final ref = item.referenceId?.toLowerCase() ?? '';
              final notes = item.notes?.toLowerCase() ?? '';
              
              if (!pName.contains(query) && !ref.contains(query) && !notes.contains(query)) {
                matchesSearch = false;
              }
            }

            // Type filter
            if (_selectedFilter != 'Tous') {
              if (item.type.label.toLowerCase() != _selectedFilter.toLowerCase()) {
                matchesFilter = false;
              }
            }

            return matchesSearch && matchesFilter;
          }).toList();
          
          isEmpty = filteredItems.isEmpty;
          
          cards = filteredItems.map((item) {
            return _MobileStockMovementCard(movement: item, warehouses: state.warehouses);
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.stockMovements,
          onModuleSelected: (module) {
            // Handled by shell
          },
          onRefresh: () {
            context.read<StockBloc>().add(LoadStock());
            context.read<ProductsBloc>().add(LoadProducts());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: _config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun mouvement de stock trouvé.',
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileStockAdjustmentForm()),
            ).then((_) {
              if (context.mounted) {
                context.read<StockBloc>().add(LoadStock());
                context.read<ProductsBloc>().add(LoadProducts());
              }
            });
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16, top: 8),
            children: cards,
          ),
        );
      },
    );
  }
}

class _MobileStockMovementCard extends StatelessWidget {
  final StockMovement movement;
  final List<Warehouse> warehouses;

  const _MobileStockMovementCard({required this.movement, required this.warehouses});

  @override
  Widget build(BuildContext context) {
    double val = movement.quantity;
    if (movement.type == MovementType.exit && val > 0) val = -val;
    if (movement.type == MovementType.entry && val < 0) val = -val;
    
    String qtyStr = '';
    Color qtyCol = AppColors.textPrimary;
    Color statusColor = AppColors.textPrimary;
    
    if (movement.type == MovementType.adjustment) {
      qtyStr = val > 0 ? '+${formatQuantity(val)}' : (val < 0 ? '-${formatQuantity(val.abs())}' : formatQuantity(val));
      qtyCol = AppColors.textSecondary;
      statusColor = AppColors.textSecondary;
    } else if (movement.type == MovementType.transfer || movement.type == MovementType.transfer_out || movement.type == MovementType.transfer_in) {
      qtyStr = formatQuantity(val.abs());
      qtyCol = AppColors.info;
      statusColor = AppColors.warning;
    } else if (val > 0) { 
      qtyStr = '+${formatQuantity(val)}'; 
      qtyCol = AppColors.success; 
      statusColor = AppColors.success;
    } else if (val < 0) { 
      qtyStr = '-${formatQuantity(val.abs())}'; 
      qtyCol = AppColors.error; 
      statusColor = AppColors.error;
    } else { 
      qtyStr = formatQuantity(val); 
      statusColor = AppColors.textPrimary;
    }

    String warehouseName = movement.warehouseName ?? '—';
    if (warehouseName == '—' && movement.warehouseId.isNotEmpty) {
      if (movement.warehouseId == 'default_warehouse') {
        final w = warehouses.where((w) => w.isDefault).firstOrNull ?? warehouses.firstOrNull;
        if (w != null) warehouseName = w.name;
      } else {
        final w = warehouses.where((w) => w.id == movement.warehouseId).firstOrNull;
        if (w != null) warehouseName = w.name;
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Date & Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    formatDate(movement.date),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    movement.type.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Product Name & Quantity
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement.productName ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.warehouse_outlined, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              warehouseName,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: qtyCol.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    qtyStr,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: qtyCol),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 3: Reference & Notes (if any)
            if ((movement.referenceId != null && movement.referenceId!.isNotEmpty) || (movement.notes != null && movement.notes!.isNotEmpty)) ...[
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (movement.referenceId != null && movement.referenceId!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${movement.referenceType ?? ''} ${movement.referenceId}'.trim(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (movement.notes != null && movement.notes!.isNotEmpty) const SizedBox(height: 6),
              ],
              if (movement.notes != null && movement.notes!.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        movement.notes!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
