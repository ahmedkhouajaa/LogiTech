import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/promo_code_model.dart';
import '../services/promo_code_service.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedTypeFilter = 'all';
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPromoCodesTab(),
                _buildUsagesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.local_offer_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Codes Promotionnels & Offres',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Créez des remises, cadeaux ou jours gratuits et suivez l\'utilisation des clients en temps réel.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _showCreatePromoDialog(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Créer un code promo', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF2563EB),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicatorColor: const Color(0xFF2563EB),
        indicatorWeight: 3,
        tabs: const [
          Tab(
            child: Row(
              children: [
                Icon(Icons.discount_outlined, size: 17),
                SizedBox(width: 8),
                Text('Tous les Codes Promo'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 17),
                SizedBox(width: 8),
                Text('Historique des Utilisations & Bénéficiaires'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: CODES PROMO ─────────────────────────────────────────────
  Widget _buildPromoCodesTab() {
    return StreamBuilder<List<PromoCode>>(
      stream: PromoCodeService.instance.streamPromoCodes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCodes = snapshot.data ?? [];
        final query = _searchController.text.trim().toLowerCase();

        final filteredCodes = allCodes.where((promo) {
          if (query.isNotEmpty) {
            final matchCode = promo.code.toLowerCase().contains(query);
            final matchDesc = promo.description.toLowerCase().contains(query);
            if (!matchCode && !matchDesc) return false;
          }

          if (_selectedTypeFilter != 'all') {
            if (promo.discountType.id != _selectedTypeFilter) return false;
          }

          if (_selectedStatusFilter == 'active' && !promo.isActive) return false;
          if (_selectedStatusFilter == 'inactive' && promo.isActive) return false;
          if (_selectedStatusFilter == 'expired' && !promo.isExpired) return false;

          return true;
        }).toList();

        // Compute KPIs
        final totalCodes = allCodes.length;
        final activeCodes = allCodes.where((c) => c.isUsable).length;
        final totalUsages = allCodes.fold<int>(0, (sum, c) => sum + c.usedCount);
        final giftCodes = allCodes.where((c) => c.discountType == PromoDiscountType.gift || c.discountType == PromoDiscountType.freeDays).length;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // KPI Stat Cards
            _buildKpiSection(
              totalCodes: totalCodes,
              activeCodes: activeCodes,
              totalUsages: totalUsages,
              giftCodes: giftCodes,
            ),
            const SizedBox(height: 20),

            // Search & Filter Bar
            _buildFilterBar(),
            const SizedBox(height: 16),

            // Promo Codes List
            if (filteredCodes.isEmpty)
              _buildEmptyState()
            else
              ...filteredCodes.map((promo) => _buildPromoCard(promo)),
          ],
        );
      },
    );
  }

  // ─── KPI Section ───────────────────────────────────────────────────
  Widget _buildKpiSection({
    required int totalCodes,
    required int activeCodes,
    required int totalUsages,
    required int giftCodes,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final cards = [
          _kpiCard(
            title: 'Total Codes Promo',
            value: '$totalCodes',
            subtitle: '$activeCodes actifs actuellement',
            icon: Icons.confirmation_number_outlined,
            color: const Color(0xFF2563EB),
          ),
          _kpiCard(
            title: 'Total Utilisations',
            value: '$totalUsages',
            subtitle: 'Clients ayant profité d\'une offre',
            icon: Icons.how_to_reg_rounded,
            color: const Color(0xFF10B981),
          ),
          _kpiCard(
            title: 'Codes Actifs',
            value: '$activeCodes',
            subtitle: 'Disponibles pour inscription',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          _kpiCard(
            title: 'Offres & Cadeaux Spéciaux',
            value: '$giftCodes',
            subtitle: 'Modules ou jours offerts',
            icon: Icons.card_giftcard_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ];

        if (isMobile) {
          return Column(
            children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
          );
        }

        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter Bar ────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Input
          SizedBox(
            width: 280,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher par code ou description...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => setState(() => _searchController.clear()),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
              ),
            ),
          ),

          // Type Filter
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTypeFilter,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tous les types d\'offre')),
                  DropdownMenuItem(value: 'percentage', child: Text('Pourcentage (%)')),
                  DropdownMenuItem(value: 'fixed_amount', child: Text('Montant fixe (DT)')),
                  DropdownMenuItem(value: 'gift', child: Text('Cadeaux & Modules')),
                  DropdownMenuItem(value: 'free_days', child: Text('Jours offerts')),
                ],
                onChanged: (v) => setState(() => _selectedTypeFilter = v ?? 'all'),
              ),
            ),
          ),

          // Status Filter
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatusFilter,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tous les statuts')),
                  DropdownMenuItem(value: 'active', child: Text('Actifs')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactifs')),
                  DropdownMenuItem(value: 'expired', child: Text('Expirés')),
                ],
                onChanged: (v) => setState(() => _selectedStatusFilter = v ?? 'all'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Promo Card ────────────────────────────────────────────────────
  Widget _buildPromoCard(PromoCode promo) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    Color badgeColor;
    IconData badgeIcon;
    switch (promo.discountType) {
      case PromoDiscountType.percentage:
        badgeColor = const Color(0xFF2563EB);
        badgeIcon = Icons.percent_rounded;
        break;
      case PromoDiscountType.fixedAmount:
        badgeColor = const Color(0xFF059669);
        badgeIcon = Icons.payments_rounded;
        break;
      case PromoDiscountType.gift:
        badgeColor = const Color(0xFF7C3AED);
        badgeIcon = Icons.card_giftcard_rounded;
        break;
      case PromoDiscountType.freeDays:
        badgeColor = const Color(0xFFD97706);
        badgeIcon = Icons.hourglass_top_rounded;
        break;
    }

    final usageRatio = promo.maxUses != null ? (promo.usedCount / promo.maxUses!).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: promo.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Code Tag Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_offer_rounded, color: Color(0xFF38BDF8), size: 15),
                      const SizedBox(width: 8),
                      Text(
                        promo.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: promo.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Code "${promo.code}" copié !'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Benefit Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        promo.benefitSummary,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Expiration / Status Tag
                if (promo.isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Expiré', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else if (promo.isLimitReached)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Plafond atteint', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: promo.isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      promo.isActive ? 'Actif' : 'Désactivé',
                      style: TextStyle(
                        color: promo.isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                const Spacer(),

                // Active toggle switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      promo.isActive ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: promo.isActive ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: promo.isActive,
                      activeTrackColor: const Color(0xFF10B981),
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        PromoCodeService.instance.togglePromoStatus(promo.code, val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description & Details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (promo.description.isNotEmpty)
                        Text(
                          promo.description,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _metaItem(Icons.calendar_today_rounded, 'Créé le ${dateFormat.format(promo.createdAt)}'),
                          if (promo.expiresAt != null)
                            _metaItem(Icons.event_busy_rounded, 'Expire le ${dateFormat.format(promo.expiresAt!)}')
                          else
                            _metaItem(Icons.all_inclusive_rounded, 'Sans expiration'),
                          _metaItem(Icons.person_outline_rounded, 'Par ${promo.createdBy}'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Usage Progress Indicator
                Container(
                  width: 170,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Utilisations', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          Text(
                            promo.maxUses != null ? '${promo.usedCount} / ${promo.maxUses}' : '${promo.usedCount} (illimité)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: promo.maxUses != null ? usageRatio : (promo.usedCount > 0 ? 1.0 : 0.0),
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            promo.isLimitReached ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Card Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Button to view users who used this code
                TextButton.icon(
                  onPressed: () => _showBeneficiariesDialog(context, promo),
                  icon: const Icon(Icons.people_outline_rounded, size: 16),
                  label: Text(
                    'Voir les bénéficiaires (${promo.usedCount})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),

                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                      tooltip: 'Modifier',
                      onPressed: () => _showEditPromoDialog(context, promo),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      tooltip: 'Supprimer',
                      onPressed: () => _confirmDeletePromo(context, promo),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_offer_outlined, size: 40, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun code promo trouvé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Créez votre premier code promotionnel pour offrir des remises à vos clients.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _showCreatePromoDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer un code promo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: USAGES / BÉNÉFICIAIRES ─────────────────────────────────
  Widget _buildUsagesTab() {
    return StreamBuilder<List<PromoCodeUsage>>(
      stream: PromoCodeService.instance.streamAllUsages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final usages = snapshot.data ?? [];
        if (usages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.history_rounded, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text('Aucune utilisation enregistrée pour l\'instant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                SizedBox(height: 4),
                Text('Dès qu\'un utilisateur utilise un code promo, il apparaîtra ici.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          );
        }

        final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: usages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final usage = usages[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    child: Text(
                      usage.userName.isNotEmpty ? usage.userName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              usage.userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                usage.enterpriseName,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Email : ${usage.userEmail} • ID Client : ${usage.userId}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),

                  // Promo Code Tag & Benefit
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              usage.code,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              usage.benefitSummary,
                              style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Utilisé le ${dateFormat.format(usage.usedAt)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── DIALOG: CREATE PROMO CODE ───────────────────────────────────────
  void _showCreatePromoDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '20');
    final giftCtrl = TextEditingController(text: '1 mois d\'abonnement offert');
    final maxUsesCtrl = TextEditingController();

    PromoDiscountType selectedType = PromoDiscountType.percentage;
    bool hasMaxUses = false;
    bool hasExpiration = false;
    DateTime expirationDate = DateTime.now().add(const Duration(days: 90));
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 10),
                Text('Nouveau Code Promotionnel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code field
                    const Text('Code Promo *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Ex: WELCOME20, VIPGIFT, SUMMER2026',
                        prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    const Text('Description / Campagne', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ex: Offre de bienvenue pour les nouveaux créateurs d\'entreprise',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Discount Type
                    const Text('Type d\'Avantage *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<PromoDiscountType>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: PromoDiscountType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            selectedType = v;
                            if (selectedType == PromoDiscountType.percentage) {
                              valueCtrl.text = '20';
                            } else if (selectedType == PromoDiscountType.fixedAmount) {
                              valueCtrl.text = '50';
                            } else if (selectedType == PromoDiscountType.freeDays) {
                              valueCtrl.text = '30';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Dynamic Value field depending on type
                    if (selectedType == PromoDiscountType.percentage) ...[
                      const Text('Pourcentage de remise (%) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: valueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Ex: 20',
                          suffixText: '%',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ] else if (selectedType == PromoDiscountType.fixedAmount) ...[
                      const Text('Montant de réduction (DT) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: valueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Ex: 50',
                          suffixText: 'DT',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ] else if (selectedType == PromoDiscountType.freeDays) ...[
                      const Text('Nombre de jours offerts *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: valueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Ex: 30',
                          suffixText: 'jours',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ] else ...[
                      const Text('Description du cadeau offert *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: giftCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ex: 1 mois d\'abonnement offert, Pack VIP Support, etc.',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Limits and Expiration checkboxes
                    Row(
                      children: [
                        Checkbox(
                          value: hasMaxUses,
                          onChanged: (v) => setDialogState(() => hasMaxUses = v ?? false),
                        ),
                        const Text('Limiter le nombre d\'utilisations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (hasMaxUses) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 10),
                        child: TextField(
                          controller: maxUsesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Ex: 100 utilisations max',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],

                    Row(
                      children: [
                        Checkbox(
                          value: hasExpiration,
                          onChanged: (v) => setDialogState(() => hasExpiration = v ?? false),
                        ),
                        const Text('Définir une date d\'expiration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (hasExpiration) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 10),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expirationDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) {
                              setDialogState(() => expirationDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text('Expire le : ${DateFormat('dd/MM/yyyy').format(expirationDate)}'),
                        ),
                      ),
                    ],

                    // Active Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activer immédiatement ce code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Les clients pourront l\'utiliser dès maintenant.', style: TextStyle(fontSize: 11)),
                      value: isActive,
                      activeTrackColor: const Color(0xFF10B981),
                      activeThumbColor: Colors.white,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final code = codeCtrl.text.trim().toUpperCase();
                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez entrer un code promo.')),
                    );
                    return;
                  }

                  final double val = double.tryParse(valueCtrl.text.trim()) ?? 0.0;
                  final int? maxU = hasMaxUses ? int.tryParse(maxUsesCtrl.text.trim()) : null;

                  final promo = PromoCode(
                    id: code,
                    code: code,
                    description: descCtrl.text.trim(),
                    discountType: selectedType,
                    discountValue: val,
                    giftDetails: giftCtrl.text.trim(),
                    isActive: isActive,
                    maxUses: maxU,
                    expiresAt: hasExpiration ? expirationDate : null,
                    createdAt: DateTime.now(),
                  );

                  try {
                    await PromoCodeService.instance.createPromoCode(promo);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Code promo "$code" créé avec succès !'), backgroundColor: const Color(0xFF10B981)),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFDC2626)),
                      );
                    }
                  }
                },
                child: const Text('Créer le code'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── DIALOG: EDIT PROMO CODE ─────────────────────────────────────────
  void _showEditPromoDialog(BuildContext context, PromoCode promo) {
    final descCtrl = TextEditingController(text: promo.description);
    final giftCtrl = TextEditingController(text: promo.giftDetails);
    final maxUsesCtrl = TextEditingController(text: promo.maxUses?.toString() ?? '');
    bool hasMaxUses = promo.maxUses != null;
    bool hasExpiration = promo.expiresAt != null;
    DateTime expirationDate = promo.expiresAt ?? DateTime.now().add(const Duration(days: 30));
    bool isActive = promo.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Modifier le code "${promo.code}"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (promo.discountType == PromoDiscountType.gift) ...[
                      const Text('Détails du cadeau', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: giftCtrl,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Row(
                      children: [
                        Checkbox(
                          value: hasMaxUses,
                          onChanged: (v) => setDialogState(() => hasMaxUses = v ?? false),
                        ),
                        const Text('Limiter le nombre d\'utilisations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (hasMaxUses) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 10),
                        child: TextField(
                          controller: maxUsesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Ex: 100',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],

                    Row(
                      children: [
                        Checkbox(
                          value: hasExpiration,
                          onChanged: (v) => setDialogState(() => hasExpiration = v ?? false),
                        ),
                        const Text('Date d\'expiration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (hasExpiration) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 10),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expirationDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) {
                              setDialogState(() => expirationDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text('Expire le : ${DateFormat('dd/MM/yyyy').format(expirationDate)}'),
                        ),
                      ),
                    ],

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Code Actif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: isActive,
                      activeTrackColor: const Color(0xFF10B981),
                      activeThumbColor: Colors.white,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                onPressed: () async {
                  final updated = promo.copyWith(
                    description: descCtrl.text.trim(),
                    giftDetails: giftCtrl.text.trim(),
                    maxUses: hasMaxUses ? int.tryParse(maxUsesCtrl.text.trim()) : null,
                    expiresAt: hasExpiration ? expirationDate : null,
                    isActive: isActive,
                  );
                  await PromoCodeService.instance.updatePromoCode(updated);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Code "${promo.code}" mis à jour !'), backgroundColor: const Color(0xFF10B981)),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── DIALOG: BENEFICIARIES ───────────────────────────────────────────
  void _showBeneficiariesDialog(BuildContext context, PromoCode promo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 10),
            Text('Bénéficiaires du code "${promo.code}"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 550,
          height: 400,
          child: promo.recentUsages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      Text('Aucun utilisateur n\'a encore utilisé ce code.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: promo.recentUsages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = promo.recentUsages[index];
                    final dateStr = item['usedAt']?.toString() ?? '';
                    final date = DateTime.tryParse(dateStr);
                    final formattedDate = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : dateStr;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      title: Text(
                        item['userName'] ?? 'Client',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${item['enterpriseName'] ?? 'Entreprise'} • ${item['userEmail'] ?? ''}\nUtilisé le : $formattedDate',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['benefitSummary'] ?? promo.benefitSummary,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  // ─── CONFIRM DELETE ──────────────────────────────────────────────────
  void _confirmDeletePromo(BuildContext context, PromoCode promo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le code promo ?'),
        content: Text('Voulez-vous vraiment supprimer définitivement le code "${promo.code}" ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await PromoCodeService.instance.deletePromoCode(promo.code);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Code "${promo.code}" supprimé.'), backgroundColor: const Color(0xFFDC2626)),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
