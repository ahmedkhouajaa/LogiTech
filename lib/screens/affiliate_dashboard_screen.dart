import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/affiliate_model.dart';
import '../services/affiliate_service.dart';
import '../utils/constants.dart';

class AffiliateDashboardScreen extends StatefulWidget {
  const AffiliateDashboardScreen({super.key});

  @override
  State<AffiliateDashboardScreen> createState() => _AffiliateDashboardScreenState();
}

class _AffiliateDashboardScreenState extends State<AffiliateDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AffiliateService _service = AffiliateService.instance;
  bool _isLoading = true;
  AffiliateProfile? _profile;
  AffiliateConfig _config = const AffiliateConfig();
  Color get _brandBlue => AppColors.primary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final config = await _service.getConfig();
      final profile = await _service.getOrCreateAffiliateProfile(
        user.uid,
        userName: user.displayName ?? (user.email != null ? user.email!.split('@').first : 'Partenaire'),
        userEmail: user.email ?? '',
      );
      if (mounted) {
        setState(() {
          _config = config;
          _profile = profile;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading || user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<AffiliateProfile?>(
      stream: _service.streamAffiliateProfile(user.uid),
      initialData: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? _profile;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroBanner(profile, isDark),
                const SizedBox(height: 20),
                _buildStatsGrid(profile, isDark),
                const SizedBox(height: 24),
                _buildActionButtons(profile, isDark),
                const SizedBox(height: 24),
                _buildTabsSection(profile, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // HERO BANNER & CODE DE PARRAINAGE
  // ==========================================
  Widget _buildHeroBanner(AffiliateProfile profile, bool isDark) {
    final referralLink = 'https://app.logitech.tn/#/signup?ref=${profile.affiliateCode}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? _brandBlue.withValues(alpha: 0.15)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.handshake_rounded,
                  color: isDark ? const Color(0xFF60A5FA) : _brandBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Programme Partenaire & Affiliation LogiTech',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gagnez ${_config.fixedRewardAmount.toStringAsFixed(0)} DT pour chaque entreprise parrainée, et offrez ${_config.referredUserBenefit} !',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Code Partenaire avec bouton copier
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Votre Code Promo Partenaire : ',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            profile.affiliateCode,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            size: 18,
                          ),
                          tooltip: 'Copier le code',
                          splashRadius: 16,
                          onPressed: () => _copyToClipboard(profile.affiliateCode, 'Code promo copié !'),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bouton Partager le lien
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text(
                    'Copier mon lien d\'invitation',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () => _copyToClipboard(
                    referralLink,
                    'Lien d\'invitation copié dans le presse-papier !',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // GRILLE DES STATISTIQUES (KPIs)
  // ==========================================
  Widget _buildStatsGrid(AffiliateProfile profile, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              title: 'Filleuls Parrainés',
              value: '${profile.totalReferrals}',
              subText: 'Comptes actifs créés',
              icon: Icons.people_alt_rounded,
              iconColor: _brandBlue,
              iconBgColor: isDark ? _brandBlue.withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
              width: cardWidth,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Solde Cash Retirable',
              value: '${profile.balanceCash.toStringAsFixed(3)} DT',
              subText: 'Disponible pour virement',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFFECFDF5),
              width: cardWidth,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Crédit d\'Abonnement',
              value: '${profile.balanceDiscount.toStringAsFixed(3)} DT',
              subText: 'Déductible de vos factures',
              icon: Icons.discount_rounded,
              iconColor: const Color(0xFF8B5CF6),
              iconBgColor: const Color(0xFFF5F3FF),
              width: cardWidth,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Gains Totaux Cumulés',
              value: '${profile.totalEarned.toStringAsFixed(3)} DT',
              subText: 'Depuis le lancement',
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBgColor: const Color(0xFFFFFBEB),
              width: cardWidth,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subText,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required double width,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.2) : iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ACTION BAR (DEMANDE DE RETRAIT / CONVERSION)
  // ==========================================
  Widget _buildActionButtons(AffiliateProfile profile, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 550;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('Demander un Retrait Cash', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showPayoutRequestDialog(profile),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brandBlue,
                  side: BorderSide(color: _brandBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Convertir en Remise Abonnement', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showConvertDialog(profile),
              ),
            ],
          );
        }

        return Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('Demander un Retrait Cash', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showPayoutRequestDialog(profile),
            ),
            const SizedBox(width: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _brandBlue,
                side: BorderSide(color: _brandBlue),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Convertir en Remise Abonnement', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showConvertDialog(profile),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TABS SECTION (FILLEULS & HISTORIQUE DES RETRAITS)
  // ==========================================
  Widget _buildTabsSection(AffiliateProfile profile, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _brandBlue,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            indicatorColor: _brandBlue,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Mes Filleuls (Entreprises)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Historique des Retraits', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 420,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReferralsTab(profile, isDark),
                _buildPayoutsTab(profile, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralsTab(AffiliateProfile profile, bool isDark) {
    return StreamBuilder<List<AffiliateReferral>>(
      stream: _service.streamUserReferrals(profile.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final referrals = snapshot.data ?? [];
        if (referrals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_add_rounded, size: 48, color: isDark ? Colors.white24 : const Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun filleul pour l\'instant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Partagez votre code promo ${profile.affiliateCode} à vos partenaires ou confrères pour commencer à générer des gains !',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: referrals.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
          ),
          itemBuilder: (context, index) {
            final item = referrals[index];
            final dateStr = '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')}/${item.createdAt.year}';

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: _brandBlue.withValues(alpha: 0.1),
                child: Icon(Icons.business_rounded, color: _brandBlue, size: 20),
              ),
              title: Text(
                item.referredEnterpriseName.isNotEmpty ? item.referredEnterpriseName : item.referredUserName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                'Inscrit le $dateStr • ${item.benefitAwarded}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+${item.commissionAmount.toStringAsFixed(0)} DT',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPayoutsTab(AffiliateProfile profile, bool isDark) {
    return StreamBuilder<List<AffiliatePayoutRequest>>(
      stream: _service.streamUserPayoutRequests(profile.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final payouts = snapshot.data ?? [];
        if (payouts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 48, color: isDark ? Colors.white24 : const Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune demande de retrait',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vos demandes de virement ou retraits apparaîtront ici avec leur suivi en temps réel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: payouts.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
          ),
          itemBuilder: (context, index) {
            final item = payouts[index];
            final dateStr = '${item.requestedAt.day.toString().padLeft(2, '0')}/${item.requestedAt.month.toString().padLeft(2, '0')}/${item.requestedAt.year}';

            Color statusColor;
            switch (item.status) {
              case PayoutStatus.paid:
                statusColor = const Color(0xFF10B981);
                break;
              case PayoutStatus.approved:
                statusColor = const Color(0xFF3B82F6);
                break;
              case PayoutStatus.rejected:
                statusColor = const Color(0xFFEF4444);
                break;
              case PayoutStatus.pending:
                statusColor = const Color(0xFFF59E0B);
                break;
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Icon(Icons.monetization_on_outlined, color: statusColor, size: 20),
              ),
              title: Row(
                children: [
                  Text(
                    '${item.amount.toStringAsFixed(3)} DT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'via ${item.payoutMethod.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Demandé le $dateStr${item.transactionReference != null ? ' • Réf: ${item.transactionReference}' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // DIALOGS: RETRAIT ET CONVERSION
  // ==========================================
  void _showPayoutRequestDialog(AffiliateProfile profile) {
    final amountController = TextEditingController(text: profile.balanceCash.toStringAsFixed(0));
    final recipientController = TextEditingController();
    final bankOrPhoneController = TextEditingController();
    String method = 'bank_transfer';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  const Text('Demande de Retrait Cash', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Solde disponible : ${profile.balanceCash.toStringAsFixed(3)} DT\nSeuil minimum de retrait : ${_config.minPayoutAmount.toStringAsFixed(0)} DT',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Montant à retirer (DT)',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          final parsed = double.tryParse(val ?? '');
                          if (parsed == null || parsed <= 0) return 'Montant invalide';
                          if (parsed < _config.minPayoutAmount) {
                            return 'Le seuil minimum est de ${_config.minPayoutAmount.toStringAsFixed(0)} DT';
                          }
                          if (parsed > profile.balanceCash) {
                            return 'Le montant dépasse votre solde disponible';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: const InputDecoration(
                          labelText: 'Mode de paiement',
                          prefixIcon: Icon(Icons.payment_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'bank_transfer', child: Text('Virement Bancaire (RIB)')),
                          DropdownMenuItem(value: 'flouci', child: Text('Flouci (Mobile Wallet)')),
                          DropdownMenuItem(value: 'd17', child: Text('D17 (La Poste Tunisienne)')),
                          DropdownMenuItem(value: 'mandat', child: Text('Mandat Minute')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => method = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: recipientController,
                        decoration: const InputDecoration(
                          labelText: 'Nom et Prénom du Bénéficiaire',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: bankOrPhoneController,
                        decoration: InputDecoration(
                          labelText: method == 'bank_transfer'
                              ? 'RIB Bancaire (20 chiffres)'
                              : 'Numéro de Téléphone (8 chiffres)',
                          prefixIcon: const Icon(Icons.numbers_rounded),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() == true) {
                      final messenger = ScaffoldMessenger.of(context);
                      final amount = double.parse(amountController.text.trim());
                      Navigator.pop(ctx);
                      try {
                        await _service.requestPayout(
                          userId: profile.userId,
                          userName: recipientController.text.trim(),
                          userEmail: profile.userEmail,
                          amount: amount,
                          payoutMethod: method,
                          payoutDetails: {
                            'recipient': recipientController.text.trim(),
                            'accountOrPhone': bankOrPhoneController.text.trim(),
                          },
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Demande de retrait transmise avec succès au Support SuperAdmin !'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Confirmer le Retrait'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showConvertDialog(AffiliateProfile profile) {
    final amountController = TextEditingController(text: profile.balanceCash.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: _brandBlue),
              const SizedBox(width: 10),
              const Text('Convertir en Remise d\'Abonnement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transférez votre solde cash (${profile.balanceCash.toStringAsFixed(3)} DT) en crédit utilisable directement lors du renouvellement de vos licences LogiTech.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant à convertir (DT)',
                    prefixIcon: Icon(Icons.discount_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final p = double.tryParse(v ?? '');
                    if (p == null || p <= 0) return 'Montant invalide';
                    if (p > profile.balanceCash) return 'Dépasse votre solde disponible';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() == true) {
                  final amount = double.parse(amountController.text.trim());
                  Navigator.pop(ctx);
                  await _service.convertCashToDiscount(profile.userId, amount);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${amount.toStringAsFixed(0)} DT ont été convertis en crédit d\'abonnement !'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              child: const Text('Convertir'),
            ),
          ],
        );
      },
    );
  }
}
