import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_client_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/customers/customers_bloc.dart';
import 'forms/mobile_customer_form_screen.dart';
import '../../screens/customers_screen.dart';

class MobileCustomersScreen extends StatefulWidget {
  const MobileCustomersScreen({super.key});

  @override
  State<MobileCustomersScreen> createState() => _MobileCustomersScreenState();
}

class _MobileCustomersScreenState extends State<MobileCustomersScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.customers);
    _fetchFilteredClients();
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
      context.read<CustomersBloc>().add(LoadNextClients(
        searchQuery: _searchQuery,
      ));
    }
  }

  void _fetchFilteredClients() {
    context.read<CustomersBloc>().add(LoadFirstClients(
      searchQuery: _searchQuery,
    ));
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredClients();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomersBloc, CustomersState>(
      builder: (context, state) {
        bool isLoading = state is CustomersLoading || state is CustomersInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        if (state is CustomersLoaded) {
          final items = state.customers;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          // Locally double-filter matches just in case SQLite fallback gets loaded
          final filteredItems = items.where((customer) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final nameMatch = customer.name.toLowerCase().contains(query);
              final codeMatch = customer.code.toLowerCase().contains(query);
              final emailMatch = (customer.email ?? '').toLowerCase().contains(query);
              if (!nameMatch && !codeMatch && !emailMatch) return false;
            }
            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((customer) {
            return MobileClientCard(
              customer: customer,
              onTap: () {
                if (customer.isDefault || customer.name.trim().toLowerCase() == 'client passager') {
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
                  builder: (ctx) => CustomerDialog(existing: customer),
                ).then((_) {
                  _fetchFilteredClients();
                });
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.customers,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<CustomersBloc>().add(ResetClientsPagination(
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
          emptyMessage: 'Aucun client trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const CustomerDialog(existing: null),
            ).then((_) {
              _fetchFilteredClients();
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
