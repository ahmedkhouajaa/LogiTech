import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/sync_indicator.dart';
import '../utils/constants.dart';
import 'mobile_drawer.dart';
import 'mobile_dashboard_screen.dart';

import 'screens/mobile_quotes_screen.dart';
import 'screens/mobile_customer_orders_screen.dart';
import 'screens/mobile_delivery_notes_screen.dart';
import 'screens/mobile_invoices_screen.dart';
import 'screens/mobile_stock_withdrawals_screen.dart';
import 'screens/mobile_stock_transfers_screen.dart';
import 'screens/mobile_inventory_sheets_screen.dart';
import 'screens/mobile_credit_notes_screen.dart';
import 'screens/mobile_return_notes_screen.dart';
import 'screens/mobile_supplier_orders_screen.dart';
import 'screens/mobile_receiving_vouchers_screen.dart';
import 'screens/mobile_purchase_invoices_screen.dart';
import 'screens/mobile_supplier_credit_notes_screen.dart';
import 'screens/mobile_supplier_returns_screen.dart';
import 'screens/mobile_payments_screen.dart';
import 'screens/mobile_transactions_screen.dart';
import 'screens/mobile_checks_traites_screen.dart';
import 'screens/mobile_customers_screen.dart';
import 'screens/mobile_suppliers_screen.dart';
import 'screens/mobile_products_screen.dart';
import 'screens/mobile_stock_screen.dart';
import 'screens/mobile_stock_movements_screen.dart';
import 'screens/mobile_projects_screen.dart';
import 'screens/mobile_withholding_tax_screen.dart';
import 'screens/mobile_warehouses_screen.dart';


// Placeholder screens for bottom nav tabs until full mobile screens are built
// These reuse the existing desktop screens which already handle isMobile layout
import '../screens/treasury_accounts_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/company_info_screen.dart';
import '../screens/document_templates_screen.dart';
import '../screens/warehouses_screen.dart';
import '../screens/product_settings_screen.dart';
import '../screens/stock_entries_screen.dart';
import '../screens/stock_withdrawals_screen.dart';
import '../screens/stock_transfers_screen.dart';
import '../screens/inventory_sheets_screen.dart';

class MobileShellScreen extends StatefulWidget {
  const MobileShellScreen({super.key});

  @override
  State<MobileShellScreen> createState() => _MobileShellScreenState();
}

class _MobileShellScreenState extends State<MobileShellScreen> {
  int _bottomNavIndex = 0;
  AppModule _activeModule = AppModule.dashboard;

