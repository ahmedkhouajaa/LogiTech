import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/sidebar_menu.dart';
import 'enterprise_service.dart';

/// Represents a single sub-module configuration item.
class ModuleItemDefinition {
  final AppModule module;
  final String title;
  final IconData icon;

  const ModuleItemDefinition({
    required this.module,
    required this.title,
    required this.icon,
  });
}

/// Represents a main group card (e.g. Ventes, Achats, Stock, etc.).
class ModuleGroupDefinition {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final List<ModuleItemDefinition> subModules;

  const ModuleGroupDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.subModules,
  });
}

/// Service managing the activation and deactivation of application modules and sub-modules.
/// Provides real-time synchronization with Firestore and local persistence in SharedPreferences.
class AppModulesService {
  static final AppModulesService instance = AppModulesService._();
  AppModulesService._() {
    _initModuleToGroupMap();
    _initEnterpriseListener();
  }

  /// Change notifier for real-time UI updates across Desktop sidebar, Mobile drawer, and Shell screens.
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  /// Map of group activation statuses (key -> isEnabled)
  final Map<String, bool> _groupEnabled = {};

  /// Map of individual module activation statuses (module -> isEnabled)
  final Map<AppModule, bool> _moduleEnabled = {};

  /// Reverse lookup: AppModule -> Group key
  final Map<AppModule, String> _moduleToGroup = {};

  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  String? _currentLoadedEnterpriseId;
  bool _isInitialized = false;

