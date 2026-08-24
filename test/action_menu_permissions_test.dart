import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/models/user_management_model.dart';
import 'package:business_manager_pro/services/permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic Action Menu Permissions Tests - "Tous" Logic for Transforms and Status', () {
    setUp(() {
      PermissionService.instance.reset();
    });

    test('Rule 1: User with ONLY "Lire" on Devis only sees "Voir" and 4 read-only actions', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesQuotes: const UserResourcePermission(
          read: true,
          create: false,
          update: false,
          delete: false,
        ),
      };

      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: perms,
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final res = UserPermissionResources.salesQuotes;
      final hasAllAccess = service.hasPermission(res, action: 'all');

      expect(service.canRead(res), isTrue, reason: 'Can Voir');
      expect(service.canUpdate(res), isFalse, reason: 'Cannot Modifier');
      expect(service.canDelete(res), isFalse, reason: 'Cannot Supprimer');
      expect(hasAllAccess, isFalse, reason: 'Transforms and Changer le statut are hidden without Tous');
      expect(service.hasAnyPermission(res), isTrue, reason: 'Can Imprimer, PDF, Email, WhatsApp');
    });

    test('Rule 2: User with "Modifier" checked (alone or with Lire) DOES NOT see transforms or Changer le statut', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesQuotes: const UserResourcePermission(
          read: true,
          create: false,
          update: true,
          delete: false,
        ),
      };

      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: perms,
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final res = UserPermissionResources.salesQuotes;
      final canUpdate = service.canUpdate(res);
      final hasAllAccess = service.hasPermission(res, action: 'all');

      expect(canUpdate, isTrue, reason: 'Modifier is visible');
      expect(service.canRead(res), isTrue, reason: 'Voir is visible');
      expect(service.canDelete(res), isFalse, reason: 'Supprimer is hidden');
      expect(hasAllAccess, isFalse, reason: 'Transforms and Changer le statut are HIDDEN because user does not have Tous');
    });

    test('Rule 3: User with "Tous" (all 4 permissions) SEES ALL options including transforms and Changer le statut', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesQuotes: const UserResourcePermission(
          read: true,
          create: true,
          update: true,
          delete: true,
        ),
      };

      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: perms,
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final res = UserPermissionResources.salesQuotes;
      final hasAllAccess = service.hasPermission(res, action: 'all');

      expect(service.canRead(res), isTrue, reason: 'Voir is visible');
      expect(service.canUpdate(res), isTrue, reason: 'Modifier is visible');
      expect(service.canDelete(res), isTrue, reason: 'Supprimer is visible');
      expect(hasAllAccess, isTrue, reason: 'Transforms and Changer le statut are VISIBLE with Tous');
      expect(service.hasAnyPermission(res), isTrue, reason: '4 read-only actions are visible');
    });

    test('Rule 4: User with ONLY "Supprimer" sees only "Supprimer" and 4 read-only actions', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
          read: false,
          create: false,
          update: false,
          delete: true,
        ),
      };

      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: perms,
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final res = UserPermissionResources.salesDeliveryNotes;
      final hasAllAccess = service.hasPermission(res, action: 'all');

      expect(service.canDelete(res), isTrue, reason: 'Supprimer is visible');
      expect(service.canRead(res), isFalse, reason: 'Voir is hidden');
      expect(service.canUpdate(res), isFalse, reason: 'Modifier is hidden');
      expect(hasAllAccess, isFalse, reason: 'Transforms and Changer le statut are hidden');
      expect(service.hasAnyPermission(res), isTrue, reason: '4 read-only actions are visible');
    });

    test('Rule 5: Admin user has all actions visible including transforms and Changer le statut', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: true,
        isOwner: false,
        role: 'admin',
        permissions: {},
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final res = UserPermissionResources.salesDeliveryNotes;

      expect(service.canRead(res), isTrue);
      expect(service.canCreate(res), isTrue);
      expect(service.canUpdate(res), isTrue);
      expect(service.canDelete(res), isTrue);
      expect(service.hasPermission(res, action: 'all'), isTrue);
      expect(service.canCreate(UserPermissionResources.salesInvoices), isTrue);
      expect(service.canCreate(UserPermissionResources.payments), isTrue);
    });

    test('Rule 6: User with NO permissions has all actions hidden', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {},
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final res = UserPermissionResources.salesDeliveryNotes;

      expect(service.canRead(res), isFalse);
      expect(service.canCreate(res), isFalse);
      expect(service.canUpdate(res), isFalse);
      expect(service.canDelete(res), isFalse);
      expect(service.hasPermission(res, action: 'all'), isFalse);
      expect(service.hasAnyPermission(res), isFalse, reason: 'All actions hidden if no permissions');
    });
  });
}
