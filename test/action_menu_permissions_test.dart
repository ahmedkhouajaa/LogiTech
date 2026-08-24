import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/services/permission_service.dart';
import 'package:business_manager_pro/models/user_management_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic 3-Dot Action Menu Permission Rules', () {
    setUp(() {
      PermissionService.instance.reset();
    });

    test('Rule 1: User with ONLY "Lire" permission has read-only access', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
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
      final res = UserPermissionResources.salesDeliveryNotes;

      expect(service.canRead(res), isTrue, reason: 'Can Voir');
      expect(service.canUpdate(res), isFalse, reason: 'Cannot Modifier or Change Status');
      expect(service.canDelete(res), isFalse, reason: 'Cannot Supprimer');
      expect(service.hasAnyPermission(res), isTrue, reason: 'Can Imprimer, PDF, Email, WhatsApp');
      expect(service.canCreate(UserPermissionResources.salesInvoices), isFalse, reason: 'Cannot Transform to Invoice');
      expect(service.canCreate(UserPermissionResources.payments), isFalse, reason: 'Cannot Ajouter Paiement');
    });

    test('Rule 2: User with ONLY "Modifier" on Devis DOES NOT see transform options without target create perm', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesQuotes: const UserResourcePermission(
          read: true,
          create: false,
          update: true,
          delete: false,
        ),
        // No create perms on orders, delivery notes, or invoices
        UserPermissionResources.salesOrders: const UserResourcePermission(
          read: true,
          create: false,
          update: false,
          delete: false,
        ),
        UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
          read: true,
          create: false,
          update: false,
          delete: false,
        ),
        UserPermissionResources.salesInvoices: const UserResourcePermission(
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
      final canUpdateDevis = service.hasPermission('devis', action: 'update');
      final canCreateInvoice = canUpdateDevis && service.hasPermission('invoices', action: 'create');
      final canCreateOrder = canUpdateDevis && service.hasPermission('customer_orders', action: 'create');
      final canCreateDelivery = canUpdateDevis && service.hasPermission('delivery_notes', action: 'create');

      expect(canUpdateDevis, isTrue, reason: 'Modifier is allowed');
      expect(service.isAdmin, isFalse, reason: 'Changer le statut is hidden for collaborator');
      expect(canCreateInvoice, isFalse, reason: 'Transformer en Facture is hidden');
      expect(canCreateOrder, isFalse, reason: 'Transformer en Commande is hidden');
      expect(canCreateDelivery, isFalse, reason: 'Transformer en BL is hidden');
    });

    test('Rule 3: User with "Modifier" on Devis AND "Créer" on Commandes Client ONLY sees Transformer en Commande Client', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesQuotes: const UserResourcePermission(
          read: true,
          create: false,
          update: true,
          delete: false,
        ),
        UserPermissionResources.salesOrders: const UserResourcePermission(
          read: true,
          create: true,
          update: false,
          delete: false,
        ),
        UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
          read: false,
          create: false,
          update: false,
          delete: false,
        ),
        UserPermissionResources.salesInvoices: const UserResourcePermission(
          read: false,
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
      final canUpdateDevis = service.hasPermission('devis', action: 'update');
      final canCreateInvoice = canUpdateDevis && service.hasPermission('invoices', action: 'create');
      final canCreateOrder = canUpdateDevis && service.hasPermission('customer_orders', action: 'create');
      final canCreateDelivery = canUpdateDevis && service.hasPermission('delivery_notes', action: 'create');

      expect(canCreateOrder, isTrue, reason: 'Transformer en Commande Client is visible');
      expect(canCreateInvoice, isFalse, reason: 'Transformer en Facture is hidden');
      expect(canCreateDelivery, isFalse, reason: 'Transformer en Bon de Livraison is hidden');
    });

    test('Rule 4: User with "Modifier" on Devis AND "Créer" on Factures and BLs sees both transformations', () {
      final perms = <String, UserResourcePermission>{
        UserPermissionResources.salesQuotes: const UserResourcePermission(
          read: true,
          create: false,
          update: true,
          delete: false,
        ),
        UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
          read: true,
          create: true,
          update: false,
          delete: false,
        ),
        UserPermissionResources.salesInvoices: const UserResourcePermission(
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
      final canUpdateDevis = service.hasPermission('devis', action: 'update');
      final canCreateInvoice = canUpdateDevis && service.hasPermission('invoices', action: 'create');
      final canCreateOrder = canUpdateDevis && service.hasPermission('customer_orders', action: 'create');
      final canCreateDelivery = canUpdateDevis && service.hasPermission('delivery_notes', action: 'create');

      expect(canCreateInvoice, isTrue, reason: 'Transformer en Facture is visible');
      expect(canCreateDelivery, isTrue, reason: 'Transformer en Bon de Livraison is visible');
      expect(canCreateOrder, isFalse, reason: 'Transformer en Commande is hidden');
    });

    test('Rule 5: User with "Supprimer" permission has delete option', () {
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

      expect(service.canDelete(res), isTrue);
      expect(service.canRead(res), isFalse);
      expect(service.canUpdate(res), isFalse);
    });

    test('Rule 6: Admin user has all actions and bypasses permissions', () {
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
      expect(service.canCreate(UserPermissionResources.salesInvoices), isTrue);
      expect(service.canCreate(UserPermissionResources.payments), isTrue);
    });

    test('Rule 7: User with NO permissions has all actions disabled', () {
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
      expect(service.hasAnyPermission(res), isFalse, reason: '4 read-only actions hidden if no permissions at all');
    });

    test('Rule 8: User with ANY permission has access to 4 read-only actions (Print, PDF, Email, WhatsApp)', () {
      // Test with only update permission
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {
          UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
            read: false,
            create: false,
            update: true,
            delete: false,
          ),
        },
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final res = UserPermissionResources.salesDeliveryNotes;

      expect(service.hasAnyPermission(res), isTrue, reason: '4 read-only actions are visible');
      expect(service.canRead(res), isFalse, reason: 'Voir is hidden');
      expect(service.canUpdate(res), isTrue, reason: 'Modifier is visible');
    });

    test('Rule 9: Delivery notes transformations require BOTH update on BL and create on target', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {
          UserPermissionResources.salesDeliveryNotes: const UserResourcePermission(
            read: true,
            create: false,
            update: true,
            delete: false,
          ),
          UserPermissionResources.salesInvoices: const UserResourcePermission(
            read: true,
            create: true,
            update: false,
            delete: false,
          ),
          UserPermissionResources.salesReturnVouchers: const UserResourcePermission(
            read: true,
            create: false,
            update: false,
            delete: false,
          ),
          UserPermissionResources.payments: const UserResourcePermission(
            read: true,
            create: false,
            update: false,
            delete: false,
          ),
        },
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final canUpdateBL = service.hasPermission('delivery_notes', action: 'update');
      final canCreateInvoice = canUpdateBL && service.hasPermission('invoices', action: 'create');
      final canCreateReturn = canUpdateBL && service.hasPermission('return_notes', action: 'create');
      final canCreatePayment = service.hasPermission('payments', action: 'create');

      expect(canCreateInvoice, isTrue, reason: 'Transformer en Facture is visible');
      expect(canCreateReturn, isFalse, reason: 'Transformer en Bon de Retour is hidden');
      expect(canCreatePayment, isFalse, reason: 'Ajouter paiement is hidden');
    });

    test('Rule 10: Invoices transformations require BOTH update on invoice and create on credit note', () {
      PermissionService.instance.setPermissionsForTesting(
        isAdmin: false,
        isOwner: false,
        role: 'collaborator',
        permissions: {
          UserPermissionResources.salesInvoices: const UserResourcePermission(
            read: true,
            create: false,
            update: true,
            delete: false,
          ),
          UserPermissionResources.salesCreditNotes: const UserResourcePermission(
            read: false,
            create: false,
            update: false,
            delete: false,
          ),
        },
        isLoaded: true,
      );

      final service = PermissionService.instance;
      final canUpdateInvoice = service.hasPermission('invoices', action: 'update');
      final canCreateCreditNote = canUpdateInvoice && service.hasPermission('credit_notes', action: 'create');

      expect(canUpdateInvoice, isTrue);
      expect(canCreateCreditNote, isFalse, reason: 'Transformer en Avoir is hidden because target create is false');
    });
  });
}
