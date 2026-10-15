import 'package:flutter/material.dart';

/// Permission flags for a single resource/module.
class UserResourcePermission {
  final bool read;
  final bool create;
  final bool update;
  final bool delete;

  const UserResourcePermission({
    this.read = false,
    this.create = false,
    this.update = false,
    this.delete = false,
  });

  bool get all => read && create && update && delete;
  bool get none => !read && !create && !update && !delete;

  UserResourcePermission copyWith({
    bool? read,
    bool? create,
    bool? update,
    bool? delete,
  }) {
    return UserResourcePermission(
      read: read ?? this.read,
      create: create ?? this.create,
      update: update ?? this.update,
      delete: delete ?? this.delete,
    );
  }

  Map<String, bool> toMap() => {
        'read': read,
        'create': create,
        'update': update,
        'delete': delete,
      };

  factory UserResourcePermission.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserResourcePermission();
    return UserResourcePermission(
      read: map['read'] == true,
      create: map['create'] == true,
      update: map['update'] == true,
      delete: map['delete'] == true,
    );
  }

  static const UserResourcePermission full = UserResourcePermission(
    read: true,
    create: true,
    update: true,
    delete: true,
  );

  static const UserResourcePermission standardCollaborator = UserResourcePermission(
    read: true,
    create: true,
    update: true,
    delete: false,
  );

  static const UserResourcePermission readOnly = UserResourcePermission(
    read: true,
    create: false,
    update: false,
    delete: false,
  );

  static const UserResourcePermission empty = UserResourcePermission(
    read: false,
    create: false,
    update: false,
    delete: false,
  );
}

/// Predefined list of menu resources for user permissions in the app.
class UserPermissionResources {
  // 1. Dashboard
  static const String dashboard = 'dashboard';

  // CRM
  static const String crmDashboard = 'crm_dashboard';
  static const String crmPipeline = 'crm_pipeline';
  static const String crmOpportunities = 'crm_opportunities';
  static const String crmLeads = 'crm_leads';
  static const String crmAutomations = 'crm_automations';
  static const String crmReports = 'crm_reports';
  static const String crmEmails = 'crm_emails';

  // RH & Paie
  static const String hrDashboard = 'hr_dashboard';
  static const String hrEmployees = 'hr_employees';
  static const String hrLeaves = 'hr_leaves';
  static const String hrAttendances = 'hr_attendances';
  static const String hrPayroll = 'hr_payroll';
  static const String hrCnssDeclaration = 'hr_cnss_declaration';
  static const String hrDocuments = 'hr_documents';
  static const String hrAccounting = 'hr_accounting';
  static const String hrLegalEntity = 'hr_legal_entity';
  static const String hrEstablishments = 'hr_establishments';
  static const String hrManagers = 'hr_managers';

  // 2-8. Sales (Ventes)
  static const String salesQuotes = 'sales_quotes';
  static const String salesOrders = 'sales_orders';
  static const String salesDeliveryNotes = 'sales_delivery_notes';
  static const String salesInvoices = 'sales_invoices';
  static const String salesExitVouchers = 'sales_exit_vouchers';
  static const String salesCreditNotes = 'sales_credit_notes';
  static const String salesReturnVouchers = 'sales_return_vouchers';

  // 9-13. Purchases (Achats)
  static const String purchasesSupplierOrders = 'purchases_supplier_orders';
  static const String purchasesReceivingVouchers = 'purchases_receiving_vouchers';
  static const String purchasesPurchaseInvoices = 'purchases_purchase_invoices';
  static const String purchasesSupplierCreditNotes = 'purchases_supplier_credit_notes';
  static const String purchasesSupplierReturns = 'purchases_supplier_returns';

  // 14. Payments
  static const String payments = 'payments';

  // 15-17. Withholding Tax (Retenue à la source)
  static const String withholdingTax = 'withholding_tax';
  static const String withholdingTaxSales = 'withholding_tax_sales';
  static const String withholdingTaxPurchases = 'withholding_tax_purchases';

