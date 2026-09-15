import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';
import '../utils/file_download_helper.dart';
import '../services/reports_data_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'Cette Année';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  ReportsDashboardData _dashboardData = ReportsDashboardData.empty();
  String? _selectedReportKey;
  String _tableSearchQuery = '';
  final TextEditingController _tableSearchController = TextEditingController();

  final List<String> _periods = [
    'Cette Année',
    'Ce Mois',
    'Mois Dernier',
    'Ce Trimestre',
    "Tout l'historique",
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await ReportsDataService.instance.loadData(period: _selectedPeriod);
    if (mounted) {
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    }
  }

  void _exportDetailCsv(ReportDetailData detail) async {
    final csv = detail.toCsv();
    final fileName = '${detail.reportKey}_${DateTime.now().millisecondsSinceEpoch}.csv';
    try {
      await FileDownloadHelper.saveStringFile(
        csv,
        fileName,
        mimeType: 'text/csv',
        context: context,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export $fileName réussi !'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 16),
                  Text(
                    'Chargement des statistiques...',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _selectedReportKey != null
                  ? _buildReportDetailView()
                  : _buildMainDashboardView(),
            ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // MAIN DASHBOARD VIEW
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildMainDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildSmartKpiRibbon(),
        const SizedBox(height: 24),
        _buildCategoriesGrid(),
      ],
    );
  }

  Widget _buildHeader() {
    final isNarrow = MediaQuery.of(context).size.width < 850;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleSection(),
                const SizedBox(height: 16),
                _buildSearchAndFilters(isNarrow: true),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildTitleSection()),
                const SizedBox(width: 16),
                _buildSearchAndFilters(isNarrow: false),
              ],
            ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Rapports et statistiques',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Consultez vos indicateurs de vente, achat, trésorerie, stock et marges commerciales.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters({required bool isNarrow}) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Search Input
        SizedBox(
          width: isNarrow ? double.infinity : 240,
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher un rapport...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
        ),

        // Period Dropdown
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPeriod,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
              items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (val) {
                if (val != null && val != _selectedPeriod) {
                  setState(() => _selectedPeriod = val);
                  _loadData();
                }
              },
            ),
          ),
        ),

        // Refresh Button
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
          onPressed: _loadData,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // SMART KPI RIBBON
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildSmartKpiRibbon() {
    final kpis = [
      _SmartKpi(
        title: 'Chiffre d\'Affaires Ventes',
        value: '${_dashboardData.totalSalesTTC.toStringAsFixed(2)} TND',
        subtitle: '${_dashboardData.invoices.length} factures enregistrées',
        icon: Icons.trending_up_rounded,
        badgeText: 'TTC',
        badgeColor: const Color(0xFF2563EB),
        accentColor: const Color(0xFF2563EB),
      ),
      _SmartKpi(
        title: 'Total Achats',
        value: '${_dashboardData.totalPurchasesTTC.toStringAsFixed(2)} TND',
        subtitle: '${_dashboardData.purchaseInvoices.length} factures fournisseurs',
        icon: Icons.shopping_bag_outlined,
        badgeText: 'Dépenses',
        badgeColor: const Color(0xFFEF4444),
        accentColor: const Color(0xFFEF4444),
      ),
      _SmartKpi(
        title: 'Marge Commerciale',
        value: '${_dashboardData.totalMargin.toStringAsFixed(2)} TND',
        subtitle: 'Taux brut : ${_dashboardData.marginRate.toStringAsFixed(1)}%',
        icon: Icons.attach_money_rounded,
        badgeText: '+${_dashboardData.marginRate.toStringAsFixed(0)}%',
        badgeColor: const Color(0xFF10B981),
        accentColor: const Color(0xFF10B981),
      ),
      _SmartKpi(
        title: 'Encaissements Reçus',
        value: '${_dashboardData.totalInflows.toStringAsFixed(2)} TND',
        subtitle: 'Paiements clients validés',
        icon: Icons.arrow_downward_rounded,
        badgeText: 'Entrées',
        badgeColor: const Color(0xFF10B981),
        accentColor: const Color(0xFF10B981),
      ),
      _SmartKpi(
        title: 'Décaissements Émis',
        value: '${_dashboardData.totalOutflows.toStringAsFixed(2)} TND',
        subtitle: 'Règlements fournisseurs',
        icon: Icons.arrow_upward_rounded,
        badgeText: 'Sorties',
        badgeColor: const Color(0xFFF59E0B),
        accentColor: const Color(0xFFF59E0B),
      ),
      _SmartKpi(
        title: 'Valeur du Stock',
        value: '${_dashboardData.stockValue.toStringAsFixed(2)} TND',
        subtitle: '${_dashboardData.outOfStockCount} articles en rupture',
        icon: Icons.inventory_2_outlined,
        badgeText: _dashboardData.outOfStockCount > 0 ? '${_dashboardData.outOfStockCount} alertes' : 'OK',
        badgeColor: _dashboardData.outOfStockCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        accentColor: const Color(0xFF8B5CF6),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 6
            : constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 500
                    ? 2
                    : 1;

        final width = (constraints.maxWidth - ((crossAxisCount - 1) * 12)) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((kpi) => SizedBox(width: width, child: _buildKpiCard(kpi))).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_SmartKpi kpi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kpi.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kpi.icon, size: 18, color: kpi.accentColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kpi.badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  kpi.badgeText,
                  style: TextStyle(
                    color: kpi.badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            kpi.value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kpi.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            kpi.subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // THE 8 CATEGORY CARDS (IMAGES 1 & 2)
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildCategoriesGrid() {
    // Define all 8 categories exactly as in images 1 and 2
    final categories = [
      // ─── Image 1 ──────────────────────────────────────────────────
      _ReportCategory(
        title: 'Rapports de vente',
        icon: Icons.trending_up_rounded,
        items: [
          _ReportItem(key: 'vente_client', title: 'Vente par client'),
          _ReportItem(key: 'vente_article', title: 'Vente par article'),
          _ReportItem(key: 'vente_famille', title: 'Vente par famille'),
          _ReportItem(key: 'vente_region', title: 'Vente par région'),
          _ReportItem(key: 'vente_projet', title: 'Vente par projet'),
          _ReportItem(key: 'tva_vente', title: 'TVA vente'),
          _ReportItem(key: 'retenue_client', title: 'Retenue clients'),
        ],
      ),
      _ReportCategory(
        title: 'Rapports d\'achat',
        icon: Icons.shopping_cart_outlined,
        items: [
          _ReportItem(key: 'achat_fournisseur', title: 'Achats par fournisseur'),
          _ReportItem(key: 'achat_article', title: 'Achats par article'),
          _ReportItem(key: 'achat_famille', title: 'Achats par famille'),
          _ReportItem(key: 'achat_region', title: 'Achats par région'),
          _ReportItem(key: 'immo_famille', title: 'Immobilisation par famille'),
          _ReportItem(key: 'achat_projet', title: 'Achat par projet'),
          _ReportItem(key: 'tva_achat', title: 'TVA achats'),
          _ReportItem(key: 'retenue_fournisseur', title: 'Retenue fournisseurs'),
        ],
      ),
      _ReportCategory(
        title: 'Rapports de paiement',
        icon: Icons.account_balance_wallet_outlined,
        items: [
          _ReportItem(key: 'paiement_recu', title: 'Paiements reçus'),
          _ReportItem(key: 'paiement_emis', title: 'Paiements émis'),
        ],
      ),

      // ─── Image 2 ──────────────────────────────────────────────────
      _ReportCategory(
        title: 'Stock',
        icon: Icons.inventory_2_outlined,
        items: [
          _ReportItem(key: 'stock_consommation_dep', title: 'Consommation par département'),
          _ReportItem(key: 'stock_consommation_famille', title: 'Consommation par famille'),
          _ReportItem(key: 'stock_rupture', title: 'Produits en rupture de stock'),
          _ReportItem(key: 'stock_surstockage', title: 'Produits en sur-stockage'),
        ],
      ),
      _ReportCategory(
        title: 'Rapports contacts',
        icon: Icons.people_outline_rounded,
        items: [
          _ReportItem(key: 'soldes_clients', title: 'Soldes clients'),
          _ReportItem(key: 'soldes_fournisseurs', title: 'Soldes fournisseurs'),
        ],
      ),
      _ReportCategory(
        title: 'Marge commerciale',
        icon: Icons.attach_money_rounded,
        items: [
          _ReportItem(key: 'marge_facture', title: 'Marge commerciale par facture'),
          _ReportItem(key: 'marge_bl', title: 'Marge commerciale par bon de livraison'),
          _ReportItem(key: 'marge_article', title: 'Marge commerciale par article'),
        ],
      ),
      _ReportCategory(
        title: 'Rapports bons de livraison',
        icon: Icons.local_shipping_outlined,
        items: [
          _ReportItem(key: 'bl_client', title: 'BL par client'),
          _ReportItem(key: 'bl_article', title: 'BL par article'),
          _ReportItem(key: 'bl_famille', title: 'BL par famille'),
          _ReportItem(key: 'bl_projet', title: 'BL par projet'),
        ],
      ),
      _ReportCategory(
        title: 'Rapports bons de réception',
        icon: Icons.all_inbox_rounded,
        items: [
          _ReportItem(key: 'br_fournisseur', title: 'BR par fournisseur'),
          _ReportItem(key: 'br_article', title: 'BR par article'),
          _ReportItem(key: 'br_famille', title: 'BR par famille'),
          _ReportItem(key: 'br_projet', title: 'BR par projet'),
        ],
      ),
    ];

    // Filter categories and items if search query is active
    final filteredCategories = categories.map((cat) {
      if (_searchQuery.isEmpty) return cat;

      final catMatch = cat.title.toLowerCase().contains(_searchQuery);
      final matchingItems = cat.items
          .where((item) => catMatch || item.title.toLowerCase().contains(_searchQuery))
          .toList();

      return _ReportCategory(
        title: cat.title,
        icon: cat.icon,
        isNew: cat.isNew,
        items: matchingItems,
      );
    }).where((cat) => cat.items.isNotEmpty).toList();

    if (filteredCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Aucun rapport ne correspond à "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1050
            ? 3
            : constraints.maxWidth > 700
                ? 2
                : 1;

        final itemWidth = (constraints.maxWidth - ((columns - 1) * 20)) / columns;

        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: filteredCategories.map((cat) {
            return SizedBox(
              width: itemWidth,
              child: _buildCategoryCard(cat),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCategoryCard(_ReportCategory category) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Blue Square Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Icon(
                      category.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (category.isNew) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Nouveau',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Items List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: category.items.length,
            itemBuilder: (context, index) {
              final item = category.items[index];
              return _buildReportItemRow(item);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReportItemRow(_ReportItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedReportKey = item.key;
            _tableSearchQuery = '';
            _tableSearchController.clear();
          });
        },
        hoverColor: const Color(0xFFF1F5F9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              const Text(
                '›',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // INTERACTIVE DRILL-DOWN REPORT DETAIL VIEW
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildReportDetailView() {
    final detail = ReportsDataService.instance.computeReport(_selectedReportKey!, _dashboardData);

    // Filter table rows if detail search is active
    final filteredRows = detail.rows.where((row) {
      if (_tableSearchQuery.isEmpty) return true;
      return row.any((cell) => cell.toLowerCase().contains(_tableSearchQuery));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Breadcrumb & Actions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedReportKey = null),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Retour aux rapports'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportDetailCsv(detail),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exporter CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Specific KPIs
        if (detail.kpis.isNotEmpty) ...[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: detail.kpis.map((kpi) {
              return Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kpi.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(kpi.icon, color: kpi.color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kpi.title,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            kpi.value,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (kpi.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              kpi.subtitle!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Chart Visualisation
        if (detail.chartPoints.isNotEmpty) ...[
          _buildDetailChart(detail),
          const SizedBox(height: 20),
        ],

        // Detail Table Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table Header & Search
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Données détaillées (${filteredRows.length} lignes)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: TextField(
                        controller: _tableSearchController,
                        onChanged: (val) => setState(() => _tableSearchQuery = val.trim().toLowerCase()),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Filtrer dans ce tableau...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

              // Data Table or Empty
              if (filteredRows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune donnée enregistrée pour cette période ($_selectedPeriod).',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        fontSize: 13,
                      ),
                      dataTextStyle: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 13,
                      ),
                      columns: detail.headers
                          .map((h) => DataColumn(label: Text(h)))
                          .toList(),
                      rows: filteredRows.map((row) {
                        return DataRow(
                          cells: row.map((c) => DataCell(Text(c))).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChart(ReportDetailData detail) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Text(
                'Visualisation graphique',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < detail.chartPoints.length) {
                          final label = detail.chartPoints[idx].label;
                          final truncated = label.length > 12 ? '${label.substring(0, 10)}..' : label;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              truncated,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barGroups: detail.chartPoints.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final point = entry.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: point.value,
                        color: const Color(0xFF2563EB),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// DATA MODELS FOR CATEGORIES & CARDS
// ────────────────────────────────────────────────────────────────────────

class _SmartKpi {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String badgeText;
  final Color badgeColor;
  final Color accentColor;

  const _SmartKpi({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    required this.badgeColor,
    required this.accentColor,
  });
}

class _ReportCategory {
  final String title;
  final IconData icon;
  final bool isNew;
  final List<_ReportItem> items;

  const _ReportCategory({
    required this.title,
    required this.icon,
    this.isNew = false,
    required this.items,
  });
}

class _ReportItem {
  final String key;
  final String title;

  const _ReportItem({
    required this.key,
    required this.title,
  });
}
