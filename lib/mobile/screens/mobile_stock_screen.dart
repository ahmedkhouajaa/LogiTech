import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

import '../../blocs/stock/stock_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../models/stock_movement.dart';
import '../../models/product.dart';
import 'forms/mobile_stock_adjustment_form.dart';
import '../../services/sync_service.dart';
class MobileStockScreen extends StatefulWidget {
  const MobileStockScreen({super.key});

  @override
  State<MobileStockScreen> createState() => _MobileStockScreenState();
}

class _MobileStockScreenState extends State<MobileStockScreen> {
  String _searchQuery = '';

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
            return const Center(child: CircularProgressIndicator());
          }
          if (state is StockError) {
            return Center(child: Text('Erreur: ${state.message}'));
          }
          if (state is StockLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                await SyncService.instance.triggerSync();
                if (!context.mounted) return;
                context.read<StockBloc>().add(LoadStock());
                context.read<ProductsBloc>().add(LoadProducts());
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // ── Title ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'Vue d\'ensemble du Stock',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 4 KPI Summary Cards (2x2 grid) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildKpiGrid(state),
                  ),
                  const SizedBox(height: 20),

                  // ── Low Stock Alerts ──
                  BlocBuilder<ProductsBloc, ProductsState>(
                    builder: (context, pState) {
                      if (pState is! ProductsLoaded || pState.lowStockProducts.isEmpty) {
                        return const SizedBox();
                      }
                      return _buildLowStockSection(pState.lowStockProducts);
                    },
                  ),

                  // ── Stock Levels ──
                  BlocBuilder<ProductsBloc, ProductsState>(
                    builder: (context, pState) {
                      if (pState is! ProductsLoaded) return const SizedBox();
                      return _buildStockLevelsSection(
                        state.movements,
                        state.warehouses,
                        pState.products,
                      );
                    },
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MobileStockAdjustmentForm()),
          ).then((_) {
            if (!mounted) return;
            context.read<StockBloc>().add(LoadStock());
            context.read<ProductsBloc>().add(LoadProducts());
          });
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouvel ajustement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // KPI Summary Cards
  // ────────────────────────────────────────────────────────────
  Widget _buildKpiGrid(StockLoaded state) {
    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, pState) {
        final lowCount = pState is ProductsLoaded ? pState.lowStockProducts.length : 0;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'Valeur du stock',
                    value: formatCurrencyCompact(state.totalStockValue),
                    icon: Icons.inventory_rounded,
                    gradientColors: const [Color(0xFF1a56db), Color(0xFF3B82F6)],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: 'Entrepôts',
                    value: state.warehouses.length.toString(),
                    icon: Icons.warehouse_rounded,
                    gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'Mouvements',
                    value: state.movements.length.toString(),
                    icon: Icons.swap_horiz_rounded,
                    gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: 'Alertes stock bas',
                    value: lowCount.toString(),
                    icon: Icons.warning_rounded,
                    gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Low Stock Alerts Section
  // ────────────────────────────────────────────────────────────
  Widget _buildLowStockSection(List<Product> lowStockProducts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.error),
              const SizedBox(width: 8),
              const Text(
                'Produits en stock bas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${lowStockProducts.length} alertes',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...lowStockProducts.map((p) => _LowStockCard(product: p)),
        const SizedBox(height: 20),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // Stock Levels Section
  // ────────────────────────────────────────────────────────────
  Widget _buildStockLevelsSection(
    List<StockMovement> movements,
    List<Warehouse> warehouses,
    List<Product> products,
  ) {
    // Calculate stock levels per product/warehouse (same logic as desktop)
    List<_StockLevelItem> items = [];
    for (var p in products) {
      for (var w in warehouses) {
        double stock = 0;
        for (var m in movements) {
          final isMatch = m.warehouseId == w.id || (m.warehouseId == 'default_warehouse' && w.isDefault);
          if (m.productId == p.id && isMatch) {
            if (m.type == MovementType.entry || m.type == MovementType.transfer_in) {
              stock += m.quantity;
            } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
              stock -= m.quantity;
            } else if (m.type == MovementType.adjustment) {
              stock += m.quantity;
            }
          }
        }
        items.add(_StockLevelItem(product: p, warehouse: w, quantity: stock));
      }
    }

    // Apply search filter
    final filteredItems = _searchQuery.isEmpty
        ? items
        : items.where((item) {
            final query = _searchQuery.toLowerCase();
            return item.product.name.toLowerCase().contains(query) ||
                item.product.code.toLowerCase().contains(query) ||
                (item.product.reference?.toLowerCase().contains(query) ?? false) ||
                item.warehouse.name.toLowerCase().contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Niveaux de Stock Actuels',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '${filteredItems.length} produits',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un produit...',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (filteredItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  const Text('Aucun produit trouvé.', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          )
        else
          ...filteredItems.map((item) => _StockLevelCard(item: item)),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// KPI Card Widget
// ────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Low Stock Product Card
// ────────────────────────────────────────────────────────────
class _LowStockCard extends StatelessWidget {
  final Product product;

  const _LowStockCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Warning icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded, size: 20, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.code} • ${product.category ?? '—'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Stock info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatQuantity(product.stockQty)} ${product.unit}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                Text(
                  'Min: ${formatQuantity(product.minStockQty)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Stock Level Item (data class)
// ────────────────────────────────────────────────────────────
class _StockLevelItem {
  final Product product;
  final Warehouse warehouse;
  final double quantity;
  _StockLevelItem({required this.product, required this.warehouse, required this.quantity});
}

// ────────────────────────────────────────────────────────────
// Stock Level Card
// ────────────────────────────────────────────────────────────
class _StockLevelCard extends StatelessWidget {
  final _StockLevelItem item;

  const _StockLevelCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isInStock = item.quantity > 0;
    final statusColor = isInStock ? AppColors.success : AppColors.error;
    final statusText = isInStock ? 'En Stock' : 'En Rupture';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Product name + Status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
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
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Details
            Row(
              children: [
                _DetailChip(
                  icon: Icons.qr_code_rounded,
                  label: item.product.reference ?? item.product.code,
                ),
                const SizedBox(width: 12),
                _DetailChip(
                  icon: Icons.warehouse_outlined,
                  label: item.warehouse.name,
                ),
                const Spacer(),
                Text(
                  formatQuantity(item.quantity),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isInStock ? AppColors.textPrimary : AppColors.error,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item.product.unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Small detail chip for stock level cards
// ────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
