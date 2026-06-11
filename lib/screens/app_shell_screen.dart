import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/custom_app_bar.dart';
import '../blocs/auth/auth_bloc.dart';
import '../utils/constants.dart';

import 'dashboard_screen.dart';
import 'customers_screen.dart';
import 'suppliers_screen.dart';
import 'products_screen.dart';
import 'invoices_screen.dart';
import 'quotes_screen.dart';
import 'delivery_notes_screen.dart';
import 'stock_screen.dart';
import 'transactions_screen.dart';
import 'checks_traites_screen.dart';
import 'projects_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'purchase_invoices_screen.dart';
import 'withholding_tax_screen.dart';
import 'warehouses_screen.dart';
import 'payments_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  AppModule _activeModule = AppModule.dashboard;
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(DashboardRefreshRequested());
  }

  Widget _buildContent() {
    switch (_activeModule) {
      case AppModule.dashboard:
        return const DashboardScreen();
      case AppModule.customers:
        return const CustomersScreen();
      case AppModule.suppliers:
        return const SuppliersScreen();
      case AppModule.products:
        return const ProductsScreen();
      case AppModule.invoices:
        return const InvoicesScreen();
      case AppModule.quotes:
        return const QuotesScreen();
      case AppModule.deliveryNotes:
        return const DeliveryNotesScreen();
      case AppModule.stockDashboard:
        return const StockScreen();
      case AppModule.transactions:
        return const TransactionsScreen();
      case AppModule.checksTraites:
        return const ChecksTraitesScreen();
      case AppModule.projects:
        return const ProjectsScreen();
      case AppModule.reports:
        return const ReportsScreen();
      case AppModule.settings:
        return const SettingsScreen();
      case AppModule.payments:
        return const PaymentsScreen();
      case AppModule.purchaseInvoices:
        return const PurchaseInvoicesScreen();
      case AppModule.withholdingTaxSales:
      case AppModule.withholdingTaxPurchase:
        return WithholdingTaxScreen(isSales: _activeModule == AppModule.withholdingTaxSales);
      case AppModule.warehouses:
        return const WarehousesScreen();
      default:
        return _ComingSoonScreen(module: _activeModule);
    }
  }

  String _getModuleTitle() {
    switch (_activeModule) {
      case AppModule.dashboard: return 'Tableau de bord';
      case AppModule.customers: return 'Clients';
      case AppModule.suppliers: return 'Fournisseurs';
      case AppModule.products: return 'Articles';
      case AppModule.invoices: return 'Factures';
      case AppModule.quotes: return 'Devis';
      case AppModule.deliveryNotes: return 'Bons de livraison';
      case AppModule.stockDashboard: return 'Stock';
      case AppModule.stockMovements: return 'Mouvements de stock';
      case AppModule.transactions: return 'Transactions';
      case AppModule.checksTraites: return 'Chèques & Traites';
      case AppModule.projects: return 'Projets';
      case AppModule.reports: return 'Rapports & Statistiques';
      case AppModule.settings: return 'Paramètres';
      case AppModule.purchaseInvoices: return 'Factures d\'achat';
      case AppModule.warehouses: return 'Entrepôts';
      case AppModule.withholdingTaxSales: return 'Retenue à la source (Ventes)';
      case AppModule.withholdingTaxPurchase: return 'Retenue à la source (Achats)';
      case AppModule.exitVouchers: return 'Bons de sortie';
      case AppModule.creditNotes: return 'Avoirs client';
      case AppModule.returnVouchers: return 'Bons de retour';
      case AppModule.supplierOrders: return 'Commandes fournisseur';
      case AppModule.receivingVouchers: return 'Bons de réception';
      case AppModule.supplierCreditNotes: return 'Avoirs fournisseur';
      case AppModule.supplierReturns: return 'Retours fournisseur';
      case AppModule.customerOrders: return 'Commandes client';
      case AppModule.accounts: return 'Comptes';
      case AppModule.stockEntry: return 'Bons d\'entrée';
      case AppModule.stockWithdrawal: return 'Bons de prélèvement';
      case AppModule.stockTransfer: return 'Bons de transfert';
      case AppModule.inventorySheet: return 'Fiche d\'inventaire';
      case AppModule.payments: return 'Paiements';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SidebarMenu(
            activeModule: _activeModule,
            isCollapsed: _isSidebarCollapsed,
            onToggleCollapse: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            onModuleSelected: (module) => setState(() => _activeModule = module),
          ),
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                    boxShadow: AppShadows.sm,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(_getModuleTitle(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const Spacer(),
                      const SyncIndicator(),
                      const SizedBox(width: 16),
                      // User menu
                      PopupMenuButton(
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(backgroundColor: AppColors.primary, radius: 14, child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                              SizedBox(width: 8),
                              Text('Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                            ],
                          ),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            onTap: () => setState(() => _activeModule = AppModule.settings),
                            child: const Row(children: [Icon(Icons.settings_rounded, size: 16), SizedBox(width: 8), Text('Paramètres')]),
                          ),
                          PopupMenuItem(
                            onTap: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                            child: const Row(children: [Icon(Icons.logout_rounded, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Déconnexion', style: TextStyle(color: AppColors.error))]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content area
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  final AppModule module;
  const _ComingSoonScreen({required this.module});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: AppColors.warning),
          const SizedBox(height: 16),
          const Text('Module en développement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Ce module sera disponible prochainement.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
