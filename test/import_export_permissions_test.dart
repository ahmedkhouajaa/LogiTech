import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/models/user_management_model.dart';
import 'package:business_manager_pro/services/permission_service.dart';
import 'package:business_manager_pro/widgets/sidebar_menu.dart' show AppModule;

void main() {
  group('Import / Export Permissions Tests', () {
    test('UserPermissionResources has importExport resource configured', () {
      expect(UserPermissionResources.importExport, equals('import_export'));

      final found = UserPermissionResources.allResources.any(
        (r) => r['key'] == UserPermissionResources.importExport,
      );
      expect(found, isTrue);

      final resource = UserPermissionResources.allResources.firstWhere(
        (r) => r['key'] == UserPermissionResources.importExport,
      );
      expect(resource['label'], equals('Import / Export des données'));
      expect(resource['category'], equals('Paramètres'));
    });

    test('Default permissions are correctly assigned for Admin and Collaborator', () {
      final adminPerms = UserPermissionResources.getAdminDefaultPermissions();
      expect(adminPerms.containsKey(UserPermissionResources.importExport), isTrue);
      final adminImportPerm = adminPerms[UserPermissionResources.importExport]!;
      expect(adminImportPerm.read, isTrue);
      expect(adminImportPerm.create, isTrue);
      expect(adminImportPerm.update, isTrue);
      expect(adminImportPerm.delete, isTrue);
      expect(adminImportPerm.all, isTrue);

      final collabPerms = UserPermissionResources.getCollaboratorDefaultPermissions();
      expect(collabPerms.containsKey(UserPermissionResources.importExport), isTrue);
      final collabImportPerm = collabPerms[UserPermissionResources.importExport]!;
      expect(collabImportPerm.read, isFalse);
      expect(collabImportPerm.create, isFalse);
      expect(collabImportPerm.update, isFalse);
      expect(collabImportPerm.delete, isFalse);
    });

    test('AppModule.importExport maps to UserPermissionResources.importExport', () {
      final key = PermissionService.instance.getResourceKeyForModule(AppModule.importExport);
      expect(key, equals(UserPermissionResources.importExport));
    });

    test('UserResourcePermission deserialization and copyWith for importExport', () {
      final rawMap = {
        'read': true,
        'create': false,
        'update': true,
        'delete': false,
      };

      final perm = UserResourcePermission.fromMap(rawMap);
      expect(perm.read, isTrue);
      expect(perm.create, isFalse);
      expect(perm.update, isTrue);
      expect(perm.delete, isFalse);
      expect(perm.all, isFalse);

      final updated = perm.copyWith(create: true, delete: true);
      expect(updated.create, isTrue);
      expect(updated.delete, isTrue);
      expect(updated.all, isTrue);
    });
  });
}
