import 'package:flutter/material.dart';

enum AdminNavModule {
  // 1. Dashboard
  dashboard,

  // 2. Ticket Management (The 6 Drawer Options)
  ticketsQueue,       // 1. File d'attente
  ticketsMy,          // 2. Mes Tickets
  ticketsUrgent,      // 3. Tickets Urgents
  ticketsUnassigned,  // 4. Non Assignés
  ticketsEscalated,   // 5. Tickets Escaladés
  ticketsAll,         // 6. Tous les Tickets

  // 3. Client Management (GESTION DES CLIENTS)
  clientsAll,             // 1. Tous les Clients
  clientsSearch,          // 2. Rechercher un Client
  clientsBanned,          // 3. Clients Bannis/Désactivés
  clientsPasswords,       // 4. Gestion des Mots de Passe
  clientsLicenseExtend,   // 5. Extension de Licence
  clientsHistory,         // 6. Historique Clients
  clientsExport,          // 7. Exporter Clients (Excel/CSV)

  // 3. Tenant Management (Legacy/Direct inspection)
  tenantXRay,
  tenantAll,
  tenantStats,

  // 4. Payment & Billing
  paymentValidation,
  paymentHistory,
  paymentPlans,

  // 5. Agent Management (SuperAdmin)
  agentsTeam,
  agentsInvite,
  agentsPerformance,
  agentsPresence,

  // 6. Audit & Security
  auditLogs,
  loginLogs,
  securityRules,

  // 7. Configuration
  configSla,
  configTemplates,
  configCategories,
  configNotifications,

  // 8. Reports & Analytics
  reportsSla,
  reportsVolume,
  reportsCsat,
  reportsPerformance,
  firestoreMetrics,

  // 9. System
  systemProfile,
  systemTheme,
  systemLanguage,
}

class AdminNavSection {
  final String title;
  final IconData icon;
  final List<AdminNavItem> items;

  const AdminNavSection({
    required this.title,
    required this.icon,
    required this.items,
  });
}

class AdminNavItem {
  final AdminNavModule module;
  final String title;
  final IconData icon;
  final String? badgeKey; // e.g. 'openTickets', 'urgentTickets', 'pendingPayments'

  const AdminNavItem({
    required this.module,
    required this.title,
    required this.icon,
    this.badgeKey,
  });
}
