import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/payments/payments_bloc.dart';
import 'forms/mobile_payment_form_screen.dart';
import 'mobile_payment_detail_screen.dart';


class MobilePaymentsScreen extends StatefulWidget {
  const MobilePaymentsScreen({super.key});

  @override
  State<MobilePaymentsScreen> createState() => _MobilePaymentsScreenState();
}

class _MobilePaymentsScreenState extends State<MobilePaymentsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.payments);
    context.read<PaymentsBloc>().add(LoadPayments());
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
              context.read<PaymentsBloc>().add(DeletePayment(id));
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
    return BlocBuilder<PaymentsBloc, PaymentsState>(
      builder: (context, state) {
        bool isLoading = state is PaymentsLoading || state is PaymentsInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is PaymentsLoaded) {
          final items = state.payments;
          
          final filteredItems = items.where((item) {
            bool matchesSearch = true;
            bool matchesFilter = true;

            String statusStr = translateStatus(item.status);
            String reference = item.paymentNumber;
            String name = item.contactName ?? item.contactId;

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
            String reference = item.paymentNumber;
            String status = translateStatus(item.status);
            String name = item.contactName ?? item.contactId;
            DateTime date = item.paymentDate;
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
                  MaterialPageRoute(builder: (_) => MobilePaymentDetailScreen(payment: item)),
                ).then((_) {
                  context.read<PaymentsBloc>().add(LoadPayments());
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobilePaymentFormScreen(existing: item)),
                ).then((_) {
                  context.read<PaymentsBloc>().add(LoadPayments());
                });
              },
              onDelete: () => _handleDelete(id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.payments,
          onModuleSelected: (module) {
          },
          onRefresh: () {
            context.read<PaymentsBloc>().add(LoadPayments());
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
              MaterialPageRoute(builder: (_) => const MobilePaymentFormScreen()),
            ).then((_) {
              context.read<PaymentsBloc>().add(LoadPayments());
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
