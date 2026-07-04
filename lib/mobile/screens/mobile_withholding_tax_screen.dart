import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/payments/payments_bloc.dart';

class MobileWithholdingTaxScreen extends StatefulWidget {
  final bool isSales;
  const MobileWithholdingTaxScreen({super.key, required this.isSales});

  @override
  State<MobileWithholdingTaxScreen> createState() => _MobileWithholdingTaxScreenState();
}

class _MobileWithholdingTaxScreenState extends State<MobileWithholdingTaxScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(widget.isSales ? AppModule.withholdingTaxSales : AppModule.withholdingTaxPurchase);
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentsBloc, PaymentsState>(
      builder: (context, state) {
        bool isLoading = state is PaymentsLoading || state is PaymentsInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is PaymentsLoaded) {
          final items = state.payments;
          print("DEBUG (RS): Total payments loaded from DB: ${items.length}");

          final filteredItems = items.where((p) {
            if (p.method != 'retenue_source') return false;
            
            if (widget.isSales && p.direction != 'encaissement') return false;
            if (!widget.isSales && p.direction != 'decaissement') return false;

            bool matchesSearch = true;
            bool matchesFilter = true;

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final reference = p.reference?.toLowerCase() ?? '';
              final number = p.paymentNumber.toLowerCase();
              final contact = p.contactName?.toLowerCase() ?? '';

              if (!reference.contains(query) && !number.contains(query) && !contact.contains(query)) {
                matchesSearch = false;
              }
            }

            if (_selectedFilter != 'Tous') {
              if (_selectedFilter == 'En attente' && p.status != 'pending') {
                matchesFilter = false;
              } else if (_selectedFilter == 'Payé' && p.status != 'paid') {
                matchesFilter = false;
              } else if (_selectedFilter == 'Annulé' && p.status != 'cancelled') {
                matchesFilter = false;
              }
            }

            return matchesSearch && matchesFilter;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((p) {
            String reference = p.reference ?? p.paymentNumber;
            String? name = p.contactName ?? 'Inconnu';
            DateTime? date = p.paymentDate;
            double amount = p.amount;

            return MobileGenericCard(
              reference: reference,
              status: 'Payé',
              name: name,
              date: date,
              amount: amount,
              onTap: () {
                // Navigation to details can be added later
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: widget.isSales ? AppModule.withholdingTaxSales : AppModule.withholdingTaxPurchase,
          onModuleSelected: (module) {},
          onRefresh: () {
            context.read<PaymentsBloc>().add(LoadPayments());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: _config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucune retenue à la source trouvée.',
          fabText: _config.fabText,
          onFabPressed: () {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Création bientôt disponible')),
             );
          },
          child: Column(
            children: [
              if (state is PaymentsLoaded)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "DEBUG: Total paiements en base = ${state.payments.length}",
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              if (state is PaymentsError)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "DEBUG ERROR: ${state.message}",
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: cards,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
