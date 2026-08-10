import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/credit_notes/credit_notes_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/invoices/invoices_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/projects/projects_bloc.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../models/customer.dart';
import 'forms/mobile_credit_note_form_screen.dart';
import 'mobile_credit_note_detail_screen.dart';
import '../../services/firestore_pagination_service.dart';

class MobileCreditNotesScreen extends StatefulWidget {
  const MobileCreditNotesScreen({super.key});

  @override
  State<MobileCreditNotesScreen> createState() => _MobileCreditNotesScreenState();
}

class _MobileCreditNotesScreenState extends State<MobileCreditNotesScreen> {
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
    _config = MobileModuleConfig.getConfig(AppModule.creditNotes);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredCreditNotes();
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
      context.read<CreditNotesBloc>().add(LoadNextCreditNotes(
        searchQuery: _searchQuery,
        customerId: _selectedCustomerId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredCreditNotes() {
    context.read<CreditNotesBloc>().add(LoadFirstCreditNotes(
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
    _fetchFilteredCreditNotes();
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
              context.read<CreditNotesBloc>().add(DeleteCreditNote(id));
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
    return BlocBuilder<CreditNotesBloc, CreditNotesState>(
      builder: (context, state) {
        bool isLoading = state is CreditNotesLoading || state is CreditNotesInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        final customersState = context.watch<CustomersBloc>().state;
        List<Customer> customersList = [];
        if (customersState is CustomersLoaded) {
          customersList = customersState.customers;
        }

        if (state is CreditNotesLoaded) {
          final items = state.creditNotes;
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
            final name = item.customerName ?? 'Client Inconnu';
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
                  MaterialPageRoute(builder: (_) => MobileCreditNoteDetailScreen(creditNote: item)),
                ).then((_) {
                  _fetchFilteredCreditNotes();
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: context.read<CreditNotesBloc>()),
                      BlocProvider.value(value: context.read<CustomersBloc>()),
                      BlocProvider.value(value: context.read<InvoicesBloc>()),
                      BlocProvider.value(value: context.read<ProductsBloc>()),
                      BlocProvider.value(value: context.read<ProjectsBloc>()),
                      BlocProvider.value(value: context.read<WarehousesBloc>()),
                    ],
                    child: MobileCreditNoteFormScreen(existing: item),
                  )),
                ).then((_) {
                  _fetchFilteredCreditNotes();
                });
              },
              onDelete: () => _handleDelete(item.id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.creditNotes,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<CreditNotesBloc>().add(ResetCreditNotesPagination(
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
            _fetchFilteredCreditNotes();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            entityLabel: 'Client',
            selectedCustomerId: _selectedCustomerId,
            customers: customersList,
            onCustomerChanged: (id) {
              setState(() => _selectedCustomerId = id);
              _fetchFilteredCreditNotes();
            },
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredCreditNotes();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredCreditNotes();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Créé', 'Validé', 'Annulé'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredCreditNotes();
            },
            onResetFilters: () {
              setState(() {
                _selectedCustomerId = null;
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredCreditNotes();
            },
            itemCount: totalMatchingCount,
          ),
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun avoir trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<CreditNotesBloc>()),
                  BlocProvider.value(value: context.read<CustomersBloc>()),
                  BlocProvider.value(value: context.read<InvoicesBloc>()),
                  BlocProvider.value(value: context.read<ProductsBloc>()),
                  BlocProvider.value(value: context.read<ProjectsBloc>()),
                  BlocProvider.value(value: context.read<WarehousesBloc>()),
                ],
                child: const MobileCreditNoteFormScreen(),
              )),
            ).then((_) {
              _fetchFilteredCreditNotes();
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
