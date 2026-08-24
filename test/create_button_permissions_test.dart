import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/models/user_management_model.dart';
import 'package:business_manager_pro/services/permission_service.dart';
import 'package:business_manager_pro/widgets/sidebar_menu.dart' show AppModule;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Create / Nouveau Button Permissions Tests for All Resources', () {
    setUp(() {
      PermissionService.instance.reset();
    });

    final allTargetResources = [
      UserPermissionResources.salesQuotes,
      UserPermissionResources.salesInvoices,
      UserPermissionResources.salesDeliveryNotes,
      UserPermissionResources.salesExitVouchers,
      UserPermissionResources.salesOrders,
      UserPermissionResources.purchasesSupplierOrders,
      UserPermissionResources.purchasesReceivingVouchers,
      UserPermissionResources.purchasesPurchaseInvoices,
      UserPermissionResources.purchasesSupplierCreditNotes,
      UserPermissionResources.purchasesSupplierReturns,
      UserPermissionResources.salesCreditNotes,
      UserPermissionResources.salesReturnVouchers,
      UserPermissionResources.customers,
      UserPermissionResources.suppliers,
      UserPermissionResources.productsList,
      UserPermissionResources.payments,
      UserPermissionResources.projects,
      UserPermissionResources.treasuryAccounts,
      UserPermissionResources.treasuryTransactions,
      UserPermissionResources.stockWarehouses,
      UserPermissionResources.stockInventorySheets,
      UserPermissionResources.stockTransferVouchers,
      UserPermissionResources.stockEntryVouchers,
      UserPermissionResources.stockWithdrawalVouchers,
      UserPermissionResources.productsSettings,
      UserPermissionResources.settingsDocTemplates,
    ];

    test('Rule 1: When "Créer" is NOT checked, canCreate is FALSE for all resources', () {
      // User has only Read and Update on all resources
      final perms = <String, UserResourcePermission>{};
      for (final res in allTargetResources) {
        perms[res] = const UserResourcePermission(
          read: true,
          create: false,
          update: true,
          delete: false,
        );
      }

      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: perms,
        isLoaded: true,
      );

      final service = PermissionService.instance;

      for (final res in allTargetResources) {
        expect(service.canCreate(res), isFalse, reason: 'Nouveau button must be hidden for $res');
        expect(service.hasPermission(res, action: 'create'), isFalse, reason: 'hasPermission create must be false for $res');
      }
    });

    test('Rule 2: When "Créer" IS checked, canCreate is TRUE for that resource', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesQuotes: const UserResourcePermission(
          read: true,
          create: true,
          update: false,
          delete: false,
        ),
        UserPermissionResources.salesInvoices: const UserResourcePermission(
          read: true,
          create: false,
          update: false,
          delete: false,
        ),
        UserPermissionResources.customers: const UserResourcePermission(
          read: true,
          create: true,
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

      expect(service.canCreate(UserPermissionResources.salesQuotes), isTrue, reason: 'Nouveau devis is visible');
      expect(service.canCreate(UserPermissionResources.salesInvoices), isFalse, reason: 'Nouvelle facture is hidden');
      expect(service.canCreate(UserPermissionResources.customers), isTrue, reason: 'Nouveau client is visible');
    });

    test('Rule 3: Admin / Owner bypass allows canCreate for all resources', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: true,
        isOwner: false,
        role: 'admin',
        permissions: {},
        isLoaded: true,
      );

      final service = PermissionService.instance;

      for (final res in allTargetResources) {
        expect(service.canCreate(res), isTrue, reason: 'Admin can create on $res');
      }
    });

    test('Rule 4: Mobile AppModule correctly maps to resource keys and evaluates canCreate', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesQuotes: const UserResourcePermission(read: true, create: true, update: false, delete: false),
        UserPermissionResources.salesInvoices: const UserResourcePermission(read: true, create: false, update: false, delete: false),
        UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(read: true, create: true, update: false, delete: false),
        UserPermissionResources.customers: const UserResourcePermission(read: true, create: true, update: false, delete: false),
        UserPermissionResources.suppliers: const UserResourcePermission(read: true, create: false, update: false, delete: false),
        UserPermissionResources.payments: const UserResourcePermission(read: true, create: false, update: false, delete: false),
        UserPermissionResources.projects: const UserResourcePermission(read: true, create: true, update: false, delete: false),
      };

      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: perms,
        isLoaded: true,
      );

      final service = PermissionService.instance;

      // Module -> Resource mapping checks
      expect(service.getResourceKeyForModule(AppModule.quotes), equals(UserPermissionResources.salesQuotes));
      expect(service.getResourceKeyForModule(AppModule.invoices), equals(UserPermissionResources.salesInvoices));
      expect(service.getResourceKeyForModule(AppModule.deliveryNotes), equals(UserPermissionResources.salesDeliveryNotes));
      expect(service.getResourceKeyForModule(AppModule.customers), equals(UserPermissionResources.customers));
      expect(service.getResourceKeyForModule(AppModule.suppliers), equals(UserPermissionResources.suppliers));
      expect(service.getResourceKeyForModule(AppModule.payments), equals(UserPermissionResources.payments));
      expect(service.getResourceKeyForModule(AppModule.projects), equals(UserPermissionResources.projects));

      // FAB canCreate checks
      expect(service.canCreate(service.getResourceKeyForModule(AppModule.quotes)!), isTrue);
      expect(service.canCreate(service.getResourceKeyForModule(AppModule.invoices)!), isFalse);
      expect(service.canCreate(service.getResourceKeyForModule(AppModule.deliveryNotes)!), isTrue);
      expect(service.canCreate(service.getResourceKeyForModule(AppModule.customers)!), isTrue);
      expect(service.canCreate(service.getResourceKeyForModule(AppModule.suppliers)!), isFalse);
      expect(service.canCreate(service.getResourceKeyForModule(AppModule.payments)!), isFalse);
      expect(service.canCreate(service.getResourceKeyForModule(AppModule.projects)!), isTrue);
    });
  });
}
