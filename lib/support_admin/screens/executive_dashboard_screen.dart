import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/admin_nav_module.dart';
import 'tenant_xray_screen.dart';

class ExecutiveDashboardScreen extends StatelessWidget {
  final ValueChanged<AdminNavModule>? onNavigate;

  const ExecutiveDashboardScreen({
    super.key,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
        builder: (context, entSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('subscription_payments')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, paySnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('support_tickets').snapshots(),
                    builder: (context, ticketSnap) {
                      if (entSnap.connectionState == ConnectionState.waiting &&
                          userSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // 1. Enterprise stats
                      final entDocs = entSnap.data?.docs ?? [];
                      final int totalEnterprises = entDocs.length;
                      int activeEnterprises = 0;
                      int premiumEnterprises = 0;
                      int proPlanCount = 0;
                      int enterprisePlanCount = 0;
                      int trialPlanCount = 0;

                      for (final doc in entDocs) {
                        final d = doc.data();
                        final isBanned = d['isBanned'] == true || d['status'] == 'banned' || d['status'] == 'disabled';
                        if (!isBanned) activeEnterprises++;

                        final plan = (d['subscriptionPlan'] ?? d['plan'] ?? d['subscriptionTier'] ?? '').toString().toLowerCase();
                        final isUpgraded = d['isUpgraded'] == true || plan == 'pro' || plan == 'enterprise';

                        if (isUpgraded) {
                          premiumEnterprises++;
                          if (plan == 'enterprise') {
                            enterprisePlanCount++;
                          } else {
                            proPlanCount++;
                          }
                        } else {
                          trialPlanCount++;
                        }
                      }

                      // 2. User & Client stats
                      final userDocs = userSnap.data?.docs ?? [];
                      int totalClients = 0;
                      int activeClients = 0;
                      int bannedClients = 0;
                      int premiumUsers = 0;

                      for (final doc in userDocs) {
                        final d = doc.data();
                        final role = (d['role'] ?? '').toString().toLowerCase();
                        final isCollaborator = role == 'collaborator';
                        final isBanned = d['isBanned'] == true ||
                            d['isDisabled'] == true ||
                            d['status'] == 'banned' ||
                            d['status'] == 'disabled' ||
                            d['isActive'] == false;

                        final bool isClient = !isCollaborator || d['isOwner'] == true;
                        if (isClient) {
                          totalClients++;
                          if (isBanned) {
                            bannedClients++;
                          } else {
                            activeClients++;
                          }
                        }

                        final plan = (d['subscriptionPlan'] ?? d['plan'] ?? d['subscriptionTier'] ?? '').toString().toLowerCase();
                        final isPrem = d['isUpgraded'] == true || d['isPremium'] == true || plan == 'pro' || plan == 'enterprise';
                        if (isPrem) premiumUsers++;
                      }

                      final int totalPremium = (premiumUsers > premiumEnterprises) ? premiumUsers : premiumEnterprises;

                      // 3. Pending payments
                      final payDocs = paySnap.data?.docs ?? [];
                      final int pendingPayments = payDocs.length;

                      // 4. Ticket stats
                      final ticketDocs = ticketSnap.data?.docs ?? [];
                      int openTickets = 0;
                      int urgentTickets = 0;
                      int breachedTickets = 0;
                      final now = DateTime.now();

                      for (final doc in ticketDocs) {
                        final d = doc.data();
                        final status = (d['status'] ?? 'open').toString().toLowerCase();
                        final priority = (d['priority'] ?? 'medium').toString().toLowerCase();
                        final deadline = (d['slaDeadline'] as Timestamp?)?.toDate();

                        if (status != 'resolved' && status != 'closed') {
                          openTickets++;
                          if (priority == 'urgent' || priority == 'high') urgentTickets++;
                          if (deadline != null && now.isAfter(deadline)) breachedTickets++;
                        }
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Top Header ──────────────────────────────
                            _buildHeader(context),
                            const SizedBox(height: 20),

                            // ─── Primary Business KPIs (Row 1) ───────────
                            _buildSectionLabel('MÉTRIQUES CLÉS PLATEFORME & CLIENTS', Icons.analytics_rounded),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildMetricCard(
                                  title: 'Nombre de Clients',
                                  count: totalClients.toString(),
                                  subtitle: '$activeClients actifs • $bannedClients suspendus',
                                  badgeText: 'Comptes propriétaires',
                                  icon: Icons.people_alt_rounded,
                                  color: const Color(0xFF2563EB),
                                  onTap: () => onNavigate?.call(AdminNavModule.clientsAll),
                                ),
                                const SizedBox(width: 14),
                                _buildMetricCard(
                                  title: 'Nombre d\'Entreprises',
                                  count: totalEnterprises.toString(),
                                  subtitle: '$activeEnterprises actives sur la plateforme',
                                  badgeText: 'Tenants créés',
                                  icon: Icons.domain_rounded,
                                  color: const Color(0xFF4F46E5),
                                  onTap: () => onNavigate?.call(AdminNavModule.tenantAll),
                                ),
                                const SizedBox(width: 14),
                                _buildMetricCard(
                                  title: 'Abonnements Premium',
                                  count: totalPremium.toString(),
                                  subtitle: '$proPlanCount Pro • $enterprisePlanCount Entreprise',
                                  badgeText: 'Abonnements payants',
                                  icon: Icons.workspace_premium_rounded,
                                  color: const Color(0xFFD97706),
                                  onTap: () => onNavigate?.call(AdminNavModule.paymentPlans),
                                ),
                                const SizedBox(width: 14),
                                _buildMetricCard(
                                  title: 'Paiements en Attente',
                                  count: pendingPayments.toString(),
                                  subtitle: pendingPayments > 0 ? '$pendingPayments virement(s) à valider' : 'Aucun paiement en attente',
                                  badgeText: pendingPayments > 0 ? 'Action requise' : 'À jour',
                                  badgeColor: pendingPayments > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  icon: Icons.receipt_long_rounded,
                                  color: const Color(0xFF059669),
                                  onTap: () => onNavigate?.call(AdminNavModule.paymentValidation),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // ─── Support & SLA Health (Row 2) ─────────────
                            _buildSectionLabel('PERFORMANCE SUPPORT & QUALITÉ SLA', Icons.support_agent_rounded),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildMetricCard(
                                  title: 'Tickets en File d\'Attente',
                                  count: openTickets.toString(),
                                  subtitle: 'Demandes clients non résolues',
                                  badgeText: 'File globale',
                                  icon: Icons.inbox_rounded,
                                  color: const Color(0xFF0284C7),
                                  onTap: () => onNavigate?.call(AdminNavModule.ticketsQueue),
                                ),
                                const SizedBox(width: 14),
                                _buildMetricCard(
                                  title: 'Tickets Urgents (SLA)',
                                  count: urgentTickets.toString(),
                                  subtitle: 'Priorité critique & escalade',
                                  badgeText: 'Priorité haute',
                                  icon: Icons.warning_amber_rounded,
                                  color: const Color(0xFFEA580C),
                                  onTap: () => onNavigate?.call(AdminNavModule.ticketsUrgent),
                                ),
                                const SizedBox(width: 14),
                                _buildMetricCard(
                                  title: 'Dépassements SLA',
                                  count: breachedTickets.toString(),
                                  subtitle: 'Délais de réponse expirés',
                                  badgeText: breachedTickets > 0 ? 'Attention requise' : 'Aucun retard',
                                  badgeColor: breachedTickets > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  icon: Icons.timer_off_rounded,
                                  color: const Color(0xFFEF4444),
                                  onTap: () => onNavigate?.call(AdminNavModule.ticketsUrgent),
                                ),
                                const SizedBox(width: 14),
                                _buildMetricCard(
                                  title: 'Comptes Restreints / Bannis',
                                  count: bannedClients.toString(),
                                  subtitle: 'Accès suspendu par l\'admin',
                                  badgeText: 'Sécurité & conformité',
                                  icon: Icons.lock_person_rounded,
                                  color: const Color(0xFF64748B),
                                  onTap: () => onNavigate?.call(AdminNavModule.clientsBanned),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ─── Subscription Distribution & Quick Shortcuts (Row 3) ───
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left: Subscription Distribution
                                Expanded(
                                  flex: 3,
                                  child: _buildSubscriptionDistributionCard(
                                    total: totalEnterprises,
                                    trial: trialPlanCount,
                                    pro: proPlanCount,
                                    enterprise: enterprisePlanCount,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Right: Quick Action Shortcuts
                                Expanded(
                                  flex: 2,
                                  child: _buildQuickActionsCard(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ─── Recent Platform Activity (Latest Enterprises) ───
                            _buildRecentEnterprisesSection(entDocs, userDocs),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Tableau de Bord Exécutif',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Vue d\'ensemble en direct • Gestion des Clients, Entreprises, Abonnements & Support',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                SizedBox(width: 6),
                Text(
                  'Synchronisation Firestore Active',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF475569)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ─── Metric Card ────────────────────────────────────────────────────

  Widget _buildMetricCard({
    required String title,
    required String count,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color color,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor != null ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Subscription Distribution Card ─────────────────────────────────

  Widget _buildSubscriptionDistributionCard({
    required int total,
    required int trial,
    required int pro,
    required int enterprise,
  }) {
    final trialPct = total > 0 ? (trial / total * 100).round() : 0;
    final proPct = total > 0 ? (pro / total * 100).round() : 0;
    final enterprisePct = total > 0 ? (enterprise / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Row(
                children: const [
                  Icon(Icons.pie_chart_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Répartition des Abonnements',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Text(
                '$total Entreprises Total',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Visual proportional distribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (trialPct > 0)
                    Expanded(
                      flex: trialPct,
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  if (proPct > 0)
                    Expanded(
                      flex: proPct,
                      child: Container(color: const Color(0xFF3B82F6)),
                    ),
                  if (enterprisePct > 0)
                    Expanded(
                      flex: enterprisePct,
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (total == 0)
                    Expanded(
                      child: Container(color: const Color(0xFFE2E8F0)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Legend Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPlanLegendItem('Période d\'Essai', trial, '$trialPct%', const Color(0xFFF59E0B)),
              _buildPlanLegendItem('Formule Pro', pro, '$proPct%', const Color(0xFF3B82F6)),
              _buildPlanLegendItem('Formule Entreprise', enterprise, '$enterprisePct%', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanLegendItem(String title, int count, String pct, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count ($pct)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Quick Actions Card ─────────────────────────────────────────────

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text(
                'Actions Rapides SuperAdmin',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildQuickActionButton(
            label: 'Annuaire de Tous les Clients',
            icon: Icons.people_outline_rounded,
            color: const Color(0xFF2563EB),
            onTap: () => onNavigate?.call(AdminNavModule.clientsAll),
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            label: 'Rechercher un Client / SIRET',
            icon: Icons.search_rounded,
            color: const Color(0xFF4F46E5),
            onTap: () => onNavigate?.call(AdminNavModule.clientsSearch),
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            label: 'Validation des Abonnements',
            icon: Icons.verified_user_outlined,
            color: const Color(0xFF059669),
            onTap: () => onNavigate?.call(AdminNavModule.paymentValidation),
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            label: 'Comptes Clients Suspendus',
            icon: Icons.block_rounded,
            color: const Color(0xFFEF4444),
            onTap: () => onNavigate?.call(AdminNavModule.clientsBanned),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // ─── Recent Enterprises Section ─────────────────────────────────────

  Widget _buildRecentEnterprisesSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> entDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
  ) {
    // Map userId -> userName
    final Map<String, String> userNames = {};
    for (final u in userDocs) {
      final d = u.data();
      userNames[u.id] = d['name'] ?? d['displayName'] ?? d['email'] ?? 'Client inconnu';
    }

    // Sort by createdAt descending
    final sortedEnts = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(entDocs);
    sortedEnts.sort((a, b) {
      final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
      final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
      return bTime.compareTo(aTime);
    });

    final recentEnts = sortedEnts.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Row(
                children: const [
                  Icon(Icons.history_rounded, size: 18, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Dernières Entreprises Enregistrées sur la Plateforme',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => onNavigate?.call(AdminNavModule.tenantAll),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Voir tout l\'annuaire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (recentEnts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Aucune entreprise enregistrée', style: TextStyle(color: Color(0xFF94A3B8)))),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2.5),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2),
                5: FixedColumnWidth(90),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                // Header row
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                  ),
                  children: [
                    _tableHeader('Entreprise'),
                    _tableHeader('Propriétaire / Client'),
                    _tableHeader('Matricule Fiscal'),
                    _tableHeader('Formule Plan'),
                    _tableHeader('Date d\'inscription'),
                    _tableHeader('Action'),
                  ],
                ),
                // Data rows
                for (final ent in recentEnts) ...[
                  _buildEnterpriseTableRow(ent, userNames),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
      ),
    );
  }

  TableRow _buildEnterpriseTableRow(
    QueryDocumentSnapshot<Map<String, dynamic>> ent,
    Map<String, String> userNames,
  ) {
    final d = ent.data();
    final name = d['name'] ?? 'Entreprise sans nom';
    final ownerId = d['ownerId'] as String?;
    final ownerName = (ownerId != null && userNames.containsKey(ownerId)) ? userNames[ownerId]! : (d['ownerEmail'] ?? 'Client');
    final taxNumber = d['taxNumber'] ?? 'Non renseigné';
    final isUpgraded = d['isUpgraded'] == true;
    final isBanned = d['isBanned'] == true || d['status'] == 'banned';

    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final dateStr = createdAt != null ? DateFormat('dd/MM/yyyy').format(createdAt) : 'N/A';

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFEFF6FF),
                child: const Icon(Icons.business_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            ownerName,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            taxNumber,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: isBanned
                    ? const Color(0xFFFEE2E2)
                    : (isUpgraded ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isBanned ? 'BANNI' : (isUpgraded ? 'ABONNÉ' : 'ESSAI'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isBanned
                      ? const Color(0xFFDC2626)
                      : (isUpgraded ? const Color(0xFF059669) : const Color(0xFFD97706)),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            dateStr,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Builder(
            builder: (ctx) => InkWell(
              onTap: () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => TenantXRayScreen(enterpriseId: ent.id)),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.visibility_outlined, size: 13, color: Color(0xFF2563EB)),
                    SizedBox(width: 4),
                    Text('X-Ray', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
