import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/payments/payments_bloc.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_payment_card.dart';
import 'forms/mobile_payment_form_screen.dart';
import 'mobile_payment_detail_screen.dart';

class MobilePaymentsScreen extends StatefulWidget {
  const MobilePaymentsScreen({super.key});

  @override
  State<MobilePaymentsScreen> createState() => _MobilePaymentsScreenState();
}

class _MobilePaymentsScreenState extends State<MobilePaymentsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _activeFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.payments);
    _scrollController.addListener(_onScroll);
    
    // Load first page of payments on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentsBloc>().add(LoadFirstPayments(
        statusFilter: _activeFilter,
        searchQuery: _searchController.text,
      ));
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<PaymentsBloc>().state;
      if (state is PaymentsLoaded && state.hasMore && !state.isLoadingMore) {
        context.read<PaymentsBloc>().add(LoadNextPayments(
          statusFilter: _activeFilter,
          searchQuery: _searchController.text,
        ));
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      context.read<PaymentsBloc>().add(LoadFirstPayments(
        statusFilter: _activeFilter,
        searchQuery: query,
      ));
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _activeFilter = filter;
    });
    context.read<PaymentsBloc>().add(LoadFirstPayments(
      statusFilter: filter,
      searchQuery: _searchController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentsBloc, PaymentsState>(
      builder: (context, state) {
        bool isLoading = state is PaymentsLoading || state is PaymentsInitial;
        bool isEmpty = true;
        List<Widget> cards = [];
        int totalMatchingCount = 0;
        bool isLoadingMore = false;

        if (state is PaymentsLoaded) {
          final items = state.payments;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount;

          isEmpty = items.isEmpty;

          cards = items.map((item) {
            return MobilePaymentCard(
              payment: item,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MobilePaymentDetailScreen(payment: item),
                  ),
                ).then((_) {
                  context.read<PaymentsBloc>().add(LoadFirstPayments(
                    statusFilter: _activeFilter,
                    searchQuery: _searchController.text,
                  ));
                });
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.payments,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<PaymentsBloc>().add(ResetPaymentsPagination(
              statusFilter: _activeFilter,
              searchQuery: _searchController.text,
            ));
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const ['Tous', 'En attente', 'Confirmé', 'Rejeté'],
          selectedFilter: _activeFilter,
          onFilterChanged: _onFilterChanged,
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun paiement trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobilePaymentFormScreen()),
            ).then((_) {
              context.read<PaymentsBloc>().add(LoadFirstPayments(
                statusFilter: _activeFilter,
                searchQuery: _searchController.text,
              ));
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
