import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_event.dart';
import '../../blocs/warehouses/warehouses_state.dart';
import '../../models/stock_movement.dart';
import '../../screens/warehouses_screen.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';

class MobileWarehousesScreen extends StatefulWidget {
  const MobileWarehousesScreen({super.key});

  @override
  State<MobileWarehousesScreen> createState() => _MobileWarehousesScreenState();
}

class _MobileWarehousesScreenState extends State<MobileWarehousesScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(AppModule.warehouses);
    context.read<WarehousesBloc>().add(LoadWarehouses());
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

  void _showCreateDialog([Warehouse? existing]) {
    if (existing != null) {
      final isDefault = existing.isDefault ||
          existing.name.trim().toLowerCase() == 'entrepôt par défaut' ||
          existing.name.trim().toLowerCase() == 'entrepot par defaut';
      if (isDefault) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cet élément est un élément par défaut et ne peut pas être modifié.'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateWarehouseDialog(warehouse: existing),
    );
  }

  void _deleteWarehouse(Warehouse warehouse) {
    final isDefault = warehouse.isDefault ||
        warehouse.name.trim().toLowerCase() == 'entrepôt par défaut' ||
        warehouse.name.trim().toLowerCase() == 'entrepot par defaut';
    if (isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cet élément est un élément par défaut et ne peut pas être supprimé.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer l\'entrepôt "${warehouse.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<WarehousesBloc>().add(DeleteWarehouse(warehouse.id));
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _buildAddressString(Warehouse item) {
    final parts = <String>[];
    if (item.address != null && item.address!.trim().isNotEmpty) {
      parts.add(item.address!.trim());
    }
    if (item.postalCode != null && item.postalCode!.trim().isNotEmpty) {
      parts.add(item.postalCode!.trim());
    }
    if (item.city != null && item.city!.trim().isNotEmpty) {
      parts.add(item.city!.trim());
    }
    if (item.country != null && item.country!.trim().isNotEmpty && item.country != 'Tunisia') {
      parts.add(item.country!.trim());
    }
    return parts.isNotEmpty ? parts.join(', ') : 'Adresse par défaut';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WarehousesBloc, WarehousesState>(
      builder: (context, state) {
        bool isLoading = state is WarehousesLoading || state is WarehousesInitial;
        bool isEmpty = true;
        List<Widget> listItems = [];

        if (state is WarehousesLoaded) {
          final items = state.warehouses;
          final filteredItems = items.where((item) {
            // Search filter
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchesName = item.name.toLowerCase().contains(q);
              final matchesRef = item.reference?.toLowerCase().contains(q) ?? false;
              final matchesAddress = item.address?.toLowerCase().contains(q) ?? false;
              final matchesCity = item.city?.toLowerCase().contains(q) ?? false;
              if (!matchesName && !matchesRef && !matchesAddress && !matchesCity) return false;
            }

            // Category Filter
            if (_selectedFilter == 'Actif' && !item.isActive) return false;
            if (_selectedFilter == 'Inactif' && item.isActive) return false;
            if (_selectedFilter == 'Par Défaut' && !item.isDefault) return false;

            return true;
          }).toList();

          isEmpty = filteredItems.isEmpty;

          listItems = filteredItems.map((item) {
            final isDefault = item.isDefault ||
                item.name.trim().toLowerCase() == 'entrepôt par défaut' ||
                item.name.trim().toLowerCase() == 'entrepot par defaut';
            final ref = (item.reference != null && item.reference!.trim().isNotEmpty)
                ? item.reference!.trim()
                : (item.name.length >= 3 ? 'WH-${item.name.substring(0, 3).toUpperCase()}' : 'WH-${item.name.toUpperCase()}');

            return MobileGenericCard(
              reference: ref,
              name: item.name,
              status: item.isActive ? 'Actif' : 'Inactif',
              badgeText: isDefault ? 'Par défaut' : null,
              subtitle: _buildAddressString(item),
              subtitleIcon: Icons.location_on_outlined,
              nameIcon: Icons.warehouse_rounded,
              onTap: () {
                if (isDefault) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Cet élément est un élément par défaut et ne peut pas être modifié.'),
                      backgroundColor: AppColors.warning,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                _showCreateDialog(item);
              },
              onEdit: (!isDefault && PermissionService.instance.canUpdate(UserPermissionResources.stockWarehouses))
                  ? () => _showCreateDialog(item)
                  : null,
              onDelete: (!isDefault && PermissionService.instance.canDelete(UserPermissionResources.stockWarehouses))
                  ? () => _deleteWarehouse(item)
                  : null,
            );
          }).toList();
        }

        return MobileGenericListScreen(
          activeModule: AppModule.warehouses,
          title: _config.title,
          isLoading: isLoading,
          isEmpty: isEmpty,
          onSearchChanged: _onSearchChanged,
          filterOptions: _config.filterOptions,
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          onModuleSelected: (v) {},
          onRefresh: () async {
            context.read<WarehousesBloc>().add(LoadWarehouses());
          },
          emptyMessage: 'Aucun entrepôt trouvé.',
          fabText: _config.fabText,
          onFabPressed: () => _showCreateDialog(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: listItems,
          ),
        );
      },
    );
  }
}
