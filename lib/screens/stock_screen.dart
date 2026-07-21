import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/stock/stock_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../widgets/custom_date_range_picker.dart';
import '../models/stock_movement.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';
import '../services/stock_export_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  @override
  void initState() {
    super.initState();
    context.read<StockBloc>().add(LoadStock());
    context.read<ProductsBloc>().add(LoadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, state) {
        if (state is StockLoading) return const Center(child: CircularProgressIndicator());
        if (state is StockError) return Center(child: Text('Erreur: ${state.message}'));
        if (state is StockLoaded) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Vue d\'ensemble du Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => const _StockAdjustmentDialog()),
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text('Nouvel ajustement de stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: DashboardCard(
                      title: 'Valeur du stock',
                      value: formatCurrencyCompact(state.totalStockValue),
                      icon: Icons.inventory_rounded,
                      gradientColors: const [Color(0xFF1a56db), Color(0xFF3B82F6)],
                    )),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: DashboardCard(
                      title: 'Entrepots',
                      value: state.warehouses.length.toString(),
                      icon: Icons.warehouse_rounded,
                      gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                    )),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: DashboardCard(
                      title: 'Mouvements (total)',
                      value: state.movements.length.toString(),
                      icon: Icons.swap_horiz_rounded,
                      gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                    )),
                    const SizedBox(width: AppSpacing.md),
                    BlocBuilder<ProductsBloc, ProductsState>(
                      builder: (context, pState) {
                        final lowCount = pState is ProductsLoaded ? pState.lowStockProducts.length : 0;
                        return Expanded(child: DashboardCard(
                          title: 'Alertes stock bas',
                          value: lowCount.toString(),
                          icon: Icons.warning_rounded,
                          gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                        ));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Low stock products
                BlocBuilder<ProductsBloc, ProductsState>(
                  builder: (context, pState) {
                    if (pState is! ProductsLoaded || pState.lowStockProducts.isEmpty) return const SizedBox();
                    return AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SectionHeader(
                              title: 'Produits en stock bas',
                              icon: Icons.warning_amber_rounded,
                              action: StatusBadge(label: '${pState.lowStockProducts.length} alertes', color: AppColors.error),
                            ),
                          ),
                          const Divider(height: 1),
                          DataTableWidget<Product>(
                            columns: const ['Code', 'Nom', 'Stock actuel', 'Minimum', 'Unite', 'Categorie'],
                            rows: pState.lowStockProducts,
                            emptyMessage: '',
                            cellBuilder: (p) => [
                              DataCell(Text(p.code, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                              DataCell(Text(p.name)),
                              DataCell(Text('${formatQuantity(p.stockQty)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
                              DataCell(Text('${formatQuantity(p.minStockQty)}')),
                              DataCell(Text(p.unit)),
                              DataCell(Text(p.category ?? '—')),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                // Niveaux de stock actuels
                BlocBuilder<ProductsBloc, ProductsState>(
                  builder: (context, pState) {
                    if (pState is! ProductsLoaded) return const SizedBox();
                    return _StockLevelsTable(
                      movements: state.movements,
                      warehouses: state.warehouses,
                      products: pState.products,
                    );
                  },
                ),
              ],
            ),
          );
        }
        return const SizedBox();
      },
    );
  }
}

class StockMovementsScreen extends StatefulWidget {
  const StockMovementsScreen({super.key});
  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  String _searchQuery = '';
  MovementType? _filterType;
  DateTimeRange? _filterDateRange;
  String? _filterWarehouseId;
  String _filterReference = '';

  @override
  void initState() {
    super.initState();
    context.read<StockBloc>().add(LoadStock());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          if (state is StockLoading) return const Center(child: CircularProgressIndicator());
          if (state is StockLoaded) {
            final filteredMovements = state.movements.where((m) {
              if (m.type == MovementType.transfer_in) return false;
              
              final matchesProduct = _searchQuery.isEmpty || 
                  (m.productName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                  
              final matchesRef = _filterReference.isEmpty ||
                  (m.referenceId?.toLowerCase().contains(_filterReference.toLowerCase()) ?? false);
                  
              final matchesWarehouse = _filterWarehouseId == null || 
                  m.warehouseId == _filterWarehouseId || 
                  (m.warehouseId == 'default_warehouse' && state.warehouses.any((w) => w.id == _filterWarehouseId && w.isDefault));
                  
              final matchesType = _filterType == null || 
                  m.type == _filterType || 
                  (_filterType == MovementType.transfer && (m.type == MovementType.transfer_in || m.type == MovementType.transfer_out));
                  
              final matchesDate = _filterDateRange == null || 
                  (m.date.isAfter(_filterDateRange!.start.subtract(const Duration(days: 1))) && 
                   m.date.isBefore(_filterDateRange!.end.add(const Duration(days: 1))));
                   
              return matchesProduct && matchesRef && matchesWarehouse && matchesType && matchesDate;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Entrepôt
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Entrepôt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                                  ...state.warehouses.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (v) => setState(() => _filterWarehouseId = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Type de mouvement', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 36,
                              child: DropdownButtonFormField<MovementType?>(
                                value: _filterType,
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
                                  const DropdownMenuItem(value: null, child: Text('Tous les types', style: TextStyle(fontSize: 13))),
                                  ...[MovementType.entry, MovementType.exit, MovementType.transfer, MovementType.adjustment].map((t) => DropdownMenuItem(value: t, child: Text(t.label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (v) => setState(() => _filterType = v),
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
                            const Text('Article', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 36,
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Rechercher produit...',
                                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                  prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textTertiary),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 36),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Référence
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Référence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 36,
                              child: TextField(
                                onChanged: (v) => setState(() => _filterReference = v),
                                decoration: InputDecoration(
                                  hintText: 'Rechercher réf...',
                                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                  prefixIcon: const Icon(Icons.tag, size: 16, color: AppColors.textTertiary),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 36),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(fontSize: 13),
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
                            const Text('Période', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  side: const BorderSide(color: AppColors.border),
                                  backgroundColor: Colors.white,
                                  alignment: Alignment.centerLeft,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _filterDateRange == null 
                                            ? 'Toutes les dates' 
                                            : '${formatDate(_filterDateRange!.start)} - ${formatDate(_filterDateRange!.end)}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_filterDateRange != null)
                                      GestureDetector(
                                        onTap: () => setState(() => _filterDateRange = null),
                                        child: const Icon(Icons.close, size: 14, color: AppColors.error),
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
                if (_filterWarehouseId != null || _filterType != null || _searchQuery.isNotEmpty || _filterReference.isNotEmpty || _filterDateRange != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${filteredMovements.length} résultat${filteredMovements.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _filterWarehouseId = null;
                            _filterType = null;
                            _searchQuery = '';
                            _filterReference = '';
                            _filterDateRange = null;
                          }),
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Réinitialiser les filtres', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<StockMovement>(
                      columns: const ['Date', 'Produit', 'Entrepot', 'Type', 'Quantite', 'Reference'],
                      rows: filteredMovements,
                      emptyMessage: 'Aucun mouvement de stock trouve',
                      cellBuilder: (m) {
                        double val = m.quantity;
                        if (m.type == MovementType.exit && val > 0) val = -val;
                        if (m.type == MovementType.entry && val < 0) val = -val;
                        
                        String qtyStr = '';
                        Color qtyCol = AppColors.textPrimary;
                        if (m.type == MovementType.adjustment) {
                          qtyStr = val > 0 ? '+${formatQuantity(val)}' : (val < 0 ? '-${formatQuantity(val.abs())}' : formatQuantity(val));
                          qtyCol = val > 0 ? AppColors.success : (val < 0 ? AppColors.error : AppColors.textPrimary);
                        } else if (m.type == MovementType.transfer || m.type == MovementType.transfer_out || m.type == MovementType.transfer_in) {
                          qtyStr = formatQuantity(val.abs());
                        } else if (val > 0) { 
                          qtyStr = '+${formatQuantity(val)}'; qtyCol = AppColors.success; 
                        } else if (val < 0) { 
                          qtyStr = '-${formatQuantity(val.abs())}'; qtyCol = AppColors.error; 
                        } else { 
                          qtyStr = formatQuantity(val); 
                        }

                        IconData typeIcon = Icons.tune_rounded;
                        Color typeColor = AppColors.textSecondary;
                        if (m.type == MovementType.entry) {
                          typeIcon = Icons.arrow_downward_rounded;
                          typeColor = AppColors.success;
                        } else if (m.type == MovementType.exit) {
                          typeIcon = Icons.arrow_upward_rounded;
                          typeColor = AppColors.error;
                        } else if (m.type == MovementType.transfer || m.type == MovementType.transfer_in || m.type == MovementType.transfer_out) {
                          typeIcon = Icons.swap_horiz_rounded;
                        }

                        return [
                          DataCell(Text(formatDate(m.date), style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(SizedBox(width: 180, child: Text(m.productName ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)))),
                          DataCell(SizedBox(width: 200, child: Text(m.warehouseName ?? '—'))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon, size: 16, color: typeColor),
                                const SizedBox(width: 6),
                                Text(m.type.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            )
                          ),
                          DataCell(Text(qtyStr, style: TextStyle(fontWeight: FontWeight.bold, color: qtyCol))),
                          DataCell(SizedBox(width: 200, child: Text(m.referenceId != null ? '${m.referenceType ?? ''} ${m.referenceId}' : '—', style: const TextStyle(color: AppColors.textSecondary)))),
                        ];
                      },
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _StockAdjustmentDialog extends StatefulWidget {
  const _StockAdjustmentDialog();

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  Product? _selectedProduct;
  String? _selectedWarehouseId;
  String _adjustmentAction = 'add'; // add, exit, correct
  final _quantityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, stockState) {
        if (stockState is! StockLoaded) return const SizedBox();

        // Si aucun entrepôt n'est sélectionné, en prendre un par défaut
        if (_selectedWarehouseId == null && stockState.warehouses.isNotEmpty) {
          _selectedWarehouseId = stockState.warehouses.first.id;
        }

        return AlertDialog(
          title: const Text('Nouvel ajustement de stock', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Article', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    BlocBuilder<ProductsBloc, ProductsState>(
                      builder: (context, pState) {
                        if (pState is! ProductsLoaded) return const CircularProgressIndicator();
                        return Autocomplete<Product>(
                          displayStringForOption: (p) => p.name,
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<Product>.empty();
                            return pState.products.where((p) =>
                                p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                p.code.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (p) {
                            setState(() {
                              _selectedProduct = p;
                              if (_adjustmentAction == 'correct') {
                                _quantityCtrl.text = p.stockQty.toString();
                              }
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Rechercher un article par nom ou code...',
                                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                filled: true,
                                fillColor: AppColors.background,
                              ),
                              validator: (v) => _selectedProduct == null ? 'Veuillez sélectionner un article' : null,
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 500),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, i) {
                                      final option = options.elementAt(i);
                                      return ListTile(
                                        title: Text(option.name, style: const TextStyle(fontSize: 13)),
                                        subtitle: Text('Stock actuel : ${option.stockQty} ${option.unit}', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                                        onTap: () => onSelected(option),
                                        dense: true,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    if (_selectedProduct != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Stock actuel : ${_selectedProduct!.stockQty} ${_selectedProduct!.unit}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Entrepôt', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedWarehouseId,
                      items: stockState.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                      onChanged: (v) => setState(() => _selectedWarehouseId = v),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      validator: (v) => v == null ? 'Sélectionner un entrepôt' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Type d\'action', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _adjustmentAction,
                                items: const [
                                  DropdownMenuItem(value: 'add', child: Text('Ajouter au stock', style: TextStyle(color: AppColors.success))),
                                  DropdownMenuItem(value: 'exit', child: Text('Retirer du stock', style: TextStyle(color: AppColors.error))),
                                  DropdownMenuItem(value: 'correct', child: Text('Corriger (Remplacer)', style: TextStyle(color: AppColors.warning))),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    _adjustmentAction = v!;
                                    if (v == 'correct' && _selectedProduct != null) {
                                      _quantityCtrl.text = _selectedProduct!.stockQty.toString();
                                    } else {
                                      _quantityCtrl.clear();
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  filled: true,
                                  fillColor: AppColors.background,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_adjustmentAction == 'correct' ? 'Nouv. Stock Réel' : 'Quantité', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _quantityCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  suffixText: _selectedProduct?.unit ?? '',
                                  filled: true,
                                  fillColor: AppColors.background,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requis';
                                  if (double.tryParse(v) == null) return 'Invalide';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Notes / Motif d\'ajustement', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: Inventaire du mois, produit cassé...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary))
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _save(context, stockState.warehouses);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Enregistrer l\'ajustement'),
            ),
          ],
        );
      },
    );
  }

  void _save(BuildContext context, List<Warehouse> warehouses) {
    final qtyInput = double.parse(_quantityCtrl.text);
    double qtyToRegister = 0;
    MovementType type = MovementType.adjustment;

    if (_adjustmentAction == 'correct') {
      final diff = qtyInput - _selectedProduct!.stockQty;
      qtyToRegister = diff;
      type = MovementType.adjustment;
    } else if (_adjustmentAction == 'add') {
      qtyToRegister = qtyInput;
      type = MovementType.adjustment; 
    } else {
      qtyToRegister = -qtyInput;
      type = MovementType.adjustment; 
    }

    if (qtyToRegister == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La quantité d\'ajustement ne peut pas être nulle.'), backgroundColor: AppColors.warning));
      return;
    }

    final movement = StockMovement(
      id: _uuid.v4(),
      productId: _selectedProduct!.id,
      productName: _selectedProduct!.name,
      warehouseId: _selectedWarehouseId!,
      warehouseName: warehouses.firstWhere((w) => w.id == _selectedWarehouseId).name,
      type: type,
      quantity: qtyToRegister,
      referenceType: 'Ajustement',
      date: DateTime.now(),
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : 'Ajustement manuel',
    );

    context.read<StockBloc>().add(AddStockMovement(movement));
    context.read<ProductsBloc>().add(LoadProducts());

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustement de stock enregistré avec succès'), backgroundColor: AppColors.success));
  }
}

class StockLevelItem {
  final Product product;
  final Warehouse warehouse;
  final double quantity;
  StockLevelItem({required this.product, required this.warehouse, required this.quantity});
}

class _StockLevelsTable extends StatefulWidget {
  final List<StockMovement> movements;
  final List<Warehouse> warehouses;
  final List<Product> products;
  
  const _StockLevelsTable({required this.movements, required this.warehouses, required this.products});
  
  @override
  State<_StockLevelsTable> createState() => _StockLevelsTableState();
}

class _StockLevelsTableState extends State<_StockLevelsTable> {
  int _rowsPerPage = 10;
  int _currentPage = 0;
  
  // Filter state
  String? _filterWarehouseId;
  String _filterDestination = 'tous'; // 'tous', 'vente', 'achat'
  String _filterProduct = '';
  String _filterReference = '';
  String _filterStatus = 'tous'; // 'tous', 'en_stock', 'rupture'
  
  @override
  Widget build(BuildContext context) {
    List<StockLevelItem> items = [];
    for (var p in widget.products) {
      for (var w in widget.warehouses) {
        double stock = 0;
        for (var m in widget.movements) {
          final isMatch = m.warehouseId == w.id || (m.warehouseId == 'default_warehouse' && w.isDefault);
          if (m.productId == p.id && isMatch) {
            if (m.type == MovementType.entry || m.type == MovementType.transfer_in) stock += m.quantity;
            else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) stock -= m.quantity;
            else if (m.type == MovementType.adjustment) stock += m.quantity;
          }
        }
        items.add(StockLevelItem(product: p, warehouse: w, quantity: stock));
      }
    }

    // Apply filters
    List<StockLevelItem> filteredItems = items.where((item) {
      // Warehouse filter
      if (_filterWarehouseId != null && item.warehouse.id != _filterWarehouseId) return false;
      
      // Destination filter (vente = sellingPrice > 0, achat = purchasePrice > 0)
      if (_filterDestination == 'vente' && item.product.sellingPrice <= 0) return false;
      if (_filterDestination == 'achat' && item.product.purchasePrice <= 0) return false;
      
      // Product name filter
      if (_filterProduct.isNotEmpty && !item.product.name.toLowerCase().contains(_filterProduct.toLowerCase())) return false;
      
      // Reference filter
      if (_filterReference.isNotEmpty) {
        final ref = item.product.reference ?? item.product.code;
        if (!ref.toLowerCase().contains(_filterReference.toLowerCase())) return false;
      }
      
      // Status filter
      if (_filterStatus == 'en_stock' && item.quantity <= 0) return false;
      if (_filterStatus == 'rupture' && item.quantity > 0) return false;
      
      return true;
    }).toList();

    final totalItems = filteredItems.length;
    final totalPages = (totalItems / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
    final currentPageItems = totalItems > 0 ? filteredItems.sublist(startIndex, endIndex) : <StockLevelItem>[];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Niveaux de Stock Actuels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('Voir les niveaux de stock actuels pour tous les produits', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'pdf') {
                      await StockExportService.exportToPdf(context, filteredItems);
                    } else if (value == 'excel') {
                      await StockExportService.exportToExcel(context, filteredItems);
                    }
                  },
                  offset: const Offset(0, 40),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 18),
                          SizedBox(width: 8),
                          Text('Exporter en PDF'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'excel',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart, size: 18),
                          SizedBox(width: 8),
                          Text('Exporter en Excel'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.download_rounded, size: 16, color: AppColors.textPrimary),
                        SizedBox(width: 8),
                        Text('Exporter', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Filter Bar ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFB),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Entrepot filter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Entrepôt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                                ...widget.warehouses.map((w) => DropdownMenuItem<String?>(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 13)))),
                              ],
                              onChanged: (v) => setState(() { _filterWarehouseId = v; _currentPage = 0; }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Destination filter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Destination', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 36,
                            child: DropdownButtonFormField<String>(
                              value: _filterDestination,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              items: const [
                                DropdownMenuItem(value: 'tous', child: Text('Toutes', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'vente', child: Text('Vente', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'achat', child: Text('Achat', style: TextStyle(fontSize: 13))),
                              ],
                              onChanged: (v) => setState(() { _filterDestination = v ?? 'tous'; _currentPage = 0; }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Product filter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Produit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 36,
                            child: TextField(
                              onChanged: (v) => setState(() { _filterProduct = v; _currentPage = 0; }),
                              decoration: InputDecoration(
                                hintText: 'Rechercher produit...',
                                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textTertiary),
                                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Reference filter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Référence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 36,
                            child: TextField(
                              onChanged: (v) => setState(() { _filterReference = v; _currentPage = 0; }),
                              decoration: InputDecoration(
                                hintText: 'Rechercher réf...',
                                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                prefixIcon: const Icon(Icons.tag, size: 16, color: AppColors.textTertiary),
                                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status filter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Statut', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 36,
                            child: DropdownButtonFormField<String>(
                              value: _filterStatus,
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              items: const [
                                DropdownMenuItem(value: 'tous', child: Text('Tous les Statuts', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'en_stock', child: Text('En Stock', style: TextStyle(fontSize: 13, color: AppColors.success))),
                                DropdownMenuItem(value: 'rupture', child: Text('En Rupture', style: TextStyle(fontSize: 13, color: AppColors.error))),
                              ],
                              onChanged: (v) => setState(() { _filterStatus = v ?? 'tous'; _currentPage = 0; }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Active filters indicator + reset
                if (_filterWarehouseId != null || _filterDestination != 'tous' || _filterProduct.isNotEmpty || _filterReference.isNotEmpty || _filterStatus != 'tous')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$totalItems résultat${totalItems > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _filterWarehouseId = null;
                            _filterDestination = 'tous';
                            _filterProduct = '';
                            _filterReference = '';
                            _filterStatus = 'tous';
                            _currentPage = 0;
                          }),
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Réinitialiser les filtres', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Référence', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Entrepôt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('Disponible', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('Réservé', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                SizedBox(width: 100, child: Text('Statut', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
              ],
            ),
          ),
          // Table body
          if (filteredItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text("Aucun produit trouvé.", style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentPageItems.length,
              itemBuilder: (context, index) {
                final item = currentPageItems[index];
                return Container(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                              child: const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(item.product.name, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(item.product.reference ?? item.product.code, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text(item.warehouse.name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                      Expanded(flex: 1, child: Text(formatQuantity(item.quantity), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                      const Expanded(flex: 1, child: Text('0', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: AppColors.error))),
                      Expanded(flex: 1, child: Text(formatQuantity(item.quantity), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
                      SizedBox(
                        width: 100,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.quantity > 0 ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.quantity > 0 ? 'En Stock' : 'En Rupture',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: item.quantity > 0 ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          // Pagination
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('Lignes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
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
                  const Spacer(),
                  Text('Page ${_currentPage + 1} sur $totalPages', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 24),
                  Row(
                    children: [
                      InkWell(
                        onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(border: Border.all(color: _currentPage > 0 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(4)),
                          child: Icon(Icons.chevron_left, size: 20, color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textTertiary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(border: Border.all(color: _currentPage < totalPages - 1 ? AppColors.border : AppColors.border.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(4)),
                          child: Icon(Icons.chevron_right, size: 20, color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
