import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_product_card.dart';
import 'forms/mobile_product_form_screen.dart';
import '../../blocs/products/products_bloc.dart';
import '../../widgets/sidebar_menu.dart';

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
                    builder: (_) => MobileProductFormScreen(existing: product),
                  ),
                ).then((_) {
                  if (mounted) {
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
              if (mounted) {
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
