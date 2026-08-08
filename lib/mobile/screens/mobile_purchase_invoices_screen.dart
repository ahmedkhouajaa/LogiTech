import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/purchase_invoices/purchase_invoices_bloc.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../models/supplier.dart';
import 'forms/mobile_purchase_invoice_form_screen.dart';
import 'mobile_purchase_invoice_detail_screen.dart';
import '../../services/firestore_pagination_service.dart';

class MobilePurchaseInvoicesScreen extends StatefulWidget {
  const MobilePurchaseInvoicesScreen({super.key});

  @override
  State<MobilePurchaseInvoicesScreen> createState() => _MobilePurchaseInvoicesScreenState();
}

class _MobilePurchaseInvoicesScreenState extends State<MobilePurchaseInvoicesScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedSupplierId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _selectedStatus;
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.purchaseInvoices);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredPurchaseInvoices();
    context.read<SuppliersBloc>().add(LoadSuppliers());
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
      context.read<PurchaseInvoicesBloc>().add(LoadNextPurchaseInvoices(
        searchQuery: _searchQuery,
        supplierId: _selectedSupplierId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredPurchaseInvoices() {
    context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredPurchaseInvoices();
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
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        final suppliersState = context.watch<SuppliersBloc>().state;
        List<Supplier> suppliersList = [];
        if (suppliersState is SuppliersLoaded) {
          suppliersList = suppliersState.suppliers;
        }

        if (state is PurchaseInvoicesLoaded) {
          final items = state.purchaseInvoices;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((item) {
            // 1. Search Query
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final numMatch = item.number.toLowerCase().contains(query);
              final supMatch = (item.supplierName ?? '').toLowerCase().contains(query);
              if (!numMatch && !supMatch) return false;
            }

            // 2. Supplier Filter
            if (_selectedSupplierId != null && _selectedSupplierId!.isNotEmpty) {
              if (item.supplierId != _selectedSupplierId) return false;
            }

            // 3. Date From Filter
            if (_dateFrom != null) {
              final iDate = DateTime(item.date.year, item.date.month, item.date.day);
              final fDate = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
              if (iDate.isBefore(fDate)) return false;
            }

            // 4. Date To Filter
            if (_dateTo != null) {
              final iDate = DateTime(item.date.year, item.date.month, item.date.day);
              final tDate = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
              if (iDate.isAfter(tDate)) return false;
            }

            // 5. Status Filter
            if (_selectedStatus != null && _selectedStatus != 'Tous' && _selectedStatus!.isNotEmpty) {
              final statusLabel = item.status.label.toLowerCase();
              final filterLower = _selectedStatus!.toLowerCase();
              if (statusLabel != filterLower) return false;
            }

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((item) {
            final reference = item.number;
            final status = item.status.label;
            final name = item.supplierName ?? 'Fournisseur Inconnu';
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
                  MaterialPageRoute(builder: (_) => MobilePurchaseInvoiceDetailScreen(invoice: item)),
                ).then((_) {
                  _fetchFilteredPurchaseInvoices();
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobilePurchaseInvoiceFormScreen(existing: item)),
                ).then((_) {
                  _fetchFilteredPurchaseInvoices();
                });
              },
              onDelete: () => _handleDelete(item.id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.purchaseInvoices,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
            context.read<SuppliersBloc>().add(LoadSuppliers());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const [],
          selectedFilter: _selectedStatus ?? 'Tous',
          onFilterChanged: (val) {
            setState(() => _selectedStatus = val == 'Tous' ? null : val);
            _fetchFilteredPurchaseInvoices();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            entityLabel: 'Fournisseur',
            selectedEntityId: _selectedSupplierId,
            suppliers: suppliersList,
            onEntityChanged: (id) {
              setState(() => _selectedSupplierId = id);
              _fetchFilteredPurchaseInvoices();
            },
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredPurchaseInvoices();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredPurchaseInvoices();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Envoyé', 'Payée', 'Partiellement payée', 'Non payée', 'Annulée'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredPurchaseInvoices();
            },
            onResetFilters: () {
              setState(() {
                _selectedSupplierId = null;
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredPurchaseInvoices();
            },
            itemCount: totalMatchingCount,
          ),
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucune facture d\'achat trouvée.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobilePurchaseInvoiceFormScreen()),
            ).then((_) {
              _fetchFilteredPurchaseInvoices();
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