  // 18-20. Treasury (Trésorerie)
  static const String treasuryAccounts = 'treasury_accounts';
  static const String treasuryTransactions = 'treasury_transactions';
  static const String treasuryChecks = 'treasury_checks';

  // 21-22. Contacts
  static const String customers = 'customers';
  static const String suppliers = 'suppliers';

  // 23-24. Products (Articles)
  static const String productsList = 'products_list';
  static const String productsSettings = 'products_settings';

  // 25-31. Stock
  static const String stockOverview = 'stock_overview';
  static const String stockMovements = 'stock_movements';
  static const String stockEntryVouchers = 'stock_entry_vouchers';
  static const String stockWithdrawalVouchers = 'stock_withdrawal_vouchers';
  static const String stockTransferVouchers = 'stock_transfer_vouchers';
  static const String stockInventorySheets = 'stock_inventory_sheets';
  static const String stockWarehouses = 'stock_warehouses';

  // Production
  static const String productionDashboard = 'production_dashboard';
  static const String productionOrders = 'production_orders';
  static const String productionBoms = 'production_boms';
  static const String productionPlanning = 'production_planning';
  static const String productionCosts = 'production_costs';
  static const String productionQuality = 'production_quality';
  static const String productionReports = 'production_reports';
  static const String productionWorkcenters = 'production_workcenters';

  // 32. Projects
  static const String projects = 'projects';

  // 33-40. Settings (Paramètres)
  static const String settingsAppModules = 'settings_app_modules';
  static const String settingsPersonalInfo = 'settings_personal_info';
  static const String settingsCompanyInfo = 'settings_company_info';
  static const String settingsDocNumbering = 'settings_doc_numbering';
  static const String settingsDocTemplates = 'settings_doc_templates';
  static const String settingsCustomFields = 'settings_custom_fields';
  static const String settingsCustomStatuses = 'settings_custom_statuses';
  static const String importExport = 'import_export';
  static const String trash = 'trash';
  static const String userTracking = 'user_tracking';

  // 39. User Management (Admin Only)
  static const String userManagement = 'user_management';

  // 40. Affiliation & Parrainage
  static const String affiliate = 'affiliate';