  /// Definitions for the 10 main business modules matching the user specifications & mockup.
  static final List<ModuleGroupDefinition> groupDefinitions = [
    ModuleGroupDefinition(
      key: 'ventes',
      title: 'Ventes',
      description: 'Devis, commandes, factures, bons de livraison et suivi des ventes',
      icon: Icons.trending_up_rounded,
      iconBgColor: const Color(0xFFEFF6FF),
      iconColor: const Color(0xFF2563EB),
      subModules: [
        ModuleItemDefinition(module: AppModule.quotes, title: 'Devis', icon: Icons.description_outlined),
        ModuleItemDefinition(module: AppModule.customerOrders, title: 'Commandes client', icon: Icons.shopping_cart_outlined),
        ModuleItemDefinition(module: AppModule.deliveryNotes, title: 'Bons de livraison', icon: Icons.local_shipping_outlined),
        ModuleItemDefinition(module: AppModule.invoices, title: 'Factures', icon: Icons.receipt_outlined),
        ModuleItemDefinition(module: AppModule.exitVouchers, title: 'Bons de sortie', icon: Icons.output_rounded),
        ModuleItemDefinition(module: AppModule.creditNotes, title: 'Avoirs client', icon: Icons.undo_rounded),
        ModuleItemDefinition(module: AppModule.returnVouchers, title: 'Bons de retour', icon: Icons.assignment_return_outlined),
      ],
    ),
    ModuleGroupDefinition(
      key: 'achats',
      title: 'Achats',
      description: 'Commandes fournisseurs, réceptions, factures d\'achat et dépenses',
      icon: Icons.shopping_bag_rounded,
      iconBgColor: const Color(0xFFECFDF5),
      iconColor: const Color(0xFF059669),
      subModules: [
        ModuleItemDefinition(module: AppModule.supplierOrders, title: 'Commandes fournisseur', icon: Icons.list_alt_rounded),
        ModuleItemDefinition(module: AppModule.receivingVouchers, title: 'Bons de réception', icon: Icons.inbox_rounded),
        ModuleItemDefinition(module: AppModule.purchaseInvoices, title: 'Factures d\'achat', icon: Icons.receipt_long_rounded),
        ModuleItemDefinition(module: AppModule.supplierCreditNotes, title: 'Avoirs fournisseur', icon: Icons.replay_rounded),
        ModuleItemDefinition(module: AppModule.supplierReturns, title: 'Retours fournisseur', icon: Icons.assignment_return_rounded),
      ],
    ),
    ModuleGroupDefinition(
      key: 'paiements',
      title: 'Paiements',
      description: 'Gestion des encaissements, décaissements et rapprochements',
      icon: Icons.payments_rounded,
      iconBgColor: const Color(0xFFF0FDF4),
      iconColor: const Color(0xFF16A34A),
      subModules: [
        ModuleItemDefinition(module: AppModule.payments, title: 'Paiements & Règlements', icon: Icons.payments_rounded),
      ],
    ),
    ModuleGroupDefinition(
      key: 'tresorerie',
      title: 'Trésorerie',
      description: 'Comptes bancaires, caisse, prévisions et flux financiers',
      icon: Icons.account_balance_rounded,
      iconBgColor: const Color(0xFFFAF5FF),
      iconColor: const Color(0xFF9333EA),
      subModules: [
        ModuleItemDefinition(module: AppModule.accounts, title: 'Comptes bancaires & caisses', icon: Icons.account_balance_rounded),
        ModuleItemDefinition(module: AppModule.transactions, title: 'Transactions financières', icon: Icons.swap_horiz_rounded),
        ModuleItemDefinition(module: AppModule.checksTraites, title: 'Chèques & Traites', icon: Icons.note_rounded),
      ],
    ),
    ModuleGroupDefinition(
      key: 'suppliers',
      title: 'Fournisseurs',
      description: 'Gestion de la base fournisseurs, conditions et historique',
      icon: Icons.factory_rounded,
      iconBgColor: const Color(0xFFFFF7ED),
      iconColor: const Color(0xFFEA580C),
      subModules: [
        ModuleItemDefinition(module: AppModule.suppliers, title: 'Fiches fournisseurs', icon: Icons.factory_rounded),
      ],
    ),
    ModuleGroupDefinition(
      key: 'customers',
      title: 'Clients',
      description: 'Gestion du portefeuille client, contacts et segmentation',
      icon: Icons.people_rounded,
      iconBgColor: const Color(0xFFF0F9FF),
      iconColor: const Color(0xFF0284C7),
      subModules: [
        ModuleItemDefinition(module: AppModule.customers, title: 'Fiches clients', icon: Icons.people_rounded),
      ],
    ),
    ModuleGroupDefinition(
      key: 'articles',
      title: 'Articles',
      description: 'Catalogue produits, services, tarifs et catégories',
      icon: Icons.inventory_2_rounded,
      iconBgColor: const Color(0xFFF0FDFA),
      iconColor: const Color(0xFF0D9488),
      subModules: [
        ModuleItemDefinition(module: AppModule.products, title: 'Catalogue des articles', icon: Icons.inventory_2_rounded),
        ModuleItemDefinition(module: AppModule.productSettings, title: 'Paramètres des articles', icon: Icons.tune_rounded),
      ],
    ),
    ModuleGroupDefinition(
      key: 'stock',
      title: 'Stock',
      description: 'Niveaux de stock, mouvements, alertes et inventaires',
      icon: Icons.warehouse_rounded,
      iconBgColor: const Color(0xFFEEF2FF),
      iconColor: const Color(0xFF4F46E5),
      subModules: [
        ModuleItemDefinition(module: AppModule.stockDashboard, title: 'Vue d\'ensemble du stock', icon: Icons.dashboard_rounded),
        ModuleItemDefinition(module: AppModule.stockMovements, title: 'Mouvements de stock', icon: Icons.swap_horiz_rounded),
        ModuleItemDefinition(module: AppModule.stockEntry, title: 'Bons d\'entrée', icon: Icons.add_box_rounded),
        ModuleItemDefinition(module: AppModule.stockWithdrawal, title: 'Bons de prélèvement', icon: Icons.outbox_rounded),
        ModuleItemDefinition(module: AppModule.stockTransfer, title: 'Bons de transfert', icon: Icons.sync_alt_rounded),
        ModuleItemDefinition(module: AppModule.inventorySheet, title: 'Fiches d\'inventaire', icon: Icons.fact_check_rounded),
        ModuleItemDefinition(module: AppModule.warehouses, title: 'Entrepôts', icon: Icons.store_rounded),
      ],
    ),
    ModuleGroupDefinition(
      key: 'projects',
      title: 'Projets',
      description: 'Suivi des projets, rentabilité, temps passé et jalons',
      icon: Icons.folder_rounded,
      iconBgColor: const Color(0xFFFFFBEB),
      iconColor: const Color(0xFFD97706),
      subModules: [
        ModuleItemDefinition(module: AppModule.projects, title: 'Projets & Chantiers', icon: Icons.folder_rounded),
      ],
    ),
    ModuleGroupDefinition(
      key: 'retenue_source',
      title: 'Retenue à la source',
      description: 'Gestion des certificats de retenue à la source (Ventes & Achats)',
      icon: Icons.request_quote_rounded,
      iconBgColor: const Color(0xFFFDF4FF),
      iconColor: const Color(0xFFC026D3),
      subModules: [
        ModuleItemDefinition(module: AppModule.withholdingTaxSales, title: 'Retenue à la source (Vente)', icon: Icons.description_rounded),
        ModuleItemDefinition(module: AppModule.withholdingTaxPurchase, title: 'Retenue à la source (Achat)', icon: Icons.receipt_rounded),
      ],
    ),
  ];

  void _initModuleToGroupMap() {
    for (final group in groupDefinitions) {
      for (final sub in group.subModules) {
        _moduleToGroup[sub.module] = group.key;
      }
    }
  }

  void _initEnterpriseListener() {
    EnterpriseService.instance.enterpriseStream.listen((enterpriseId) {
      if (enterpriseId != null && enterpriseId.isNotEmpty) {
        loadConfig(enterpriseId);
      }
    });

    final currentId = EnterpriseService.instance.currentEnterpriseId;
    if (currentId != null && currentId.isNotEmpty) {
      loadConfig(currentId);
    }
  }

  /// System modules that cannot and should not be disabled.
  bool isSystemModule(AppModule module) {
    return module == AppModule.dashboard ||
        module == AppModule.settings ||
        module == AppModule.personalInfo ||
        module == AppModule.companyInfo ||
        module == AppModule.documentNumbering ||
        module == AppModule.documentTemplates ||
        module == AppModule.customFields ||
        module == AppModule.customStatuses ||
        module == AppModule.appModulesSettings ||
        module == AppModule.userManagement ||
        module == AppModule.importExport ||
        module == AppModule.support;
  }

