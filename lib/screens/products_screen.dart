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
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';

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
    context.read<ProductsBloc>().add(const LoadFirstProducts());
    context.read<StockBloc>().add(LoadStock());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Action Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Articles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Gérer vos articles', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 250,
                height: 32,
                child: AppSearchBar(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
              ),
              if (PermissionService.instance.canCreate(UserPermissionResources.productsList)) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _navigateToCreate(context, null),
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: const Text('Nouvel Article', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        
        // Data List
        Expanded(
          child: BlocBuilder<StockBloc, StockState>(
            builder: (context, stockState) {
              final movements = stockState is StockLoaded ? stockState.movements : <StockMovement>[];
              
              return BlocBuilder<ProductsBloc, ProductsState>(
                builder: (context, state) {
                  if (state is ProductsLoading || state is ProductsInitial) {
                    return AppShimmer(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
                        itemCount: 8,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, index) => Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              ShimmerBox(width: 36, height: 36, borderRadius: 10),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    ShimmerBox(width: 160, height: 12, borderRadius: 4),
                                    SizedBox(height: 6),
                                    ShimmerBox(width: 110, height: 10, borderRadius: 4),
                                  ],
                                ),
                              ),
                              ShimmerBox(width: 70, height: 20, borderRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  if (state is ProductsError) return AppErrorWidget(message: state.message);
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
                        Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Aucun article trouvé', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => _navigateToCreate(context, p),
                          hoverColor: AppColors.primary.withValues(alpha: 0.02),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.inventory_2_rounded, color: AppColors.textSecondary, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
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
                                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              p.productType.capitalize(),
                                              style: TextStyle(fontSize: 9.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.tag_rounded, size: 12, color: AppColors.textTertiary),
                                          const SizedBox(width: 3),
                                          Text(p.code, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                          if (p.reference != null && p.reference!.isNotEmpty) ...[
                                            const SizedBox(width: 10),
                                            Icon(Icons.qr_code_2_rounded, size: 12, color: AppColors.textTertiary),
                                            const SizedBox(width: 3),
                                            Text(p.reference!, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                          ],
                                          const SizedBox(width: 10),
                                          Icon(Icons.straighten_rounded, size: 12, color: AppColors.textTertiary),
                                          const SizedBox(width: 3),
                                          Text(p.unit, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
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
                                      Text('Stock', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: realStock <= 0 ? AppColors.errorLight : AppColors.successLight.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          formatQuantity(realStock),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: realStock <= 0 ? AppColors.error : AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Price
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Prix Vente (TTC)', style: TextStyle(fontSize: 10.5, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successLight.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          formatCurrency(sellTtc),
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Actions
                                const SizedBox(width: 12),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textTertiary),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 4,
                                  onSelected: (val) {
                                    if (val == 'edit') _navigateToCreate(context, p);
                                    if (val == 'delete') context.read<ProductsBloc>().add(DeleteProduct(p.id));
                                  },
                                  itemBuilder: (context) => [
                                    if (PermissionService.instance.canUpdate(UserPermissionResources.productsList))
                                      PopupMenuItem(value: 'edit', height: 36, child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: AppColors.primary), const SizedBox(width: 8), const Text('Modifier', style: TextStyle(fontSize: 13))])),
                                    if (PermissionService.instance.canDelete(UserPermissionResources.productsList))
                                      PopupMenuItem(value: 'delete', height: 36, child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error), const SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.error, fontSize: 13))])),
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