  // Maps bottom nav index to module
  static const _bottomNavModules = [
    AppModule.dashboard,
    AppModule.invoices,
    AppModule.purchaseInvoices,
    AppModule.customers,
  ];

  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(DashboardRefreshRequested());
  }

  void _onModuleSelected(AppModule module) {
    setState(() {
      _activeModule = module;
      // Update bottom nav if the module matches a tab
      final navIndex = _bottomNavModules.indexOf(module);
      if (navIndex >= 0) {
        _bottomNavIndex = navIndex;
      } else {
        _bottomNavIndex = -1; // No tab selected
      }
    });
  }

  void _onBottomNavTapped(int index) {
    if (index == 4) {
      // "Plus" tab → open drawer
      Scaffold.of(context).openDrawer();
      return;
    }
    setState(() {
      _bottomNavIndex = index;
      _activeModule = _bottomNavModules[index];
    });
  }

  Widget _buildContent() {
    switch (_activeModule) {
      case AppModule.dashboard:
        return const MobileDashboardScreen();
      case AppModule.customers:
        return const MobileCustomersScreen();
      case AppModule.suppliers:
        return const MobileSuppliersScreen();
      case AppModule.products:
        return const MobileProductsScreen();
      case AppModule.productSettings:
        return const ProductSettingsScreen();
      case AppModule.invoices:
        return const MobileInvoicesScreen();
      case AppModule.customerOrders:
        return const MobileCustomerOrdersScreen();
      case AppModule.quotes:
        return const MobileQuotesScreen();
      case AppModule.deliveryNotes:
        return const MobileDeliveryNotesScreen();
      case AppModule.stockDashboard:
        return const MobileStockScreen();
      case AppModule.stockMovements:
        return const MobileStockMovementsScreen();
      case AppModule.transactions:
        return const MobileTreasuryTransactionsScreen();
      case AppModule.checksTraites:
        return const MobileChecksTraitesScreen();
      case AppModule.projects:
        return const MobileProjectsScreen();
      case AppModule.reports:
        return const ReportsScreen();
      case AppModule.settings:
        return const SettingsScreen();
      case AppModule.payments:
        return const MobilePaymentsScreen();
      case AppModule.purchaseInvoices:
        return const MobilePurchaseInvoicesScreen();
      case AppModule.supplierOrders:
        return const MobileSupplierOrdersScreen();
      case AppModule.receivingVouchers:
        return const MobileReceivingVouchersScreen();
      case AppModule.withholdingTaxSales:
      case AppModule.withholdingTaxPurchase:
        return MobileWithholdingTaxScreen(isSales: _activeModule == AppModule.withholdingTaxSales);
      case AppModule.warehouses:
        return const MobileWarehousesScreen();
      case AppModule.exitVouchers:
      case AppModule.stockWithdrawal:
        return MobileStockWithdrawalsScreen(activeModule: _activeModule);
      case AppModule.stockTransfer:
        return const StockTransfersScreen();
      case AppModule.inventorySheet:
        return const InventorySheetsScreen();
      case AppModule.returnVouchers:
        return const MobileReturnNotesScreen();
      case AppModule.creditNotes:
        return const MobileCreditNotesScreen();
      case AppModule.supplierReturns:
        return const MobileSupplierReturnsScreen();
      case AppModule.supplierCreditNotes:
        return const MobileSupplierCreditNotesScreen();
      case AppModule.accounts:
        return const TreasuryAccountsScreen();
      case AppModule.companyInfo:
        return const CompanyInfoScreen();
      case AppModule.documentTemplates:
        return const DocumentTemplatesScreen();
      case AppModule.stockEntry:
        return const StockEntriesScreen();
      default:
        return _ComingSoonMobile(module: _activeModule);
    }
  }

  String _getModuleTitle() {
    switch (_activeModule) {
      case AppModule.dashboard: return 'Tableau de bord';
      case AppModule.customers: return 'Clients';
      case AppModule.suppliers: return 'Fournisseurs';
      case AppModule.products: return 'Articles';
      case AppModule.productSettings: return 'Parametres Articles';
      case AppModule.invoices: return 'Factures';
      case AppModule.quotes: return 'Devis';
      case AppModule.deliveryNotes: return 'Bons de livraison';
      case AppModule.stockDashboard: return 'Stock';
      case AppModule.stockMovements: return 'Mouvements';
      case AppModule.stockEntry: return 'Bons d\'entrée';
      case AppModule.stockWithdrawal: return 'Prélèvements';
      case AppModule.stockTransfer: return 'Bons de transfert';
      case AppModule.inventorySheet: return 'Fiche d\'inventaire';
      case AppModule.transactions: return 'Transactions';
      case AppModule.checksTraites: return 'Cheques & Traites';
      case AppModule.projects: return 'Projets';
      case AppModule.reports: return 'Rapports';
      case AppModule.settings: return 'Parametres';
      case AppModule.purchaseInvoices: return 'Factures d\'achat';
      case AppModule.warehouses: return 'Entrepots';
      case AppModule.exitVouchers: return 'Bons de sortie';
      case AppModule.creditNotes: return 'Avoirs Client';
      case AppModule.returnVouchers: return 'Bons de retour';
      case AppModule.supplierOrders: return 'Commandes Fournisseur';
      case AppModule.receivingVouchers: return 'Bons de reception';
      case AppModule.supplierCreditNotes: return 'Avoirs Fournisseur';
      case AppModule.supplierReturns: return 'Retours Fournisseur';
      case AppModule.customerOrders: return 'Commandes Client';
      case AppModule.accounts: return 'Comptes';
      case AppModule.payments: return 'Paiements';
      case AppModule.companyInfo: return 'Ma Societe';
      case AppModule.documentTemplates: return 'Modeles';
      case AppModule.stockEntry: return "Bons d'entree";
      default: return 'LogiTech Pro';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: MobileDrawer(
        activeModule: _activeModule,
        onModuleSelected: _onModuleSelected,
      ),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _getModuleTitle(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        actions: const [
          SyncIndicator(),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _buildContent(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _bottomNavIndex >= 0 ? _bottomNavIndex : 0,
          onDestinationSelected: _onBottomNavTapped,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primary.withValues(alpha: 0.1),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: 22),
              selectedIcon: Icon(Icons.dashboard_rounded, size: 22, color: AppColors.primary),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_outlined, size: 22),
              selectedIcon: Icon(Icons.receipt_rounded, size: 22, color: AppColors.primary),
              label: 'Ventes',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined, size: 22),
              selectedIcon: Icon(Icons.shopping_bag_rounded, size: 22, color: AppColors.primary),
              label: 'Achats',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, size: 22),
              selectedIcon: Icon(Icons.people_rounded, size: 22, color: AppColors.primary),
              label: 'Tiers',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded, size: 22),
              selectedIcon: Icon(Icons.more_horiz_rounded, size: 22, color: AppColors.primary),
              label: 'Plus',
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonMobile extends StatelessWidget {
  final AppModule module;
  const _ComingSoonMobile({required this.module});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.construction_rounded, size: 32, color: AppColors.warning),
          ),
          const SizedBox(height: 16),
          const Text(
            'Module en developpement',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Disponible prochainement',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
