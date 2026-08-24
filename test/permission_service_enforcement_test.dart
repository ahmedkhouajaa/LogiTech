import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/models/user_management_model.dart';
import 'package:business_manager_pro/services/permission_service.dart';
import 'package:business_manager_pro/widgets/sidebar_menu.dart' show AppModule;

void main() {
  group('PermissionService Enforcement Tests', () {
    setUp(() {
      PermissionService.instance.reset();
    });

    test('Initial or reset state gives zero permissions for collaborators', () {
      final service = PermissionService.instance;
      expect(service.isAdmin, isFalse);
      expect(service.isOwner, isFalse);
      expect(service.role, equals('collaborator'));

      for (final res in UserPermissionResources.allResources) {
        final key = res['key'] as String;
        expect(service.canRead(key), isFalse, reason: 'Read should be false for $key');
        expect(service.canCreate(key), isFalse, reason: 'Create should be false for $key');
        expect(service.canUpdate(key), isFalse, reason: 'Update should be false for $key');
        expect(service.canDelete(key), isFalse, reason: 'Delete should be false for $key');
        expect(service.hasPermission(key, action: 'all'), isFalse);
      }
    });

    test('Collaborator with only 1 permission (sales_exit_vouchers: read) has strict access', () {
      final service = PermissionService.instance;
      
      // Simulate loaded permissions where only salesExitVouchers has read: true
      final singlePerm = <String, UserResourcePermission>{
        UserPermissionResources.salesExitVouchers: const UserResourcePermission(
          read: true,
          create: false,
          update: false,
          delete: false,
        ),
      };
      
      // Assign parsed map directly
      service.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: singlePerm,
      );

      // Verify salesExitVouchers
      expect(service.canRead(UserPermissionResources.salesExitVouchers), isTrue);
      expect(service.canCreate(UserPermissionResources.salesExitVouchers), isFalse);
      expect(service.canUpdate(UserPermissionResources.salesExitVouchers), isFalse);
      expect(service.canDelete(UserPermissionResources.salesExitVouchers), isFalse);
      expect(service.canAccessModule(AppModule.exitVouchers), isTrue);

      // Verify quotes (salesQuotes) are completely blocked
      expect(service.canRead(UserPermissionResources.salesQuotes), isFalse);
      expect(service.canCreate(UserPermissionResources.salesQuotes), isFalse);
      expect(service.canUpdate(UserPermissionResources.salesQuotes), isFalse);
      expect(service.canDelete(UserPermissionResources.salesQuotes), isFalse);
      expect(service.canAccessModule(AppModule.quotes), isFalse);

      // Verify invoices (salesInvoices) are completely blocked
      expect(service.canRead(UserPermissionResources.salesInvoices), isFalse);
      expect(service.canAccessModule(AppModule.invoices), isFalse);

      // Verify customer orders (salesOrders) are completely blocked
      expect(service.canRead(UserPermissionResources.salesOrders), isFalse);
      expect(service.canAccessModule(AppModule.customerOrders), isFalse);

      // Verify user management is completely blocked for collaborators
      expect(service.canAccessModule(AppModule.userManagement), isFalse);
    });

    test('Collaborator with ALL permissions unchecked cannot access anything', () {
      final service = PermissionService.instance;
      
      final emptyPerms = <String, UserResourcePermission>{};
      for (final res in UserPermissionResources.allResources) {
        emptyPerms[res['key'] as String] = UserResourcePermission.empty;
      }

      service.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: emptyPerms,
      );

      for (final res in UserPermissionResources.allResources) {
        final key = res['key'] as String;
        expect(service.canRead(key), isFalse);
        expect(service.canCreate(key), isFalse);
        expect(service.canUpdate(key), isFalse);
        expect(service.canDelete(key), isFalse);
        expect(service.hasPermission(key, read: true), isFalse);
        expect(service.hasPermission(key, create: true), isFalse);
        expect(service.hasPermission(key, update: true), isFalse);
        expect(service.hasPermission(key, delete: true), isFalse);
      }

      // Check all AppModules
      for (final module in AppModule.values) {
        if (module == AppModule.userManagement || service.getResourceKeyForModule(module) != null) {
          expect(service.canAccessModule(module), isFalse, reason: 'Module $module should not be accessible');
        }
      }
    });

    test('Admin user has full access to all resources and actions', () {
      final service = PermissionService.instance;

      service.setPermissionsForTesting(
        isAdmin: true,
        isOwner: true,
        role: 'admin',
        permissions: UserPermissionResources.getAdminDefaultPermissions(),
      );

      expect(service.isAdmin, isTrue);
      expect(service.isOwner, isTrue);

      for (final res in UserPermissionResources.allResources) {
        final key = res['key'] as String;
        expect(service.canRead(key), isTrue);
        expect(service.canCreate(key), isTrue);
        expect(service.canUpdate(key), isTrue);
        expect(service.canDelete(key), isTrue);
        expect(service.hasPermission(key, action: 'read'), isTrue);
        expect(service.hasPermission(key, action: 'create'), isTrue);
        expect(service.hasPermission(key, action: 'update'), isTrue);
        expect(service.hasPermission(key, action: 'delete'), isTrue);
        expect(service.hasPermission(key, action: 'all'), isTrue);
      }

      for (final module in AppModule.values) {
        expect(service.canAccessModule(module), isTrue);
      }
    });

    test('Guard blocks ALL actions when isLoaded is false', () {
      final service = PermissionService.instance;
      service.setPermissionsForTesting(
        isAdmin: true,
        isOwner: true,
        role: 'admin',
        permissions: UserPermissionResources.getAdminDefaultPermissions(),
        isLoaded: false, // NOT loaded!
      );

      expect(service.isLoaded, isFalse);
      expect(service.isAdmin, isFalse);
      expect(service.isOwner, isFalse);

      for (final res in UserPermissionResources.allResources) {
        final key = res['key'] as String;
        expect(service.canRead(key), isFalse);
        expect(service.canCreate(key), isFalse);
        expect(service.canUpdate(key), isFalse);
        expect(service.canDelete(key), isFalse);
        expect(service.hasPermission(key, action: 'read'), isFalse);
      }

      for (final mod in AppModule.values) {
        expect(service.canAccessModule(mod), isFalse);
      }
      expect(service.getFirstAccessibleModule(), isNull);
    });

    test('Fresh user with NO permissions sees NOTHING', () {
      final service = PermissionService.instance;
      service.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {}, // empty permissions map
        isLoaded: true,
      );

      expect(service.isLoaded, isTrue);
      expect(service.isAdmin, isFalse);
      expect(service.isOwner, isFalse);

      for (final res in UserPermissionResources.allResources) {
        final key = res['key'] as String;
        expect(service.canRead(key), isFalse);
        expect(service.canCreate(key), isFalse);
        expect(service.canUpdate(key), isFalse);
        expect(service.canDelete(key), isFalse);
      }

      for (final mod in AppModule.values) {
        expect(service.canAccessModule(mod), isFalse, reason: 'Module $mod should be blocked');
      }
      expect(service.getFirstAccessibleModule(), isNull);
    });

    test('User with ONLY "Lire" for Clients only sees Clients and nothing else', () {
      final service = PermissionService.instance;
      service.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {
          UserPermissionResources.customers: const UserResourcePermission(
            read: true,
            create: false,
            update: false,
            delete: false,
          ),
        },
        isLoaded: true,
      );

      expect(service.isLoaded, isTrue);
      expect(service.isAdmin, isFalse);

      // Clients checks
      expect(service.canRead(UserPermissionResources.customers), isTrue);
      expect(service.canCreate(UserPermissionResources.customers), isFalse);
      expect(service.canUpdate(UserPermissionResources.customers), isFalse);
      expect(service.canDelete(UserPermissionResources.customers), isFalse);
      expect(service.canAccessModule(AppModule.customers), isTrue);
      expect(service.getFirstAccessibleModule(), equals(AppModule.customers));

      // Check all other resources are strictly blocked
      for (final res in UserPermissionResources.allResources) {
        final key = res['key'] as String;
        if (key == UserPermissionResources.customers) continue;

        expect(service.canRead(key), isFalse, reason: 'Resource $key should not be readable');
        expect(service.canCreate(key), isFalse, reason: 'Resource $key should not be creatable');
        expect(service.canUpdate(key), isFalse, reason: 'Resource $key should not be updatable');
        expect(service.canDelete(key), isFalse, reason: 'Resource $key should not be deletable');
      }

      // Check all other modules are blocked
      for (final mod in AppModule.values) {
        if (mod == AppModule.customers) continue;
        expect(service.canAccessModule(mod), isFalse, reason: 'Module $mod should be blocked');
      }
    });

    test('hasPermission supports multilingual strings and named parameters', () {
      final service = PermissionService.instance;

      service.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {
          UserPermissionResources.customers: const UserResourcePermission(
            read: true,
            create: true,
            update: false,
            delete: false,
          ),
        },
      );

      final key = UserPermissionResources.customers;

      // English & French read
      expect(service.hasPermission(key, action: 'read'), isTrue);
      expect(service.hasPermission(key, action: 'lire'), isTrue);
      expect(service.hasPermission(key, action: 'view'), isTrue);
      expect(service.hasPermission(key, action: 'voir'), isTrue);

      // English & French create
      expect(service.hasPermission(key, action: 'create'), isTrue);
      expect(service.hasPermission(key, action: 'créer'), isTrue);
      expect(service.hasPermission(key, action: 'creer'), isTrue);
      expect(service.hasPermission(key, action: 'add'), isTrue);
      expect(service.hasPermission(key, action: 'ajouter'), isTrue);

      // Update & Delete should be false
      expect(service.hasPermission(key, action: 'update'), isFalse);
      expect(service.hasPermission(key, action: 'modifier'), isFalse);
      expect(service.hasPermission(key, action: 'delete'), isFalse);
      expect(service.hasPermission(key, action: 'supprimer'), isFalse);
      expect(service.hasPermission(key, action: 'all'), isFalse);
      expect(service.hasPermission(key, action: 'tous'), isFalse);

      // Named parameters
      expect(service.hasPermission(key, read: true), isTrue);
      expect(service.hasPermission(key, create: true), isTrue);
      expect(service.hasPermission(key, update: true), isFalse);
      expect(service.hasPermission(key, delete: true), isFalse);
    });
  });
}
