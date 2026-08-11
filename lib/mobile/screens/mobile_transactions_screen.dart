import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_transaction_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import 'forms/mobile_transaction_form_screen.dart';
import 'mobile_treasury_transaction_detail_screen.dart';

class MobileTreasuryTransactionsScreen extends StatefulWidget {
  const MobileTreasuryTransactionsScreen({super.key});

  @override
  State<MobileTreasuryTransactionsScreen> createState() => _MobileTreasuryTransactionsScreenState();
}

class _MobileTreasuryTransactionsScreenState extends State<MobileTreasuryTransactionsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.transactions);
    _scrollController.addListener(_onScroll);
    context.read<TreasuryTransactionsBloc>().add(const ResetTreasuryTransactionsPagination());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<TreasuryTransactionsBloc>().add(const LoadNextTreasuryTransactions());
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    context.read<TreasuryTransactionsBloc>().add(
      ResetTreasuryTransactionsPagination(searchQuery: _searchQuery, typeFilter: _selectedFilter)
    );
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    context.read<TreasuryTransactionsBloc>().add(
      ResetTreasuryTransactionsPagination(searchQuery: _searchQuery, typeFilter: _selectedFilter)
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TreasuryTransactionsBloc, TreasuryTransactionsState>(
      builder: (context, state) {
        bool isLoading = state is TreasuryTransactionsLoading || state is TreasuryTransactionsInitial;
        bool isEmpty = true;
        List<Widget> cards = [];
        int totalMatchingCount = 0;
        bool isLoadingMore = false;

        if (state is TreasuryTransactionsLoaded) {
          final items = state.transactions;
          isEmpty = items.isEmpty;
          totalMatchingCount = state.totalCount;
          isLoadingMore = state.isLoadingMore;
          
          cards = items.map((item) {
            return BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
              builder: (context, accountState) {
                final accounts = accountState is TreasuryAccountsLoaded ? accountState.accounts : [];
                final account = accounts.cast<dynamic>().firstWhere((a) => a?.id == item.accountId, orElse: () => null);
                final accountName = account?.name ?? item.accountName ?? '—';
                final updatedItem = item.copyWith(accountName: accountName);
                
                return MobileTransactionCard(
                  transaction: updatedItem,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MobileTreasuryTransactionDetailScreen(transaction: updatedItem)),
                    ).then((_) {
                      if (mounted) {
                        context.read<TreasuryTransactionsBloc>().add(
                          ResetTreasuryTransactionsPagination(searchQuery: _searchQuery, typeFilter: _selectedFilter)
                        );
                      }
                    });
                  },
                );
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.transactions,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<TreasuryTransactionsBloc>().add(
              ResetTreasuryTransactionsPagination(searchQuery: _searchQuery, typeFilter: _selectedFilter)
            );
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const ['Tous', 'Entrée', 'Sortie'],
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucune transaction trouvée.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileTransactionFormScreen()),
            ).then((_) {
              if (mounted) {
                context.read<TreasuryTransactionsBloc>().add(
                  ResetTreasuryTransactionsPagination(searchQuery: _searchQuery, typeFilter: _selectedFilter)
                );
              }
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
