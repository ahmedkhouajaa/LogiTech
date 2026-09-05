import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_nav_module.dart';
import '../services/agent_presence_service.dart';
import '../services/ticket_stream_service.dart';
import 'admin_login_screen.dart';
import 'agent_dashboard_screen.dart';
import 'agent_management_screen.dart';
import 'all_tenants_screen.dart';
import 'analytics_reports_screen.dart';
import 'agent_profile_screen.dart';
import 'audit_log_screen.dart';
import 'configuration_screen.dart';
import 'payment_history_screen.dart';
import 'payment_validation_screen.dart';
import 'executive_dashboard_screen.dart';
import 'clients/all_clients_screen.dart';
import 'clients/client_search_screen.dart';
import 'clients/banned_clients_screen.dart';
import 'clients/password_management_screen.dart';
import 'clients/license_extension_screen.dart';
import 'clients/client_history_screen.dart';
import 'clients/client_export_screen.dart';
import 'clients/user_activation_screen.dart';
import '../services/user_presence_helper.dart';
import 'firestore_metrics_screen.dart';

class SupportAdminShellScreen extends StatefulWidget {
  const SupportAdminShellScreen({super.key});

  @override
  State<SupportAdminShellScreen> createState() => _SupportAdminShellScreenState();
}

class _SupportAdminShellScreenState extends State<SupportAdminShellScreen> {
  AdminNavModule _activeModule = AdminNavModule.dashboard;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    AgentPresenceService.instance.startPresenceHeartbeat();
  }

  @override
  void dispose() {
    AgentPresenceService.instance.stopPresence();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter de la console support ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AgentPresenceService.instance.stopPresence();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = FirebaseAuth.instance.currentUser;
    final agentEmail = agent?.email ?? 'support@logitech.tn';
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: isMobile
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : IconButton(
                icon: Icon(_isCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded, color: Colors.white70),
                onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                tooltip: _isCollapsed ? 'Déplier le menu' : 'Replier le menu',
              ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'LogiTech Pro',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('CONSOLE SUPPORT & SUPERADMIN', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            if (!isMobile) ...[
              const Text('•', style: TextStyle(color: Colors.white24)),
              const SizedBox(width: 16),
              Text(_getModuleTitle(_activeModule), style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ],
        ),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(agentEmail, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: isMobile ? Drawer(child: _buildDrawerContent(agentEmail, isDrawer: true)) : null,
      body: Row(
        children: [
          if (!isMobile)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isCollapsed ? 68 : 270,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(right: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: _buildDrawerContent(agentEmail, isDrawer: false),
            ),
          Expanded(
            child: _buildActiveScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveScreen() {
    switch (_activeModule) {
      case AdminNavModule.dashboard:
        return ExecutiveDashboardScreen(
          key: const ValueKey('dashboard'),
          onNavigate: (AdminNavModule module) {
            setState(() => _activeModule = module);
          },
        );

      // The 6 Ticket Drawer Options (All use the SAME dashboard interface with appropriate filter)
      case AdminNavModule.ticketsQueue:
        return const AgentDashboardScreen(key: ValueKey('ticketsQueue'), menuFilter: TicketMenuFilter.queue);
      case AdminNavModule.ticketsMy:
        return const AgentDashboardScreen(key: ValueKey('ticketsMy'), menuFilter: TicketMenuFilter.myTickets);
      case AdminNavModule.ticketsUrgent:
        return const AgentDashboardScreen(key: ValueKey('ticketsUrgent'), menuFilter: TicketMenuFilter.urgent);
      case AdminNavModule.ticketsUnassigned:
        return const AgentDashboardScreen(key: ValueKey('ticketsUnassigned'), menuFilter: TicketMenuFilter.unassigned);
      case AdminNavModule.ticketsEscalated:
        return const AgentDashboardScreen(key: ValueKey('ticketsEscalated'), menuFilter: TicketMenuFilter.escalated);
      case AdminNavModule.ticketsAll:
        return const AgentDashboardScreen(key: ValueKey('ticketsAll'), menuFilter: TicketMenuFilter.all);

      // 3. Client Management views (GESTION DES CLIENTS)
      case AdminNavModule.clientsAll:
        return const AllClientsScreen(key: ValueKey('clientsAll'));
      case AdminNavModule.userActivation:
        return const UserActivationScreen(key: ValueKey('userActivation'));
      case AdminNavModule.clientsSearch:
        return const ClientSearchScreen(key: ValueKey('clientsSearch'));
      case AdminNavModule.clientsBanned:
        return const BannedClientsScreen(key: ValueKey('clientsBanned'));
      case AdminNavModule.clientsPasswords:
        return const PasswordManagementScreen(key: ValueKey('clientsPasswords'));
      case AdminNavModule.clientsLicenseExtend:
        return const LicenseExtensionScreen(key: ValueKey('clientsLicenseExtend'));
      case AdminNavModule.clientsHistory:
        return const ClientHistoryScreen(key: ValueKey('clientsHistory'));
      case AdminNavModule.clientsExport:
        return const ClientExportScreen(key: ValueKey('clientsExport'));

      // Tenant views (Legacy)
      case AdminNavModule.tenantXRay:
        return const ClientSearchScreen(key: ValueKey('tenantXRay'));
      case AdminNavModule.tenantAll:
        return const AllClientsScreen(key: ValueKey('tenantAll'));
      case AdminNavModule.tenantStats:
        return const AllTenantsScreen(key: ValueKey('tenantStats'), showStatsOnly: true);

      // Payment views
      case AdminNavModule.paymentValidation:
        return const PaymentValidationScreen(key: ValueKey('paymentValidation'));
      case AdminNavModule.paymentHistory:
        return const PaymentHistoryScreen(key: ValueKey('paymentHistory'));
      case AdminNavModule.paymentPlans:
        return const PaymentHistoryScreen(key: ValueKey('paymentPlans'), showPlansOnly: true);

      // Agent management
      case AdminNavModule.agentsTeam:
        return const AgentManagementScreen(key: ValueKey('agentsTeam'));
      case AdminNavModule.agentsInvite:
        return const AgentManagementScreen(key: ValueKey('agentsInvite'));
      case AdminNavModule.agentsPerformance:
        return const AgentManagementScreen(key: ValueKey('agentsPerformance'), showOnlyPerformance: true);
      case AdminNavModule.agentsPresence:
        return const AgentManagementScreen(key: ValueKey('agentsPresence'), showOnlyPresence: true);

      // Audit & Security
      case AdminNavModule.auditLogs:
        return const AuditLogScreen(key: ValueKey('auditLogs'));
      case AdminNavModule.loginLogs:
        return const AuditLogScreen(key: ValueKey('loginLogs'), showLoginLogsOnly: true);
      case AdminNavModule.securityRules:
        return const AuditLogScreen(key: ValueKey('securityRules'));

      // Configuration (The 3 drawer options open directly into the corresponding tab)
      case AdminNavModule.configSla:
        return const ConfigurationScreen(key: ValueKey('configSla'), initialTabIndex: 0);
      case AdminNavModule.configTemplates:
        return const ConfigurationScreen(key: ValueKey('configTemplates'), initialTabIndex: 1);
      case AdminNavModule.configCategories:
        return const ConfigurationScreen(key: ValueKey('configCategories'), initialTabIndex: 2);
      case AdminNavModule.configNotifications:
        return const ConfigurationScreen(key: ValueKey('configNotifications'), initialTabIndex: 0);

      // Reports & Analytics
      case AdminNavModule.firestoreMetrics:
        return const FirestoreMetricsScreen(key: ValueKey('firestoreMetrics'));
      case AdminNavModule.reportsSla:
      case AdminNavModule.reportsVolume:
      case AdminNavModule.reportsCsat:
      case AdminNavModule.reportsPerformance:
        return const AnalyticsReportsScreen(key: ValueKey('reports'));

      // System
      case AdminNavModule.systemProfile:
      case AdminNavModule.systemTheme:
      case AdminNavModule.systemLanguage:
        return const AgentProfileScreen(key: ValueKey('systemProfile'));
    }
  }

  Widget _buildDrawerContent(String agentEmail, {required bool isDrawer}) {
    final collapsed = _isCollapsed && !isDrawer;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('support_tickets').snapshots(),
      builder: (context, ticketSnap) {
        int openCount = 0;
        int urgentCount = 0;
        int unassignedCount = 0;
        int escalatedCount = 0;

        if (ticketSnap.hasData) {
          for (final doc in ticketSnap.data!.docs) {
            final data = doc.data();
            final status = (data['status'] ?? 'open').toString().toLowerCase();
            final priority = (data['priority'] ?? 'medium').toString().toLowerCase();
            final assignedUid = data['assignedAgentId'];

            if (status != 'resolved' && status != 'closed') {
              openCount++;
              if (priority == 'urgent' || priority == 'high') urgentCount++;
              if (assignedUid == null || assignedUid.toString().trim().isEmpty) unassignedCount++;
              if (status == 'escalated') escalatedCount++;
            }
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
          builder: (context, enterpriseSnap) {
            int bannedCount = 0;
            if (enterpriseSnap.hasData) {
              for (final doc in enterpriseSnap.data!.docs) {
                final d = doc.data();
                if (d['isBanned'] == true || d['status'] == 'banned' || d['status'] == 'disabled') {
                  bannedCount++;
                }
              }
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, userSnap) {
                int onlineUsersCount = 0;
                int activeUsersCount = 0;
                int invitedUsersCount = 0;

                if (userSnap.hasData) {
                  for (final doc in userSnap.data!.docs) {
                    final d = doc.data();
                    final isOnline = UserPresenceHelper.isUserOnline(d);
                    final isBanned = d['isBanned'] == true || d['isDisabled'] == true || d['status'] == 'banned' || d['status'] == 'disabled' || d['isActive'] == false;
                    final isInvited = d['status'] == 'invited' || d['status'] == 'pending';

                    if (isOnline) onlineUsersCount++;
                    if (isInvited) {
                      invitedUsersCount++;
                    } else if (!isBanned) {
                      activeUsersCount++;
                    }
                  }
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('subscription_payments')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, paymentSnap) {
                    final pendingPaymentCount = paymentSnap.data?.docs.length ?? 0;

                    final Map<String, int> badgeCounts = {
                      'open': openCount,
                      'urgent': urgentCount,
                      'unassigned': unassignedCount,
                      'escalated': escalatedCount,
                      'bannedClients': bannedCount,
                      'pendingPayments': pendingPaymentCount,
                      'onlineUsers': onlineUsersCount,
                    };

                    return Column(
                      children: [
                        const SizedBox(height: 12),

                        // Navigation Sections
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            children: [
                              // 1. Dashboard
                              _menuItem(AdminNavModule.dashboard, 'Tableau de Bord', Icons.dashboard_rounded, collapsed, isDrawer),
                              const Divider(color: Color(0xFF1E293B), height: 16),

                              // Drawer Quick Presence & Activation Summary Pill Card
                              if (!collapsed) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.sensors_rounded, size: 14, color: Color(0xFF10B981)),
                                          SizedBox(width: 6),
                                          Text('PRÉSENCE & ACTIVATION', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _presenceBadge('En Ligne', '$onlineUsersCount', const Color(0xFF10B981)),
                                          _presenceBadge('Comptes Actifs', '$activeUsersCount', const Color(0xFF3B82F6)),
                                          _presenceBadge('En Attente', '$invitedUsersCount', const Color(0xFFF59E0B)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // 2. Ticket Management (The 6 Drawer Options)
                              _sectionHeader('GESTION DES TICKETS', collapsed),
                              _menuItem(AdminNavModule.ticketsQueue, 'File d\'attente', Icons.inbox_rounded, collapsed, isDrawer, badge: badgeCounts['open']),
                              _menuItem(AdminNavModule.ticketsMy, 'Mes Tickets', Icons.person_outline_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.ticketsUrgent, 'Tickets Urgents', Icons.warning_amber_rounded, collapsed, isDrawer, badge: badgeCounts['urgent'], badgeColor: const Color(0xFFEF4444)),
                              _menuItem(AdminNavModule.ticketsUnassigned, 'Non Assignés', Icons.push_pin_outlined, collapsed, isDrawer),
                              _menuItem(AdminNavModule.ticketsEscalated, 'Tickets Escaladés', Icons.sync_problem_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.ticketsAll, 'Tous les Tickets', Icons.all_inbox_rounded, collapsed, isDrawer),
                              const Divider(color: Color(0xFF1E293B), height: 16),

                              // 3. Client Management (GESTION DES CLIENTS - 8 options)
                              _sectionHeader('GESTION DES CLIENTS', collapsed),
                              _menuItem(AdminNavModule.clientsAll, 'Tous les Clients', Icons.groups_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.userActivation, 'User Activation', Icons.how_to_reg_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.clientsSearch, 'Rechercher un Client', Icons.person_search_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.clientsBanned, 'Clients Bannis/Désactivés', Icons.block_rounded, collapsed, isDrawer, badge: badgeCounts['bannedClients'], badgeColor: const Color(0xFFEF4444)),
                              _menuItem(AdminNavModule.clientsPasswords, 'Gestion Mots de Passe', Icons.key_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.clientsLicenseExtend, 'Extension de Licence', Icons.event_available_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.clientsHistory, 'Historique Clients', Icons.history_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.clientsExport, 'Exporter Clients (Excel/CSV)', Icons.file_download_rounded, collapsed, isDrawer),
                              const Divider(color: Color(0xFF1E293B), height: 16),

                              // 4. Payment & Billing
                              _sectionHeader('PAIEMENTS & FACTURATION', collapsed),
                              _menuItem(AdminNavModule.paymentValidation, 'Validation Paiements', Icons.verified_rounded, collapsed, isDrawer, badge: badgeCounts['pendingPayments'], badgeColor: const Color(0xFFF59E0B)),
                              _menuItem(AdminNavModule.paymentHistory, 'Historique Paiements', Icons.receipt_long_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.paymentPlans, 'Plans & Abonnements', Icons.card_membership_rounded, collapsed, isDrawer),
                              const Divider(color: Color(0xFF1E293B), height: 16),

                              // 5. Agent Management (SuperAdmin)
                              _sectionHeader('GESTION DES AGENTS', collapsed),
                              _menuItem(AdminNavModule.agentsTeam, 'Équipe Support', Icons.people_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.agentsPerformance, 'Performance Agents', Icons.leaderboard_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.agentsPresence, 'Présence en Direct', Icons.sensors_rounded, collapsed, isDrawer, badge: badgeCounts['onlineUsers'], badgeColor: const Color(0xFF10B981)),
                              const Divider(color: Color(0xFF1E293B), height: 16),

                              // 6. Audit & Security
                              _sectionHeader('AUDIT & SÉCURITÉ', collapsed),
                              _menuItem(AdminNavModule.auditLogs, 'Journal d\'Audit', Icons.security_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.loginLogs, 'Logs de Connexion', Icons.lock_clock_rounded, collapsed, isDrawer),
                              const Divider(color: Color(0xFF1E293B), height: 16),

                              // 7. Configuration
                              _sectionHeader('CONFIGURATION', collapsed),
                              _menuItem(AdminNavModule.configSla, 'Paramètres SLA', Icons.timer_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.configTemplates, 'Modèles de Réponse', Icons.flash_on_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.configCategories, 'Catégories Tickets', Icons.category_rounded, collapsed, isDrawer),
                              const Divider(color: Color(0xFF1E293B), height: 16),

                              // 8. Reports & Analytics
                              _sectionHeader('MÉTRIQUES & ANALYTIQUE', collapsed),
                              _menuItem(AdminNavModule.firestoreMetrics, 'Métriques Firestore (R/W/D)', Icons.query_stats_rounded, collapsed, isDrawer),
                              _menuItem(AdminNavModule.reportsSla, 'Rapports SLA & CSAT', Icons.analytics_rounded, collapsed, isDrawer),
                              const Divider(color: Color(0xFF1E293B), height: 16),

                              // 9. System
                              _sectionHeader('SYSTÈME', collapsed),
                              _menuItem(AdminNavModule.systemProfile, 'Mon Profil & Thème', Icons.person_rounded, collapsed, isDrawer),
                            ],
                          ),
                        ),

                        // Bottom Logout
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: InkWell(
                            onTap: _logout,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                                children: [
                                  const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                                  if (!collapsed) ...[
                                    const SizedBox(width: 12),
                                    const Text('Déconnexion', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              },
            );
          },
        );

      },
    );
  }

  Widget _sectionHeader(String title, bool collapsed) {
    if (collapsed) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.6),
      ),
    );
  }

  Widget _menuItem(
    AdminNavModule module,
    String label,
    IconData icon,
    bool collapsed,
    bool isDrawer, {
    int? badge,
    Color? badgeColor,
  }) {
    final isSelected = _activeModule == module;

    return InkWell(
      onTap: () {
        setState(() => _activeModule = module);
        if (isDrawer) {
          Navigator.pop(context);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null && badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _getModuleTitle(AdminNavModule module) {
    switch (module) {
      case AdminNavModule.dashboard: return 'Tableau de Bord Exécutif';
      case AdminNavModule.ticketsQueue: return 'File d\'attente des Tickets';
      case AdminNavModule.ticketsMy: return 'Mes Tickets Assignés';
      case AdminNavModule.ticketsUrgent: return 'Tickets Urgents (SLA)';
      case AdminNavModule.ticketsUnassigned: return 'Tickets Non Assignés';
      case AdminNavModule.ticketsEscalated: return 'Tickets Escaladés';
      case AdminNavModule.ticketsAll: return 'Tous les Tickets';

      // Client Management
      case AdminNavModule.clientsAll: return 'Annuaire de Tous les Clients';
      case AdminNavModule.userActivation: return 'Activation & Présence des Utilisateurs (User Activation)';
      case AdminNavModule.clientsSearch: return 'Recherche Globale de Clients';
      case AdminNavModule.clientsBanned: return 'Clients Bannis & Suspendus';
      case AdminNavModule.clientsPasswords: return 'Gestion des Mots de Passe Utilisateurs';
      case AdminNavModule.clientsLicenseExtend: return 'Extension de Licences & Abonnements';
      case AdminNavModule.clientsHistory: return 'Historique & Piste d\'Audit Clients';
      case AdminNavModule.clientsExport: return 'Exportation des Données Clients';

      case AdminNavModule.tenantXRay: return 'Inspection X-Ray des Tenants';
      case AdminNavModule.tenantAll: return 'Annuaire des Entreprises';
      case AdminNavModule.tenantStats: return 'Statistiques des Tenants';
      case AdminNavModule.paymentValidation: return 'Validation des Paiements & Licences';
      case AdminNavModule.paymentHistory: return 'Historique des Transactions';
      case AdminNavModule.paymentPlans: return 'Plans d\'Abonnement Actifs';
      case AdminNavModule.agentsTeam: return 'Gestion de l\'Équipe Support';
      case AdminNavModule.agentsInvite: return 'Inviter un Agent Support';
      case AdminNavModule.agentsPerformance: return 'Performance des Agents';
      case AdminNavModule.agentsPresence: return 'Présence des Agents en Direct';
      case AdminNavModule.auditLogs: return 'Journal d\'Audit Immuable';
      case AdminNavModule.loginLogs: return 'Logs de Connexion';
      case AdminNavModule.securityRules: return 'Règles de Sécurité';
      case AdminNavModule.configSla: return 'Paramètres des Délais SLA';
      case AdminNavModule.configTemplates: return 'Modèles de Réponse Rapide';
      case AdminNavModule.configCategories: return 'Catégories de Tickets';
      case AdminNavModule.configNotifications: return 'Paramètres de Notifications';
      case AdminNavModule.reportsSla: return 'Rapports de Conformité SLA';
      case AdminNavModule.reportsVolume: return 'Volume & Tendances des Tickets';
      case AdminNavModule.reportsCsat: return 'Satisfaction Client (CSAT)';
      case AdminNavModule.reportsPerformance: return 'Performance Globale';
      case AdminNavModule.firestoreMetrics: return 'Métriques Firestore & Consommation Cloud';
      case AdminNavModule.systemProfile: return 'Mon Profil d\'Agent';
      case AdminNavModule.systemTheme: return 'Thème & Apparence';
      case AdminNavModule.systemLanguage: return 'Langue du Système';
    }
  }

  Widget _presenceBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

