import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import 'forms/mobile_purchase_invoice_form_screen.dart';
import 'mobile_purchase_invoice_detail_screen.dart';


class MobilePurchaseInvoicesScreen extends StatefulWidget {
  const MobilePurchaseInvoicesScreen({super.key});

  @override
  State<MobilePurchaseInvoicesScreen> createState() => _MobilePurchaseInvoicesScreenState();
}

class _MobilePurchaseInvoicesScreenState extends State<MobilePurchaseInvoicesScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.purchaseInvoices);
    context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
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
              context.read<PurchaseInvoicesBloc>().add(DeletePurchaseInvoice(id));
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
    return BlocBuilder<PurchaseInvoicesBloc, PurchaseInvoicesState>(
      builder: (context, state) {
        bool isLoading = state is PurchaseInvoicesLoading || state is PurchaseInvoicesInitial;
        bool isEmpty = true;
        List<Widget> cards = [];

        if (state is PurchaseInvoicesLoaded) {
          final items = state.purchaseInvoices;
          
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
            String status = item.status.label;
            String? name = item.supplierName ?? 'Fournisseur Inconnu';
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
                  MaterialPageRoute(builder: (_) => MobilePurchaseInvoiceDetailScreen(invoice: item)),
                );
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobilePurchaseInvoiceFormScreen(existing: item)),
                ).then((_) {
                  context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
                });
              },
              onDelete: () => _handleDelete(id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.purchaseInvoices,
          onModuleSelected: (module) {
          },
          onRefresh: () {
            context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
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
                MaterialPageRoute(builder: (_) => const MobilePurchaseInvoiceFormScreen()),
              ).then((_) {
                context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
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
