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

/// Predefined list of 35 menu resources for user permissions in the app.
class UserPermissionResources {
  // 1. Dashboard
  static const String dashboard = 'dashboard';

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

  // 32. Projects
  static const String projects = 'projects';

  // 33-34. Settings (Paramètres)
  static const String settingsCompanyInfo = 'settings_company_info';
  static const String settingsDocTemplates = 'settings_doc_templates';

  // 35. User Management (Admin Only)
  static const String userManagement = 'user_management';

  static const List<Map<String, dynamic>> allResources = [
    // 1. Tableau de bord
    {
      'key': dashboard,
      'label': 'Tableau de bord',
      'category': 'Général',
      'icon': Icons.dashboard_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    // 2-8. Ventes
    {
      'key': salesQuotes,
      'label': 'Ventes - Devis',
      'category': 'Ventes',
      'icon': Icons.description_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': salesOrders,
      'label': 'Ventes - Commandes',
      'category': 'Ventes',
      'icon': Icons.shopping_cart_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': salesDeliveryNotes,
      'label': 'Ventes - Bons de livraison',
      'category': 'Ventes',
      'icon': Icons.local_shipping_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': salesInvoices,
      'label': 'Ventes - Factures',
      'category': 'Ventes',
      'icon': Icons.receipt_long_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': salesExitVouchers,
      'label': 'Ventes - Bons de sortie',
      'category': 'Ventes',
      'icon': Icons.outbox_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': salesCreditNotes,
      'label': 'Ventes - Avoirs',
      'category': 'Ventes',
      'icon': Icons.assignment_return_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': salesReturnVouchers,
      'label': 'Ventes - Bons de retour',
      'category': 'Ventes',
      'icon': Icons.keyboard_return_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    // 9-13. Achats
    {
      'key': purchasesSupplierOrders,
      'label': 'Achats - Commandes fournisseur',
      'category': 'Achats',
      'icon': Icons.shopping_bag_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': purchasesReceivingVouchers,
      'label': 'Achats - Bons de réception',
      'category': 'Achats',
      'icon': Icons.inventory_2_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': purchasesPurchaseInvoices,
      'label': 'Achats - Factures d\'achat',
      'category': 'Achats',
      'icon': Icons.receipt_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': purchasesSupplierCreditNotes,
      'label': 'Achats - Avoirs fournisseur',
      'category': 'Achats',
      'icon': Icons.assignment_returned_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': purchasesSupplierReturns,
      'label': 'Achats - Retours fournisseur',
      'category': 'Achats',
      'icon': Icons.assignment_return_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    // 14. Paiements
    {
      'key': payments,
      'label': 'Paiements',
      'category': 'Finances',
      'icon': Icons.credit_card_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    // 15-17. Retenue à la source
    {
      'key': withholdingTax,
      'label': 'Retenue à la source',
      'category': 'Taxes',
      'icon': Icons.request_page_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': withholdingTaxSales,
      'label': 'RS vente',
      'category': 'Taxes',
      'icon': Icons.price_check_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': withholdingTaxPurchases,
      'label': 'RS achat',
      'category': 'Taxes',
      'icon': Icons.receipt_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    // 18-20. Trésorerie
    {
      'key': treasuryAccounts,
      'label': 'Trésorerie - Comptes',
      'category': 'Trésorerie',
      'icon': Icons.account_balance_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': treasuryTransactions,
      'label': 'Trésorerie - Transactions',
      'category': 'Trésorerie',
      'icon': Icons.sync_alt_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': treasuryChecks,
      'label': 'Trésorerie - Chèques & Traites',
      'category': 'Trésorerie',
      'icon': Icons.style_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    // 21-22. Contacts
    {
      'key': customers,
      'label': 'Clients',
      'category': 'Contacts',
      'icon': Icons.people_outline,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': suppliers,
      'label': 'Fournisseurs',
      'category': 'Contacts',
      'icon': Icons.storefront_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    // 23-24. Articles
    {
      'key': productsList,
      'label': 'Articles - Liste des articles',
      'category': 'Articles',
      'icon': Icons.inventory_2_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': productsSettings,
      'label': 'Articles - Paramètres des articles',
      'category': 'Articles',
      'icon': Icons.tune_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    // 25-31. Stock
    {
      'key': stockOverview,
      'label': 'Stock - Vue d\'ensemble',
      'category': 'Stock',
      'icon': Icons.all_inbox_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': stockMovements,
      'label': 'Stock - Mouvements',
      'category': 'Stock',
      'icon': Icons.compare_arrows_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': stockEntryVouchers,
      'label': 'Stock - Bons d\'entrée',
      'category': 'Stock',
      'icon': Icons.move_to_inbox_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': stockWithdrawalVouchers,
      'label': 'Stock - Bons de prélèvement',
      'category': 'Stock',
      'icon': Icons.unarchive_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': stockTransferVouchers,
      'label': 'Stock - Bons de transfert',
      'category': 'Stock',
      'icon': Icons.swap_horiz_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    {
      'key': stockInventorySheets,
      'label': 'Stock - Fiche d\'inventaire',
      'category': 'Stock',
      'icon': Icons.assignment_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': stockWarehouses,
      'label': 'Stock - Entrepôts',
      'category': 'Stock',
      'icon': Icons.warehouse_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    // 32. Projets
    {
      'key': projects,
      'label': 'Projets',
      'category': 'Projets',
      'icon': Icons.folder_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.standardCollaborator,
    },
    // 33-34. Paramètres
    {
      'key': settingsCompanyInfo,
      'label': 'Paramètres - Informations de la société',
      'category': 'Paramètres',
      'icon': Icons.business_outlined,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    {
      'key': settingsDocTemplates,
      'label': 'Paramètres - Modèles de documents',
      'category': 'Paramètres',
      'icon': Icons.description_rounded,
      'defaultAdmin': UserResourcePermission.full,
      'defaultCollab': UserResourcePermission.readOnly,
    },
    // 35. Gestion des utilisateurs
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
