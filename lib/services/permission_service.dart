import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_management_model.dart';
import '../widgets/sidebar_menu.dart' show AppModule;
import '../utils/constants.dart';
import 'enterprise_service.dart';

/// Singleton service that manages active user permissions for the current enterprise context.
class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  bool _isAdmin = false;
  bool _isOwner = false;
  String _role = 'collaborator';
  String _userName = '';
  String _userEmail = '';
  Map<String, UserResourcePermission> _permissions = {};

  final ValueNotifier<bool> permissionsNotifier = ValueNotifier<bool>(false);

  bool get isAdmin => _isAdmin || _isOwner;
  bool get isOwner => _isOwner;
  String get role => _role;
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

    if (uid == null) {
      _isAdmin = false;
      _isOwner = false;
      _role = 'collaborator';
      _permissions = {};
      permissionsNotifier.value = !permissionsNotifier.value;
      return;
    }

    try {
      // 1. Fetch user doc for profile name & currentEnterpriseId fallback
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      Map<String, dynamic> uData = {};
      if (userDoc.exists) {
        uData = userDoc.data() ?? {};
        if (uData['name']?.toString().isNotEmpty == true) {
          _userName = uData['name'].toString();
        }
        if (uData['email']?.toString().isNotEmpty == true) {
          _userEmail = uData['email'].toString();
        }
      }

      // If eid is missing, try to resolve from user document or enterprises collection
      if (eid == null || eid.isEmpty) {
        if (uData['currentEnterpriseId']?.toString().isNotEmpty == true) {
          eid = uData['currentEnterpriseId'].toString();
        } else if (uData['enterprises'] is List && (uData['enterprises'] as List).isNotEmpty) {
          eid = (uData['enterprises'] as List).first.toString();
        }
      }

      // If user has no enterprise at all yet, check if self-registered / admin
      if (eid == null || eid.isEmpty) {
        final isUserAdmin = uData['role'] == null ||
            uData['role'] == 'admin' ||
            uData['role'] == 'administrateur' ||
            uData['isOwner'] == true ||
            uData['role'] != 'collaborator';
        _isAdmin = isUserAdmin;
        _isOwner = isUserAdmin;
        _role = isUserAdmin ? 'admin' : 'collaborator';
        _permissions = isUserAdmin ? UserPermissionResources.getAdminDefaultPermissions() : {};
        permissionsNotifier.value = !permissionsNotifier.value;
        return;
      }

      // 2. Check enterprise document to check ownership and members list
      final enterpriseDoc = await FirebaseFirestore.instance.collection('enterprises').doc(eid).get();
      if (enterpriseDoc.exists) {
        final entData = enterpriseDoc.data() ?? {};
        final ownerId = entData['owner_id']?.toString() ??
            entData['userId']?.toString() ??
            entData['ownerId']?.toString() ??
            entData['createdBy']?.toString() ??
            '';

        // Check if user is the enterprise creator / owner
        if (ownerId == uid || ownerId.isEmpty) {
          _isOwner = true;
          _isAdmin = true;
          _role = 'admin';
          _permissions = UserPermissionResources.getAdminDefaultPermissions();
          permissionsNotifier.value = !permissionsNotifier.value;
          return;
        }

        final members = entData['members'];
        if (members is List && members.isNotEmpty) {
          for (final m in members) {
            if (m is Map && m['uid'] == uid) {
              if (m['name']?.toString().isNotEmpty == true) {
                _userName = m['name'].toString();
              }
              final r = m['role']?.toString().toLowerCase() ?? '';
              final isMemOwner = m['isOwner'] == true;
              final isMemAdmin = isMemOwner || r == 'admin' || r == 'administrateur';

              if (isMemAdmin || r.isEmpty) {
                _isOwner = isMemOwner || ownerId == uid;
                _isAdmin = true;
                _role = 'admin';
                _permissions = UserPermissionResources.getAdminDefaultPermissions();
              } else if (r == 'collaborator') {
                _isOwner = false;
                _isAdmin = false;
                _role = 'collaborator';
                if (m['permissions'] is Map) {
                  final pMap = Map<String, dynamic>.from(m['permissions']);
                  final parsed = <String, UserResourcePermission>{};
                  for (final res in UserPermissionResources.allResources) {
                    final k = res['key'] as String;
                    if (pMap[k] is Map) {
                      parsed[k] = UserResourcePermission.fromMap(Map<String, dynamic>.from(pMap[k]));
                    } else {
                      parsed[k] = UserResourcePermission.empty;
                    }
                  }
                  _permissions = parsed;
                } else {
                  _permissions = UserPermissionResources.getCollaboratorDefaultPermissions();
                }
              }

              permissionsNotifier.value = !permissionsNotifier.value;
              return;
            }
          }
        }
      }

      // 3. Check user profile doc users/{uid} for enterpriseRoles[eid]
      if (userDoc.exists) {
        final entRoles = uData['enterpriseRoles'];
        if (entRoles is Map && entRoles[eid] is Map) {
          final info = Map<String, dynamic>.from(entRoles[eid]);
          final r = info['role']?.toString().toLowerCase() ?? '';
          final isRoleAdmin = r == 'admin' || r == 'administrateur' || info['isOwner'] == true;

          if (isRoleAdmin) {
            _isOwner = info['isOwner'] == true;
            _isAdmin = true;
            _role = 'admin';
            _permissions = UserPermissionResources.getAdminDefaultPermissions();
          } else if (r == 'collaborator' && info['permissions'] is Map) {
            _isAdmin = false;
            _isOwner = false;
            _role = 'collaborator';
            final pMap = Map<String, dynamic>.from(info['permissions']);
            final parsed = <String, UserResourcePermission>{};
            for (final res in UserPermissionResources.allResources) {
              final k = res['key'] as String;
              if (pMap[k] is Map) {
                parsed[k] = UserResourcePermission.fromMap(Map<String, dynamic>.from(pMap[k]));
              } else {
                parsed[k] = UserResourcePermission.empty;
              }
            }
            _permissions = parsed;
          } else {
            _permissions = UserPermissionResources.getCollaboratorDefaultPermissions();
          }

          permissionsNotifier.value = !permissionsNotifier.value;
          return;
        }
      }

      // 4. Default for self-registered users: if not explicitly marked as restricted collaborator, grant full admin access!
      final isSelfRegisteredAdmin = uData['role'] != 'collaborator';
      if (isSelfRegisteredAdmin) {
        _isAdmin = true;
        _isOwner = true;
        _role = 'admin';
        _permissions = UserPermissionResources.getAdminDefaultPermissions();

        // Only write to Firestore if user doc is missing role or permissions (avoid infinite write-snapshot loop)
        final needsInit = uData['role'] == null || uData['permissions'] == null;
        if (needsInit) {
          final adminPerms = UserPermissionResources.getAdminDefaultPermissions()
              .map((k, v) => MapEntry(k, v.toMap()));
          FirebaseFirestore.instance.collection('users').doc(uid).set({
            'role': 'admin',
            'isOwner': true,
            'permissions': adminPerms,
            if (eid.isNotEmpty) 'currentEnterpriseId': eid,
            if (eid.isNotEmpty) 'enterprises': FieldValue.arrayUnion([eid]),
          }, SetOptions(merge: true)).ignore();
        }
      } else {
        _isAdmin = false;
        _isOwner = false;
        _role = 'collaborator';
        _permissions = {};
      }
      permissionsNotifier.value = !permissionsNotifier.value;
    } catch (e) {
      debugPrint('Error loading permissions: $e');
      // On error, if the user is authenticated, default to full admin permissions so they are not locked out
      _isAdmin = true;
      _isOwner = true;
      _role = 'admin';
      _permissions = UserPermissionResources.getAdminDefaultPermissions();
      permissionsNotifier.value = !permissionsNotifier.value;
    }
  }

  /// Check whether user has specific permission for a resource key.
  /// Supports action as string ('read', 'create', 'update', 'delete', 'lire', 'créer', 'modifier', 'supprimer')
  /// or named flags (read, create, update, delete).
  bool hasPermission(
    String resourceKey, {
    dynamic action,
    bool? read,
    bool? create,
    bool? update,
    bool? delete,
  }) {
    if (_isAdmin || _isOwner) return true;
    final perm = _permissions[resourceKey] ?? const UserResourcePermission();

    if (read == true && !perm.read) return false;
    if (create == true && !perm.create) return false;
    if (update == true && !perm.update) return false;
    if (delete == true && !perm.delete) return false;
    if (read != null || create != null || update != null || delete != null) {
      return true;
    }

    if (action is String) {
      final act = action.toLowerCase().trim();
      switch (act) {
        case 'read':
        case 'lire':
        case 'view':
        case 'voir':
          return perm.read;
        case 'create':
        case 'creer':
        case 'créer':
        case 'add':
        case 'ajouter':
          return perm.create;
        case 'update':
        case 'modifier':
        case 'edit':
          return perm.update;
        case 'delete':
        case 'supprimer':
        case 'suppr':
        case 'remove':
          return perm.delete;
        default:
          return false;
      }
    }

    return perm.read;
  }

  bool canRead(String resourceKey) => hasPermission(resourceKey, action: 'read');

  bool canCreate(String resourceKey) => hasPermission(resourceKey, action: 'create');

  bool canUpdate(String resourceKey) => hasPermission(resourceKey, action: 'update');

  bool canDelete(String resourceKey) => hasPermission(resourceKey, action: 'delete');

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
      case AppModule.userManagement:
        return UserPermissionResources.userManagement;
      case AppModule.settings:
      case AppModule.reports:
        return null;
    }
  }

  /// Check if the active user can view the given module
  bool canAccessModule(AppModule module) {
    if (_isAdmin || _isOwner) return true;
    if (module == AppModule.userManagement) return false;
    final resKey = getResourceKeyForModule(module);
    if (resKey == null) return true;
    return canRead(resKey);
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
