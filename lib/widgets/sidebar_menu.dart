import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/permission_service.dart';
import '../services/app_modules_service.dart';
import 'enterprise_switcher.dart';
import '../l10n/app_localizations.dart';
import 'ai_chat_modal_sheet.dart';
import '../utils/platform_utils.dart';

enum AppModule {
  dashboard,
  reports,
  eInvoice,
  // CRM
  crmDashboard,
  crmPipeline,
  crmOpportunities,
  crmLeads,
  crmAutomations,
  crmReports,
  crmEmails,
  // RH & Paie
  hrDashboard,
  hrEmployees,
  hrLeaves,
  hrAttendances,
  hrPayroll,
  hrCnssDeclaration,
  hrDocuments,
  hrAccounting,
  hrLegalEntity,
  hrEstablishments,
  hrManagers,
  // Ventes
  quotes,
  customerOrders,
  deliveryNotes,
  invoices,
  exitVouchers,
  creditNotes,
  returnVouchers,
  // Achats
  supplierOrders,
  receivingVouchers,
  purchaseInvoices,
  supplierCreditNotes,
  supplierReturns,
  // Paiements
  payments,
  accounts,
  transactions,
  checksTraites,
  withholdingTaxSales,
  withholdingTaxPurchase,
  // Tiers
  customers,
  suppliers,
  products,
  productSettings,
  // Stock
  stockDashboard,
  stockMovements,
  stockEntry,
  stockWithdrawal,
  stockTransfer,
  inventorySheet,
  warehouses,
  // Production
  productionDashboard,
  productionOrders,
  productionBoms,
  productionPlanning,
  productionCosts,
  productionQuality,
  productionReports,
  productionWorkcenters,
  // Projets
  projects,
  // Parametres
  settings,
  appModulesSettings,
  personalInfo,
  companyInfo,
  documentNumbering,
  documentTemplates,
  customFields,
  customStatuses,
  userManagement,
  importExport,
  support,
  affiliate,
  trash,
  userTracking,
}

class SidebarMenu extends StatefulWidget {
  final AppModule activeModule;
  final ValueChanged<AppModule> onModuleSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onAiAssistantTap;

