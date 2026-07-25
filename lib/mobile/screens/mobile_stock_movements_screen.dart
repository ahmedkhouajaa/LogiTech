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
import '../../services/sync_service.dart';
import '../../widgets/custom_date_range_picker.dart';
class MobileStockMovementsScreen extends StatefulWidget {
  const MobileStockMovementsScreen({super.key});

  @override
  State<MobileStockMovementsScreen> createState() => _MobileStockMovementsScreenState();
}

class _MobileStockMovementsScreenState extends State<MobileStockMovementsScreen> {
  String _searchQuery = '';
  
  // Filter state
  String? _filterWarehouseId;
  MovementType? _filterType;
  String _filterReference = '';
  DateTimeRange? _filterDateRange;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    context.read<StockBloc>().add(LoadStock());
    context.read<ProductsBloc>().add(LoadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is StockLoading || state is StockInitial) {
            return Center(child: CircularProgressIndicator());
          }
          if (state is StockError) {
            return Center(child: Text('Erreur: ${state.message}'));
          }
          if (state is StockLoaded) {
            final movements = List<StockMovement>.from(state.movements);
            movements.sort((a, b) => b.date.compareTo(a.date));

            final filteredItems = movements.where((item) {
              if (item.type == MovementType.transfer_in) return false;
              
              final matchesProduct = _searchQuery.isEmpty || 
                  (item.productName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                  
              final matchesRef = _filterReference.isEmpty ||
                  (item.referenceId?.toLowerCase().contains(_filterReference.toLowerCase()) ?? false);
                  
              final matchesWarehouse = _filterWarehouseId == null || 
                  item.warehouseId == _filterWarehouseId || 
                  (item.warehouseId == 'default_warehouse' && state.warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault));
                  
              final matchesType = _filterType == null || 
                  item.type == _filterType || 
                  (_filterType == MovementType.transfer && (item.type == MovementType.transfer_in || item.type == MovementType.transfer_out));
                  
              final matchesDate = _filterDateRange == null || 
                  (item.date.isAfter(_filterDateRange!.start.subtract(const Duration(days: 1))) && 
                   item.date.isBefore(_filterDateRange!.end.add(const Duration(days: 1))));
                   
              return matchesProduct && matchesRef && matchesWarehouse && matchesType && matchesDate;
            }).toList();

            final hasActiveFilters = _filterWarehouseId != null || 
                _filterType != null || 
                _filterReference.isNotEmpty || 
                _filterDateRange != null;

            return RefreshIndicator(
              onRefresh: () async {
                await SyncService.instance.triggerSync();
                if (!context.mounted) return;
                context.read<StockBloc>().add(LoadStock());
                context.read<ProductsBloc>().add(LoadProducts());
              },
              child: ListView(
                padding: EdgeInsets.only(bottom: 100),
                children: [
                  // Title
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'Mouvements de Stock',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  // Search bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),

                  // Filter Toggle Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _showFilters = !_showFilters),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _showFilters || hasActiveFilters ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _showFilters || hasActiveFilters ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded, size: 16, color: _showFilters || hasActiveFilters ? AppColors.primary : AppColors.textSecondary),
                                SizedBox(width: 6),
                                Text(
                                  'Filtres',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _showFilters || hasActiveFilters ? AppColors.primary : AppColors.textSecondary),
                                ),
                                if (hasActiveFilters) ...[
                                  SizedBox(width: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      '${[_filterWarehouseId != null, _filterType != null, _filterReference.isNotEmpty, _filterDateRange != null].where((v) => v).length}',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (hasActiveFilters) ...[
                          SizedBox(width: 8),
                          // Results count pill
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${filteredItems.length} résultat${filteredItems.length > 1 ? 's' : ''}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              _filterWarehouseId = null;
                              _filterType = null;
                              _filterReference = '';
                              _filterDateRange = null;
                            }),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.clear_all, size: 14, color: AppColors.error),
                                  SizedBox(width: 4),
                                  Text('Réinitialiser', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Collapsible Filter Panel
                  if (_showFilters) ...[
                    SizedBox(height: 8),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Row 1: Entrepôt + Type
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Entrepôt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                    SizedBox(height: 4),
                                    SizedBox(
                                      height: 40,
                                      child: DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  
                                        value: _filterWarehouseId,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                                          filled: true,
                                          fillColor: Color(0xFFFAFAFB),
                                        ),
                                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        items: [
                                          const DropdownMenuItem<String?>(value: null, child: Text('Tous', style: TextStyle(fontSize: 12))),
                                          ...state.warehouses.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text(w.name, style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                                        ],
                                        onChanged: (v) => setState(() => _filterWarehouseId = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                    SizedBox(height: 4),
                                    SizedBox(
                                      height: 40,
                                      child: DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  
                                        value: _filterType,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                                          filled: true,
                                          fillColor: Color(0xFFFAFAFB),
                                        ),
                                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        items: [
                                          DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(fontSize: 12))),
                                          ...[MovementType.entry, MovementType.exit, MovementType.transfer, MovementType.adjustment].map((t) => DropdownMenuItem(value: t, child: Text(t.label, style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                                        ],
                                        onChanged: (v) => setState(() => _filterType = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          // Row 2: Reference + Date
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Référence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                    SizedBox(height: 4),
                                    SizedBox(
                                      height: 40,
                                      child: TextField(
                                        onChanged: (v) => setState(() => _filterReference = v),
                                        decoration: InputDecoration(
                                          hintText: 'Rechercher réf...',
                                          hintStyle: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                          prefixIcon: Icon(Icons.tag, size: 14, color: AppColors.textTertiary),
                                          prefixIconConstraints: BoxConstraints(minWidth: 32),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                                          filled: true,
                                          fillColor: const Color(0xFFFAFAFB),
                                        ),
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Période', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                    SizedBox(height: 4),
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
                                          padding: EdgeInsets.symmetric(horizontal: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          side: BorderSide(color: AppColors.border),
                                          backgroundColor: Color(0xFFFAFAFB),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textTertiary),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _filterDateRange == null 
                                                    ? 'Toutes dates' 
                                                    : '${formatDate(_filterDateRange!.start)} - ${formatDate(_filterDateRange!.end)}',
                                                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
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
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 12),

                  // List Content
                  if (filteredItems.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                            SizedBox(height: 8),
                            Text('Aucun mouvement trouvé.', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${filteredItems.length} mouvements',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          SizedBox(height: 8),
                          ...filteredItems.map((item) => _MobileStockMovementCard(movement: item, warehouses: state.warehouses)),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }
          return SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
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
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Nouvel ajustement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
      ),
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
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
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
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            SizedBox(height: 12),
            // Row 2: Product Name & Quantity
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textSecondary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement.productName ?? '—',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.warehouse_outlined, size: 14, color: AppColors.textTertiary),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              warehouseName,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            SizedBox(height: 12),
            // Row 3: Reference & Notes (if any)
            if ((movement.referenceId != null && movement.referenceId!.isNotEmpty) || (movement.notes != null && movement.notes!.isNotEmpty)) ...[
              Divider(height: 1),
              SizedBox(height: 12),
              if (movement.referenceId != null && movement.referenceId!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.textTertiary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${movement.referenceType ?? ''} ${movement.referenceId}'.trim(),
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (movement.notes != null && movement.notes!.isNotEmpty) SizedBox(height: 6),
              ],
              if (movement.notes != null && movement.notes!.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 14, color: AppColors.textTertiary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        movement.notes!,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
