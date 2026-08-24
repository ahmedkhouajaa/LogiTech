import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/services/permission_service.dart';
import 'package:business_manager_pro/models/user_management_model.dart';
import 'package:business_manager_pro/services/user_management_service.dart';
import 'package:business_manager_pro/widgets/sidebar_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Management Hierarchy & Owner Protection Tests', () {
    setUp(() {
      PermissionService.instance.reset();
    });

    test('Enterprise Owner has isOwner == true, isAdmin == true, and can access user management', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: true,
        isOwner: true,
        role: 'admin',
        permissions: UserPermissionResources.getAdminDefaultPermissions(),
        isLoaded: true,
      );

      expect(PermissionService.instance.isOwner, isTrue);
      expect(PermissionService.instance.isAdmin, isTrue);
      expect(PermissionService.instance.canAccessModule(AppModule.userManagement), isTrue);
    });

    test('Regular Admin has isAdmin == true, isOwner == false', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: true,
        isOwner: false,
        role: 'admin',
        permissions: UserPermissionResources.getAdminDefaultPermissions(),
        isLoaded: true,
      );

      expect(PermissionService.instance.isAdmin, isTrue);
      expect(PermissionService.instance.isOwner, isFalse);
      expect(PermissionService.instance.canAccessModule(AppModule.userManagement), isTrue);
    });

    test('Collaborator has isAdmin == false, isOwner == false, and CANNOT access user management module', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {
          UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
            read: true,
            create: true,
            update: true,
            delete: false,
          ),
        },
        isLoaded: true,
      );

      expect(PermissionService.instance.isAdmin, isFalse);
      expect(PermissionService.instance.isOwner, isFalse);
      expect(PermissionService.instance.canAccessModule(AppModule.userManagement), isFalse);
    });

    test('EnterpriseUserModel correctly identifies Owner vs Admin vs Collaborator', () {
      final ownerUser = EnterpriseUserModel(
        uid: 'user_owner',
        name: 'Enterprise Owner',
        email: 'owner@test.com',
        role: 'admin',
        isOwner: true,
      );

      final adminUser = EnterpriseUserModel(
        uid: 'user_admin',
        name: 'Regular Admin',
        email: 'admin@test.com',
        role: 'admin',
        isOwner: false,
      );

      final collabUser = EnterpriseUserModel(
        uid: 'user_collab',
        name: 'Collaborator',
        email: 'collab@test.com',
        role: 'collaborator',
        isOwner: false,
      );

      expect(ownerUser.isOwner, isTrue);
      expect(ownerUser.isAdmin, isTrue);
      expect(ownerUser.displayRole, equals('Administrateur'));

      expect(adminUser.isOwner, isFalse);
      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.displayRole, equals('Administrateur'));

      expect(collabUser.isOwner, isFalse);
      expect(collabUser.isAdmin, isFalse);
      expect(collabUser.displayRole, equals('Collaborateur'));
    });

    test('Non-owner admin is blocked from creating user with Admin role in UserManagementService', () async {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: true,
        isOwner: false,
        role: 'admin',
        permissions: UserPermissionResources.getAdminDefaultPermissions(),
        isLoaded: true,
      );

      expect(
        () => UserManagementService.instance.createAndAddUserToEnterprises(
          email: 'newadmin@test.com',
          name: 'New Admin',
          role: 'admin',
          selectedEnterpriseIds: ['ent_1'],
          permissions: UserPermissionResources.getAdminDefaultPermissions(),
        ),
        throwsA(isA<String>().having(
          (e) => e,
          'message',
          contains('Seul le propriétaire de l\'entreprise peut attribuer le rôle Administrateur.'),
        )),
      );
    });
  });
}
