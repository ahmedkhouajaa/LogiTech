import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                  children: [
                    Expanded(child: DashboardCard(
                      title: 'Valeur du stock',
                      value: formatCurrencyCompact(state.totalStockValue),
                      icon: Icons.inventory_rounded,
                      gradientColors: const [Color(0xFF1a56db), Color(0xFF3B82F6)],
                    )),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: DashboardCard(
                      title: 'Entrepôts',
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
                            columns: const ['Code', 'Nom', 'Stock actuel', 'Minimum', 'Unité', 'Catégorie'],
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
            return AppCard(
              padding: EdgeInsets.zero,
              child: DataTableWidget<StockMovement>(
                columns: const ['Date', 'Produit', 'Entrepôt', 'Type', 'Quantité', 'Référence'],
                rows: state.movements,
                emptyMessage: 'Aucun mouvement de stock',
                cellBuilder: (m) => [
                  DataCell(Text(formatDate(m.date))),
                  DataCell(Text(m.productName ?? '—')),
                  DataCell(Text(m.warehouseName ?? '—')),
                  DataCell(StatusBadge(
                    label: m.type.label,
                    color: m.type == MovementType.entry ? AppColors.success : m.type == MovementType.exit ? AppColors.error : AppColors.info,
                  )),
                  DataCell(Text('${m.type == MovementType.exit ? '-' : '+'}${formatQuantity(m.quantity)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: m.type == MovementType.exit ? AppColors.error : AppColors.success))),
                  DataCell(Text('${m.referenceType ?? '—'} ${m.referenceId ?? ''}')),
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