  const SidebarMenu({
    super.key,
    required this.activeModule,
    required this.onModuleSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.onAiAssistantTap,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  final Set<String> _expandedGroups = {'ventes'};

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScale = mediaQuery.textScaler.scale(1.0).clamp(1.0, 1.6);
    final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;
    final isMobileOrDrawer = screenWidth <= 800 && !isDesktopOrWeb;
    final double baseWidth = isDesktopOrWeb
        ? (screenWidth >= 1600 ? 235.0 : (screenWidth >= 1200 ? 225.0 : 215.0))
        : (screenWidth >= 1600 ? 310.0 : (screenWidth >= 1200 ? 295.0 : 280.0));
    final double expandedWidth = isMobileOrDrawer
        ? (320.0 * textScale).clamp(300.0, 380.0)
        : (baseWidth * textScale).clamp(210.0, 255.0);
    final double collapsedWidth = isDesktopOrWeb ? 62.0 : 68.0;
    final double sidebarWidth = widget.isCollapsed
        ? collapsedWidth
        : expandedWidth;

    return ListenableBuilder(
      listenable: Listenable.merge([
        PermissionService.instance.permissionsNotifier,
        AppModulesService.instance.notifier,
      ]),
      builder: (context, _) {
        return ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: sidebarWidth,
            color: AppColors.sidebarBg,
            child: Column(
              children: [
                _buildHeader(collapsedWidth: collapsedWidth),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      scrollbars: !widget.isCollapsed,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                      _buildItem(AppModule.dashboard, Icons.dashboard_rounded, 'Tableau de bord'),
                      _buildItem(AppModule.reports, Icons.bar_chart_rounded, 'Rapports et statistiques'),
                      _buildItem(AppModule.eInvoice, Icons.receipt_long_rounded, 'Facture électronique'),
                      // Section 1: Documents commerciaux & CRM
                      if (_hasAnyVisibleGroup(['crm', 'ventes', 'achats', 'paiements', 'retenue_source', 'tresorerie']))
                        const _SidebarDivider(),
                      _buildGroup('crm', Icons.hub_rounded, 'CRM', [
                        _buildSubItem(AppModule.crmDashboard, 'Tableau de bord CRM'),
                        _buildSubItem(AppModule.crmPipeline, 'Pipeline de vente'),
                        _buildSubItem(AppModule.crmOpportunities, 'Opportunités'),
                        _buildSubItem(AppModule.crmLeads, 'Prospects (Leads)'),
                        _buildSubItem(AppModule.crmAutomations, 'Automatisations'),
                        _buildSubItem(AppModule.crmReports, 'Rapports CRM'),
                        _buildSubItem(AppModule.crmEmails, 'Intégration email'),
                      ]),
                      _buildGroup('ventes', Icons.shopping_cart_rounded, 'Ventes', [
                        _buildSubItem(AppModule.quotes, 'Devis'),
                        _buildSubItem(AppModule.customerOrders, 'Commandes'),
                        _buildSubItem(AppModule.deliveryNotes, 'Bons de livraison'),
                        _buildSubItem(AppModule.invoices, 'Factures'),
                        _buildSubItem(AppModule.exitVouchers, 'Bons de sortie'),
                        _buildSubItem(AppModule.creditNotes, 'Avoirs'),
                        _buildSubItem(AppModule.returnVouchers, 'Bons de retour'),
                      ]),
                      _buildGroup('achats', Icons.local_shipping_rounded, 'Achats', [
                        _buildSubItem(AppModule.supplierOrders, 'Commandes fournisseur'),
                        _buildSubItem(AppModule.receivingVouchers, 'Bons de reception'),
                        _buildSubItem(AppModule.purchaseInvoices, 'Factures d\'achat'),
                        _buildSubItem(AppModule.supplierCreditNotes, 'Avoirs fournisseur'),
                        _buildSubItem(AppModule.supplierReturns, 'Retours fournisseur'),
                      ]),
                      _buildGroup('paiements', Icons.account_balance_wallet_rounded, 'Paiements', [
                        _buildSubItem(AppModule.payments, 'Paiements'),
                      ]),
                      _buildGroup('retenue_source', Icons.request_quote_rounded, 'Retenue à la source', [
                        _buildSubItem(AppModule.withholdingTaxSales, 'RS vente'),
                        _buildSubItem(AppModule.withholdingTaxPurchase, 'RS achat'),
                      ]),
                      _buildGroup('tresorerie', Icons.account_balance_rounded, 'Tresorerie', [
                        _buildSubItem(AppModule.accounts, 'Comptes'),
                        _buildSubItem(AppModule.transactions, 'Transactions'),
                        _buildSubItem(AppModule.checksTraites, 'Cheques & Traites'),
                      ]),
                      // Section 2: Tiers & Articles
                      if (_hasAnyVisibleItem([AppModule.customers, AppModule.suppliers]) ||
                          _hasAnyVisibleGroup(['articles']))
                        const _SidebarDivider(),
                      _buildItem(AppModule.customers, Icons.people_rounded, 'Clients'),
                      _buildItem(AppModule.suppliers, Icons.factory_rounded, 'Fournisseurs'),
                      _buildGroup('articles', Icons.inventory_2_rounded, 'Articles', [
                        _buildSubItem(AppModule.products, 'Liste des articles'),
                        _buildSubItem(AppModule.productSettings, 'Parametres des articles'),
                      ]),
                      // Section 3: Stock
                      if (_hasAnyVisibleGroup(['stock', 'production']))
                        const _SidebarDivider(),
                      _buildGroup('stock', Icons.warehouse_rounded, 'Stock', [
                        _buildSubItem(AppModule.stockDashboard, 'Vue d\'ensemble'),
                        _buildSubItem(AppModule.stockMovements, 'Mouvements'),
                        _buildSubItem(AppModule.stockEntry, 'Bons d\'entree'),
                        _buildSubItem(AppModule.stockWithdrawal, 'Bons de prelevement'),
                        _buildSubItem(AppModule.stockTransfer, 'Bons de transfert'),
                        _buildSubItem(AppModule.inventorySheet, 'Fiche d\'inventaire'),
                        _buildSubItem(AppModule.warehouses, 'Entrepots'),
                      ]),
                      _buildGroup('production', Icons.precision_manufacturing_rounded, 'Production', [
                        _buildSubItem(AppModule.productionDashboard, 'Tableau de bord Production'),
                        _buildSubItem(AppModule.productionOrders, 'Ordres de fabrication'),
                        _buildSubItem(AppModule.productionBoms, 'Nomenclatures (BOM)'),
                        _buildSubItem(AppModule.productionPlanning, 'Planification de production'),
                        _buildSubItem(AppModule.productionCosts, 'Suivi des coûts'),
                        _buildSubItem(AppModule.productionQuality, 'Contrôle qualité'),
                        _buildSubItem(AppModule.productionReports, 'Rapports de rendement'),
                        _buildSubItem(AppModule.productionWorkcenters, 'Postes de travail'),
                      ]),
                      // Section 4: Projets & RH
                      if (_hasAnyVisibleItem([AppModule.projects]) || _hasAnyVisibleGroup(['rh']))
                        const _SidebarDivider(),
                      _buildItem(AppModule.projects, Icons.folder_rounded, 'Projets'),
                      _buildGroup('rh', Icons.badge_rounded, 'RH & Paie', [
                        _buildSubItem(AppModule.hrDashboard, 'Tableau de bord'),
                        _buildSubItem(AppModule.hrEmployees, 'Personnel (Employés)'),
                        _buildSubItem(AppModule.hrLeaves, 'Congés & Absences'),
                        _buildSubItem(AppModule.hrAttendances, 'Présences / Pointages'),
                        _buildSubItem(AppModule.hrPayroll, 'Fiches de Paie'),
                        _buildSubItem(AppModule.hrCnssDeclaration, 'Déclaration CNSS'),
                        _buildSubItem(AppModule.hrDocuments, 'Documents'),
                        _buildSubItem(AppModule.hrAccounting, 'Comptabilité'),
                        _buildSubItem(AppModule.hrLegalEntity, 'Entité juridique'),
                        _buildSubItem(AppModule.hrEstablishments, 'Établissements'),
                        _buildSubItem(AppModule.hrManagers, 'Gestionnaires'),
                      ]),
                      // Section 5: Paramètres (always visible)
                      const _SidebarDivider(),
                      _buildItem(AppModule.settings, Icons.settings_rounded, 'Parametres'),
                      _buildAiAssistantItem(isMobileOrDrawer),
                      _buildItem(AppModule.trash, Icons.delete_outline_rounded, 'Corbeille'),
                      _buildItem(AppModule.appModulesSettings, Icons.widgets_rounded, 'Modules de l\'application'),
                      _buildItem(AppModule.personalInfo, Icons.badge_outlined, 'Informations personnelles'),
                      _buildItem(AppModule.companyInfo, Icons.business_rounded, 'Informations de la societe'),
                      _buildItem(AppModule.documentNumbering, Icons.format_list_numbered_rounded, 'Numérotation des documents'),
                      _buildItem(AppModule.documentTemplates, Icons.design_services_rounded, 'Modeles de documents'),
                      _buildItem(AppModule.customFields, Icons.tune_rounded, 'Champs personnalisés'),
                      _buildItem(AppModule.customStatuses, Icons.bookmarks_outlined, 'Statuts personnalisés'),
                      _buildItem(AppModule.importExport, Icons.sync_alt_rounded, 'Import / Export des données'),
                      _buildItem(AppModule.support, Icons.support_agent_rounded, 'Support client'),
                      _buildItem(AppModule.affiliate, Icons.handshake_rounded, 'Affiliation & Parrainage'),
                      if (PermissionService.instance.isAdmin)
                        _buildItem(AppModule.userManagement, Icons.manage_accounts_rounded, 'Gestion des utilisateurs'),
                      _buildItem(AppModule.userTracking, Icons.manage_history_rounded, 'Traçabilité Utilisateurs'),
                      const SizedBox(height: 16),
                      
                      // // TEMP SYNC BUTTON - Temporarily hidden
                      // if (!widget.isCollapsed)
                      //   Padding(
                      //     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      //     child: ElevatedButton.icon(
                      //       style: ElevatedButton.styleFrom(
                      //         backgroundColor: Colors.red,
                      //         foregroundColor: Colors.white,
                      //       ),
                      //       onPressed: () async {
                      //         ScaffoldMessenger.of(context).showSnackBar(
                      //           const SnackBar(content: Text('Starting Force Sync... Please wait!')),
                      //         );
                      //         await DatabaseHelper.instance.forceSyncAllExistingDataWithItems();
                      //         // Force upload to Firebase immediately!
                      //         await SyncService.instance.triggerSync();
                      //         if (context.mounted) {
                      //           ScaffoldMessenger.of(context).showSnackBar(
                      //             const SnackBar(content: Text('Force Sync Complete! Check Mobile now.')),
                      //           );
                      //         }
                      //       },
                      //       icon: const Icon(Icons.sync_problem),
                      //       label: const Text('FORCE SYNC FIX'),
                      //     ),
                      //   ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
  }

  Widget _buildHeader({required double collapsedWidth}) {
    final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;

    if (widget.isCollapsed) {
      return Container(
        width: collapsedWidth,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.sidebarBg,
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const EnterpriseSwitcherWidget(
              isCollapsed: true,
            ),
            const SizedBox(height: 8),
            _buildCollapseToggle(isCollapsed: true),
          ],
        ),
      );
    }

    return Container(
      height: isDesktopOrWeb ? 52 : 64,
      padding: EdgeInsets.symmetric(horizontal: isDesktopOrWeb ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: EnterpriseSwitcherWidget(
              isCollapsed: false,
            ),
          ),
          const SizedBox(width: 4),
          _buildCollapseToggle(isCollapsed: false),
        ],
      ),
    );
  }

  Widget _buildCollapseToggle({required bool isCollapsed}) {
    final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final collapseIcon = isCollapsed
        ? (isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded)
        : (isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded);

    final tooltipMsg = isCollapsed
        ? context.tr('Développer la barre latérale')
        : context.tr('Réduire la barre latérale');

    return Tooltip(
      message: tooltipMsg,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onToggleCollapse,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          splashColor: Colors.white.withValues(alpha: 0.12),
          child: Container(
            width: isCollapsed ? 36 : 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCollapsed
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isCollapsed
                  ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                  : null,
            ),
            child: Icon(
              collapseIcon,
              color: AppColors.sidebarText,
              size: isDesktopOrWeb ? 17 : 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(AppModule module, IconData icon, String label) {
    if (!PermissionService.instance.canAccessModule(module)) {
      return const SizedBox.shrink();
    }
    if (!AppModulesService.instance.isModuleEnabled(module)) {
      return const SizedBox.shrink();
    }
    final isActive = widget.activeModule == module;
    return _SidebarItemWidget(
      icon: icon,
      label: context.tr(label),
      isActive: isActive,
      isCollapsed: widget.isCollapsed,
      onTap: () => widget.onModuleSelected(module),
    );
  }

  Widget _buildGroup(String groupKey, IconData icon, String label, List<Widget> children) {
    if (!AppModulesService.instance.isGroupEnabled(groupKey)) {
      return const SizedBox.shrink();
    }

    // Filter visible children based on permission and module activation
    final visibleChildren = children.where((w) {
      if (w is _SidebarSubItemWidget) {
        return PermissionService.instance.canAccessModule(w.module) &&
            AppModulesService.instance.isModuleEnabled(w.module);
      }
      return true;
    }).toList();

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    final isExpanded = _expandedGroups.contains(groupKey);
    final localizedLabel = context.tr(label);

    if (widget.isCollapsed) {
      final isAnyChildActive = visibleChildren.any((w) {
        if (w is _SidebarSubItemWidget) {
          return w.module == widget.activeModule;
        }
        return false;
      });

      final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;
      final double collapsedWidth = isDesktopOrWeb ? 62.0 : 68.0;

      return PopupMenuButton<AppModule>(
        tooltip: localizedLabel,
        offset: Offset(collapsedWidth + 2, 0),
        color: const Color(0xFF1E293B),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        onSelected: (mod) => widget.onModuleSelected(mod),
        itemBuilder: (context) {
          final items = <PopupMenuEntry<AppModule>>[];
          // Group title header
          items.add(
            PopupMenuItem<AppModule>(
              enabled: false,
              height: 36,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    localizedLabel.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.sidebarText.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          );
          items.add(const PopupMenuDivider(height: 8));

          for (final w in visibleChildren) {
            if (w is _SidebarSubItemWidget) {
              final isCurrentActive = w.module == widget.activeModule;
              items.add(
                PopupMenuItem<AppModule>(
                  value: w.module,
                  height: 38,
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrentActive ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w.label,
                          style: TextStyle(
                            color: isCurrentActive ? Colors.white : AppColors.sidebarText,
                            fontWeight: isCurrentActive ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isCurrentActive)
                        Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            }
          }
          return items;
        },
        child: _SidebarItemWidget(
          icon: icon,
          label: localizedLabel,
          isActive: isAnyChildActive,
          isCollapsed: true,
          hasSubmenu: true,
          onTap: null,
        ),
      );
    }

    final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final groupMinHeight = isDesktopOrWeb
        ? (28.0 * textScale).clamp(28.0, 34.0)
        : (42.0 * textScale).clamp(42.0, 56.0);
    final verticalPadding = isDesktopOrWeb ? 1.5 : 4.0;
    final iconSize = isDesktopOrWeb ? 15.0 : 18.0;
    final fontSize = isDesktopOrWeb ? 11.8 : 13.0;

    return Column(
      children: [
        Tooltip(
          message: localizedLabel,
          waitDuration: const Duration(milliseconds: 600),
          child: InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroups.remove(groupKey);
                } else {
                  _expandedGroups.add(groupKey);
                }
              });
            },
            child: Container(
              constraints: BoxConstraints(minHeight: groupMinHeight),
              padding: EdgeInsets.symmetric(horizontal: isDesktopOrWeb ? 10 : 12, vertical: verticalPadding),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.sidebarText, size: iconSize),
                  SizedBox(width: isDesktopOrWeb ? 8 : 10),
                  Expanded(
                    child: Text(
                      localizedLabel,
                      style: TextStyle(color: AppColors.sidebarText, fontSize: fontSize, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.sidebarText,
                    size: isDesktopOrWeb ? 15 : 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...visibleChildren,
      ],
    );
  }

  Widget _buildSubItem(AppModule module, String label) {
    if (!PermissionService.instance.canAccessModule(module)) {
      return const SizedBox.shrink();
    }
    if (!AppModulesService.instance.isModuleEnabled(module)) {
      return const SizedBox.shrink();
    }
    final isActive = widget.activeModule == module;
    return _SidebarSubItemWidget(
      module: module,
      label: context.tr(label),
      isActive: isActive,
      onTap: () => widget.onModuleSelected(module),
    );
  }

  /// Returns true if at least one group key in [groupKeys] is enabled and permitted.
  bool _hasAnyVisibleGroup(List<String> groupKeys) {
    for (final key in groupKeys) {
      if (AppModulesService.instance.isGroupEnabled(key)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if at least one module in [modules] is enabled and has permission.
  bool _hasAnyVisibleItem(List<AppModule> modules) {
    for (final mod in modules) {
      if (PermissionService.instance.canAccessModule(mod) &&
          AppModulesService.instance.isModuleEnabled(mod)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildAiAssistantItem(bool isMobileOrDrawer) {
    return _SidebarItemWidget(
      icon: Icons.auto_awesome_rounded,
      label: context.tr('Assistant IA'),
      isActive: false,
      isCollapsed: widget.isCollapsed,
      onTap: () {
        if (isMobileOrDrawer && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (widget.onAiAssistantTap != null) {
          widget.onAiAssistantTap!();
        } else {
          AiChatModalSheet.show(context);
        }
      },
    );
  }
}

class _SidebarSubItemWidget extends StatelessWidget {
  final AppModule module;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarSubItemWidget({
    required this.module,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final itemMinHeight = isDesktopOrWeb
        ? (23.0 * textScale).clamp(23.0, 28.0)
        : (36.0 * textScale).clamp(36.0, 48.0);
    final verticalPadding = isDesktopOrWeb ? 1.0 : 4.0;
    final leftPadding = isDesktopOrWeb ? 28.0 : 40.0;
    final fontSize = isDesktopOrWeb ? 11.2 : 12.0;

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: BoxConstraints(minHeight: itemMinHeight),
          padding: EdgeInsets.only(left: leftPadding, right: 8, top: verticalPadding, bottom: verticalPadding),
          decoration: BoxDecoration(
            color: isActive ? AppColors.sidebarActive.withValues(alpha: 0.2) : Colors.transparent,
            border: isActive ? Border(left: BorderSide(color: AppColors.primary, width: isDesktopOrWeb ? 2.5 : 3.0)) : null,
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppColors.sidebarText.withValues(alpha: 0.75),
                    fontSize: fontSize,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItemWidget extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isCollapsed;
  final bool hasSubmenu;
  final VoidCallback? onTap;

  const _SidebarItemWidget({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isCollapsed,
    this.hasSubmenu = false,
    this.onTap,
  });

  @override
  State<_SidebarItemWidget> createState() => _SidebarItemWidgetState();
}

class _SidebarItemWidgetState extends State<_SidebarItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final fontSize = isDesktopOrWeb ? 11.8 : 13.0;

    if (widget.isCollapsed) {
      final double buttonSize = isDesktopOrWeb ? 40.0 : 44.0;
      final double iconSize = isDesktopOrWeb ? 19.0 : 22.0;

      final content = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: buttonSize,
          height: buttonSize,
          margin: EdgeInsets.symmetric(vertical: isDesktopOrWeb ? 3.0 : 4.0),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.primary
                : _hovered
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                color: widget.isActive ? Colors.white : (_hovered ? Colors.white : AppColors.sidebarText),
                size: iconSize,
              ),
              if (widget.hasSubmenu)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isActive
                          ? Colors.white70
                          : (_hovered ? Colors.white70 : AppColors.sidebarText.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

      if (widget.onTap != null) {
        return Tooltip(
          message: widget.label,
          waitDuration: const Duration(milliseconds: 250),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Center(child: content),
          ),
        );
      }

      return Center(child: content);
    }

    final itemMinHeight = isDesktopOrWeb
        ? (28.0 * textScale).clamp(28.0, 34.0)
        : (42.0 * textScale).clamp(42.0, 56.0);
    final verticalPadding = isDesktopOrWeb ? 1.5 : 4.0;
    final verticalMargin = isDesktopOrWeb ? 0.5 : 1.5;
    final horizontalMargin = isDesktopOrWeb ? 5.0 : 8.0;
    final horizontalPadding = isDesktopOrWeb ? 7.0 : 10.0;
    final iconSize = isDesktopOrWeb ? 15.0 : 18.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: BoxConstraints(minHeight: itemMinHeight),
            margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.sidebarActive
                  : _hovered
                      ? AppColors.sidebarHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(isDesktopOrWeb ? 6 : AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.isActive ? Colors.white : AppColors.sidebarText, size: iconSize),
                SizedBox(width: isDesktopOrWeb ? 8 : 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isActive ? Colors.white : AppColors.sidebarText,
                      fontSize: fontSize,
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();
  @override
  Widget build(BuildContext context) {
    final isDesktopOrWeb = PlatformUtils.isDesktop || PlatformUtils.isWeb;
    return Divider(
      color: Colors.white.withValues(alpha: 0.07),
      height: isDesktopOrWeb ? 14 : 18,
      indent: isDesktopOrWeb ? 10 : 12,
      endIndent: isDesktopOrWeb ? 10 : 12,
    );
  }
}

