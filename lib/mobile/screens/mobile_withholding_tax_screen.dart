import 'package:flutter/material.dart';
import '../utils/mobile_module_config.dart';
import '../../utils/constants.dart';
import '../../widgets/sidebar_menu.dart';
import 'mobile_retenue_source_ventes_list.dart';

class MobileWithholdingTaxScreen extends StatefulWidget {
  final bool isSales;
  const MobileWithholdingTaxScreen({super.key, required this.isSales});

  @override
  State<MobileWithholdingTaxScreen> createState() => _MobileWithholdingTaxScreenState();
}

class _MobileWithholdingTaxScreenState extends State<MobileWithholdingTaxScreen> {
  late MobileModuleConfig _config;

  @override
  void initState() {
    super.initState();
    _config = MobileModuleConfig.getConfig(widget.isSales ? AppModule.withholdingTaxSales : AppModule.withholdingTaxPurchase);
  }

  @override
  void didUpdateWidget(MobileWithholdingTaxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSales != widget.isSales) {
      setState(() {
        _config = MobileModuleConfig.getConfig(widget.isSales ? AppModule.withholdingTaxSales : AppModule.withholdingTaxPurchase);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileRetenueSourceVentesList(
      config: _config,
      isSales: widget.isSales,
    );
  }
}
