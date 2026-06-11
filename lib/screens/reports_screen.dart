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
      subtitle: 'Les tableaux de bord analytiques seront bientôt disponibles',
    );
  }
}

class PurchaseInvoicesScreen extends StatelessWidget {
  const PurchaseInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.receipt_long_rounded,
      title: 'Factures d\'achat',
      subtitle: 'La gestion des achats sera bientôt disponible',
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
      title: isSales ? 'Retenue à la source (Ventes)' : 'Retenue à la source (Achats)',
      subtitle: 'La gestion des retenues sera bientôt disponible',
    );
  }
}

class WarehousesScreen extends StatelessWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.warehouse_rounded,
      title: 'Gestion des entrepôts',
      subtitle: 'La création et configuration des entrepôts sera bientôt disponible',
    );
  }
}
