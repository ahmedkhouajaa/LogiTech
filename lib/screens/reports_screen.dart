import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.bar_chart_rounded,
      title: 'Rapports et statistiques',
      subtitle: 'Les tableaux de bord analytiques seront bientot disponibles',
    );
  }
}


class WithholdingTaxScreen extends StatelessWidget {
  final bool isSales;
  const WithholdingTaxScreen({super.key, required this.isSales});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.account_balance_rounded,
      title: isSales ? 'Retenue a la source (Ventes)' : 'Retenue a la source (Achats)',
      subtitle: 'La gestion des retenues sera bientot disponible',
    );
  }
}

class WarehousesScreen extends StatelessWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.warehouse_rounded,
      title: 'Gestion des entrepots',
      subtitle: 'La creation et configuration des entrepots sera bientot disponible',
    );
  }
}
