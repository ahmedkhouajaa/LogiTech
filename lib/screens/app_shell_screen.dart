import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/sync_indicator.dart';
import '../blocs/auth/auth_bloc.dart';
import '../utils/constants.dart';
import '../services/permission_service.dart';
import '../l10n/app_localizations.dart';

import 'dashboard_screen.dart';
import 'crm_dashboard_screen.dart';
import 'crm_pipeline_screen.dart';
import 'crm_opportunities_screen.dart';
import 'crm_leads_screen.dart';
import 'crm_automations_screen.dart';
import 'crm_reports_screen.dart';
import 'crm_emails_screen.dart';
import 'hr_employees_screen.dart';
import 'hr_leaves_screen.dart';
import 'hr_attendance_screen.dart';
import 'hr_payroll_screen.dart';
import 'hr_cnss_declaration_screen.dart';
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
import 'supplier_returns_screen.dart';
import 'supplier_credit_notes_screen.dart';
import 'credit_notes_screen.dart';
import 'purchase_invoices_screen.dart';
import 'supplier_orders_screen.dart';
import 'receiving_vouchers_screen.dart';
import 'withholding_tax_screen.dart';
import 'warehouses_screen.dart';
import 'payments_screen.dart';
import 'exit_vouchers_screen.dart';
import 'stock_withdrawals_screen.dart';
import 'stock_entries_screen.dart';
import 'company_info_screen.dart';
import 'personal_info_screen.dart';
import 'document_numbering_screen.dart';
import 'document_templates_screen.dart';
import 'custom_fields_screen.dart';
import 'custom_statuses_screen.dart';
import 'app_modules_settings_screen.dart';
import 'stock_transfers_screen.dart';
import 'inventory_sheets_screen.dart';
import 'user_management_screen.dart';
import 'import_export_screen.dart';
import 'support_tickets_screen.dart';
import 'affiliate_dashboard_screen.dart';
import 'trash_screen.dart';
import 'user_tracking_screen.dart';
import 'electronic_invoice_screen.dart';
import 'hr_documents_screen.dart';
import 'hr_accounting_screen.dart';
import 'hr_legal_entity_screen.dart';
import 'hr_establishments_screen.dart';
import 'hr_managers_screen.dart';
import 'hr_dashboard_screen.dart';
import 'production_dashboard_screen.dart';
import 'production_orders_screen.dart';
import 'production_boms_screen.dart';
import 'production_planning_screen.dart';
import 'production_costs_screen.dart';
import 'production_quality_screen.dart';
import 'production_reports_screen.dart';
import 'production_workcenters_screen.dart';
import '../services/trial_service.dart';
import '../services/app_navigation_service.dart';
import '../widgets/trial_banner_widget.dart';
import '../services/update_service.dart';
import '../widgets/update_banner_widget.dart';
import '../widgets/stock_notification_bell.dart';
import '../services/stock_notification_service.dart';
class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => AppShellScreenState();
}

