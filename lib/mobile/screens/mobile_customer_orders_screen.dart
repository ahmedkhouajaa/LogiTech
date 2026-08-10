import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../widgets/sidebar_menu.dart';
import 'mobile_customer_order_detail_screen.dart';
import '../../blocs/customer_orders/customer_orders_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/projects/projects_bloc.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../models/customer.dart';
import 'forms/mobile_customer_order_form_screen.dart';
import '../../services/firestore_pagination_service.dart';

class MobileCustomerOrdersScreen extends StatefulWidget {
  const MobileCustomerOrdersScreen({super.key});

  @override
  State<MobileCustomerOrdersScreen> createState() => _MobileCustomerOrdersScreenState();
}

class _MobileCustomerOrdersScreenState extends State<MobileCustomerOrdersScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedCustomerId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _selectedStatus;
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.customerOrders);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredOrders();
    context.read<CustomersBloc>().add(LoadCustomers());
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
      context.read<CustomerOrdersBloc>().add(LoadNextCustomerOrders(
        searchQuery: _searchQuery,
        customerId: _selectedCustomerId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredOrders() {
    context.read<CustomerOrdersBloc>().add(LoadFirstCustomerOrders(
      searchQuery: _searchQuery,
      customerId: _selectedCustomerId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      status: _selectedStatus,
    ));
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredOrders();
  }

  void _handleDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet élément ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              context.read<CustomerOrdersBloc>().add(DeleteCustomerOrder(id));
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerOrdersBloc, CustomerOrdersState>(
      builder: (context, state) {
        bool isLoading = state is CustomerOrdersLoading || state is CustomerOrdersInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        final customersState = context.watch<CustomersBloc>().state;
        List<Customer> customersList = [];
        if (customersState is CustomersLoaded) {
          customersList = customersState.customers;
        }

        if (state is CustomerOrdersLoaded) {
          final items = state.orders;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((item) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final numMatch = item.number.toLowerCase().contains(query);
              final custMatch = (item.customerName ?? '').toLowerCase().contains(query);
              if (!numMatch && !custMatch) return false;
            }

            if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
              if (item.customerId != _selectedCustomerId) return false;
            }

            if (_dateFrom != null) {
              final iDate = DateTime(item.date.year, item.date.month, item.date.day);
              final fDate = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
              if (iDate.isBefore(fDate)) return false;
            }

            if (_dateTo != null) {
              final iDate = DateTime(item.date.year, item.date.month, item.date.day);
              final tDate = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
              if (iDate.isAfter(tDate)) return false;
            }

            if (_selectedStatus != null && _selectedStatus != 'Tous' && _selectedStatus!.isNotEmpty) {
              final statusLabel = translateStatus(item.status).toLowerCase();
              final filterLower = _selectedStatus!.toLowerCase();
              if (statusLabel != filterLower) return false;
            }

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((item) {
            final reference = item.number;
            final status = translateStatus(item.status);
            final name = item.customerName;
            final date = item.date;
            final amount = item.totalTTC;

            return MobileGenericCard(
              reference: reference,
              status: status,
              name: name,
              date: date,
              amount: amount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileCustomerOrderDetailScreen(order: item)),
                ).then((_) {
                  _fetchFilteredOrders();
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: context.read<CustomerOrdersBloc>()),
                        BlocProvider.value(value: context.read<CustomersBloc>()),
                        BlocProvider.value(value: context.read<ProductsBloc>()),
                        BlocProvider.value(value: context.read<ProjectsBloc>()),
                        BlocProvider.value(value: context.read<WarehousesBloc>()),
                      ],
                      child: MobileCustomerOrderFormScreen(existing: item),
                    ),
                  ),
                ).then((_) {
                  _fetchFilteredOrders();
                });
              },
              onDelete: () => _handleDelete(item.id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.customerOrders,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<CustomerOrdersBloc>().add(ResetCustomerOrdersPagination(
              searchQuery: _searchQuery,
              customerId: _selectedCustomerId,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              status: _selectedStatus,
            ));
            context.read<CustomersBloc>().add(LoadCustomers());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const [],
          selectedFilter: _selectedStatus ?? 'Tous',
          onFilterChanged: (val) {
            setState(() => _selectedStatus = val == 'Tous' ? null : val);
            _fetchFilteredOrders();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            entityLabel: 'Client',
            selectedCustomerId: _selectedCustomerId,
            customers: customersList,
            onCustomerChanged: (id) {
              setState(() => _selectedCustomerId = id);
              _fetchFilteredOrders();
            },
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredOrders();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredOrders();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Créé', 'Validé', 'Validée et facturée', 'Livré', 'Annulé'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredOrders();
            },
            onResetFilters: () {
              setState(() {
                _selectedCustomerId = null;
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredOrders();
            },
            itemCount: totalMatchingCount,
          ),
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucune commande trouvée.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: context.read<CustomerOrdersBloc>()),
                    BlocProvider.value(value: context.read<CustomersBloc>()),
                    BlocProvider.value(value: context.read<ProductsBloc>()),
                    BlocProvider.value(value: context.read<ProjectsBloc>()),
                    BlocProvider.value(value: context.read<WarehousesBloc>()),
                  ],
                  child: const MobileCustomerOrderFormScreen(),
                ),
              ),
            ).then((_) {
              _fetchFilteredOrders();
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
