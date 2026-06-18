import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/stock/stock_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../models/stock_movement.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

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
              final matchesSearch = _searchQuery.isEmpty || 
                  (m.productName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                  (m.referenceId?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
              final matchesType = _filterType == null || m.type == _filterType;
              final matchesDate = _filterDateRange == null || 
                  (m.date.isAfter(_filterDateRange!.start.subtract(const Duration(days: 1))) && 
                   m.date.isBefore(_filterDateRange!.end.add(const Duration(days: 1))));
              return matchesSearch && matchesType && matchesDate;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Rechercher un article ou référence...',
                            prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<MovementType?>(
                          value: _filterType,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tous les types')),
                            ...MovementType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))),
                          ],
                          onChanged: (v) => setState(() => _filterType = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDateRange: _filterDateRange,
                            );
                            if (range != null) {
                              setState(() => _filterDateRange = range);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: Text(
                            _filterDateRange == null 
                                ? 'Filtrer par date' 
                                : '${formatDate(_filterDateRange!.start)} - ${formatDate(_filterDateRange!.end)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      if (_filterDateRange != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.error),
                          tooltip: 'Effacer la date',
                          onPressed: () => setState(() => _filterDateRange = null),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<StockMovement>(
                      columns: const ['Date', 'Produit', 'Entrepot', 'Type', 'Quantite', 'Reference', 'Notes'],
                      rows: filteredMovements,
                      emptyMessage: 'Aucun mouvement de stock trouve',
                      cellBuilder: (m) {
                        double val = m.quantity;
                        if (m.type == MovementType.exit && val > 0) val = -val;
                        if (m.type == MovementType.entry && val < 0) val = -val;
                        
                        String qtyStr = '';
                        Color qtyCol = AppColors.textPrimary;
                        if (val > 0) { qtyStr = '+${formatQuantity(val)}'; qtyCol = AppColors.success; }
                        else if (val < 0) { qtyStr = '-${formatQuantity(val.abs())}'; qtyCol = AppColors.error; }
                        else { qtyStr = formatQuantity(val); }

                        return [
                          DataCell(Text(formatDate(m.date), style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(m.productName ?? '—', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(m.warehouseName ?? '—')),
                          DataCell(StatusBadge(
                            label: m.type.label,
                            color: m.type == MovementType.entry ? AppColors.success : m.type == MovementType.exit ? AppColors.error : AppColors.warning,
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: qtyCol.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(qtyStr, style: TextStyle(fontWeight: FontWeight.bold, color: qtyCol)),
                          )),
                          DataCell(Text(m.referenceId != null ? '${m.referenceType ?? ''} ${m.referenceId}' : '—', style: const TextStyle(color: AppColors.textSecondary))),
                          DataCell(Text(m.notes ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary))),
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
