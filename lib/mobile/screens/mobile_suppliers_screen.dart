import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_supplier_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../screens/suppliers_screen.dart';

class MobileSuppliersScreen extends StatefulWidget {
  const MobileSuppliersScreen({super.key});

  @override
  State<MobileSuppliersScreen> createState() => _MobileSuppliersScreenState();
}

class _MobileSuppliersScreenState extends State<MobileSuppliersScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.suppliers);
    _fetchFilteredSuppliers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<SuppliersBloc>().add(LoadNextSuppliers(
        searchQuery: _searchQuery,
      ));
    }
  }

  void _fetchFilteredSuppliers() {
    context.read<SuppliersBloc>().add(LoadFirstSuppliers(
      searchQuery: _searchQuery,
    ));
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SuppliersBloc, SuppliersState>(
      builder: (context, state) {
        bool isLoading = state is SuppliersLoading || state is SuppliersInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        if (state is SuppliersLoaded) {
          final items = state.suppliers;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          // Locally double-filter matches just in case SQLite fallback gets loaded
          final filteredItems = items.where((supplier) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final nameMatch = supplier.name.toLowerCase().contains(query);
              final codeMatch = supplier.code.toLowerCase().contains(query);
              final emailMatch = (supplier.email ?? '').toLowerCase().contains(query);
              if (!nameMatch && !codeMatch && !emailMatch) return false;
            }
            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((supplier) {
            return MobileSupplierCard(
              supplier: supplier,
              onTap: () {
                if (supplier.isDefault || supplier.name.trim().toLowerCase() == 'fournisseur passager') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Cet élément est un élément par défaut et ne peut pas être modifié.'),
                      backgroundColor: AppColors.warning,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => SupplierDialog(existing: supplier),
                ).then((_) {
                  _fetchFilteredSuppliers();
                });
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.suppliers,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<SuppliersBloc>().add(ResetSuppliersPagination(
              searchQuery: _searchQuery,
            ));
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const [],
          selectedFilter: 'Tous',
          onFilterChanged: (_) {},
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun fournisseur trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const SupplierDialog(existing: null),
            ).then((_) {
              _fetchFilteredSuppliers();
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...cards,
              if (isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}
