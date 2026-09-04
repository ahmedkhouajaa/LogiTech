import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_client_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../screens/customers_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';
import '../../services/contact_import_export_service.dart';
import '../../widgets/import_export/contact_import_dialog.dart';
import '../../models/customer.dart';
import '../../screens/customer_detail_screen.dart';

class MobileCustomersScreen extends StatefulWidget {
  const MobileCustomersScreen({super.key});

  @override
  State<MobileCustomersScreen> createState() => _MobileCustomersScreenState();
}

class _MobileCustomersScreenState extends State<MobileCustomersScreen> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.customers);
    _fetchFilteredClients();
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
      context.read<CustomersBloc>().add(LoadNextClients(
        searchQuery: _searchQuery,
      ));
    }
  }

  void _fetchFilteredClients() {
    context.read<CustomersBloc>().add(LoadFirstClients(
      searchQuery: _searchQuery,
    ));
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchFilteredClients();
  }

  Widget _buildActionsButton(BuildContext context, CustomersState state) {
    final customers = state is CustomersLoaded ? state.customers : <Customer>[];
    return PopupMenuButton<String>(
      tooltip: 'Actions Import / Export',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      color: AppColors.surface,
      elevation: 4,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              'Actions',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) {
        final canExport = PermissionService.instance.canCreate(UserPermissionResources.importExport);
        final canImport = PermissionService.instance.canUpdate(UserPermissionResources.importExport);
        final items = <PopupMenuEntry<String>>[];
        if (canExport) {
          items.addAll([
            const PopupMenuItem(
              value: 'export_excel',
              child: Text('Exporter Excel', style: TextStyle(fontSize: 13)),
            ),
            const PopupMenuItem(
              value: 'export_csv',
              child: Text('Exporter CSV', style: TextStyle(fontSize: 13)),
            ),
            const PopupMenuItem(
              value: 'export_json',
              child: Text('Exporter JSON', style: TextStyle(fontSize: 13)),
            ),
          ]);
        }
        if (canExport && canImport) {
          items.add(const PopupMenuDivider());
        }
        if (canImport) {
          items.add(
            const PopupMenuItem(
              value: 'import_excel',
              child: Text(
                'Importer depuis Excel',
                style: TextStyle(fontSize: 13),
              ),
            ),
          );
        }
        return items;
      },
      onSelected: (val) async {
        if (!context.mounted) return;
        if (val == 'export_excel') {
          if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
          await ContactImportExportService.instance.exportContactsToExcel(
            context: context,
            type: ContactType.customer,
            contacts: customers,
          );
        } else if (val == 'export_csv') {
          if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
          await ContactImportExportService.instance.exportContactsToCsv(
            context: context,
            type: ContactType.customer,
            contacts: customers,
          );
        } else if (val == 'export_json') {
          if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) return;
          await ContactImportExportService.instance.exportContactsToJson(
            context: context,
            type: ContactType.customer,
            contacts: customers,
          );
        } else if (val == 'import_excel') {
          if (!PermissionService.instance.canUpdate(UserPermissionResources.importExport)) return;
          ContactImportDialog.show(
            context,
            type: ContactType.customer,
            onImportSuccess: () {
              if (context.mounted) {
                context.read<CustomersBloc>().add(LoadFirstClients(searchQuery: _searchQuery));
              }
            },
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomersBloc, CustomersState>(
      builder: (context, state) {
        bool isLoading = state is CustomersLoading || state is CustomersInitial;
        bool isEmpty = true;
        bool isLoadingMore = false;
        int totalMatchingCount = 0;
        List<Widget> cards = [];

        if (state is CustomersLoaded) {
          final items = state.customers;
          isLoadingMore = state.isLoadingMore;
          totalMatchingCount = state.totalCount > 0 ? state.totalCount : items.length;

          // Locally double-filter matches just in case SQLite fallback gets loaded
          final filteredItems = items.where((customer) {
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final nameMatch = customer.name.toLowerCase().contains(query);
              final codeMatch = customer.code.toLowerCase().contains(query);
              final emailMatch = (customer.email ?? '').toLowerCase().contains(query);
              if (!nameMatch && !codeMatch && !emailMatch) return false;
            }
            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          cards = filteredItems.map((customer) {
            return MobileClientCard(
              customer: customer,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(customer: customer),
                  ),
                ).then((_) {
                  _fetchFilteredClients();
                });
              },
            );
          }).toList();
        }

        return MobileGenericListScreen(
          title: _config.title,
          activeModule: AppModule.customers,
          onModuleSelected: (module) {},
          onRefresh: () async {
            context.read<CustomersBloc>().add(ResetClientsPagination(
              searchQuery: _searchQuery,
            ));
          },
          onSearchChanged: _onSearchChanged,
          searchTrailing: _buildActionsButton(context, state),
          filterOptions: const [],
          selectedFilter: 'Tous',
          onFilterChanged: (_) {},
          scrollController: _scrollController,
          isLoading: isLoading,
          isEmpty: isEmpty,
          emptyMessage: 'Aucun client trouvé.',
          itemCount: totalMatchingCount,
          fabText: _config.fabText,
          onFabPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const CustomerDialog(existing: null),
            ).then((_) {
              _fetchFilteredClients();
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
