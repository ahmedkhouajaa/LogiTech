import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/treasury_transactions/treasury_transactions_bloc.dart';
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

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.transactions);
    context.read<TreasuryTransactionsBloc>().add(LoadTreasuryTransactions());
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
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
              context.read<TreasuryTransactionsBloc>().add(DeleteTreasuryTransaction(id));
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
    return BlocBuilder<TreasuryTransactionsBloc, TreasuryTransactionsState>(
      builder: (context, state) {
        bool isLoading = state is TreasuryTransactionsLoading || state is TreasuryTransactionsInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is TreasuryTransactionsLoaded) {
          final items = state.transactions;
          
          final filteredItems = items.where((item) {
            bool matchesSearch = true;
            bool matchesFilter = true;

            String statusStr = item.type == 'income' ? 'Entrée' : 'Sortie';
            String reference = item.transactionNumber;
            String name = item.accountName ?? item.accountId;

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              if (!reference.toLowerCase().contains(query) && !name.toLowerCase().contains(query)) {
                matchesSearch = false;
              }
            }

            if (_selectedFilter != 'Tous') {
               if (statusStr.toLowerCase() != _selectedFilter.toLowerCase()) {
                   matchesFilter = false;
               }
            }

            return matchesSearch && matchesFilter;
          }).toList();
          
          isEmpty = filteredItems.isEmpty;
          
          cards = filteredItems.map((item) {
            String reference = item.transactionNumber;
            String status = item.type == 'income' ? 'Entrée' : 'Sortie';
            String name = item.accountName ?? item.accountId;
            DateTime date = item.dateTransaction;
            double amount = item.amount;
            String id = item.id;

            return MobileGenericCard(
              reference: reference,
              status: status,
              name: name,
              date: date,
              amount: amount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileTreasuryTransactionDetailScreen(transaction: item)),
                ).then((_) {
                  context.read<TreasuryTransactionsBloc>().add(LoadTreasuryTransactions());
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileTransactionFormScreen(existing: item)),
                ).then((_) {
                  context.read<TreasuryTransactionsBloc>().add(LoadTreasuryTransactions());
                });
              },
              onDelete: () => _handleDelete(id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.transactions,
          onModuleSelected: (module) {
          },
          onRefresh: () {
            context.read<TreasuryTransactionsBloc>().add(LoadTreasuryTransactions());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: _config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun élément trouvé.',
          itemCount: cards.length,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileTransactionFormScreen()),
            ).then((_) {
              context.read<TreasuryTransactionsBloc>().add(LoadTreasuryTransactions());
            });
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: cards,
          ),
        );
      },
    );
  }
}
