import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/supplier_orders/supplier_orders_bloc.dart';
import 'forms/mobile_supplier_order_form_screen.dart';
import 'mobile_supplier_order_detail_screen.dart';


class MobileSupplierOrdersScreen extends StatefulWidget {
  const MobileSupplierOrdersScreen({super.key});

  @override
  State<MobileSupplierOrdersScreen> createState() => _MobileSupplierOrdersScreenState();
}

class _MobileSupplierOrdersScreenState extends State<MobileSupplierOrdersScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.supplierOrders);
    context.read<SupplierOrdersBloc>().add(LoadSupplierOrders());
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
              context.read<SupplierOrdersBloc>().add(DeleteSupplierOrder(id));
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
    return BlocBuilder<SupplierOrdersBloc, SupplierOrdersState>(
      builder: (context, state) {
        bool isLoading = state is SupplierOrdersLoading || state is SupplierOrdersInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is SupplierOrdersLoaded) {
          final items = state.orders;
          
          final filteredItems = items.where((item) {
            bool matchesSearch = true;
            bool matchesFilter = true;

            String statusStr = 'N/A';
            try {
              final s = (item as dynamic).status;
              if (s != null) {
                statusStr = translateStatus(s.toString());
              }
            } catch (_) {}

            String reference = '';
            try { reference = ((item as dynamic).number ?? (item as dynamic).reference ?? (item as dynamic).name ?? '').toString(); } catch (_) {}
            
            String name = '';
            try { name = ((item as dynamic).customerName ?? (item as dynamic).supplierName ?? (item as dynamic).companyName ?? (item as dynamic).name ?? '').toString(); } catch (_) {}

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
            String reference = item.number;
            String status = translateStatus(item.status);
            String? name = item.supplierName ?? item.supplierCompany ?? 'Fournisseur Inconnu';
            DateTime? date = item.date;
            double amount = item.totalTTC;
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
                  MaterialPageRoute(builder: (_) => MobileSupplierOrderDetailScreen(order: item)),
                );
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileSupplierOrderFormScreen(existing: item)),
                ).then((_) {
                  context.read<SupplierOrdersBloc>().add(LoadSupplierOrders());
                });
              },
              onDelete: () => _handleDelete(id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.supplierOrders,
          onModuleSelected: (module) {
          },
          onRefresh: () {
            context.read<SupplierOrdersBloc>().add(LoadSupplierOrders());
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
                MaterialPageRoute(builder: (_) => const MobileSupplierOrderFormScreen()),
              ).then((_) {
                context.read<SupplierOrdersBloc>().add(LoadSupplierOrders());
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
