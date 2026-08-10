import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../widgets/mobile_advanced_filter_panel.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/stock_withdrawals/stock_withdrawals_bloc.dart';
import '../../blocs/exit_vouchers/exit_vouchers_bloc.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../blocs/products/products_bloc.dart';
import '../../blocs/projects/projects_bloc.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../models/customer.dart';
import '../../services/sync_service.dart';
import 'forms/mobile_exit_voucher_form_screen.dart';
import 'mobile_stock_withdrawal_detail_screen.dart';
import '../../models/stock_withdrawal.dart';
import '../../services/firestore_pagination_service.dart';

class MobileStockWithdrawalsScreen extends StatefulWidget {
  final AppModule activeModule;
  const MobileStockWithdrawalsScreen({super.key, this.activeModule = AppModule.exitVouchers});

  @override
  State<MobileStockWithdrawalsScreen> createState() => _MobileStockWithdrawalsScreenState();
}

class _MobileStockWithdrawalsScreenState extends State<MobileStockWithdrawalsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedCustomerId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _selectedStatus;
  late MobileModuleConfig _config;
  StreamSubscription<SyncStatus>? _syncSubscription;

  bool get _isExitVoucher => widget.activeModule == AppModule.exitVouchers;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(widget.activeModule);
    FirestorePaginationService.instance.enablePersistence();
    _fetchFilteredWithdrawals();
    context.read<CustomersBloc>().add(LoadCustomers());
    _scrollController.addListener(_onScroll);

    _syncSubscription = SyncService.instance.onSyncStatusChanged.listen((status) {
      if (status == SyncStatus.success && mounted) {
        _fetchFilteredWithdrawals();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_isExitVoucher) {
        context.read<ExitVouchersBloc>().add(LoadNextExitVouchers(
          searchQuery: _searchQuery,
          customerId: _selectedCustomerId,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          status: _selectedStatus,
        ));
      } else {
        context.read<StockWithdrawalsBloc>().add(LoadNextStockWithdrawals(
          searchQuery: _searchQuery,
          customerId: _selectedCustomerId,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          status: _selectedStatus,
        ));
      }
    }
  }

  void _fetchFilteredWithdrawals() {
    if (_isExitVoucher) {
      context.read<ExitVouchersBloc>().add(LoadFirstExitVouchers(
        searchQuery: _searchQuery,
        customerId: _selectedCustomerId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    } else {
      context.read<StockWithdrawalsBloc>().add(LoadFirstStockWithdrawals(
        searchQuery: _searchQuery,
        customerId: _selectedCustomerId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        status: _selectedStatus,
      ));
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredWithdrawals();
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
              if (_isExitVoucher) {
                context.read<ExitVouchersBloc>().add(DeleteExitVoucher(id));
              } else {
                context.read<StockWithdrawalsBloc>().add(DeleteStockWithdrawal(id));
              }
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
    final customersState = context.watch<CustomersBloc>().state;
    List<Customer> customersList = [];
    if (customersState is CustomersLoaded) {
      customersList = customersState.customers;
    }

    if (_isExitVoucher) {
      return BlocBuilder<ExitVouchersBloc, ExitVouchersState>(
        builder: (context, state) {
          bool isLoading = state is ExitVouchersLoading || state is ExitVouchersInitial;
          bool isLoadingMore = false;
          int totalMatchingCount = 0;
          List<StockWithdrawal> items = [];
          if (state is ExitVouchersLoaded) {
            items = state.withdrawals;
            isLoadingMore = state.isLoadingMore;
            totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;
          }
          return _buildListScreen(items, isLoading, isLoadingMore, totalMatchingCount, customersList);
        },
      );
    } else {
      return BlocBuilder<StockWithdrawalsBloc, StockWithdrawalsState>(
        builder: (context, state) {
          bool isLoading = state is StockWithdrawalsLoading || state is StockWithdrawalsInitial;
          bool isLoadingMore = false;
          int totalMatchingCount = 0;
          List<StockWithdrawal> items = [];
          if (state is StockWithdrawalsLoaded) {
            items = state.withdrawals;
            isLoadingMore = state.isLoadingMore;
            totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;
          }
          return _buildListScreen(items, isLoading, isLoadingMore, totalMatchingCount, customersList);
        },
      );
    }
  }

  Widget _buildListScreen(List<StockWithdrawal> items, bool isLoading, bool isLoadingMore, int totalMatchingCount, List<Customer> customersList) {
    final filteredItems = items.where((item) {
      String reference = item.number;
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

      if (_dateFrom != null) {
        final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
        final fDate = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
        if (itemDate.isBefore(fDate)) return false;
      }

      if (_dateTo != null) {
        final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
        final tDate = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
        if (itemDate.isAfter(tDate)) return false;
      }

      if (_selectedStatus != null && _selectedStatus != 'Tous' && _selectedStatus!.isNotEmpty) {
        final statusStr = translateStatus(item.status).toLowerCase();
        final rawStatus = item.status.toLowerCase();
        final filterLower = _selectedStatus!.toLowerCase();
        if (statusStr != filterLower && rawStatus != filterLower) return false;
      }

      return true;
    }).toList();

    bool isEmpty = filteredItems.isEmpty;

    List<Widget> cards = filteredItems.map((item) {
      return MobileGenericCard(
        reference: item.number,
        status: item.status,
        name: item.customerName ?? item.customerCompany ?? 'Client non spécifié',
        nameIcon: Icons.person_outline,
        date: item.date,
        amount: item.totalTTC,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MobileStockWithdrawalDetailScreen(withdrawal: item, isExitVoucher: _isExitVoucher)),
          ).then((_) {
            _fetchFilteredWithdrawals();
          });
        },
        onEdit: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<ExitVouchersBloc>()),
                BlocProvider.value(value: context.read<StockWithdrawalsBloc>()),
                BlocProvider.value(value: context.read<CustomersBloc>()),
                BlocProvider.value(value: context.read<ProductsBloc>()),
                BlocProvider.value(value: context.read<ProjectsBloc>()),
                BlocProvider.value(value: context.read<WarehousesBloc>()),
              ],
              child: MobileExitVoucherFormScreen(
                existing: item,
                isExitVoucher: _isExitVoucher,
              ),
            )),
          ).then((_) {
            _fetchFilteredWithdrawals();
          });
        },
        onDelete: () => _handleDelete(item.id),
      );
    }).toList();

    return MobileGenericListScreen(
      title: _config.title,
      activeModule: widget.activeModule,
      onModuleSelected: (module) {},
      onRefresh: () async {
        if (_isExitVoucher) {
          context.read<ExitVouchersBloc>().add(ResetExitVouchersPagination(
            searchQuery: _searchQuery,
            customerId: _selectedCustomerId,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            status: _selectedStatus,
          ));
        } else {
          context.read<StockWithdrawalsBloc>().add(ResetStockWithdrawalsPagination(
            searchQuery: _searchQuery,
            customerId: _selectedCustomerId,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            status: _selectedStatus,
          ));
        }
        context.read<CustomersBloc>().add(LoadCustomers());
      },
      onSearchChanged: _onSearchChanged,
      filterOptions: const [],
      selectedFilter: _selectedStatus ?? 'Tous',
      onFilterChanged: (val) {
        setState(() => _selectedStatus = val == 'Tous' ? null : val);
        _fetchFilteredWithdrawals();
      },
      customFilterWidget: MobileAdvancedFilterPanel(
        entityLabel: 'Client',
        selectedCustomerId: _selectedCustomerId,
        customers: customersList,
        onCustomerChanged: (id) {
          setState(() => _selectedCustomerId = id);
          _fetchFilteredWithdrawals();
        },
        dateFrom: _dateFrom,
        onDateFromChanged: (d) {
          setState(() => _dateFrom = d);
          _fetchFilteredWithdrawals();
        },
        dateTo: _dateTo,
        onDateToChanged: (d) {
          setState(() => _dateTo = d);
          _fetchFilteredWithdrawals();
        },
        selectedStatus: _selectedStatus,
        statusOptions: const ['Tous', 'Brouillon', 'Validé', 'Facturé', 'Annulé'],
        onStatusChanged: (s) {
          setState(() => _selectedStatus = s);
          _fetchFilteredWithdrawals();
        },
        onResetFilters: () {
          setState(() {
            _selectedCustomerId = null;
            _dateFrom = null;
            _dateTo = null;
            _selectedStatus = null;
          });
          _fetchFilteredWithdrawals();
        },
        itemCount: totalMatchingCount > 0 ? totalMatchingCount : cards.length,
      ),
      scrollController: _scrollController,
      isLoading: isLoading,
      isEmpty: isEmpty,
      emptyMessage: 'Aucun élément trouvé.',
      itemCount: totalMatchingCount > 0 ? totalMatchingCount : cards.length,
      fabText: _config.fabText,
      onFabPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: context.read<ExitVouchersBloc>()),
              BlocProvider.value(value: context.read<StockWithdrawalsBloc>()),
              BlocProvider.value(value: context.read<CustomersBloc>()),
              BlocProvider.value(value: context.read<ProductsBloc>()),
              BlocProvider.value(value: context.read<ProjectsBloc>()),
              BlocProvider.value(value: context.read<WarehousesBloc>()),
            ],
            child: MobileExitVoucherFormScreen(isExitVoucher: _isExitVoucher),
          )),
        ).then((_) {
          _fetchFilteredWithdrawals();
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
  }
}
