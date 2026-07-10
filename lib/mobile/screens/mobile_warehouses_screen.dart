import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart'; // Defines AppModule
import '../../blocs/warehouses/warehouses_bloc.dart';
import '../../blocs/warehouses/warehouses_event.dart';
import '../../blocs/warehouses/warehouses_state.dart';
import '../../models/stock_movement.dart';

class MobileWarehousesScreen extends StatefulWidget {
  const MobileWarehousesScreen({super.key});

  @override
  State<MobileWarehousesScreen> createState() => _MobileWarehousesScreenState();
}

class _MobileWarehousesScreenState extends State<MobileWarehousesScreen> {
  String _searchQuery = '';
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WarehousesBloc, WarehousesState>(
      builder: (context, state) {
        bool isLoading = state is WarehousesLoading;
        bool isEmpty = false;
        List<Widget> listItems = [];

        if (state is WarehousesLoaded) {
          final items = state.warehouses;
          final filteredItems = items.where((item) {
            if (_searchQuery.isEmpty) return true;
            return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (item.reference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          }).toList();
          
          isEmpty = filteredItems.isEmpty;

          listItems = filteredItems.map((item) {
            return _WarehouseCard(warehouse: item);
          }).toList();
        }

        return MobileGenericListScreen(
          activeModule: AppModule.warehouses,
          title: _config.title,
          isLoading: isLoading,
          isEmpty: isEmpty,
          onSearchChanged: _onSearchChanged,
          filterOptions: const ['Tous'],
          selectedFilter: 'Tous',
          onFilterChanged: (v) {},
          onModuleSelected: (v) {},
          onRefresh: () async {
            context.read<WarehousesBloc>().add(LoadWarehouses());
          },
          emptyMessage: 'Aucun entrepôt trouvé.',
          fabText: _config.fabText,
          onFabPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Veuillez utiliser la version PC pour ajouter un entrepôt')),
            );
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: listItems,
          ),
        );
      },
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  final Warehouse warehouse;

  const _WarehouseCard({required this.warehouse});

  @override
  Widget build(BuildContext context) {
    return MobileGenericCard(
      reference: warehouse.reference ?? 'Aucune réf',
      name: warehouse.name,
      status: warehouse.isActive ? 'Actif' : 'Inactif',
      amount: 0.0,
      nameIcon: Icons.warehouse_rounded,
      onTap: () {},
    );
  }
}
