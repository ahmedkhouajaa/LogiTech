import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_product_card.dart';
import 'forms/mobile_product_form_screen.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/stock/stock_bloc.dart';
import '../../widgets/sidebar_menu.dart';
import '../../services/article_import_export_service.dart';
import '../../widgets/import_export/article_import_dialog.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';
import '../../models/product.dart';
import '../../screens/article_detail_screen.dart';

class MobileProductsScreen extends StatefulWidget {
  const MobileProductsScreen({super.key});

  @override
  State<MobileProductsScreen> createState() => _MobileProductsScreenState();
}

class _MobileProductsScreenState extends State<MobileProductsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.products);
    _scrollController.addListener(_onScroll);
    context.read<ProductsBloc>().add(
      ResetProductsPagination(
        searchQuery: _searchQuery,
        stockFilter: _selectedFilter,
      )
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
          )
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
      )
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
      )
    );
  }

  Widget _buildActionsButton(BuildContext context, ProductsState state) {
    final products = state is ProductsLoaded ? state.products : <Product>[];
    return PopupMenuButton<String>(
      tooltip: 'Actions Import / Export Articles',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      color: AppColors.surface,
      elevation: 4,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              'Actions',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) {
        final canExport = PermissionService.instance.canCreate(UserPermissionResources.importExport);
        final canImport = PermissionService.instance.canUpdate(UserPermissionResources.importExport);
        final items = <PopupMenuEntry<String>>[];
        if (canExport) {
          items.addAll([
            const PopupMenuItem(
              value: 'export_excel',
              child: Text('Exporter Excel', style: TextStyle(fontSize: 13)),
            ),
            const PopupMenuItem(
              value: 'export_csv',
              child: Text('Exporter CSV', style: TextStyle(fontSize: 13)),
            ),
            const PopupMenuItem(
              value: 'export_json',
              child: Text('Exporter JSON', style: TextStyle(fontSize: 13)),
            ),
          ]);
        }
        if (canExport && canImport) {
          items.add(const PopupMenuDivider());
        }
        if (canImport) {
          items.add(
            const PopupMenuItem(
              value: 'import_excel',
              child: Text(
                'Importer depuis Excel',
                style: TextStyle(fontSize: 13),
              ),
            ),
          );
        }
        return items;
      },
      onSelected: (val) async {
        if (!context.mounted) return;
        if (val == 'export_excel') {
          if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
          await ArticleImportExportService.instance.exportArticlesToExcel(
            context: context,
            products: products,
          );
        } else if (val == 'export_csv') {
          if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
          await ArticleImportExportService.instance.exportArticlesToCsv(
            context: context,
            products: products,
          );
        } else if (val == 'export_json') {
          if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
          await ArticleImportExportService.instance.exportArticlesToJson(
            context: context,
            products: products,
          );
        } else if (val == 'import_excel') {
          if (!PermissionService.instance.canUpdate(UserPermissionResources.importExport)) return;
          ArticleImportDialog.show(
            context,
            onImportSuccess: () {
              if (context.mounted) {
                context.read<ProductsBloc>().add(
                  ResetProductsPagination(
                    searchQuery: _searchQuery,
                    stockFilter: _selectedFilter,
                  ),
                );
                context.read<StockBloc>().add(LoadStock());
              }
            },
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        bool isLoading = state is ProductsLoading || state is ProductsInitial;
        bool isEmpty = true;
        int count = 0;
        List<Widget> cards = [];

        if (state is ProductsLoaded) {
          isEmpty = state.products.isEmpty;
          count = state.totalCount;

          cards = state.products.map((product) {
            return MobileProductCard(
              product: product,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailScreen(product: product),
                  ),
                ).then((_) {
                  if (mounted && context.mounted) {
                    context.read<ProductsBloc>().add(
                      ResetProductsPagination(
                        searchQuery: _searchQuery,
                        stockFilter: _selectedFilter,
                      )
                    );
                  }
                });
              },
            );
          }).toList();

          if (state.isLoadingMore) {
            cards.add(const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ));
          }
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.products,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<ProductsBloc>().add(
              ResetProductsPagination(
                searchQuery: _searchQuery,
                stockFilter: _selectedFilter,
              )
            );
          },
          onSearchChanged: _onSearchChanged,
          searchTrailing: _buildActionsButton(context, state),
          filterOptions: const ['Tous', 'En stock', 'Rupture'],
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun article trouvé.',
          itemCount: count,
          fabText: 'Nouvel article',
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileProductFormScreen()),
            ).then((_) {
              if (mounted && context.mounted) {
                context.read<ProductsBloc>().add(
                  ResetProductsPagination(
                    searchQuery: _searchQuery,
                    stockFilter: _selectedFilter,
                  )
                );
              }
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          ),
        );
      },
    );
  }
}
