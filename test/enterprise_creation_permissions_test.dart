import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/services/permission_service.dart';
import 'package:business_manager_pro/models/user_management_model.dart';
import 'package:business_manager_pro/models/enterprise.dart';
import 'package:business_manager_pro/services/enterprise_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Enterprise Creation Permission Tests', () {
    setUp(() {
      PermissionService.instance.reset();
    });

    test('Admin user has isAdmin == true and can create enterprises', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: true,
        isOwner: true,
        role: 'admin',
        permissions: {},
        isLoaded: true,
      );

      expect(PermissionService.instance.isAdmin, isTrue);
      expect(PermissionService.instance.role, equals('admin'));
    });

    test('Collaborator user has isAdmin == false and is blocked from creating enterprise', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {
          UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
            read: true,
            create: true,
            update: true,
            delete: true,
          ),
        },
        isLoaded: true,
      );

      expect(PermissionService.instance.isAdmin, isFalse);
      expect(PermissionService.instance.role, equals('collaborator'));

      // If existing enterprises are loaded, createEnterprise must throw
      EnterpriseService.instance.setEnterprisesForTesting([
        Enterprise(id: 'ent_1', name: 'Test Enterprise', ownerId: 'admin_1'),
      ]);

      expect(
        () => EnterpriseService.instance.createEnterprise('New Fake Enterprise'),
        throwsA(isA<String>().having(
          (e) => e,
          'message',
          contains('Action non autorisée. Seuls les administrateurs peuvent créer une entreprise.'),
        )),
      );
    });
  });
}
