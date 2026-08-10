import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/return_notes/return_notes_bloc.dart';
import '../../blocs/return_notes/return_notes_state.dart';
import '../../blocs/return_notes/return_notes_event.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/projects/projects_bloc.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../models/customer.dart';
import 'mobile_return_note_detail_screen.dart';
import 'forms/mobile_return_voucher_form_screen.dart';
import '../../services/firestore_pagination_service.dart';

class MobileReturnNotesScreen extends StatefulWidget {
  const MobileReturnNotesScreen({super.key});

  @override
  State<MobileReturnNotesScreen> createState() => _MobileReturnNotesScreenState();
}

class _MobileReturnNotesScreenState extends State<MobileReturnNotesScreen> {
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
    _config = MobileModuleConfig.getConfig(AppModule.returnVouchers);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredReturnNotes();
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
      context.read<ReturnNotesBloc>().add(LoadNextReturnNotes(
        searchQuery: _searchQuery,
        customerId: _selectedCustomerId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredReturnNotes() {
    context.read<ReturnNotesBloc>().add(LoadFirstReturnNotes(
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
    _fetchFilteredReturnNotes();
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
              context.read<ReturnNotesBloc>().add(DeleteReturnNote(id));
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
    return BlocBuilder<ReturnNotesBloc, ReturnNotesState>(
      builder: (context, state) {
        bool isLoading = state is ReturnNotesLoading || state is ReturnNotesInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        final customersState = context.watch<CustomersBloc>().state;
        List<Customer> customersList = [];
        if (customersState is CustomersLoaded) {
          customersList = customersState.customers;
        }

        if (state is ReturnNotesLoaded) {
          final items = state.notes;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((item) {
            String reference = item.returnNumber;
            String name = item.customerName ?? item.customerCompany ?? '';

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              if (!reference.toLowerCase().contains(query) && !name.toLowerCase().contains(query)) {
                return false;
              }
            }

            if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
              if (item.customerId != _selectedCustomerId) return false;
            }

            final dEmission = item.dateEmission;
            if (_dateFrom != null) {
              final itemDate = DateTime(dEmission.year, dEmission.month, dEmission.day);
              final fDate = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
              if (itemDate.isBefore(fDate)) return false;
            }

            if (_dateTo != null) {
              final itemDate = DateTime(dEmission.year, dEmission.month, dEmission.day);
              final tDate = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
              if (itemDate.isAfter(tDate)) return false;
            }

            if (_selectedStatus != null && _selectedStatus != 'Tous' && _selectedStatus!.isNotEmpty) {
              final rawStatus = item.status.toLowerCase();
              final filterLower = _selectedStatus!.toLowerCase();
              if (rawStatus != filterLower) return false;
            }

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((item) {
            String reference = item.returnNumber;
            String status = item.status;
            String? name = item.customerName ?? item.customerCompany ?? 'Client Inconnu';
            DateTime date = item.dateEmission;
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
                  MaterialPageRoute(builder: (_) => MobileReturnNoteDetailScreen(returnNote: item)),
                ).then((_) {
                  _fetchFilteredReturnNotes();
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: context.read<ReturnNotesBloc>()),
                      BlocProvider.value(value: context.read<CustomersBloc>()),
                      BlocProvider.value(value: context.read<ProductsBloc>()),
                      BlocProvider.value(value: context.read<ProjectsBloc>()),
                      BlocProvider.value(value: context.read<WarehousesBloc>()),
                    ],
                    child: MobileReturnVoucherFormScreen(existing: item),
                  )),
                ).then((_) {
                  _fetchFilteredReturnNotes();
                });
              },
              onDelete: () => _handleDelete(id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.returnVouchers,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<ReturnNotesBloc>().add(ResetReturnNotesPagination(
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
            _fetchFilteredReturnNotes();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            entityLabel: 'Client',
            selectedCustomerId: _selectedCustomerId,
            customers: customersList,
            onCustomerChanged: (id) {
              setState(() => _selectedCustomerId = id);
              _fetchFilteredReturnNotes();
            },
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredReturnNotes();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredReturnNotes();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Validé', 'Payée', 'Annulé'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredReturnNotes();
            },
            onResetFilters: () {
              setState(() {
                _selectedCustomerId = null;
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredReturnNotes();
            },
            itemCount: totalMatchingCount,
          ),
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun bon de retour trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<ReturnNotesBloc>()),
                  BlocProvider.value(value: context.read<CustomersBloc>()),
                  BlocProvider.value(value: context.read<ProductsBloc>()),
                  BlocProvider.value(value: context.read<ProjectsBloc>()),
                  BlocProvider.value(value: context.read<WarehousesBloc>()),
                ],
                child: const MobileReturnVoucherFormScreen(),
              )),
            ).then((_) {
              _fetchFilteredReturnNotes();
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
