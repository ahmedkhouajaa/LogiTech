import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/sync_indicator.dart';
import '../utils/constants.dart';

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
                  _buildItem(AppModule.reports, Icons.bar_chart_rounded, 'Rapports'),
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
                    _buildItem(AppModule.accounts, Icons.account_balance_rounded, 'Comptes'),
                    _buildItem(AppModule.transactions, Icons.swap_horiz_rounded, 'Transactions'),
                    _buildItem(AppModule.checksTraites, Icons.note_rounded, 'Cheques & Traites'),
                  ]),
                  _buildGroup('retenue', 'Retenue à la source', Icons.request_quote_rounded, [
                    _buildItem(AppModule.withholdingTaxSales, Icons.description_rounded, 'RS vente'),
                    _buildItem(AppModule.withholdingTaxPurchase, Icons.receipt_rounded, 'RS achat'),
                  ]),
                  _buildGroup('tiers', 'Tiers', Icons.people_rounded, [
                    _buildItem(AppModule.customers, Icons.person_rounded, 'Clients'),
                    _buildItem(AppModule.suppliers, Icons.business_rounded, 'Fournisseurs'),
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
                  const _DrawerDivider(),
                  _buildItem(AppModule.projects, Icons.folder_rounded, 'Projets'),
                  _buildItem(AppModule.settings, Icons.settings_rounded, 'Parametres'),
                  _buildItem(AppModule.companyInfo, Icons.business_center_rounded, 'Ma Societe'),
                  _buildItem(AppModule.documentTemplates, Icons.design_services_rounded, 'Modeles'),
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
                  label: const Text('Deconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
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
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LogiTech Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Gestion d\'entreprise',
                  style: TextStyle(color: AppColors.sidebarText, fontSize: 11),
                ),
              ],
            ),
          ),
          const SyncIndicator(),
        ],
      ),
    );
  }

  Widget _buildItem(AppModule module, IconData icon, String label) {
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
                    label,
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

  Widget _buildGroup(String key, String title, IconData icon, List<Widget> children) {
    final isExpanded = _expandedGroups.contains(key);
    final hasActive = children.any((c) {
      if (c is Padding) {
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
                      title,
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
            child: Column(children: children),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
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
