import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/products/products_bloc.dart';
import '../blocs/stock/stock_bloc.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../mobile/widgets/mobile_product_card.dart';
import '../mobile/widgets/mobile_search_bar.dart';
import '../mobile/widgets/mobile_filter_chips.dart';
import '../mobile/widgets/mobile_empty_state.dart';
import '../mobile/screens/forms/mobile_product_form_screen.dart';

class ArticleSelectionModal extends StatefulWidget {
  final String? warehouseId;
  const ArticleSelectionModal({super.key, this.warehouseId});

  static Future<Product?> show(BuildContext context, {String? warehouseId}) {
    return showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ArticleSelectionModal(warehouseId: warehouseId),
    );
  }

  @override
  State<ArticleSelectionModal> createState() => _ArticleSelectionModalState();
}

class _ArticleSelectionModalState extends State<ArticleSelectionModal> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<ProductsBloc>().add(
      ResetProductsPagination(
        searchQuery: _searchQuery,
        stockFilter: _selectedFilter,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      final state = context.read<ProductsBloc>().state;
      if (state is ProductsLoaded && state.hasMore && !state.isLoadingMore) {
        context.read<ProductsBloc>().add(
          LoadNextProducts(
            searchQuery: _searchQuery,
            stockFilter: _selectedFilter,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    context.read<ProductsBloc>().add(
      ResetProductsPagination(
        searchQuery: _searchQuery,
        stockFilter: _selectedFilter,
      ),
    );
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    context.read<ProductsBloc>().add(
      ResetProductsPagination(
        searchQuery: _searchQuery,
        stockFilter: _selectedFilter,
      ),
    );
  }

  double _getWarehouseStock(Product product, StockState stockState) {
    if (widget.warehouseId == null || widget.warehouseId!.isEmpty) {
      return product.stockQty;
    }
    if (stockState is! StockLoaded) {
      return product.stockQty;
    }

    double stock = 0.0;
    bool isWarehouseDefault = false;
    try {
      isWarehouseDefault = stockState.warehouses.firstWhere((w) => w.id == widget.warehouseId).isDefault;
    } catch (_) {}

    for (var m in stockState.movements) {
      if (m.productId == product.id) {
        final isWarehouseMatch = m.warehouseId == widget.warehouseId || (m.warehouseId == 'default_warehouse' && isWarehouseDefault);
        if (isWarehouseMatch) {
          if (m.type == MovementType.entry || m.type == MovementType.transfer_in || m.type == MovementType.adjustment) {
            stock += m.quantity;
          } else if (m.type == MovementType.exit || m.type == MovementType.transfer_out) {
            stock -= m.quantity;
          }
        }
      }
    }
    return stock;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Text(
                  'Articles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('En ligne', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          MobileSearchBar(onChanged: _onSearchChanged),

          // Filter Chips
          MobileFilterChips(
            options: const ['Tous', 'En stock', 'Rupture'],
            selectedOption: _selectedFilter,
            onSelected: _onFilterChanged,
          ),

          // List content & count
          Expanded(
            child: BlocBuilder<StockBloc, StockState>(
              builder: (context, stockState) {
                return BlocBuilder<ProductsBloc, ProductsState>(
                  builder: (context, state) {
                    if (state is ProductsLoading || state is ProductsInitial) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is ProductsLoaded) {
                      if (state.products.isEmpty) {
                        return const MobileEmptyState(message: 'Aucun article trouvé.');
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dynamic Count Badge
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${state.totalCount} résultats',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: state.products.length + (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == state.products.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                final rawProduct = state.products[index];
                                final warehouseStock = _getWarehouseStock(rawProduct, stockState);
                                final displayProduct = rawProduct.copyWith(stockQty: warehouseStock);

                                return MobileProductCard(
                                  product: displayProduct,
                                  onTap: () {
                                    Navigator.pop(context, displayProduct);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    return const SizedBox();
                  },
                );
              },
            ),
          ),

          // Footer with "Nouvel article" FAB button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MobileProductFormScreen()),
                  );
                  if (mounted) {
                    context.read<ProductsBloc>().add(
                      ResetProductsPagination(
                        searchQuery: _searchQuery,
                        stockFilter: _selectedFilter,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text('Nouvel article', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
