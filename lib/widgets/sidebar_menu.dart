import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum AppModule {
  dashboard,
  reports,
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
  // Stock
  stockDashboard,
  stockMovements,
  stockEntry,
  stockWithdrawal,
  stockTransfer,
  inventorySheet,
  warehouses,
  // Projets
  projects,
  // Paramètres
  settings,
}

class SidebarMenu extends StatefulWidget {
  final AppModule activeModule;
  final ValueChanged<AppModule> onModuleSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const SidebarMenu({
    super.key,
    required this.activeModule,
    required this.onModuleSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  final Set<String> _expandedGroups = {'ventes'};

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: widget.isCollapsed ? 64 : 256,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildItem(AppModule.dashboard, Icons.dashboard_rounded, 'Tableau de bord'),
                  _buildItem(AppModule.reports, Icons.bar_chart_rounded, 'Rapports'),
                  const _SidebarDivider(),
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
                    _buildSubItem(AppModule.receivingVouchers, 'Bons de réception'),
                    _buildSubItem(AppModule.purchaseInvoices, 'Factures d\'achat'),
                    _buildSubItem(AppModule.supplierCreditNotes, 'Avoirs fournisseur'),
                    _buildSubItem(AppModule.supplierReturns, 'Retours fournisseur'),
                  ]),
                  _buildGroup('paiements', Icons.account_balance_wallet_rounded, 'Paiements', [
                    _buildSubItem(AppModule.payments, 'Paiements'),
                    _buildSubItem(AppModule.withholdingTaxSales, 'Retenue (ventes)'),
                    _buildSubItem(AppModule.withholdingTaxPurchase, 'Retenue (achats)'),
                  ]),
                  _buildGroup('tresorerie', Icons.account_balance_rounded, 'Trésorerie', [
                    _buildSubItem(AppModule.accounts, 'Comptes'),
                    _buildSubItem(AppModule.transactions, 'Transactions'),
                    _buildSubItem(AppModule.checksTraites, 'Chèques & Traites'),
                  ]),
                  const _SidebarDivider(),
                  _buildItem(AppModule.customers, Icons.people_rounded, 'Clients'),
                  _buildItem(AppModule.suppliers, Icons.factory_rounded, 'Fournisseurs'),
                  _buildItem(AppModule.products, Icons.inventory_2_rounded, 'Articles'),
                  const _SidebarDivider(),
                  _buildGroup('stock', Icons.warehouse_rounded, 'Stock', [
                    _buildSubItem(AppModule.stockDashboard, 'Vue d\'ensemble'),
                    _buildSubItem(AppModule.stockMovements, 'Mouvements'),
                    _buildSubItem(AppModule.stockEntry, 'Bons d\'entrée'),
                    _buildSubItem(AppModule.stockWithdrawal, 'Bons de prélèvement'),
                    _buildSubItem(AppModule.stockTransfer, 'Bons de transfert'),
                    _buildSubItem(AppModule.inventorySheet, 'Fiche d\'inventaire'),
                    _buildSubItem(AppModule.warehouses, 'Entrepôts'),
                  ]),
                  const _SidebarDivider(),
                  _buildItem(AppModule.projects, Icons.folder_rounded, 'Projets'),
                  const _SidebarDivider(),
                  _buildItem(AppModule.settings, Icons.settings_rounded, 'Paramètres'),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
          ),
          if (!widget.isCollapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Business Manager', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('Pro', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          IconButton(
            icon: Icon(
              widget.isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              color: AppColors.sidebarText,
              size: 20,
            ),
            onPressed: widget.onToggleCollapse,
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildItem(AppModule module, IconData icon, String label) {
    final isActive = widget.activeModule == module;
    return _SidebarItemWidget(
      icon: icon,
      label: label,
      isActive: isActive,
      isCollapsed: widget.isCollapsed,
      onTap: () => widget.onModuleSelected(module),
    );
  }

  Widget _buildGroup(String groupKey, IconData icon, String label, List<Widget> children) {
    final isExpanded = _expandedGroups.contains(groupKey);
    final isGroupActive = false; // Could check if any child is active

    if (widget.isCollapsed) {
      return _SidebarItemWidget(
        icon: icon,
        label: label,
        isActive: isGroupActive,
        isCollapsed: true,
        onTap: () {},
      );
    }

    return Column(
      children: [
        InkWell(
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
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.sidebarText, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: TextStyle(color: AppColors.sidebarText, fontSize: 13, fontWeight: FontWeight.w500))),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.sidebarText,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...children,
      ],
    );
  }

  Widget _buildSubItem(AppModule module, String label) {
    final isActive = widget.activeModule == module;
    return InkWell(
      onTap: () => widget.onModuleSelected(module),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.only(left: 40),
        decoration: BoxDecoration(
          color: isActive ? AppColors.sidebarActive.withValues(alpha: 0.2) : Colors.transparent,
          border: isActive ? Border(left: BorderSide(color: AppColors.primary, width: 3)) : null,
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.sidebarText.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
  final VoidCallback onTap;

  const _SidebarItemWidget({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_SidebarItemWidget> createState() => _SidebarItemWidgetState();
}

class _SidebarItemWidgetState extends State<_SidebarItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 0 : 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.sidebarActive
                : _hovered
                    ? AppColors.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: widget.isCollapsed
              ? Center(child: Icon(widget.icon, color: widget.isActive ? Colors.white : AppColors.sidebarText, size: 20))
              : Row(
                  children: [
                    Icon(widget.icon, color: widget.isActive ? Colors.white : AppColors.sidebarText, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.isActive ? Colors.white : AppColors.sidebarText,
                        fontSize: 13,
                        fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
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
    return Divider(
      color: Colors.white.withValues(alpha: 0.06),
      height: 16,
      indent: 12,
      endIndent: 12,
    );
  }
}
