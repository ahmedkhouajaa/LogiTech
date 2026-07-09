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
import 'product_settings_screen.dart';
import 'invoices_screen.dart';
import 'customer_orders_screen.dart';
import 'quotes_screen.dart';
import 'delivery_notes_screen.dart';
import 'return_notes_screen.dart';
import 'stock_screen.dart';
import 'treasury_transactions_screen.dart';
import 'checks_traites_screen.dart';
import 'treasury_accounts_screen.dart';
import 'projects_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'package:business_manager_pro/screens/return_notes_screen.dart';
import 'package:business_manager_pro/screens/supplier_returns_screen.dart';
import 'package:business_manager_pro/screens/stock_withdrawals_screen.dart';
import 'package:business_manager_pro/screens/exit_vouchers_screen.dart';
import 'package:business_manager_pro/screens/supplier_orders_screen.dart';
import 'package:business_manager_pro/screens/supplier_credit_notes_screen.dart';
import 'credit_notes_screen.dart';
import 'purchase_invoices_screen.dart';
import 'supplier_orders_screen.dart';
import 'receiving_vouchers_screen.dart';
import 'withholding_tax_screen.dart';
import 'warehouses_screen.dart';
import 'payments_screen.dart';
import 'stock_withdrawals_screen.dart';
import 'stock_entries_screen.dart';
import 'company_info_screen.dart';
import 'document_templates_screen.dart';
import 'stock_transfers_screen.dart';
import 'inventory_sheets_screen.dart';
class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => AppShellScreenState();
}

class AppShellScreenState extends State<AppShellScreen> {
  AppModule _activeModule = AppModule.dashboard;
  bool _isSidebarCollapsed = false;

  void setActiveModule(AppModule module) {
    setState(() {
      _activeModule = module;
    });
  }

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
      case AppModule.accounts:
        return const TreasuryAccountsScreen();
      case AppModule.suppliers:
        return const SuppliersScreen();
      case AppModule.products:
        return const ProductsScreen();
      case AppModule.productSettings:
        return const ProductSettingsScreen();
      case AppModule.invoices:
        return const InvoicesScreen();
      case AppModule.customerOrders:
        return const CustomerOrdersScreen();
      case AppModule.quotes:
        return const QuotesScreen();
      case AppModule.deliveryNotes:
        return const DeliveryNotesScreen();
      case AppModule.stockDashboard:
        return const StockScreen();
      case AppModule.stockMovements:
        return const StockMovementsScreen();
      case AppModule.transactions:
        return const TreasuryTransactionsScreen();
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
      case AppModule.supplierOrders:
        return const SupplierOrdersScreen();
      case AppModule.receivingVouchers:
        return const ReceivingVouchersScreen();
      case AppModule.withholdingTaxSales:
      case AppModule.withholdingTaxPurchase:
        return WithholdingTaxScreen(isSales: _activeModule == AppModule.withholdingTaxSales);
      case AppModule.warehouses:
        return const WarehousesScreen();
      case AppModule.exitVouchers:
        return const ExitVouchersScreen();
      case AppModule.inventorySheet:
        return const InventorySheetsScreen();
      case AppModule.stockWithdrawal:
        return const StockWithdrawalsScreen();
      case AppModule.stockTransfer:
        return const StockTransfersScreen();
      case AppModule.returnVouchers:
        return const ReturnNotesScreen();
      case AppModule.creditNotes:
        return const CreditNotesScreen();
      case AppModule.supplierReturns:
        return const SupplierReturnsScreen();
      case AppModule.supplierCreditNotes:
        return const SupplierCreditNotesScreen();
      case AppModule.companyInfo:
        return const CompanyInfoScreen();
      case AppModule.documentTemplates:
        return const DocumentTemplatesScreen();
      case AppModule.stockEntry:
        return const StockEntriesScreen();
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
      case AppModule.productSettings: return 'Parametres des articles';
      case AppModule.invoices: return 'Factures';
      case AppModule.quotes: return 'Devis';
      case AppModule.deliveryNotes: return 'Bons de livraison';
      case AppModule.stockDashboard: return 'Stock';
      case AppModule.stockMovements: return 'Mouvements de stock';
      case AppModule.transactions: return 'Transactions';
      case AppModule.checksTraites: return 'Cheques & Traites';
      case AppModule.projects: return 'Projets';
      case AppModule.reports: return 'Rapports & Statistiques';
      case AppModule.settings: return 'Parametres';
      case AppModule.purchaseInvoices: return 'Factures d\'achat';
      case AppModule.warehouses: return 'Entrepots';
      case AppModule.withholdingTaxSales: return 'Retenue a la source (Ventes)';
      case AppModule.withholdingTaxPurchase: return 'Retenue a la source (Achats)';
      case AppModule.exitVouchers: return 'Bons de sortie';
      case AppModule.creditNotes: return 'Avoirs client';
      case AppModule.returnVouchers: return 'Bons de retour';
      case AppModule.supplierOrders: return 'Commandes fournisseur';
      case AppModule.receivingVouchers: return 'Bons de reception';
      case AppModule.supplierCreditNotes: return 'Avoirs fournisseur';
      case AppModule.supplierReturns: return 'Retours fournisseur';
      case AppModule.customerOrders: return 'Commandes client';
      case AppModule.accounts: return 'Comptes de Tresorerie';
      case AppModule.stockEntry: return 'Bons d\'entree';
      case AppModule.stockWithdrawal: return 'Bons de prelevement';
      case AppModule.stockTransfer: return 'Bons de transfert';
      case AppModule.inventorySheet: return 'Fiche d\'inventaire';
      case AppModule.payments: return 'Paiements';
      case AppModule.companyInfo: return 'Informations sur la societe';
      case AppModule.documentTemplates: return 'Modeles de documents';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 800;
        
        final sidebar = SidebarMenu(
          activeModule: _activeModule,
          isCollapsed: isMobile ? false : _isSidebarCollapsed,
          onToggleCollapse: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
          onModuleSelected: (module) {
            setState(() => _activeModule = module);
            if (isMobile) {
              Navigator.pop(context); // Close drawer
            }
          },
        );

        final contentArea = Column(
          children: [
            // Top bar
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
                boxShadow: AppShadows.sm,
              ),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 24),
              child: Row(
                children: [
                  if (isMobile)
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _getModuleTitle(), 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SyncIndicator(),
                  const SizedBox(width: 8),
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
                      child: Row(
                        children: [
                          const CircleAvatar(backgroundColor: AppColors.primary, radius: 14, child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          if (!isMobile) const SizedBox(width: 8),
                          if (!isMobile) const Text('Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          if (!isMobile) const SizedBox(width: 4),
                          if (!isMobile) const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                        ],
                      ),
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        onTap: () => setState(() => _activeModule = AppModule.settings),
                        child: const Row(children: [Icon(Icons.settings_rounded, size: 16), SizedBox(width: 8), Text('Parametres')]),
                      ),
                      PopupMenuItem(
                        onTap: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                        child: const Row(children: [Icon(Icons.logout_rounded, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Deconnexion', style: TextStyle(color: AppColors.error))]),
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
        );

        if (isMobile) {
          return Scaffold(
            drawer: Drawer(
              child: SafeArea(child: sidebar),
            ),
            body: contentArea,
          );
        }

        return Scaffold(
          body: Row(
            children: [
              sidebar,
              Expanded(child: contentArea),
            ],
          ),
        );
      },
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
          const Text('Module en developpement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Ce module sera disponible prochainement.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
