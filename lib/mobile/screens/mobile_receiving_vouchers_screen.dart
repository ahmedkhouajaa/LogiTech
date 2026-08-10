import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import '../../blocs/suppliers/suppliers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/projects/projects_bloc.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../models/supplier.dart';
import 'forms/mobile_receiving_voucher_form_screen.dart';
import 'mobile_receiving_voucher_detail_screen.dart';
import '../../services/firestore_pagination_service.dart';

class MobileReceivingVouchersScreen extends StatefulWidget {
  const MobileReceivingVouchersScreen({super.key});

  @override
  State<MobileReceivingVouchersScreen> createState() => _MobileReceivingVouchersScreenState();
}

class _MobileReceivingVouchersScreenState extends State<MobileReceivingVouchersScreen> {
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
    _config = MobileModuleConfig.getConfig(AppModule.receivingVouchers);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredVouchers();
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
      context.read<ReceivingVouchersBloc>().add(LoadNextReceivingVouchers(
        searchQuery: _searchQuery,
        supplierId: _selectedSupplierId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _fetchFilteredVouchers() {
    context.read<ReceivingVouchersBloc>().add(LoadFirstReceivingVouchers(
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
    _fetchFilteredVouchers();
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
              context.read<ReceivingVouchersBloc>().add(DeleteReceivingVoucher(id));
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
    return BlocBuilder<ReceivingVouchersBloc, ReceivingVouchersState>(
      builder: (context, state) {
        bool isLoading = state is ReceivingVouchersLoading || state is ReceivingVouchersInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        final suppliersState = context.watch<SuppliersBloc>().state;
        List<Supplier> suppliersList = [];
        if (suppliersState is SuppliersLoaded) {
          suppliersList = suppliersState.suppliers;
        }

        if (state is ReceivingVouchersLoaded) {
          final items = state.vouchers;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          final filteredItems = items.where((item) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final numMatch = item.number.toLowerCase().contains(query);
              final supMatch = (item.supplierName ?? '').toLowerCase().contains(query);
              if (!numMatch && !supMatch) return false;
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
              final statusLabel = item.status.toLowerCase();
              final filterLower = _selectedStatus!.toLowerCase();
              if (statusLabel != filterLower) return false;
            }

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((item) {
            final reference = item.number;
            final status = item.status;
            final name = item.supplierName ?? 'Fournisseur Inconnu';
            final date = item.date;
            final amount = item.computedTotalTTC;

            return MobileGenericCard(
              reference: reference,
              status: status,
              name: name,
              date: date,
              amount: amount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MobileReceivingVoucherDetailScreen(voucher: item)),
                ).then((_) {
                  _fetchFilteredVouchers();
                });
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider.value(value: context.read<ReceivingVouchersBloc>()),
                      BlocProvider.value(value: context.read<SuppliersBloc>()),
                      BlocProvider.value(value: context.read<ProductsBloc>()),
                      BlocProvider.value(value: context.read<ProjectsBloc>()),
                      BlocProvider.value(value: context.read<WarehousesBloc>()),
                    ],
                    child: MobileReceivingVoucherFormScreen(existing: item),
                  )),
                ).then((_) {
                  _fetchFilteredVouchers();
                });
              },
              onDelete: () => _handleDelete(item.id),
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.receivingVouchers,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<ReceivingVouchersBloc>().add(ResetReceivingVouchersPagination(
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
            _fetchFilteredVouchers();
          },
          customFilterWidget: MobileAdvancedFilterPanel(
            entityLabel: 'Fournisseur',
            selectedCustomerId: _selectedSupplierId,
            suppliers: suppliersList,
            onCustomerChanged: (id) {
              setState(() => _selectedSupplierId = id);
              _fetchFilteredVouchers();
            },
            dateFrom: _dateFrom,
            onDateFromChanged: (d) {
              setState(() => _dateFrom = d);
              _fetchFilteredVouchers();
            },
            dateTo: _dateTo,
            onDateToChanged: (d) {
              setState(() => _dateTo = d);
              _fetchFilteredVouchers();
            },
            selectedStatus: _selectedStatus,
            statusOptions: const ['Tous', 'Brouillon', 'Reçu', 'Facturé', 'Annulé'],
            onStatusChanged: (s) {
              setState(() => _selectedStatus = s);
              _fetchFilteredVouchers();
            },
            onResetFilters: () {
              setState(() {
                _selectedSupplierId = null;
                _dateFrom = null;
                _dateTo = null;
                _selectedStatus = null;
              });
              _fetchFilteredVouchers();
            },
            itemCount: totalMatchingCount,
          ),
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun bon de réception trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<ReceivingVouchersBloc>()),
                  BlocProvider.value(value: context.read<SuppliersBloc>()),
                  BlocProvider.value(value: context.read<ProductsBloc>()),
                  BlocProvider.value(value: context.read<ProjectsBloc>()),
                  BlocProvider.value(value: context.read<WarehousesBloc>()),
                ],
                child: const MobileReceivingVoucherFormScreen(),
              )),
            ).then((_) {
              _fetchFilteredVouchers();
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
