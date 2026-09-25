import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/enterprise_switcher.dart';
import '../utils/constants.dart';
import '../blocs/theme/theme_cubit.dart';
import '../services/permission_service.dart';
import '../services/app_modules_service.dart';
import '../blocs/locale/locale_cubit.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selection_dialog.dart';

class MobileDrawer extends StatefulWidget {
  final AppModule activeModule;
  final ValueChanged<AppModule> onModuleSelected;

  const MobileDrawer({
    super.key,
    required this.activeModule,
    required this.onModuleSelected,
  });

  @override
  State<MobileDrawer> createState() => _MobileDrawerState();
}

class _MobileDrawerState extends State<MobileDrawer> {
  final Set<String> _expandedGroups = {'ventes'};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PermissionService.instance.permissionsNotifier,
        AppModulesService.instance.notifier,
      ]),
      builder: (context, _) {
        return Drawer(
          backgroundColor: AppColors.sidebarBg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildItem(AppModule.dashboard, Icons.dashboard_rounded, 'Tableau de bord'),
                      _buildItem(AppModule.reports, Icons.bar_chart_rounded, 'Rapports et statistiques'),
                      // Section 1: Documents commerciaux
                      if (_hasAnyVisibleGroup(['ventes', 'achats', 'paiements', 'tresorerie', 'retenue_source', 'contacts', 'articles', 'stock']))
                        const _DrawerDivider(),
                      _buildGroup('ventes', 'Ventes', Icons.trending_up_rounded, [
                        _buildItem(AppModule.quotes, Icons.description_rounded, 'Devis'),
                        _buildItem(AppModule.customerOrders, Icons.shopping_cart_rounded, 'Commandes Client'),
                        _buildItem(AppModule.deliveryNotes, Icons.local_shipping_rounded, 'Bons de livraison'),
                        _buildItem(AppModule.invoices, Icons.receipt_rounded, 'Factures'),
                        _buildItem(AppModule.exitVouchers, Icons.output_rounded, 'Bons de sortie'),
                        _buildItem(AppModule.creditNotes, Icons.undo_rounded, 'Avoirs Client'),
                        _buildItem(AppModule.returnVouchers, Icons.assignment_return_rounded, 'Bons de retour'),
                      ]),
                      _buildGroup('achats', 'Achats', Icons.shopping_bag_rounded, [
                        _buildItem(AppModule.supplierOrders, Icons.list_alt_rounded, 'Commandes Fournisseur'),
                        _buildItem(AppModule.receivingVouchers, Icons.inbox_rounded, 'Bons de reception'),
                        _buildItem(AppModule.purchaseInvoices, Icons.receipt_long_rounded, 'Factures d\'achat'),
                        _buildItem(AppModule.supplierCreditNotes, Icons.replay_rounded, 'Avoirs Fournisseur'),
                        _buildItem(AppModule.supplierReturns, Icons.assignment_return_rounded, 'Retours Fournisseur'),
                      ]),
                      _buildGroup('paiements', 'Paiements', Icons.payment_rounded, [
                        _buildItem(AppModule.payments, Icons.payments_rounded, 'Paiements'),
                      ]),
                      _buildGroup('tresorerie', 'Trésorerie', Icons.account_balance_rounded, [
                        _buildItem(AppModule.accounts, Icons.account_balance_rounded, 'Comptes'),
                        _buildItem(AppModule.transactions, Icons.swap_horiz_rounded, 'Transactions'),
                        _buildItem(AppModule.checksTraites, Icons.note_rounded, 'Cheques & Traites'),
                      ]),
                      _buildGroup('retenue_source', 'Retenue à la source', Icons.request_quote_rounded, [
                        _buildItem(AppModule.withholdingTaxSales, Icons.description_rounded, 'RS vente'),
                        _buildItem(AppModule.withholdingTaxPurchase, Icons.receipt_rounded, 'RS achat'),
                      ]),
                      _buildGroup('contacts', 'Contacts', Icons.people_rounded, [
                        _buildItem(AppModule.customers, Icons.person_rounded, 'Clients'),
                        _buildItem(AppModule.suppliers, Icons.business_rounded, 'Fournisseurs'),
                      ]),
                      _buildGroup('articles', 'Articles', Icons.inventory_2_rounded, [
                        _buildItem(AppModule.products, Icons.inventory_2_rounded, 'Articles'),
                        _buildItem(AppModule.productSettings, Icons.tune_rounded, 'Parametres Articles'),
                      ]),
                      _buildGroup('stock', 'Stock', Icons.warehouse_rounded, [
                        _buildItem(AppModule.stockDashboard, Icons.dashboard_rounded, 'Vue d\'ensemble'),
                        _buildItem(AppModule.stockMovements, Icons.swap_horiz_rounded, 'Mouvements'),
                        _buildItem(AppModule.stockEntry, Icons.add_box_rounded, 'Bons d\'entree'),
                        _buildItem(AppModule.stockWithdrawal, Icons.outbox_rounded, 'Prelevements'),
                        _buildItem(AppModule.stockTransfer, Icons.sync_alt_rounded, 'Bons de transfert'),
                        _buildItem(AppModule.inventorySheet, Icons.fact_check_rounded, 'Fiche d\'inventaire'),
                        _buildItem(AppModule.warehouses, Icons.warehouse_rounded, 'Entrepots'),
                      ]),
                      // Section 2: Projets + Paramètres
                      if (_hasAnyVisibleDrawerItem([AppModule.projects]))
                        const _DrawerDivider(),
                      _buildItem(AppModule.projects, Icons.folder_rounded, 'Projets'),
                      // Paramètres always visible
                      const _DrawerDivider(),
                      _buildItem(AppModule.settings, Icons.settings_rounded, 'Parametres'),
                      _buildItem(AppModule.trash, Icons.delete_outline_rounded, 'Corbeille'),
                      _buildItem(AppModule.appModulesSettings, Icons.widgets_rounded, 'Modules de l\'application'),
                      _buildThemeToggleItem(),
                      _buildLanguageItem(),
                      _buildItem(AppModule.personalInfo, Icons.badge_outlined, 'Informations personnelles'),
                      _buildItem(AppModule.companyInfo, Icons.business_rounded, 'Informations de la société'),
                      _buildItem(AppModule.documentNumbering, Icons.format_list_numbered_rounded, 'Numérotation des documents'),
                      _buildItem(AppModule.documentTemplates, Icons.design_services_rounded, 'Modeles'),
                      _buildItem(AppModule.customFields, Icons.tune_rounded, 'Champs personnalisés'),
                      _buildItem(AppModule.customStatuses, Icons.bookmarks_outlined, 'Statuts personnalisés'),
                      _buildItem(AppModule.importExport, Icons.sync_alt_rounded, 'Import / Export'),
                      _buildItem(AppModule.support, Icons.support_agent_rounded, 'Support client'),
                      if (PermissionService.instance.isAdmin)
                        _buildItem(AppModule.userManagement, Icons.manage_accounts_rounded, 'Gestion des utilisateurs'),
                      _buildItem(AppModule.userTracking, Icons.manage_history_rounded, 'Traçabilité Utilisateurs'),
                    ],
                  ),
                ),
                // Logout
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(context.tr('Deconnexion'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: const Row(
        children: [
          Expanded(
            child: EnterpriseSwitcherWidget(isMobile: true),
          ),
          SyncIndicator(),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            widget.onModuleSelected(module);
            Navigator.pop(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isActive ? AppColors.sidebarActive.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? AppColors.primaryLight : AppColors.sidebarText,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.tr(label),
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.sidebarText,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggleItem() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          final isDark = themeMode == ThemeMode.dark;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                context.read<ThemeCubit>().toggleTheme();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_rounded,
                      size: 20,
                      color: AppColors.sidebarText,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        context.tr('Mode sombre'),
                        style: TextStyle(
                          color: AppColors.sidebarText,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Switch(
                      value: isDark,
                      onChanged: (value) {
                        context.read<ThemeCubit>().toggleTheme();
                      },
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageItem() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          final localeCubit = context.read<LocaleCubit>();
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                LanguageSelectionDialog.show(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: 20,
                      color: AppColors.sidebarText,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        context.tr('Langue et region'),
                        style: TextStyle(
                          color: AppColors.sidebarText,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      localeCubit.currentLanguageName,
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroup(String key, String title, IconData icon, List<Widget> children) {
    if (key != 'contacts' && !AppModulesService.instance.isGroupEnabled(key)) {
      return const SizedBox.shrink();
    }

    // For 'contacts' group, check individual module visibility
    if (key == 'contacts') {
      final hasCustomers = PermissionService.instance.canAccessModule(AppModule.customers) &&
          AppModulesService.instance.isModuleEnabled(AppModule.customers);
      final hasSuppliers = PermissionService.instance.canAccessModule(AppModule.suppliers) &&
          AppModulesService.instance.isModuleEnabled(AppModule.suppliers);
      if (!hasCustomers && !hasSuppliers) return const SizedBox.shrink();
    }

    // Filter visible children
    final visibleChildren = children.where((c) {
      if (c is SizedBox) return false;
      return true;
    }).toList();

    // Check if any child module is accessible
    final hasAnyAccessible = children.any((c) {
      if (c is Padding) {
        return true;
      }
      return false;
    });

    if (!hasAnyAccessible) {
      return const SizedBox.shrink();
    }

    final isExpanded = _expandedGroups.contains(key);
    final hasActive = children.any((c) {
      if (c is Padding && c.child is Material) {
        final inkWell = (c.child as Material).child as InkWell;
        final container = inkWell.child as AnimatedContainer;
        return container.decoration != null &&
            (container.decoration as BoxDecoration).color != null;
      }
      return false;
    });

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroups.remove(key);
                } else {
                  _expandedGroups.add(key);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.sidebarText.withValues(alpha: 0.6)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      context.tr(title),
                      style: TextStyle(
                        color: hasActive ? Colors.white : AppColors.sidebarText.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.sidebarText.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(children: visibleChildren),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  bool _hasAnyVisibleGroup(List<String> groupKeys) {
    for (final key in groupKeys) {
      if (key == 'contacts') {
        final hasCustomers = PermissionService.instance.canAccessModule(AppModule.customers) &&
            AppModulesService.instance.isModuleEnabled(AppModule.customers);
        final hasSuppliers = PermissionService.instance.canAccessModule(AppModule.suppliers) &&
            AppModulesService.instance.isModuleEnabled(AppModule.suppliers);
        if (hasCustomers || hasSuppliers) return true;
      } else if (AppModulesService.instance.isGroupEnabled(key)) {
        return true;
      }
    }
    return false;
  }

  bool _hasAnyVisibleDrawerItem(List<AppModule> modules) {
    for (final mod in modules) {
      if (PermissionService.instance.canAccessModule(mod) &&
          AppModulesService.instance.isModuleEnabled(mod)) {
        return true;
      }
    }
    return false;
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
    );
  }
}