class AppShellScreenState extends State<AppShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AppModule _activeModule = AppModule.dashboard;
  bool _isSidebarCollapsed = false;

  void setActiveModule(AppModule module) {
    setState(() {
      _activeModule = module;
    });
  }

  StreamSubscription<AppModule>? _navSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialModule();
    TrialService.instance.initTrial();
    UpdateService.instance.checkForUpdate();
    StockNotificationService.instance.init();
    PermissionService.instance.permissionsNotifier.addListener(_onPermissionsChanged);
    _navSubscription = AppNavigationService.instance.onModuleNavigation.listen((mod) {
      if (mounted) {
        setState(() {
          _activeModule = mod;
        });
      }
    });
    context.read<DashboardBloc>().add(DashboardRefreshRequested());
  }

  @override
  void dispose() {
    _navSubscription?.cancel();
    PermissionService.instance.permissionsNotifier.removeListener(_onPermissionsChanged);
    super.dispose();
  }

  void _onPermissionsChanged() {
    if (!mounted) return;
    if (!PermissionService.instance.canAccessModule(_activeModule)) {
      final firstPermitted = PermissionService.instance.getFirstAccessibleModule();
      if (firstPermitted != null && firstPermitted != _activeModule) {
        setState(() {
          _activeModule = firstPermitted;
        });
      } else {
        setState(() {});
      }
    } else {
      // If the app previously defaulted to support before permissions were ready, restore to dashboard
      if (_activeModule == AppModule.support && PermissionService.instance.canAccessModule(AppModule.dashboard)) {
        setState(() {
          _activeModule = AppModule.dashboard;
        });
        return;
      }
      setState(() {});
    }
  }

  void _checkInitialModule() {
    if (PermissionService.instance.isLoaded) {
      if (!PermissionService.instance.canAccessModule(_activeModule)) {
        final firstPermitted = PermissionService.instance.getFirstAccessibleModule();
        if (firstPermitted != null) {
          _activeModule = firstPermitted;
        }
      } else if (_activeModule == AppModule.support && PermissionService.instance.canAccessModule(AppModule.dashboard)) {
        _activeModule = AppModule.dashboard;
      }
    }
  }

  Widget _buildContent() {
    return ValueListenableBuilder<bool>(
      valueListenable: PermissionService.instance.permissionsNotifier,
      builder: (context, _, __) {
        if (!PermissionService.instance.isLoaded) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (!PermissionService.instance.canAccessModule(_activeModule)) {
          return const UnauthorizedView();
        }
        switch (_activeModule) {
          case AppModule.dashboard:
            return const DashboardScreen();
          case AppModule.crmDashboard:
            return const CrmDashboardScreen();
          case AppModule.crmPipeline:
            return const CrmPipelineScreen();
          case AppModule.crmOpportunities:
            return const CrmOpportunitiesScreen();
          case AppModule.crmLeads:
            return const CrmLeadsScreen();
          case AppModule.crmAutomations:
            return const CrmAutomationsScreen();
          case AppModule.crmReports:
            return const CrmReportsScreen();
          case AppModule.crmEmails:
            return const CrmEmailsScreen();
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
      case AppModule.eInvoice:
        return const ElectronicInvoiceScreen();
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
        return WithholdingTaxScreen(key: ValueKey(_activeModule), isSales: _activeModule == AppModule.withholdingTaxSales);
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
      case AppModule.personalInfo:
        return const PersonalInfoScreen();
      case AppModule.companyInfo:
        return const CompanyInfoScreen();
      case AppModule.documentNumbering:
        return const DocumentNumberingScreen();
      case AppModule.documentTemplates:
        return const DocumentTemplatesScreen();
      case AppModule.customFields:
        return const CustomFieldsScreen();
      case AppModule.customStatuses:
        return const CustomStatusesScreen();
      case AppModule.appModulesSettings:
        return const AppModulesSettingsScreen();
      case AppModule.stockEntry:
        return const StockEntriesScreen();
      case AppModule.userManagement:
        return const UserManagementScreen();
      case AppModule.importExport:
        return const ImportExportScreen();
      case AppModule.support:
        return const SupportTicketsScreen();
      case AppModule.affiliate:
        return const AffiliateDashboardScreen();
      case AppModule.trash:
        return const TrashScreen();
      case AppModule.hrDashboard:
        return const HrDashboardScreen();
      case AppModule.hrEmployees:
        return const HrEmployeesScreen();
      case AppModule.hrLeaves:
        return const HrLeavesScreen();
      case AppModule.hrAttendances:
        return const HrAttendanceScreen();
      case AppModule.hrPayroll:
        return const HrPayrollScreen();
      case AppModule.hrCnssDeclaration:
        return const HrCnssDeclarationScreen();
      case AppModule.hrDocuments:
        return const HrDocumentsScreen();
      case AppModule.hrAccounting:
        return const HrAccountingScreen();
      case AppModule.hrLegalEntity:
        return const HrLegalEntityScreen();
      case AppModule.hrEstablishments:
        return const HrEstablishmentsScreen();
      case AppModule.hrManagers:
        return const HrManagersScreen();
      case AppModule.userTracking:
        return const UserTrackingScreen();
      case AppModule.productionDashboard:
        return const ProductionDashboardScreen();
      case AppModule.productionOrders:
        return const ProductionOrdersScreen();
      case AppModule.productionBoms:
        return const ProductionBomsScreen();
      case AppModule.productionPlanning:
        return const ProductionPlanningScreen();
      case AppModule.productionCosts:
        return const ProductionCostsScreen();
      case AppModule.productionQuality:
        return const ProductionQualityScreen();
      case AppModule.productionReports:
        return const ProductionReportsScreen();
      case AppModule.productionWorkcenters:
        return const ProductionWorkcentersScreen();
    }
  },
);
  }

  String _getModuleTitle(BuildContext context) {
    String raw;
    switch (_activeModule) {
      case AppModule.dashboard: raw = 'Tableau de bord'; break;
      case AppModule.crmDashboard: raw = 'Tableau de bord CRM'; break;
      case AppModule.crmPipeline: raw = 'Pipeline de vente'; break;
      case AppModule.crmOpportunities: raw = 'Opportunités'; break;
      case AppModule.crmLeads: raw = 'Prospects (Leads)'; break;
      case AppModule.crmAutomations: raw = 'Automatisations commerciales'; break;
      case AppModule.crmReports: raw = 'Rapports CRM'; break;
      case AppModule.crmEmails: raw = 'Intégration email'; break;
      case AppModule.hrDashboard: raw = 'Tableau de bord RH'; break;
      case AppModule.hrEmployees: raw = 'Personnel (Employés)'; break;
      case AppModule.hrLeaves: raw = 'Congés & Absences'; break;
      case AppModule.hrAttendances: raw = 'Présences / Pointages'; break;
      case AppModule.hrPayroll: raw = 'Fiches de Paie'; break;
      case AppModule.hrCnssDeclaration: raw = 'Déclaration CNSS'; break;
      case AppModule.hrDocuments: raw = 'Documents'; break;
      case AppModule.hrAccounting: raw = 'Comptabilité'; break;
      case AppModule.hrLegalEntity: raw = 'Entité juridique'; break;
      case AppModule.hrEstablishments: raw = 'Établissements'; break;
      case AppModule.hrManagers: raw = 'Gestionnaires'; break;
      case AppModule.customers: raw = 'Clients'; break;
      case AppModule.suppliers: raw = 'Fournisseurs'; break;
      case AppModule.products: raw = 'Articles'; break;
      case AppModule.productSettings: raw = 'Parametres des articles'; break;
      case AppModule.invoices: raw = 'Factures'; break;
      case AppModule.quotes: raw = 'Devis'; break;
      case AppModule.deliveryNotes: raw = 'Bons de livraison'; break;
      case AppModule.stockDashboard: raw = 'Stock'; break;
      case AppModule.stockMovements: raw = 'Mouvements'; break;
      case AppModule.transactions: raw = 'Transactions'; break;
      case AppModule.checksTraites: raw = 'Cheques & Traites'; break;
      case AppModule.projects: raw = 'Projets'; break;
      case AppModule.reports: raw = 'Rapports et statistiques'; break;
      case AppModule.settings: raw = 'Parametres'; break;
      case AppModule.trash: raw = 'Corbeille'; break;
      case AppModule.purchaseInvoices: raw = 'Factures d\'achat'; break;
      case AppModule.warehouses: raw = 'Entrepots'; break;
      case AppModule.withholdingTaxSales: raw = 'RS vente'; break;
      case AppModule.withholdingTaxPurchase: raw = 'RS achat'; break;
      case AppModule.exitVouchers: raw = 'Bons de sortie'; break;
      case AppModule.creditNotes: raw = 'Avoirs'; break;
      case AppModule.returnVouchers: raw = 'Bons de retour'; break;
      case AppModule.supplierOrders: raw = 'Commandes fournisseur'; break;
      case AppModule.receivingVouchers: raw = 'Bons de reception'; break;
      case AppModule.supplierCreditNotes: raw = 'Avoirs fournisseur'; break;
      case AppModule.supplierReturns: raw = 'Retours fournisseur'; break;
      case AppModule.customerOrders: raw = 'Commandes'; break;
      case AppModule.accounts: raw = 'Comptes'; break;
      case AppModule.stockEntry: raw = 'Bons d\'entree'; break;
      case AppModule.stockWithdrawal: raw = 'Bons de prelevement'; break;
      case AppModule.stockTransfer: raw = 'Bons de transfert'; break;
      case AppModule.inventorySheet: raw = 'Fiche d\'inventaire'; break;
      case AppModule.payments: raw = 'Paiements'; break;
      case AppModule.personalInfo: raw = 'Informations personnelles'; break;
      case AppModule.companyInfo: raw = 'Informations de l\'entreprise'; break;
      case AppModule.documentNumbering: raw = 'Numérotation des documents'; break;
      case AppModule.documentTemplates: raw = 'Modèles de documents'; break;
      case AppModule.customFields: raw = 'Champs personnalisés'; break;
      case AppModule.customStatuses: raw = 'Statuts personnalisés'; break;
      case AppModule.appModulesSettings: raw = 'Modules de l\'application'; break;
      case AppModule.userManagement: raw = 'Gestion des utilisateurs'; break;
      case AppModule.importExport: raw = 'Import / Export des données'; break;
      case AppModule.support: raw = 'Support client'; break;
      case AppModule.affiliate: raw = 'Affiliation & Parrainage'; break;
      case AppModule.userTracking: raw = 'Traçabilité Utilisateurs'; break;
      case AppModule.eInvoice: raw = 'Facture électronique'; break;
      case AppModule.productionDashboard: raw = 'Tableau de bord Production'; break;
      case AppModule.productionOrders: raw = 'Ordres de fabrication (OF)'; break;
      case AppModule.productionBoms: raw = 'Nomenclatures (BOM)'; break;
      case AppModule.productionPlanning: raw = 'Planification de production'; break;
      case AppModule.productionCosts: raw = 'Suivi des coûts de revient'; break;
      case AppModule.productionQuality: raw = 'Contrôle qualité & NC'; break;
      case AppModule.productionReports: raw = 'Rapports de rendement'; break;
      case AppModule.productionWorkcenters: raw = 'Postes de charge & Ateliers'; break;
    }
    return context.tr(raw);
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
              _scaffoldKey.currentState?.closeDrawer();
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
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                  Expanded(
                    child: Text(
                      _getModuleTitle(context), 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SyncIndicator(),
                  const SizedBox(width: 8),
                  const StockNotificationBell(),
                  const SizedBox(width: 10),
                  // User menu
                  ValueListenableBuilder<bool>(
                    valueListenable: PermissionService.instance.permissionsNotifier,
                    builder: (context, _, __) {
                      final name = PermissionService.instance.userName;
                      final initial = PermissionService.instance.userInitial;
                      return PopupMenuButton(
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
                              CircleAvatar(
                                backgroundColor: AppColors.primary,
                                radius: 14,
                                child: Text(
                                  initial,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (!isMobile) const SizedBox(width: 8),
                              if (!isMobile)
                                Text(
                                  name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              if (!isMobile) const SizedBox(width: 4),
                              if (!isMobile) const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                            ],
                          ),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            onTap: () => setState(() => _activeModule = AppModule.settings),
                            child: Row(children: [const Icon(Icons.settings_rounded, size: 16), const SizedBox(width: 8), Text(context.tr('Parametres'))]),
                          ),
                          PopupMenuItem(
                            onTap: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                            child: Row(children: [Icon(Icons.logout_rounded, size: 16, color: AppColors.error), const SizedBox(width: 8), Text(context.tr('Deconnexion'), style: TextStyle(color: AppColors.error))]),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            // Update Banner Widget
            const UpdateBannerWidget(),
            // Trial Banner Widget
            const TrialBannerWidget(),
            // Content area
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: PermissionService.instance.permissionsNotifier,
                builder: (context, _, __) => _buildContent(),
              ),
            ),
          ],
        );

        final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
        final drawerWidth = (320.0 * textScale).clamp(300.0, 380.0);

        if (isMobile) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              width: drawerWidth,
              child: SafeArea(child: sidebar),
            ),
            body: contentArea,
          );
        }

        return Scaffold(
          key: _scaffoldKey,
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
