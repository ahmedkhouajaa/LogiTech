import 'package:flutter/material.dart';
import '../../models/affiliate_model.dart';
import '../../services/affiliate_service.dart';

class AffiliateManagementScreen extends StatefulWidget {
  const AffiliateManagementScreen({super.key});

  @override
  State<AffiliateManagementScreen> createState() => _AffiliateManagementScreenState();
}

class _AffiliateManagementScreenState extends State<AffiliateManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AffiliateService _service = AffiliateService.instance;
  String _searchQuery = '';
  PayoutStatus? _selectedPayoutFilter;

  // Controllers pour la configuration
  late TextEditingController _rewardAmountCtrl;
  late TextEditingController _minPayoutCtrl;
  late TextEditingController _referredBenefitCtrl;
  late TextEditingController _referredDiscountCtrl;
  late TextEditingController _referredFreeDaysCtrl;
  bool _isAffiliateProgramEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _rewardAmountCtrl = TextEditingController(text: '20');
    _minPayoutCtrl = TextEditingController(text: '50');
    _referredBenefitCtrl = TextEditingController(text: '10% de remise immédiate sur votre abonnement');
    _referredDiscountCtrl = TextEditingController(text: '10');
    _referredFreeDaysCtrl = TextEditingController(text: '14');

    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _service.getConfig();
    if (mounted) {
      setState(() {
        _isAffiliateProgramEnabled = config.isEnabled;
        _rewardAmountCtrl.text = config.fixedRewardAmount.toStringAsFixed(0);
        _minPayoutCtrl.text = config.minPayoutAmount.toStringAsFixed(0);
        _referredBenefitCtrl.text = config.referredUserBenefit;
        _referredDiscountCtrl.text = config.referredUserDiscount.toStringAsFixed(0);
        _referredFreeDaysCtrl.text = config.referredUserFreeDays.toString();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rewardAmountCtrl.dispose();
    _minPayoutCtrl.dispose();
    _referredBenefitCtrl.dispose();
    _referredDiscountCtrl.dispose();
    _referredFreeDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildStatsCards(),
            const SizedBox(height: 20),
            _buildTabsNav(),
            const SizedBox(height: 14),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPayoutRequestsTab(),
                  _buildAffiliatesListTab(),
                  _buildReferralHistoryTab(),
                  _buildProgramConfigTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HEADER
  // ==========================================
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.handshake_rounded, color: Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Programme d\'Affiliation & Parrainage',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Supervisez les ambassadeurs, traitez les demandes de retraits cash et configurez les récompenses.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // STATS KPIS
  // ==========================================
  Widget _buildStatsCards() {
    return StreamBuilder<List<AffiliateProfile>>(
      stream: _service.streamAllAffiliates(),
      builder: (context, affiliateSnap) {
        final affiliates = affiliateSnap.data ?? [];
        final totalAffiliates = affiliates.length;
        int totalReferrals = 0;
        double totalCommissionsEarned = 0;

        for (final aff in affiliates) {
          totalReferrals += aff.totalReferrals;
          totalCommissionsEarned += aff.totalEarned;
        }

        return StreamBuilder<List<AffiliatePayoutRequest>>(
          stream: _service.streamAllPayoutRequests(),
          builder: (context, payoutSnap) {
            final payouts = payoutSnap.data ?? [];
            final pendingPayouts = payouts.where((p) => p.status == PayoutStatus.pending).length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 36) / 4;

                return Row(
                  children: [
                    _buildKpiCard('Total Ambassadeurs', '$totalAffiliates', Icons.groups_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), cardWidth),
                    const SizedBox(width: 12),
                    _buildKpiCard('Filleuls Inscrits', '$totalReferrals', Icons.link_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), cardWidth),
                    const SizedBox(width: 12),
                    _buildKpiCard('Commissions Distribuées', '${totalCommissionsEarned.toStringAsFixed(0)} DT', Icons.monetization_on_rounded, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF), cardWidth),
                    const SizedBox(width: 12),
                    _buildKpiCard('Retraits en Attente', '$pendingPayouts', Icons.hourglass_top_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), cardWidth),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, Color bgColor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TABS NAVIGATION
  // ==========================================
  Widget _buildTabsNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF2563EB),
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: const Color(0xFF2563EB),
        indicatorWeight: 3,
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.payment_rounded, size: 17),
                SizedBox(width: 6),
                Text('Demandes de Retrait (Payouts)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.leaderboard_rounded, size: 17),
                SizedBox(width: 6),
                Text('Liste des Affiliés & Performance', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 17),
                SizedBox(width: 6),
                Text('Historique des Parrainages', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_suggest_rounded, size: 17),
                SizedBox(width: 6),
                Text('Configuration du Programme', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: DEMANDES DE RETRAIT
  // ==========================================
  Widget _buildPayoutRequestsTab() {
    return StreamBuilder<List<AffiliatePayoutRequest>>(
      stream: _service.streamAllPayoutRequests(statusFilter: _selectedPayoutFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        return Column(
          children: [
            // Filtre par statut
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Text('Filtrer par statut : ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  const SizedBox(width: 8),
                  _filterChip('Tous', null),
                  const SizedBox(width: 6),
                  _filterChip('En attente', PayoutStatus.pending),
                  const SizedBox(width: 6),
                  _filterChip('Payés', PayoutStatus.paid),
                  const SizedBox(width: 6),
                  _filterChip('Rejetés', PayoutStatus.rejected),
                ],
              ),
            ),
            Expanded(
              child: requests.isEmpty
                  ? Center(
                      child: Text(
                        _selectedPayoutFilter == null
                            ? 'Aucune demande de retrait reçue pour le moment.'
                            : 'Aucune demande avec ce statut.',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final dateStr = '${req.requestedAt.day.toString().padLeft(2, '0')}/${req.requestedAt.month.toString().padLeft(2, '0')}/${req.requestedAt.year}';
                        final detailStr = req.payoutDetails['accountOrPhone'] ?? req.payoutDetails['recipient'] ?? '';

                        Color statusColor;
                        switch (req.status) {
                          case PayoutStatus.paid:
                            statusColor = const Color(0xFF10B981);
                            break;
                          case PayoutStatus.rejected:
                            statusColor = const Color(0xFFEF4444);
                            break;
                          case PayoutStatus.approved:
                            statusColor = const Color(0xFF3B82F6);
                            break;
                          case PayoutStatus.pending:
                            statusColor = const Color(0xFFF59E0B);
                            break;
                        }

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: statusColor.withValues(alpha: 0.1),
                                child: Icon(Icons.account_balance_rounded, color: statusColor, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(req.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(req.userEmail, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${req.amount.toStringAsFixed(3)} DT',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                    ),
                                    Text('Méthode : ${req.payoutMethod.toUpperCase()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Détails : $detailStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    Text('Demandé le : $dateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  req.status.label,
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (req.status == PayoutStatus.pending) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.check_rounded, size: 16),
                                  label: const Text('Valider & Payer', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showApprovePayoutDialog(req),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  label: const Text('Rejeter', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showRejectPayoutDialog(req),
                                ),
                              ] else if (req.transactionReference != null) ...[
                                Tooltip(
                                  message: 'Réf: ${req.transactionReference}',
                                  child: const Icon(Icons.receipt_rounded, color: Color(0xFF64748B), size: 20),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, PayoutStatus? status) {
    final isSelected = _selectedPayoutFilter == status;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF475569))),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      onSelected: (_) => setState(() => _selectedPayoutFilter = status),
    );
  }

  // ==========================================
  // TAB 2: LISTE DES AFFILIÉS & PERFORMANCE
  // ==========================================
  Widget _buildAffiliatesListTab() {
    return StreamBuilder<List<AffiliateProfile>>(
      stream: _service.streamAllAffiliates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var list = snapshot.data ?? [];
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          list = list.where((a) {
            return a.userName.toLowerCase().contains(q) ||
                a.userEmail.toLowerCase().contains(q) ||
                a.affiliateCode.toLowerCase().contains(q);
          }).toList();
        }

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom, email ou code affilié (ex: LOGI-...)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Aucun affilié trouvé.', style: TextStyle(color: Color(0xFF94A3B8))))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final aff = list[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                child: Text(
                                  aff.userName.isNotEmpty ? aff.userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(aff.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(aff.userEmail, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    const Icon(Icons.qr_code_rounded, color: Color(0xFF64748B), size: 16),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        aff.affiliateCode,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${aff.totalReferrals} Filleuls', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Text('Entreprises actives', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${aff.balanceCash.toStringAsFixed(3)} DT',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14),
                                    ),
                                    const Text('Solde retirable', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${aff.totalEarned.toStringAsFixed(3)} DT',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6), fontSize: 14),
                                    ),
                                    const Text('Gains cumulés', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TAB 3: HISTORIQUE DE TOUS LES PARRAINAGES
  // ==========================================
  Widget _buildReferralHistoryTab() {
    return StreamBuilder<List<AffiliateReferral>>(
      stream: _service.streamAllReferrals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final referrals = snapshot.data ?? [];
        if (referrals.isEmpty) {
          return const Center(child: Text('Aucun événement de parrainage pour le moment.', style: TextStyle(color: Color(0xFF94A3B8))));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: referrals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = referrals[index];
            final dateStr = '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year}';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.how_to_reg_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Filleul : ${item.referredEnterpriseName.isNotEmpty ? item.referredEnterpriseName : item.referredUserName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(item.referredUserEmail, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        const Text('Code : ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        Text(item.referrerCode, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Avantage : ${item.benefitAwarded}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        Text('Date : $dateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+${item.commissionAmount.toStringAsFixed(0)} DT',
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 4: CONFIGURATION DU PROGRAMME
  // ==========================================
  Widget _buildProgramConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Règles & Barème d\'Affiliation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Définissez les récompenses attribuées aux parrains et les remises offertes aux nouveaux clients.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                Switch(
                  value: _isAffiliateProgramEnabled,
                  onChanged: (val) => setState(() => _isAffiliateProgramEnabled = val),
                  activeThumbColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rewardAmountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Gain Fixe par Filleul (DT)',
                      helperText: 'Crédité au parrain dès que le filleul crée son entreprise',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _minPayoutCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Seuil Minimum de Retrait (DT)',
                      helperText: 'Montant minimal requis pour demander un virement bancaire',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _referredDiscountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Remise Offerte au Filleul (%)',
                      helperText: 'Pourcentage déduit de sa facture d\'abonnement',
                      prefixIcon: Icon(Icons.percent_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _referredFreeDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jours d\'Essai Supplémentaires Offerts',
                      helperText: 'Ex: 14 jours gratuits ajoutés à la période d\'essai',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _referredBenefitCtrl,
              decoration: const InputDecoration(
                labelText: 'Description affichée au filleul lors de la saisie du code',
                prefixIcon: Icon(Icons.label_important_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Enregistrer la Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final reward = double.tryParse(_rewardAmountCtrl.text.trim()) ?? 20.0;
                  final minPayout = double.tryParse(_minPayoutCtrl.text.trim()) ?? 50.0;
                  final discount = double.tryParse(_referredDiscountCtrl.text.trim()) ?? 10.0;
                  final freeDays = int.tryParse(_referredFreeDaysCtrl.text.trim()) ?? 14;

                  final newConfig = AffiliateConfig(
                    isEnabled: _isAffiliateProgramEnabled,
                    fixedRewardAmount: reward,
                    minPayoutAmount: minPayout,
                    referredUserDiscount: discount,
                    referredUserFreeDays: freeDays,
                    referredUserBenefit: _referredBenefitCtrl.text.trim(),
                  );

                  final messenger = ScaffoldMessenger.of(context);
                  await _service.updateConfig(newConfig);

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Configuration du programme d\'affiliation mise à jour avec succès !'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOGS SUPERADMIN (APPROUVER / REJETER RETRAIT)
  // ==========================================
  void _showApprovePayoutDialog(AffiliatePayoutRequest req) {
    final refController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Text('Valider le Retrait (${req.amount.toStringAsFixed(3)} DT)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bénéficiaire : ${req.userName} (${req.userEmail})'),
            Text('Mode : ${req.payoutMethod.toUpperCase()} • ${req.payoutDetails['accountOrPhone']}'),
            const SizedBox(height: 16),
            TextField(
              controller: refController,
              decoration: const InputDecoration(
                labelText: 'Référence du Virement / N° Transaction',
                prefixIcon: Icon(Icons.receipt_long_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes internes (optionnel)',
                prefixIcon: Icon(Icons.note_alt_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.processPayoutRequest(
                req.id,
                status: PayoutStatus.paid,
                transactionRef: refController.text.trim(),
                adminNotes: notesController.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retrait marqué comme payé !'), backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            child: const Text('Confirmer le Paiement'),
          ),
        ],
      ),
    );
  }

  void _showRejectPayoutDialog(AffiliatePayoutRequest req) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('Rejeter la Demande de Retrait'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attention : Le montant de ${req.amount.toStringAsFixed(3)} DT sera immédiatement recrédité sur le solde de l\'affilié.'),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif du rejet (RIB invalide, etc.)',
                prefixIcon: Icon(Icons.comment_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.processPayoutRequest(
                req.id,
                status: PayoutStatus.rejected,
                adminNotes: reasonController.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demande rejetée et solde recrédité.'), backgroundColor: Color(0xFFEF4444)),
                );
              }
            },
            child: const Text('Confirmer le Rejet'),
          ),
        ],
      ),
    );
  }
}
