import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_management_model.dart';
import '../widgets/sidebar_menu.dart' show AppModule;
import '../utils/constants.dart';
import 'enterprise_service.dart';
import '../utils/firestore_safe_helper.dart';

/// Singleton service that manages active user permissions for the current enterprise context.
class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  bool _isLoaded = false;
  bool _isAdmin = false;
  bool _isOwner = false;
  String _role = 'collaborator';
  String _userName = '';
  String _userEmail = '';
  Map<String, UserResourcePermission> _permissions = {};

  final ValueNotifier<bool> permissionsNotifier = ValueNotifier<bool>(false);

  bool get isLoaded => _isLoaded;
  bool get isAdmin => (_isAdmin || _isOwner) && _isLoaded;
  bool get isOwner => _isOwner && _isLoaded;
  String get role => _role;
  String get userEmail => _userEmail;
  String get userName {
    if (_userName.isNotEmpty) return _userName;
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser?.displayName?.isNotEmpty == true) return fbUser!.displayName!;
    if (fbUser?.email?.isNotEmpty == true) {
      final prefix = fbUser!.email!.split('@').first;
      return prefix.isNotEmpty ? prefix[0].toUpperCase() + prefix.substring(1) : prefix;
    }
    return _isAdmin ? 'Admin' : 'Utilisateur';
  }
  String get userInitial {
    final name = userName.trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'U';
  }
  Map<String, UserResourcePermission> get permissions => Map.unmodifiable(_permissions);

  /// Reset in-memory permissions state on logout
  void reset() {
    debugPrint('[PermissionService.reset] Resetting in-memory permissions state.');
    _isLoaded = false;
    _isAdmin = false;
    _isOwner = false;
    _role = 'collaborator';
    _userName = '';
    _userEmail = '';
    _permissions = {};
    permissionsNotifier.value = !permissionsNotifier.value;
  }

  /// Helper for testing to inject specific permission scenarios
  void setPermissionsForTesting({
    required bool isAdmin,
    required bool isOwner,
    required String role,
    required Map<String, UserResourcePermission> permissions,
    bool isLoaded = true,
  }) {
    _isLoaded = isLoaded;
    _isAdmin = isAdmin;
    _isOwner = isOwner;
    _role = role;
    _permissions = Map.from(permissions);
    permissionsNotifier.value = !permissionsNotifier.value;
  }

  /// Load user permissions for the specified or current enterprise from Firestore
  Future<void> loadPermissions({String? enterpriseId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? eid = enterpriseId ?? EnterpriseService.instance.currentEnterpriseId;

    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser?.displayName?.isNotEmpty == true) {
      _userName = fbUser!.displayName!;
    }
    if (fbUser?.email?.isNotEmpty == true) {
      _userEmail = fbUser!.email!;
    }

    debugPrint('[PermissionService.loadPermissions] START loading permissions for UID: $uid, Email: $_userEmail, targetEnterpriseId: $eid');

    if (uid == null) {
      _isLoaded = false;
      _isAdmin = false;
      _isOwner = false;
      _role = 'collaborator';
      _permissions = {};
      debugPrint('[PermissionService.loadPermissions] No authenticated user. State cleared.');
      permissionsNotifier.value = !permissionsNotifier.value;
      return;
    }

    try {
      // 1. Fetch user doc for profile name & enterprise roles
      final uData = await FirestoreSafeHelper.getDocData(
        FirebaseFirestore.instance.collection('users'),
        uid,
      ) ?? {};

      debugPrint('[PermissionService.loadPermissions] Step 1: User doc (users/$uid) -> found: ${uData.isNotEmpty}, role: ${uData['role']}, currentEnterpriseId: ${uData['currentEnterpriseId']}, enterprises: ${uData['enterprises']}');

      if (uData.isNotEmpty) {
        if (uData['name']?.toString().isNotEmpty == true) {
          _userName = uData['name'].toString();
        }
        if (uData['email']?.toString().isNotEmpty == true) {
          _userEmail = uData['email'].toString();
        }
      }

      // If eid is missing, try to resolve from user document or enterprises list
      if (eid == null || eid.isEmpty) {
        if (uData['currentEnterpriseId']?.toString().isNotEmpty == true) {
          eid = uData['currentEnterpriseId'].toString();
        } else if (uData['enterprises'] is List && (uData['enterprises'] as List).isNotEmpty) {
          eid = (uData['enterprises'] as List).first.toString();
        } else if (EnterpriseService.instance.enterprises.isNotEmpty) {
          eid = EnterpriseService.instance.enterprises.first.id;
        }
      }

      if (eid == null || eid.isEmpty) {
        _isLoaded = true;
        _isAdmin = false;
        _isOwner = false;
        _role = 'collaborator';
        _permissions = {};
        debugPrint('[PermissionService.loadPermissions] No active enterprise found for user $uid. ZERO permissions granted.');
        permissionsNotifier.value = !permissionsNotifier.value;
        return;
      }

      debugPrint('[PermissionService.loadPermissions] Step 2: Querying enterprise doc (enterprises/$eid)...');

      // 2. Check enterprise document for ownership & members list
      final entData = await FirestoreSafeHelper.getDocData(
        FirebaseFirestore.instance.collection('enterprises'),
        eid,
      );

      if (entData != null) {
        final ownerId = entData['owner_id']?.toString() ??
            entData['userId']?.toString() ??
            entData['ownerId']?.toString() ??
            entData['createdBy']?.toString() ??
            '';

        debugPrint('[PermissionService.loadPermissions] Step 2: Enterprise $eid loaded -> ownerId: $ownerId, isOwnerMatch: ${ownerId.isNotEmpty && ownerId == uid}');

        // Check if user is the enterprise creator / owner
        if (ownerId.isNotEmpty && ownerId == uid) {
          _isLoaded = true;
          _isOwner = true;
          _isAdmin = true;
          _role = 'admin';
          _permissions = UserPermissionResources.getAdminDefaultPermissions();
          debugPrint('[PermissionService.loadPermissions] User $uid is OWNER of enterprise $eid -> FULL ADMIN access granted (all 36 resources).');
          permissionsNotifier.value = !permissionsNotifier.value;
          return;
        }

        final members = entData['members'];
        if (members is List && members.isNotEmpty) {
          debugPrint('[PermissionService.loadPermissions] Step 2: Scanning ${members.length} members in enterprise $eid...');
          for (final m in members) {
            if (m is Map) {
              final mUid = m['uid']?.toString() ?? '';
              final mEmail = m['email']?.toString().toLowerCase().trim() ?? '';
              final matchUid = mUid.isNotEmpty && mUid == uid;
              final matchEmail = mEmail.isNotEmpty && _userEmail.isNotEmpty && mEmail == _userEmail.toLowerCase().trim();

              if (matchUid || matchEmail) {
                if (m['name']?.toString().isNotEmpty == true) {
                  _userName = m['name'].toString();
                }
                final r = m['role']?.toString().toLowerCase().trim() ?? '';
                final isMemOwner = m['isOwner'] == true;
                final isMemAdmin = isMemOwner || r == 'admin' || r == 'administrateur';

                debugPrint('[PermissionService.loadPermissions] Member match found! uid: $mUid, email: $mEmail, role: $r, isMemAdmin: $isMemAdmin');

                if (isMemAdmin) {
                  _isLoaded = true;
                  _isOwner = isMemOwner;
                  _isAdmin = true;
                  _role = 'admin';
                  _permissions = UserPermissionResources.getAdminDefaultPermissions();
                  debugPrint('[PermissionService.loadPermissions] User $uid is MEMBER ADMIN of enterprise $eid -> FULL ADMIN access granted.');
                } else {
                  _isLoaded = true;
                  _isOwner = false;
                  _isAdmin = false;
                  _role = 'collaborator';

                  final parsed = <String, UserResourcePermission>{};
                  if (m['permissions'] is Map) {
                    final pMap = Map<String, dynamic>.from(m['permissions']);
                    for (final res in UserPermissionResources.allResources) {
                      final k = res['key'] as String;
                      if (pMap.containsKey(k) && pMap[k] is Map) {
                        parsed[k] = UserResourcePermission.fromMap(Map<String, dynamic>.from(pMap[k]));
                      } else {
                        parsed[k] = UserResourcePermission.empty;
                      }
                    }
                  } else {
                    // Empty or null permissions -> strictly NO PERMISSIONS (all false)
                    for (final res in UserPermissionResources.allResources) {
                      parsed[res['key'] as String] = UserResourcePermission.empty;
                    }
                  }
                  _permissions = parsed;
                  final readableList = _permissions.entries.where((e) => e.value.read).map((e) => e.key).toList();
                  debugPrint('[PermissionService.loadPermissions] User $uid is COLLABORATOR in enterprise $eid with ${readableList.length}/36 readable resources: $readableList');
                }

                permissionsNotifier.value = !permissionsNotifier.value;
                return;
              }
            }
          }
        }
      }

      // 3. Fallback: Check user profile doc users/{uid} for enterpriseRoles[eid]
      if (uData.isNotEmpty) {
        final entRoles = uData['enterpriseRoles'];
        debugPrint('[PermissionService.loadPermissions] Step 3: Checking users/$uid enterpriseRoles for $eid -> found: ${entRoles is Map && entRoles[eid] is Map}');
        if (entRoles is Map && entRoles[eid] is Map) {
          final info = Map<String, dynamic>.from(entRoles[eid]);
          final r = info['role']?.toString().toLowerCase().trim() ?? '';
          final isRoleAdmin = r == 'admin' || r == 'administrateur' || info['isOwner'] == true;

          if (isRoleAdmin) {
            _isLoaded = true;
            _isOwner = info['isOwner'] == true;
            _isAdmin = true;
            _role = 'admin';
            _permissions = UserPermissionResources.getAdminDefaultPermissions();
            debugPrint('[PermissionService.loadPermissions] User $uid resolved as ADMIN from user.enterpriseRoles[$eid].');
          } else {
            _isLoaded = true;
            _isAdmin = false;
            _isOwner = false;
            _role = 'collaborator';
            final parsed = <String, UserResourcePermission>{};
            if (info['permissions'] is Map) {
              final pMap = Map<String, dynamic>.from(info['permissions']);
              for (final res in UserPermissionResources.allResources) {
                final k = res['key'] as String;
                if (pMap.containsKey(k) && pMap[k] is Map) {
                  parsed[k] = UserResourcePermission.fromMap(Map<String, dynamic>.from(pMap[k]));
                } else {
                  parsed[k] = UserResourcePermission.empty;
                }
              }
            } else {
              // Empty or null permissions -> strictly NO PERMISSIONS (all false)
              for (final res in UserPermissionResources.allResources) {
                parsed[res['key'] as String] = UserResourcePermission.empty;
              }
            }
            _permissions = parsed;
            final readableList = _permissions.entries.where((e) => e.value.read).map((e) => e.key).toList();
            debugPrint('[PermissionService.loadPermissions] User $uid resolved as COLLABORATOR from user.enterpriseRoles[$eid] with ${readableList.length}/36 readable resources: $readableList');
          }

          permissionsNotifier.value = !permissionsNotifier.value;
          return;
        }
      }

      // 4. If user has no membership in this enterprise, deny all access
      _isLoaded = true;
      _isAdmin = false;
      _isOwner = false;
      _role = 'collaborator';
      _permissions = {};
      debugPrint('[PermissionService.loadPermissions] User $uid has NO active membership or roles in enterprise $eid -> ZERO permissions granted.');
      permissionsNotifier.value = !permissionsNotifier.value;
    } catch (e) {
      debugPrint('[PermissionService.loadPermissions] EXCEPTION loading permissions: $e -> Access LOCKED (fail-secure)');
      _isLoaded = true;
      _isAdmin = false;
      _isOwner = false;
      _role = 'collaborator';
      _permissions = {};
      permissionsNotifier.value = !permissionsNotifier.value;
    }
  }

  /// Normalize resource keys to canonical UserPermissionResources constants.
  /// Supports friendly alias names (e.g. 'devis' -> 'sales_quotes', 'customer_orders' -> 'sales_orders', 'invoices' -> 'sales_invoices', 'delivery_notes' -> 'sales_delivery_notes').
  static String normalizeResourceKey(String rawKey) {
    final k = rawKey.toLowerCase().trim().replaceAll('-', '_').replaceAll(' ', '_');
    switch (k) {
      case 'devis':
      case 'quotes':
      case 'quote':
      case 'salesquotes':
      case 'sales_quotes':
        return UserPermissionResources.salesQuotes;
      case 'commandes':
      case 'commande':
      case 'customer_orders':
      case 'customer_order':
      case 'customerorders':
      case 'orders':
      case 'order':
      case 'salesorders':
      case 'sales_orders':
        return UserPermissionResources.salesOrders;
      case 'delivery_notes':
      case 'delivery_note':
      case 'deliverynotes':
      case 'bons_livraison':
      case 'bon_livraison':
      case 'bl':
      case 'salesdeliverynotes':
      case 'sales_delivery_notes':
        return UserPermissionResources.salesDeliveryNotes;
      case 'invoices':
      case 'invoice':
      case 'factures':
      case 'facture':
      case 'salesinvoices':
      case 'sales_invoices':
        return UserPermissionResources.salesInvoices;
      case 'exit_vouchers':
      case 'exit_voucher':
      case 'exitvouchers':
      case 'bons_sortie':
      case 'bon_sortie':
      case 'bs':
      case 'salesexitvouchers':
      case 'sales_exit_vouchers':
        return UserPermissionResources.salesExitVouchers;
      case 'credit_notes':
      case 'credit_note':
      case 'creditnotes':
      case 'avoirs':
      case 'avoir':
      case 'salescreditnotes':
      case 'sales_credit_notes':
        return UserPermissionResources.salesCreditNotes;
      case 'return_vouchers':
      case 'return_voucher':
      case 'returnvouchers':
      case 'return_notes':
      case 'return_note':
      case 'returnnotes':
      case 'bons_retour':
      case 'bon_retour':
      case 'br':
      case 'salesreturnvouchers':
      case 'sales_return_vouchers':
        return UserPermissionResources.salesReturnVouchers;
      case 'supplier_orders':
      case 'supplier_order':
      case 'supplierorders':
      case 'commandes_fournisseur':
      case 'commande_fournisseur':
      case 'purchasessupplierorders':
      case 'purchases_supplier_orders':
        return UserPermissionResources.purchasesSupplierOrders;
      case 'receiving_vouchers':
      case 'receiving_voucher':
      case 'receivingvouchers':
      case 'bons_reception':
      case 'bon_reception':
      case 'purchasesreceivingvouchers':
      case 'purchases_receiving_vouchers':
        return UserPermissionResources.purchasesReceivingVouchers;
      case 'purchase_invoices':
      case 'purchase_invoice':
      case 'purchaseinvoices':
      case 'factures_achat':
      case 'facture_achat':
      case 'purchasespurchaseinvoices':
      case 'purchases_purchase_invoices':
        return UserPermissionResources.purchasesPurchaseInvoices;
      case 'supplier_credit_notes':
      case 'supplier_credit_note':
      case 'suppliercreditnotes':
      case 'avoirs_fournisseur':
      case 'avoir_fournisseur':
      case 'purchasessuppliercreditnotes':
      case 'purchases_supplier_credit_notes':
        return UserPermissionResources.purchasesSupplierCreditNotes;
      case 'supplier_returns':
      case 'supplier_return':
      case 'supplierreturns':
      case 'retours_fournisseur':
      case 'retour_fournisseur':
      case 'purchasessupplierreturns':
      case 'purchases_supplier_returns':
        return UserPermissionResources.purchasesSupplierReturns;
      case 'payments':
      case 'payment':
      case 'paiements':
      case 'paiement':
        return UserPermissionResources.payments;
      case 'withholding_tax':
      case 'withholdingtax':
      case 'retenue_source':
        return UserPermissionResources.withholdingTax;
      case 'withholding_tax_sales':
      case 'rs_vente':
        return UserPermissionResources.withholdingTaxSales;
      case 'withholding_tax_purchases':
      case 'rs_achat':
        return UserPermissionResources.withholdingTaxPurchases;
      case 'treasury_accounts':
      case 'treasuryaccounts':
      case 'comptes_tresorerie':
        return UserPermissionResources.treasuryAccounts;
      case 'treasury_transactions':
      case 'treasurytransactions':
      case 'transactions_tresorerie':
        return UserPermissionResources.treasuryTransactions;
      case 'treasury_checks':
      case 'treasurychecks':
      case 'cheques_tresorerie':
        return UserPermissionResources.treasuryChecks;
      case 'customers':
      case 'customer':
      case 'clients':
      case 'client':
        return UserPermissionResources.customers;
      case 'suppliers':
      case 'supplier':
      case 'fournisseurs':
      case 'fournisseur':
        return UserPermissionResources.suppliers;
      case 'products':
      case 'product':
      case 'products_list':
      case 'articles':
      case 'article':
        return UserPermissionResources.productsList;
      case 'products_settings':
      case 'parametres_articles':
        return UserPermissionResources.productsSettings;
      case 'stock_overview':
      case 'vue_stock':
        return UserPermissionResources.stockOverview;
      case 'stock_movements':
      case 'mouvements_stock':
        return UserPermissionResources.stockMovements;
      case 'stock_entry_vouchers':
      case 'bons_entree':
        return UserPermissionResources.stockEntryVouchers;
      case 'stock_withdrawal_vouchers':
      case 'bons_prelevement':
        return UserPermissionResources.stockWithdrawalVouchers;
      case 'stock_transfer_vouchers':
      case 'bons_transfert':
        return UserPermissionResources.stockTransferVouchers;
      case 'stock_inventory_sheets':
      case 'fiches_inventaire':
        return UserPermissionResources.stockInventorySheets;
      case 'stock_warehouses':
      case 'entrepots':
        return UserPermissionResources.stockWarehouses;
      case 'projects':
      case 'projets':
        return UserPermissionResources.projects;
      case 'settings_company_info':
      case 'infos_societe':
        return UserPermissionResources.settingsCompanyInfo;
      case 'settings_doc_templates':
      case 'modeles_documents':
        return UserPermissionResources.settingsDocTemplates;
      case 'import_export':
      case 'importexport':
        return UserPermissionResources.importExport;
      case 'user_management':
      case 'usermanagement':
      case 'gestion_utilisateurs':
        return UserPermissionResources.userManagement;
      case 'dashboard':
      case 'tableau_de_bord':
        return UserPermissionResources.dashboard;
      default:
        return rawKey;
    }
  }

  /// Check whether user has specific permission for a resource key.
  /// Supports action as string ('read', 'create', 'update', 'delete', 'all', 'lire', 'créer', 'modifier', 'supprimer', 'tous')
  /// or named flags (read, create, update, delete).
  /// Automatically normalizes resource key aliases (e.g. 'devis' -> 'sales_quotes', 'customer_orders' -> 'sales_orders').
  bool hasPermission(
    String resourceKey, {
    dynamic action,
    bool? read,
    bool? create,
    bool? update,
    bool? delete,
  }) {
    final normKey = normalizeResourceKey(resourceKey);

    // GUARD: Block ALL actions if permissions not loaded yet!
    if (!_isLoaded) {
      debugPrint('[PermissionService.hasPermission] BLOCKED (not loaded): resource="$resourceKey" ($normKey), action="$action" -> result=false');
      return false;
    }

    if (_isAdmin || _isOwner) {
      debugPrint('[PermissionService.hasPermission] ADMIN/OWNER bypass for resource="$resourceKey" ($normKey), action="$action" -> result=true');
      return true;
    }

    final perm = _permissions[normKey] ?? _permissions[resourceKey];
    if (perm == null) {
      debugPrint('[PermissionService.hasPermission] NO PERMISSION ENTRY: resource="$resourceKey" ($normKey), action="$action" -> result=false');
      return false;
    }

    bool result = false;

    if (read != null || create != null || update != null || delete != null) {
      result = (read != true || perm.read) &&
               (create != true || perm.create) &&
               (update != true || perm.update) &&
               (delete != true || perm.delete);
    } else if (action is String) {
      final act = action.toLowerCase().trim();
      switch (act) {
        case 'read':
        case 'lire':
        case 'view':
        case 'voir':
          result = perm.read;
          break;
        case 'create':
        case 'creer':
        case 'créer':
        case 'add':
        case 'ajouter':
          result = perm.create;
          break;
        case 'update':
        case 'modifier':
        case 'edit':
          result = perm.update;
          break;
        case 'delete':
        case 'supprimer':
        case 'suppr':
        case 'remove':
          result = perm.delete;
          break;
        case 'all':
        case 'tous':
        case 'full':
          result = perm.all;
          break;
        default:
          result = false;
          break;
      }
    } else {
      result = perm.read;
    }

    debugPrint('[PermissionService.hasPermission] CHECK: resource="$resourceKey" ($normKey), action="$action" -> result=$result (user=$_userEmail, role=$_role, perm=[read:${perm.read}, create:${perm.create}, update:${perm.update}, delete:${perm.delete}])');
    return result;
  }

  bool canRead(String resourceKey) => hasPermission(resourceKey, action: 'read');

  bool canCreate(String resourceKey) => hasPermission(resourceKey, action: 'create');

  bool canUpdate(String resourceKey) => hasPermission(resourceKey, action: 'update');

  bool canDelete(String resourceKey) => hasPermission(resourceKey, action: 'delete');

  /// Returns true if the user has AT LEAST ONE permission on the resource (read, create, update, or delete), or is Admin/Owner.
  bool hasAnyPermission(String resourceKey) {
    final normKey = normalizeResourceKey(resourceKey);
    if (!_isLoaded) {
      debugPrint('[PermissionService.hasAnyPermission] BLOCKED (not loaded): resource="$resourceKey" ($normKey) -> result=false');
      return false;
    }
    if (isAdmin || isOwner) {
      debugPrint('[PermissionService.hasAnyPermission] ADMIN/OWNER: resource="$resourceKey" ($normKey) -> result=true');
      return true;
    }
    final perm = _permissions[normKey] ?? _permissions[resourceKey];
    if (perm == null) {
      debugPrint('[PermissionService.hasAnyPermission] NO PERMISSION ENTRY: resource="$resourceKey" ($normKey) -> result=false');
      return false;
    }
    final result = perm.read || perm.create || perm.update || perm.delete;
    debugPrint('[PermissionService.hasAnyPermission] CHECK: resource="$resourceKey" ($normKey) -> result=$result (perm=[read:${perm.read}, create:${perm.create}, update:${perm.update}, delete:${perm.delete}])');
    return result;
  }

  /// Map an AppModule enum to its corresponding UserPermissionResources key
  String? getResourceKeyForModule(AppModule module) {
    switch (module) {
      case AppModule.dashboard:
        return UserPermissionResources.dashboard;
      case AppModule.quotes:
        return UserPermissionResources.salesQuotes;
      case AppModule.customerOrders:
        return UserPermissionResources.salesOrders;
      case AppModule.deliveryNotes:
        return UserPermissionResources.salesDeliveryNotes;
      case AppModule.invoices:
        return UserPermissionResources.salesInvoices;
      case AppModule.exitVouchers:
        return UserPermissionResources.salesExitVouchers;
      case AppModule.creditNotes:
        return UserPermissionResources.salesCreditNotes;
      case AppModule.returnVouchers:
        return UserPermissionResources.salesReturnVouchers;
      case AppModule.supplierOrders:
        return UserPermissionResources.purchasesSupplierOrders;
      case AppModule.receivingVouchers:
        return UserPermissionResources.purchasesReceivingVouchers;
      case AppModule.purchaseInvoices:
        return UserPermissionResources.purchasesPurchaseInvoices;
      case AppModule.supplierCreditNotes:
        return UserPermissionResources.purchasesSupplierCreditNotes;
      case AppModule.supplierReturns:
        return UserPermissionResources.purchasesSupplierReturns;
      case AppModule.payments:
        return UserPermissionResources.payments;
      case AppModule.withholdingTaxSales:
        return UserPermissionResources.withholdingTaxSales;
      case AppModule.withholdingTaxPurchase:
        return UserPermissionResources.withholdingTaxPurchases;
      case AppModule.accounts:
        return UserPermissionResources.treasuryAccounts;
      case AppModule.transactions:
        return UserPermissionResources.treasuryTransactions;
      case AppModule.checksTraites:
        return UserPermissionResources.treasuryChecks;
      case AppModule.customers:
        return UserPermissionResources.customers;
      case AppModule.suppliers:
        return UserPermissionResources.suppliers;
      case AppModule.products:
        return UserPermissionResources.productsList;
      case AppModule.productSettings:
        return UserPermissionResources.productsSettings;
      case AppModule.stockDashboard:
        return UserPermissionResources.stockOverview;
      case AppModule.stockMovements:
        return UserPermissionResources.stockMovements;
      case AppModule.stockEntry:
        return UserPermissionResources.stockEntryVouchers;
      case AppModule.stockWithdrawal:
        return UserPermissionResources.stockWithdrawalVouchers;
      case AppModule.stockTransfer:
        return UserPermissionResources.stockTransferVouchers;
      case AppModule.inventorySheet:
        return UserPermissionResources.stockInventorySheets;
      case AppModule.warehouses:
        return UserPermissionResources.stockWarehouses;
      case AppModule.projects:
        return UserPermissionResources.projects;
      case AppModule.companyInfo:
        return UserPermissionResources.settingsCompanyInfo;
      case AppModule.documentTemplates:
        return UserPermissionResources.settingsDocTemplates;
      case AppModule.importExport:
        return UserPermissionResources.importExport;
      case AppModule.userManagement:
        return UserPermissionResources.userManagement;
      case AppModule.settings:
      case AppModule.reports:
        return null;
    }
  }

  /// Check if the active user can view the given module
  bool canAccessModule(AppModule module) {
    if (!_isLoaded) return false;
    if (_isAdmin || _isOwner) return true;
    if (module == AppModule.userManagement) return false;

    if (module == AppModule.settings) {
      return canRead(UserPermissionResources.settingsCompanyInfo) ||
             canRead(UserPermissionResources.settingsDocTemplates) ||
             canRead(UserPermissionResources.importExport);
    }
    if (module == AppModule.reports) {
      return canRead(UserPermissionResources.dashboard);
    }

    final resKey = getResourceKeyForModule(module);
    if (resKey == null) return false;
    return canRead(resKey);
  }

  /// Get the first accessible AppModule for the current user, or null if 0 permissions.
  AppModule? getFirstAccessibleModule() {
    if (!_isLoaded) return null;
    if (isAdmin || isOwner) return AppModule.dashboard;
    for (final mod in AppModule.values) {
      if (canAccessModule(mod)) {
        return mod;
      }
    }
    return null;
  }
}

/// Widget that guards child widgets based on resource permissions
class PermissionGuard extends StatelessWidget {
  final String resourceKey;
  final Widget child;
  final Widget? fallback;
  final bool requireRead;
  final bool requireCreate;
  final bool requireUpdate;
  final bool requireDelete;

  const PermissionGuard({
    super.key,
    required this.resourceKey,
    required this.child,
    this.fallback,
    this.requireRead = true,
    this.requireCreate = false,
    this.requireUpdate = false,
    this.requireDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PermissionService.instance.permissionsNotifier,
      builder: (context, _, __) {
        final hasAccess = PermissionService.instance.hasPermission(
          resourceKey,
          read: requireRead,
          create: requireCreate,
          update: requireUpdate,
          delete: requireDelete,
        );

        if (hasAccess) return child;
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Standalone unauthorized view shown when attempting to open a restricted screen
class UnauthorizedView extends StatelessWidget {
  final String? message;
  const UnauthorizedView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded, size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 18),
            Text(
              'Accès non autorisé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? "Vous n'avez pas la permission de consulter ce module. Veuillez contacter un administrateur pour obtenir l'accès.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
