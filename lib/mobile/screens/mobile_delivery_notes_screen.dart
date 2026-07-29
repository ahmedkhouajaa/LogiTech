import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/constants.dart';
import '../../blocs/delivery_notes/delivery_notes_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../models/customer.dart';
import 'forms/mobile_delivery_note_form_screen.dart';
import 'mobile_delivery_note_detail_screen.dart';
import '../../services/firestore_pagination_service.dart';

class MobileDeliveryNotesScreen extends StatefulWidget {
  const MobileDeliveryNotesScreen({super.key});

  @override
  State<MobileDeliveryNotesScreen> createState() => _MobileDeliveryNotesScreenState();
}

class _MobileDeliveryNotesScreenState extends State<MobileDeliveryNotesScreen> {
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
    _config = MobileModuleConfig.getConfig(AppModule.deliveryNotes);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredNotes();
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
      context.read<DeliveryNotesBloc>().add(LoadNextDeliveryNotes(
        searchQuery: _searchQuery,
        customerId: _selectedCustomerId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredNotes() {
    context.read<DeliveryNotesBloc>().add(LoadFirstDeliveryNotes(
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
    _fetchFilteredNotes();
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
              context.read<DeliveryNotesBloc>().add(DeleteDeliveryNote(id));
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
    return BlocBuilder<DeliveryNotesBloc, DeliveryNotesState>(
      builder: (context, state) {
        bool isLoading = state is DeliveryNotesLoading || state is DeliveryNotesInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        final customersState = context.watch<CustomersBloc>().state;
        List<Customer> customersList = [];
        if (customersState is CustomersLoaded) {
          customersList = customersState.customers;
        }

        if (state is DeliveryNotesLoaded) {
          final items = state.notes;
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
              final statusLower = item.status.toLowerCase();
              final translatedLower = translateStatus(item.status).toLowerCase();
              final filterLower = _selectedStatus!.toLowerCase();
              if (statusLower != filterLower && translatedLower != filterLower) return false;
            }

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((item) {
            return MobileGenericCard(
              reference: item.number,
              status: item.status,
              name: item.customerName ?? 'Client Inconnu',
              date: item.date,
              amount: item.totalTTC,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileDeliveryNoteDetailScreen(deliveryNote: item)),
                ).then((_) {
                  _fetchFilteredNotes();
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileDeliveryNoteFormScreen(existing: item)),
                ).then((_) {
                  _fetchFilteredNotes();
                });
              },
              onDelete: () => _handleDelete(item.id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.deliveryNotes,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<DeliveryNotesBloc>().add(ResetDeliveryNotesPagination(
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
            _fetchFilteredNotes();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            selectedCustomerId: _selectedCustomerId,
            customers: customersList,
            onCustomerChanged: (id) {
              setState(() => _selectedCustomerId = id);
              _fetchFilteredNotes();
            },
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredNotes();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredNotes();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Livré', 'Facturé', 'Annulé'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredNotes();
            },
            onResetFilters: () {
              setState(() {
                _selectedCustomerId = null;
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredNotes();
            },
            itemCount: totalMatchingCount,
          ),
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun bon de livraison trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileDeliveryNoteFormScreen()),
            ).then((_) {
              _fetchFilteredNotes();
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
