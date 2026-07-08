import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/products/products_bloc.dart';
import '../models/product.dart';
import '../blocs/stock/stock_bloc.dart';
import '../models/stock_movement.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';
import 'create_article_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProducts());
    context.read<StockBloc>().add(LoadStock());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Action Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(bottom: BorderSide(color: Colors.transparent)),
          ),
          child: Row(
            children: [
              const Text('Articles', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              SizedBox(
                width: 300,
                child: AppSearchBar(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => _navigateToCreate(context, null),
                icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                label: const Text('Nouvel Article', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ],
          ),
        ),
        
        // Data List
        Expanded(
          child: BlocBuilder<StockBloc, StockState>(
            builder: (context, stockState) {
              final movements = stockState is StockLoaded ? stockState.movements : <StockMovement>[];
              
              return BlocBuilder<ProductsBloc, ProductsState>(
                builder: (context, state) {
                  if (state is ProductsLoading) return const Center(child: CircularProgressIndicator());
                  if (state is ProductsError) return Center(child: Text('Erreur: ${state.message}'));
                  if (state is ProductsLoaded) {
                final filtered = _search.isEmpty ? state.products
                    : state.products.where((p) => 
                        p.name.toLowerCase().contains(_search) || 
                        p.code.toLowerCase().contains(_search) || 
                        (p.reference?.toLowerCase().contains(_search) ?? false)
                      ).toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('Aucun article trouve', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    
                    double realStock = 0;
                    for (var m in movements) {
                      if (m.productId == p.id) {
                        if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) realStock += m.quantity;
                        else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) realStock -= m.quantity;
                      }
                    }

                    final tvaMultiplier = 1 + (p.tvaRate / 100);
                    final sellTtc = p.sellingPrice * tvaMultiplier;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () => _navigateToCreate(context, p),
                          hoverColor: AppColors.primary.withValues(alpha: 0.02),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.inventory_2_rounded, color: AppColors.textSecondary, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Info
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              p.productType.capitalize(),
                                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.tag_rounded, size: 14, color: AppColors.textTertiary),
                                          const SizedBox(width: 4),
                                          Text(p.code, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                          if (p.reference != null && p.reference!.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.qr_code_2_rounded, size: 14, color: AppColors.textTertiary),
                                            const SizedBox(width: 4),
                                            Text(p.reference!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          ],
                                          const SizedBox(width: 12),
                                          const Icon(Icons.straighten_rounded, size: 14, color: AppColors.textTertiary),
                                          const SizedBox(width: 4),
                                          Text(p.unit, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Stock
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Stock', style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: realStock <= 0 ? AppColors.errorLight : AppColors.successLight.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            formatQuantity(realStock),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: realStock <= 0 ? AppColors.error : AppColors.success,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                
                                // Price
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Prix Vente (TTC)', style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrency(sellTtc),
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Actions
                                const SizedBox(width: 16),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 4,
                                  onSelected: (val) {
                                    if (val == 'edit') _navigateToCreate(context, p);
                                    if (val == 'delete') context.read<ProductsBloc>().add(DeleteProduct(p.id));
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Modifier')])),
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.error))])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          );
        },
      ),
    ),
  ],
    );
  }

  void _navigateToCreate(BuildContext context, Product? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProductsBloc>(),
          child: CreateArticleScreen(existing: existing),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
