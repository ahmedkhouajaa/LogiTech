import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_devis_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import 'mobile_devis_detail_screen.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/quotes/quotes_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../models/customer.dart';
import 'forms/mobile_quote_form_screen.dart';
import '../../services/firestore_pagination_service.dart';

class MobileQuotesScreen extends StatefulWidget {
  const MobileQuotesScreen({super.key});

  @override
  State<MobileQuotesScreen> createState() => _MobileQuotesScreenState();
}

class _MobileQuotesScreenState extends State<MobileQuotesScreen> {
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
    _config = MobileModuleConfig.getConfig(AppModule.quotes);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredDevis();
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
      context.read<QuotesBloc>().add(LoadNextDevis(
        searchQuery: _searchQuery,
        customerId: _selectedCustomerId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredDevis() {
    context.read<QuotesBloc>().add(LoadFirstDevis(
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
    _fetchFilteredDevis();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuotesBloc, QuotesState>(
      builder: (context, state) {
        bool isLoading = state is QuotesLoading || state is QuotesInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        final customersState = context.watch<CustomersBloc>().state;
        List<Customer> customersList = [];
        if (customersState is CustomersLoaded) {
          customersList = customersState.customers;
        }

        if (state is QuotesLoaded) {
          final items = state.quotes;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((quote) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final numMatch = quote.number.toLowerCase().contains(query);
              final custMatch = (quote.customerName ?? '').toLowerCase().contains(query);
              if (!numMatch && !custMatch) return false;
            }

            if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
              if (quote.customerId != _selectedCustomerId) return false;
            }

            if (_dateFrom != null) {
              final qDate = DateTime(quote.date.year, quote.date.month, quote.date.day);
              final fDate = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
              if (qDate.isBefore(fDate)) return false;
            }

            if (_dateTo != null) {
              final qDate = DateTime(quote.date.year, quote.date.month, quote.date.day);
              final tDate = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
              if (qDate.isAfter(tDate)) return false;
            }

            if (_selectedStatus != null && _selectedStatus != 'Tous' && _selectedStatus!.isNotEmpty) {
              final statusLabel = quote.status.label.toLowerCase();
              final statusName = quote.status.name.toLowerCase();
              final filterLower = _selectedStatus!.toLowerCase();
              if (statusLabel != filterLower && statusName != filterLower) return false;
            }

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((quote) {
            return MobileDevisCard(
              quote: quote,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileDevisDetailScreen(quote: quote)),
                ).then((_) {
                  _fetchFilteredDevis();
                });
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.quotes,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<QuotesBloc>().add(ResetDevisPagination(
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
            _fetchFilteredDevis();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            selectedCustomerId: _selectedCustomerId,
            customers: customersList,
            onCustomerChanged: (id) {
              setState(() => _selectedCustomerId = id);
              _fetchFilteredDevis();
            },
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredDevis();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredDevis();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Envoyé', 'Accepté', 'Rejeté', 'Facturé'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredDevis();
            },
            onResetFilters: () {
              setState(() {
                _selectedCustomerId = null;
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredDevis();
            },
            itemCount: totalMatchingCount,
          ),
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun devis trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileQuoteFormScreen()),
            ).then((_) {
              _fetchFilteredDevis();
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