  static const List<Map<String, dynamic>> allResources = [
    // 1. Tableau de bord
    {
      'key': dashboard,
      'label': 'Tableau de bord',
      'category': 'Général',
      'icon': Icons.dashboard_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // Affiliation & Parrainage
    {
      'key': affiliate,
      'label': 'Affiliation & Parrainage',
      'category': 'Général',
      'icon': Icons.handshake_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    // CRM
    {
      'key': crmDashboard,
      'label': 'CRM - Tableau de bord',
      'category': 'CRM',
      'icon': Icons.dashboard_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': crmPipeline,
      'label': 'CRM - Pipeline de vente',
      'category': 'CRM',
      'icon': Icons.view_kanban_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': crmOpportunities,
      'label': 'CRM - Opportunités',
      'category': 'CRM',
      'icon': Icons.auto_graph_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': crmLeads,
      'label': 'CRM - Prospects (Leads)',
      'category': 'CRM',
      'icon': Icons.contact_phone_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': crmAutomations,
      'label': 'CRM - Automatisations',
      'category': 'CRM',
      'icon': Icons.smart_toy_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': crmReports,
      'label': 'CRM - Rapports de performance',
      'category': 'CRM',
      'icon': Icons.insights_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': crmEmails,
      'label': 'CRM - Intégration email',
      'category': 'CRM',
      'icon': Icons.mark_email_read_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    // RH & Paie
    {
      'key': hrDashboard,
      'label': 'RH - Tableau de bord',
      'category': 'RH & Paie',
      'icon': Icons.dashboard_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': hrEmployees,
      'label': 'RH - Personnel & Employés',
      'category': 'RH & Paie',
      'icon': Icons.badge_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': hrLeaves,
      'label': 'RH - Congés & Absences',
      'category': 'RH & Paie',
      'icon': Icons.event_available_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': hrAttendances,
      'label': 'RH - Présences & Pointages',
      'category': 'RH & Paie',
      'icon': Icons.access_time_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': hrPayroll,
      'label': 'RH - Fiches de Paie',
      'category': 'RH & Paie',
      'icon': Icons.payments_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': hrCnssDeclaration,
      'label': 'RH - Déclaration CNSS',
      'category': 'RH & Paie',
      'icon': Icons.assignment_turned_in_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': hrDocuments,
      'label': 'RH - Documents',
      'category': 'RH & Paie',
      'icon': Icons.folder_shared_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': hrAccounting,
      'label': 'RH - Comptabilité',
      'category': 'RH & Paie',
      'icon': Icons.account_balance_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': hrLegalEntity,
      'label': 'RH - Entité juridique',
      'category': 'RH & Paie',
      'icon': Icons.account_balance_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': hrEstablishments,
      'label': 'RH - Établissements',
      'category': 'RH & Paie',
      'icon': Icons.apartment_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': hrManagers,
      'label': 'RH - Gestionnaires',
      'category': 'RH & Paie',
      'icon': Icons.manage_accounts_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    // 2-8. Ventes
    {
      'key': salesQuotes,
      'label': 'Ventes - Devis',
      'category': 'Ventes',
      'icon': Icons.description_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': salesOrders,
      'label': 'Ventes - Commandes',
      'category': 'Ventes',
      'icon': Icons.shopping_cart_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': salesDeliveryNotes,
      'label': 'Ventes - Bons de livraison',
      'category': 'Ventes',
      'icon': Icons.local_shipping_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': salesInvoices,
      'label': 'Ventes - Factures',
      'category': 'Ventes',
      'icon': Icons.receipt_long_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': salesExitVouchers,
      'label': 'Ventes - Bons de sortie',
      'category': 'Ventes',
      'icon': Icons.outbox_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': salesCreditNotes,
      'label': 'Ventes - Avoirs',
      'category': 'Ventes',
      'icon': Icons.assignment_return_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': salesReturnVouchers,
      'label': 'Ventes - Bons de retour',
      'category': 'Ventes',
      'icon': Icons.keyboard_return_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 9-13. Achats
    {
      'key': purchasesSupplierOrders,
      'label': 'Achats - Commandes fournisseur',
      'category': 'Achats',
      'icon': Icons.shopping_bag_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': purchasesReceivingVouchers,
      'label': 'Achats - Bons de réception',
      'category': 'Achats',
      'icon': Icons.inventory_2_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': purchasesPurchaseInvoices,
      'label': 'Achats - Factures d\'achat',
      'category': 'Achats',
      'icon': Icons.receipt_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': purchasesSupplierCreditNotes,
      'label': 'Achats - Avoirs fournisseur',
      'category': 'Achats',
      'icon': Icons.assignment_returned_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': purchasesSupplierReturns,
      'label': 'Achats - Retours fournisseur',
      'category': 'Achats',
      'icon': Icons.assignment_return_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 14. Paiements
    {
      'key': payments,
      'label': 'Paiements',
      'category': 'Finances',
      'icon': Icons.credit_card_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 15-17. Retenue à la source
    {
      'key': withholdingTax,
      'label': 'Retenue à la source',
      'category': 'Taxes',
      'icon': Icons.request_page_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': withholdingTaxSales,
      'label': 'RS vente',
      'category': 'Taxes',
      'icon': Icons.price_check_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': withholdingTaxPurchases,
      'label': 'RS achat',
      'category': 'Taxes',
      'icon': Icons.receipt_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 18-20. Trésorerie
    {
      'key': treasuryAccounts,
      'label': 'Trésorerie - Comptes',
      'category': 'Trésorerie',
      'icon': Icons.account_balance_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': treasuryTransactions,
      'label': 'Trésorerie - Transactions',
      'category': 'Trésorerie',
      'icon': Icons.sync_alt_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': treasuryChecks,
      'label': 'Trésorerie - Chèques & Traites',
      'category': 'Trésorerie',
      'icon': Icons.style_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 21-22. Contacts
    {
      'key': customers,
      'label': 'Clients',
      'category': 'Contacts',
      'icon': Icons.people_outline,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': suppliers,
      'label': 'Fournisseurs',
      'category': 'Contacts',
      'icon': Icons.storefront_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 23-24. Articles
    {
      'key': productsList,
      'label': 'Articles - Liste des articles',
      'category': 'Articles',
      'icon': Icons.inventory_2_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': productsSettings,
      'label': 'Articles - Paramètres des articles',
      'category': 'Articles',
      'icon': Icons.tune_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 25-31. Stock
    {
      'key': stockOverview,
      'label': 'Stock - Vue d\'ensemble',
      'category': 'Stock',
      'icon': Icons.all_inbox_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': stockMovements,
      'label': 'Stock - Mouvements',
      'category': 'Stock',
      'icon': Icons.compare_arrows_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': stockEntryVouchers,
      'label': 'Stock - Bons d\'entrée',
      'category': 'Stock',
      'icon': Icons.move_to_inbox_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': stockWithdrawalVouchers,
      'label': 'Stock - Bons de prélèvement',
      'category': 'Stock',
      'icon': Icons.unarchive_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': stockTransferVouchers,
      'label': 'Stock - Bons de transfert',
      'category': 'Stock',
      'icon': Icons.swap_horiz_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': stockInventorySheets,
      'label': 'Stock - Fiche d\'inventaire',
      'category': 'Stock',
      'icon': Icons.assignment_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': stockWarehouses,
      'label': 'Stock - Entrepôts',
      'category': 'Stock',
      'icon': Icons.warehouse_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // Production
    {
      'key': productionDashboard,
      'label': 'Production - Tableau de bord',
      'category': 'Production',
      'icon': Icons.dashboard_customize_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': productionOrders,
      'label': 'Production - Ordres de fabrication',
      'category': 'Production',
      'icon': Icons.assignment_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': productionBoms,
      'label': 'Production - Nomenclatures (BOM)',
      'category': 'Production',
      'icon': Icons.account_tree_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': productionPlanning,
      'label': 'Production - Planification',
      'category': 'Production',
      'icon': Icons.calendar_month_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': productionCosts,
      'label': 'Production - Suivi des coûts',
      'category': 'Production',
      'icon': Icons.price_check_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': productionQuality,
      'label': 'Production - Contrôle qualité',
      'category': 'Production',
      'icon': Icons.verified_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': productionReports,
      'label': 'Production - Rapports de rendement',
      'category': 'Production',
      'icon': Icons.bar_chart_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    {
      'key': productionWorkcenters,
      'label': 'Production - Postes de travail',
      'category': 'Production',
      'icon': Icons.precision_manufacturing_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.full,
    },
    // 32. Projets
    {
      'key': projects,
      'label': 'Projets',
      'category': 'Projets',
      'icon': Icons.folder_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 33-38. Paramètres
    {
      'key': settingsAppModules,
      'label': 'Paramètres - Modules de l\'application',
      'category': 'Paramètres',
      'icon': Icons.widgets_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': settingsPersonalInfo,
      'label': 'Paramètres - Informations personnelles',
      'category': 'Paramètres',
      'icon': Icons.badge_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': settingsCompanyInfo,
      'label': 'Paramètres - Informations de la société',
      'category': 'Paramètres',
      'icon': Icons.business_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': settingsDocNumbering,
      'label': 'Paramètres - Numérotation des documents',
      'category': 'Paramètres',
      'icon': Icons.format_list_numbered_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': settingsDocTemplates,
      'label': 'Paramètres - Modèles de documents',
      'category': 'Paramètres',
      'icon': Icons.description_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': settingsCustomFields,
      'label': 'Paramètres - Champs personnalisés',
      'category': 'Paramètres',
      'icon': Icons.tune_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': settingsCustomStatuses,
      'label': 'Paramètres - Statuts personnalisés',
      'category': 'Paramètres',
      'icon': Icons.bookmarks_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    {
      'key': importExport,
      'label': 'Import / Export des données',
      'category': 'Paramètres',
      'icon': Icons.sync_alt_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 39. Corbeille
    {
      'key': trash,
      'label': 'Corbeille',
      'category': 'Paramètres',
      'icon': Icons.delete_outline_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 40. Traçabilité Utilisateurs
    {
      'key': userTracking,
      'label': 'Traçabilité Utilisateurs',
      'category': 'Paramètres',
      'icon': Icons.manage_history_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
    },
    // 41. Gestion des utilisateurs
    {
      'key': userManagement,
      'label': 'Gestion des utilisateurs',
      'category': 'Administration',
      'icon': Icons.manage_accounts_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.empty,
      'adminOnly': true,
    },
  ];

  static Map<String, UserResourcePermission> getAdminDefaultPermissions() {
    final map = <String, UserResourcePermission>{};
    for (final res in allResources) {
      map[res['key'] as String] = UserResourcePermission.full;
    }
    return map;
  }

  static Map<String, UserResourcePermission> getCollaboratorDefaultPermissions() {
    final map = <String, UserResourcePermission>{};
    for (final res in allResources) {
      map[res['key'] as String] = res['defaultCollab'] as UserResourcePermission;
    }
    return map;
  }
}

/// Represents a user within the enterprise management system.
class EnterpriseUserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String role; // 'admin' or 'collaborator'
  final List<String> enterprises;
  final Map<String, UserResourcePermission> permissions;
  final bool isOwner;
  final String? addedBy;
  final DateTime? addedAt;
  final bool isActive;

  EnterpriseUserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.role = 'collaborator',
    this.enterprises = const [],
    this.permissions = const {},
    this.isOwner = false,
    this.addedBy,
    this.addedAt,
    this.isActive = true,
  });

  bool get isAdmin => role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrateur' || isOwner;
  String get displayRole => isAdmin ? 'Administrateur' : 'Collaborateur';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'enterprises': enterprises,
        'permissions': permissions.map((k, v) => MapEntry(k, v.toMap())),
        'isOwner': isOwner,
        'addedBy': addedBy,
        'addedAt': addedAt?.toIso8601String(),
        'isActive': isActive,
      };

  factory EnterpriseUserModel.fromMap(Map<String, dynamic> map, {bool isOwner = false}) {
    Map<String, UserResourcePermission> parsedPermissions = {};
    if (map['permissions'] != null && map['permissions'] is Map) {
      final pMap = Map<String, dynamic>.from(map['permissions']);
      pMap.forEach((key, value) {
        if (value is Map) {
          parsedPermissions[key] = UserResourcePermission.fromMap(Map<String, dynamic>.from(value));
        }
      });
    }

    return EnterpriseUserModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Utilisateur',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString(),
      role: map['role']?.toString() ?? 'collaborator',
      enterprises: map['enterprises'] != null ? List<String>.from(map['enterprises']) : [],
      permissions: parsedPermissions,
      isOwner: isOwner || (map['isOwner'] == true),
      addedBy: map['addedBy']?.toString(),
      addedAt: map['addedAt'] != null
          ? DateTime.tryParse(map['addedAt'].toString())
          : null,
      isActive: map['isActive'] != false,
    );
  }

  EnterpriseUserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    List<String>? enterprises,
    Map<String, UserResourcePermission>? permissions,
    bool? isOwner,
    String? addedBy,
    DateTime? addedAt,
    bool? isActive,
  }) {
    return EnterpriseUserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      enterprises: enterprises ?? this.enterprises,
      permissions: permissions ?? this.permissions,
      isOwner: isOwner ?? this.isOwner,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
