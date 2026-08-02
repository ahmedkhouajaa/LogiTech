import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/constants.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_state.dart';
import '../../blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../models/supplier.dart';
import 'forms/mobile_supplier_credit_note_form_screen.dart';
import 'mobile_supplier_credit_note_detail_screen.dart';
import '../../services/firestore_pagination_service.dart';

class MobileSupplierCreditNotesScreen extends StatefulWidget {
  const MobileSupplierCreditNotesScreen({super.key});

  @override
  State<MobileSupplierCreditNotesScreen> createState() => _MobileSupplierCreditNotesScreenState();
}

class _MobileSupplierCreditNotesScreenState extends State<MobileSupplierCreditNotesScreen> {
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
    _config = MobileModuleConfig.getConfig(AppModule.supplierCreditNotes);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredCreditNotes();
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
      context.read<SupplierCreditNotesBloc>().add(LoadNextSupplierCreditNotes(
        searchQuery: _searchQuery,
        supplierId: _selectedSupplierId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredCreditNotes() {
    context.read<SupplierCreditNotesBloc>().add(LoadFirstSupplierCreditNotes(
      searchQuery: _searchQuery,
      supplierId: _selectedSupplierId,
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
              context.read<SupplierCreditNotesBloc>().add(DeleteSupplierCreditNote(id));
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
    return BlocBuilder<SupplierCreditNotesBloc, SupplierCreditNotesState>(
      builder: (context, state) {
        bool isLoading = state is SupplierCreditNotesLoading || state is SupplierCreditNotesInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        final suppliersState = context.watch<SuppliersBloc>().state;
        List<Supplier> suppliersList = [];
        if (suppliersState is SuppliersLoaded) {
          suppliersList = suppliersState.suppliers;
        }

        if (state is SupplierCreditNotesLoaded) {
          final items = state.creditNotes;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((item) {
            String reference = item.number;

            String name = 'Fournisseur Inconnu';
            if (item.supplierId.isNotEmpty) {
              final found = suppliersList.firstWhere(
                (s) => s.id == item.supplierId,
                orElse: () => Supplier(id: '', code: '', name: 'Fournisseur Inconnu', country: ''),
              );
              if (found.name != 'Fournisseur Inconnu') {
                name = found.name;
              } else if (found.companyName?.isNotEmpty == true) {
                name = found.companyName!;
              }
            }

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              if (!reference.toLowerCase().contains(query) && !name.toLowerCase().contains(query)) {
                return false;
              }
            }

            if (_selectedSupplierId != null && _selectedSupplierId!.isNotEmpty) {
              if (item.supplierId != _selectedSupplierId) return false;
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
              final rawStatus = item.status.toLowerCase();
              final translatedLower = translateStatus(item.status).toLowerCase();
              final filterLower = _selectedStatus!.toLowerCase();
              if (rawStatus != filterLower && translatedLower != filterLower) return false;
            }

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((item) {
            String reference = item.number;
            String status = item.status;
            DateTime date = item.date;
            double amount = item.totalTTC;

            String name = 'Fournisseur Inconnu';
            if (item.supplierId.isNotEmpty) {
              final found = suppliersList.firstWhere(
                (s) => s.id == item.supplierId,
                orElse: () => Supplier(id: '', code: '', name: 'Fournisseur Inconnu', country: ''),
              );
              if (found.id.isNotEmpty) {
                name = (found.companyName != null && found.companyName!.isNotEmpty) ? found.companyName! : found.name;
              }
            }

            return MobileGenericCard(
              reference: reference,
              status: status,
              name: name,
              date: date,
              amount: amount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: context.read<SuppliersBloc>()),
                        BlocProvider.value(value: context.read<ProductsBloc>()),
                        BlocProvider.value(value: context.read<SupplierCreditNotesBloc>()),
                      ],
                      child: MobileSupplierCreditNoteDetailScreen(note: item),
                    ),
                  ),
                ).then((_) {
                  _fetchFilteredCreditNotes();
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileSupplierCreditNoteFormScreen(existing: item)),
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
          activeModule: AppModule.supplierCreditNotes,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<SupplierCreditNotesBloc>().add(ResetSupplierCreditNotesPagination(
              searchQuery: _searchQuery,
              supplierId: _selectedSupplierId,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              status: _selectedStatus,
            ));
            context.read<SuppliersBloc>().add(LoadSuppliers());
          },
          onSearchChanged: _onSearchChanged,
          filterOptions: const [],
          selectedFilter: _selectedStatus ?? 'Tous',
          onFilterChanged: (val) {
            setState(() => _selectedStatus = val == 'Tous' ? null : val);
            _fetchFilteredCreditNotes();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            entityLabel: 'Fournisseur',
            selectedCustomerId: _selectedSupplierId,
            suppliers: suppliersList,
            onCustomerChanged: (id) {
              setState(() => _selectedSupplierId = id);
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
                _selectedSupplierId = null;
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
          emptyMessage: 'Aucun élément trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MobileSupplierCreditNoteFormScreen()),
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