  /// Check if a group is enabled.
  bool isGroupEnabled(String groupKey) {
    // Retenue source alias support
    if (groupKey == 'retenue') {
      groupKey = 'retenue_source';
    }
    return _groupEnabled[groupKey] ?? true;
  }

  /// Check if an individual module is enabled.
  bool isModuleEnabled(AppModule module) {
    if (isSystemModule(module)) return true;

    final groupKey = _moduleToGroup[module];
    if (groupKey != null && !isGroupEnabled(groupKey)) {
      return false;
    }

    return _moduleEnabled[module] ?? true;
  }

  /// Set the enabled state of a main group.
  void setGroupEnabled(String groupKey, bool enabled) {
    if (groupKey == 'retenue') groupKey = 'retenue_source';
    _groupEnabled[groupKey] = enabled;
    _notify();
  }

  /// Set the enabled state of a specific sub-module.
  void setModuleEnabled(AppModule module, bool enabled) {
    _moduleEnabled[module] = enabled;
    // If enabling a sub-module, automatically ensure the parent group is active
    if (enabled) {
      final groupKey = _moduleToGroup[module];
      if (groupKey != null) {
        _groupEnabled[groupKey] = true;
      }
    }
    _notify();
  }

  /// Batch set all sub-modules in a group to enabled or disabled.
  void setAllInGroup(String groupKey, bool enabled) {
    if (groupKey == 'retenue') groupKey = 'retenue_source';
    _groupEnabled[groupKey] = enabled;
    final group = groupDefinitions.firstWhere((g) => g.key == groupKey, orElse: () => groupDefinitions.first);
    for (final sub in group.subModules) {
      _moduleEnabled[sub.module] = enabled;
    }
    _notify();
  }

  void _notify() {
    notifier.value++;
  }

  /// Returns the count of enabled sub-modules in a group.
  int getEnabledCountInGroup(String groupKey) {
    if (groupKey == 'retenue') groupKey = 'retenue_source';
    final group = groupDefinitions.firstWhere((g) => g.key == groupKey, orElse: () => groupDefinitions.first);
    return group.subModules.where((s) => _moduleEnabled[s.module] ?? true).length;
  }

  /// Load configuration from SharedPreferences cache and Firestore.
  Future<void> loadConfig(String enterpriseId) async {
    if (_currentLoadedEnterpriseId == enterpriseId && _isInitialized) return;
    _currentLoadedEnterpriseId = enterpriseId;

    // 1. Load from SharedPreferences cache first for instant UI response
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString('modules_config_$enterpriseId');
      if (cacheStr != null && cacheStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(cacheStr);
        _applyConfigMap(decoded);
      }
    } catch (e) {
      debugPrint('[AppModulesService] Error reading local cache: $e');
    }

    _isInitialized = true;
    _notify();

    // 2. Set up real-time listener to Firestore
    _firestoreSub?.cancel();
    _firestoreSub = FirebaseFirestore.instance
        .collection('enterprises')
        .doc(enterpriseId)
        .collection('settings')
        .doc('modules_config')
        .snapshots()
        .listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        _applyConfigMap(data);
        _notify();
        // Update local cache
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('modules_config_$enterpriseId', jsonEncode(data));
        });
      }
    }, onError: (err) {
      debugPrint('[AppModulesService] Firestore snapshot error: $err');
    });
  }

  void _applyConfigMap(Map<String, dynamic> data) {
    if (data['groups'] is Map) {
      final groups = Map<String, dynamic>.from(data['groups'] as Map);
      for (final entry in groups.entries) {
        _groupEnabled[entry.key] = entry.value == true;
      }
    }

    if (data['modules'] is Map) {
      final modules = Map<String, dynamic>.from(data['modules'] as Map);
      for (final entry in modules.entries) {
        try {
          final mod = AppModule.values.firstWhere((m) => m.name == entry.key);
          _moduleEnabled[mod] = entry.value == true;
        } catch (_) {}
      }
    }
  }

  /// Persist current configuration to SharedPreferences and Firestore.
  Future<void> saveConfig([String? targetEnterpriseId]) async {
    final eid = targetEnterpriseId ??
        EnterpriseService.instance.currentEnterpriseId ??
        _currentLoadedEnterpriseId;
    if (eid == null || eid.isEmpty) return;

    final Map<String, dynamic> payload = {
      'groups': Map<String, bool>.from(_groupEnabled),
      'modules': {
        for (var entry in _moduleEnabled.entries) entry.key.name: entry.value,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Cache locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('modules_config_$eid', jsonEncode({
        'groups': payload['groups'],
        'modules': payload['modules'],
      }));
    } catch (e) {
      debugPrint('[AppModulesService] Error caching config locally: $e');
    }

    // Persist to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(eid)
          .collection('settings')
          .doc('modules_config')
          .set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AppModulesService] Error saving to Firestore: $e');
      rethrow;
    }
  }
}
