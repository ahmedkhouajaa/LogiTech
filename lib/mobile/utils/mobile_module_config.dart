import '../../utils/constants.dart';
import '../../widgets/sidebar_menu.dart';

class MobileModuleConfig {
  final String title;
  final String fabText;
  final List<String> filterOptions;

  MobileModuleConfig({
    required this.title,
    required this.fabText,
    required this.filterOptions,
  });

  static MobileModuleConfig getConfig(AppModule module) {
    switch (module) {
      // Ventes
      case AppModule.quotes:
        return MobileModuleConfig(
          title: 'Devis',
          fabText: 'Nouveau devis',
          filterOptions: ['Tous', 'Brouillon', 'Accepté', 'Refusé'],
        );
      case AppModule.customerOrders:
        return MobileModuleConfig(
          title: 'Commandes',
          fabText: 'Nouvelle commande',
          filterOptions: ['Tous', 'Brouillon', 'Validée', 'Validée et facturée', 'En cours', 'Livrée', 'Annulée'],
        );
      case AppModule.deliveryNotes:
        return MobileModuleConfig(
          title: 'Bons de livraison',
          fabText: 'Nouveau bon de livraison',
          filterOptions: ['Tous', 'En préparation', 'Livré', 'Annulé'],
        );
      case AppModule.invoices:
        return MobileModuleConfig(
          title: 'Factures',
          fabText: 'Nouvelle facture',
          filterOptions: ['Tous', 'Payée', 'Non payée', 'Brouillon'],
        );
      case AppModule.exitVouchers:
        return MobileModuleConfig(
          title: 'Bons de sortie',
          fabText: 'Nouveau bon de sortie',
          filterOptions: ['Tous', 'En cours', 'Validé', 'Annulé'],
        );
      case AppModule.creditNotes:
        return MobileModuleConfig(
          title: 'Avoirs',
          fabText: 'Nouvel avoir',
          filterOptions: ['Tous', 'Brouillon', 'Validé', 'Annulé'],
        );
      case AppModule.returnVouchers:
        return MobileModuleConfig(
          title: 'Bons de retour',
          fabText: 'Nouveau bon de retour',
          filterOptions: ['Tous', 'En cours', 'Validé', 'Annulé'],
        );

      // Achats
      case AppModule.supplierOrders:
        return MobileModuleConfig(
          title: 'Commandes fournisseur',
          fabText: 'Nouvelle commande fournisseur',
          filterOptions: ['Tous', 'En cours', 'Reçu', 'Annulé'],
        );
      case AppModule.receivingVouchers:
        return MobileModuleConfig(
          title: 'Bons de réception',
          fabText: 'Nouveau bon de réception',
          filterOptions: ['Tous', 'En cours', 'Validé', 'Annulé'],
        );
      case AppModule.purchaseInvoices:
        return MobileModuleConfig(
          title: 'Factures d\'achat',
          fabText: 'Nouvelle facture d\'achat',
          filterOptions: ['Tous', 'Payée', 'Non payée', 'Brouillon'],
        );
      case AppModule.supplierCreditNotes:
        return MobileModuleConfig(
          title: 'Avoirs fournisseur',
          fabText: 'Nouvel avoir fournisseur',
          filterOptions: ['Tous', 'Brouillon', 'Validé', 'Annulé'],
        );
      case AppModule.supplierReturns:
        return MobileModuleConfig(
          title: 'Retours fournisseur',
          fabText: 'Nouveau retour fournisseur',
          filterOptions: ['Tous', 'En cours', 'Validé', 'Annulé'],
        );

      // Others
      case AppModule.payments:
        return MobileModuleConfig(
          title: 'Paiements',
          fabText: 'Nouveau paiement',
          filterOptions: ['Tous', 'En attente', 'Confirmé', 'Rejeté'],
        );
      case AppModule.withholdingTaxSales:
        return MobileModuleConfig(
          title: 'RS vente',
          fabText: 'Nouvelle retenue vente',
          filterOptions: ['Tous', 'En attente', 'Payé', 'Annulé'],
        );
      case AppModule.withholdingTaxPurchase:
        return MobileModuleConfig(
          title: 'RS achat',
          fabText: 'Nouvelle retenue achat',
          filterOptions: ['Tous', 'En attente', 'Payé', 'Annulé'],
        );
      case AppModule.transactions:
        return MobileModuleConfig(
          title: 'Transactions',
          fabText: 'Nouvelle transaction',
          filterOptions: ['Tous', 'Entrée', 'Sortie'],
        );
      case AppModule.checksTraites:
        return MobileModuleConfig(
          title: 'Chèques & Traites',
          fabText: 'Nouveau chèque/traite',
          filterOptions: ['Tous', 'En attente', 'Encaisé', 'Rejeté'],
        );
      case AppModule.customers:
        return MobileModuleConfig(
          title: 'Clients',
          fabText: 'Nouveau client',
          filterOptions: ['Tous', 'Actif', 'Inactif'], // Added defaults
        );
      case AppModule.suppliers:
        return MobileModuleConfig(
          title: 'Fournisseurs',
          fabText: 'Nouveau fournisseur',
          filterOptions: ['Tous', 'Actif', 'Inactif'], // Added defaults
        );
      case AppModule.products:
        return MobileModuleConfig(
          title: 'Articles',
          fabText: 'Nouvel article',
          filterOptions: ['Tous', 'En stock', 'Rupture'], // Added defaults
        );
      case AppModule.stockMovements:
      case AppModule.stockDashboard:
        return MobileModuleConfig(
          title: 'Stock',
          fabText: 'Nouveau mouvement',
          filterOptions: ['Tous', 'Entrée', 'Sortie'], // Added defaults
        );
      case AppModule.projects:
        return MobileModuleConfig(
          title: 'Projets',
          fabText: 'Nouveau projet',
          filterOptions: ['Tous', 'En cours', 'Terminé'], // Added defaults
        );
      default:
        return MobileModuleConfig(
          title: 'Module',
          fabText: 'Nouveau',
          filterOptions: ['Tous'],
        );
    }
  }
}
