import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/constants.dart';
import '../utils/mobile_module_config.dart';
import '../widgets/mobile_generic_list_screen.dart';
import '../widgets/mobile_generic_card.dart';
import '../../widgets/sidebar_menu.dart';

class MobileWithholdingTaxScreen extends StatefulWidget {
  final bool isSales;
  const MobileWithholdingTaxScreen({super.key, required this.isSales});

  @override
  State<MobileWithholdingTaxScreen> createState() => _MobileWithholdingTaxScreenState();
}

class _MobileWithholdingTaxScreenState extends State<MobileWithholdingTaxScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(widget.isSales ? AppModule.withholdingTaxSales : AppModule.withholdingTaxPurchase);
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

  @override
  Widget build(BuildContext context) {
    return MobileGenericListScreen(
      title: _config.title,
      activeModule: widget.isSales ? AppModule.withholdingTaxSales : AppModule.withholdingTaxPurchase,
      onModuleSelected: (module) {},
      onRefresh: () {},
      onSearchChanged: _onSearchChanged,
      filterOptions: _config.filterOptions,
      selectedFilter: _selectedFilter,
      onFilterChanged: _onFilterChanged,
      isLoading: false,
      isEmpty: true,
      emptyMessage: 'Aucune retenue à la source trouvée.',
      fabText: _config.fabText,
      onFabPressed: () {},
      child: ListView(),
    );
  }
}
