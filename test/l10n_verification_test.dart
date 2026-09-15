import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/l10n/app_localizations.dart';

void main() {
  group('Localization Verification Tests', () {
    test('Verify Customer Order translations', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));
      final fr = AppLocalizations(const Locale('fr'));

      expect(en.tr('Ajouter une commande client'), equals('Add Customer Order'));
      expect(ar.tr('Ajouter une commande client'), equals('إضافة طلب زبون'));
      expect(fr.tr('Ajouter une commande client'), equals('Ajouter une commande client'));

      expect(en.tr('Nouvelle commande client'), equals('New Customer Order'));
      expect(ar.tr('Nouvelle commande client'), equals('طلب زبون جديد'));

      expect(en.tr('Modifier la commande client'), equals('Edit Customer Order'));
      expect(ar.tr('Modifier la commande client'), equals('تعديل طلب الزبون'));
    });

    test('Verify Return Note translations and Custom Fields', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));

      expect(en.tr('Ajouter un Bon de retour'), equals('Add Return Note'));
      expect(ar.tr('Ajouter un Bon de retour'), equals('إضافة وصل إرجاع'));
      expect(en.tr('Modifier le Bon de retour'), equals('Edit Return Note'));
      expect(ar.tr('Modifier le Bon de retour'), equals('تعديل وصل الإرجاع'));

      expect(en.tr('Champs Personnalisés'), equals('Custom Fields'));
      expect(ar.tr('Champs Personnalisés'), equals('حقول مخصصة'));

      expect(en.tr('Informations supplémentaires spécifiques à ce document'), equals('Additional information specific to this document'));
      expect(ar.tr('Informations supplémentaires spécifiques à ce document'), equals('معلومات إضافية خاصة بهذه الوثيقة'));

      expect(en.tr('Matricule du véhicule'), equals('Vehicle registration'));
      expect(ar.tr('Matricule du véhicule'), equals('رقم تسجيل المركبة'));

      expect(en.tr('Nom du chauffeur'), equals('Driver name'));
      expect(ar.tr('Nom du chauffeur'), equals('اسم السائق'));

      expect(en.tr('Entrer la valeur'), equals('Enter value'));
      expect(ar.tr('Entrer la valeur'), equals('أدخل القيمة'));
    });

    test('Verify Supplier Order translations and action buttons', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));

      expect(en.tr('Ajouter une commande fournisseur'), equals('Add Supplier Order'));
      expect(ar.tr('Ajouter une commande fournisseur'), equals('إضافة طلب مورد'));

      expect(en.tr('Valider'), equals('Validate'));
      expect(ar.tr('Valider'), equals('تأكيد'));

      expect(en.tr('Brouillon'), equals('Draft'));
      expect(ar.tr('Brouillon'), equals('مسودة'));

      expect(en.tr('Envoyer'), equals('Send'));
      expect(ar.tr('Envoyer'), equals('إرسال'));

      expect(en.tr('Enregistrer'), equals('Save'));
      expect(ar.tr('Enregistrer'), equals('حفظ'));

      expect(en.tr('Retour'), equals('Back'));
      expect(ar.tr('Retour'), equals('رجوع'));
    });

    test('Verify Receiving Voucher translations', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));

      expect(en.tr('Ajouter un bon de réception'), equals('Add Receiving Voucher'));
      expect(ar.tr('Ajouter un bon de réception'), equals('إضافة وصل استلام'));
      expect(en.tr('Ajouter un bon de reception'), equals('Add Receiving Voucher'));
      expect(ar.tr('Ajouter un bon de reception'), equals('إضافة وصل استلام'));
    });

    test('Verify Supplier Credit Note & Supplier Return translations', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));

      expect(en.tr('Ajouter un Avoir fournisseur'), equals('Add Supplier Credit Note'));
      expect(ar.tr('Ajouter un Avoir fournisseur'), equals('إضافة إشعار دائن مورد'));

      expect(en.tr('Ajouter un Bon de retour fournisseur'), equals('Add Supplier Return'));
      expect(ar.tr('Ajouter un Bon de retour fournisseur'), equals('إضافة إرجاع إلى مورد'));
    });

    test('Verify Default Project & Warehouse translations', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));

      expect(en.tr('Projet par défaut'), equals('Default project'));
      expect(ar.tr('Projet par défaut'), equals('المشروع الافتراضي'));

      expect(en.tr('Entrepôt par défaut'), equals('Default warehouse'));
      expect(ar.tr('Entrepôt par défaut'), equals('المستودع الافتراضي'));
    });

    test('Verify Payments translations and method badges', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));
      final fr = AppLocalizations(const Locale('fr'));

      // Method translations
      expect(en.tr('Retenue à la source'), equals('Withholding Tax'));
      expect(ar.tr('Retenue à la source'), equals('الخصم من المنبع'));
      expect(fr.tr('Retenue à la source'), equals('Retenue à la source'));

      expect(en.tr('retenue_source'), equals('Withholding Tax'));
      expect(ar.tr('retenue_source'), equals('الخصم من المنبع'));
      expect(fr.tr('retenue_source'), equals('Retenue à la source'));

      expect(en.tr('Espèces'), equals('Cash'));
      expect(ar.tr('Espèces'), equals('نقداً'));
      expect(fr.tr('Espèces'), equals('Espèces'));

      expect(en.tr('Chèque'), equals('Check'));
      expect(ar.tr('Chèque'), equals('شيك'));
      expect(fr.tr('Chèque'), equals('Chèque'));

      expect(en.tr('Virement'), equals('Bank Transfer'));
      expect(ar.tr('Virement'), equals('تحويل بنكي'));
      expect(fr.tr('Virement'), equals('Virement'));

      expect(en.tr('Carte'), equals('Card'));
      expect(ar.tr('Carte'), equals('بطاقة بنكية'));
      expect(fr.tr('Carte'), equals('Carte'));

      expect(en.tr('Traite'), equals('Bill of Exchange'));
      expect(ar.tr('Traite'), equals('كمبيالة'));
      expect(fr.tr('Traite'), equals('Traite'));

      // Status translations
      expect(en.tr('Payé'), equals('Paid'));
      expect(ar.tr('Payé'), equals('مدفوع'));
      expect(fr.tr('Payé'), equals('Payé'));

      expect(en.tr('En attente'), equals('Pending'));
      expect(ar.tr('En attente'), equals('في الانتظار'));
      expect(fr.tr('En attente'), equals('En attente'));

      expect(en.tr('Annulé'), equals('Cancelled'));
      expect(ar.tr('Annulé'), equals('ملغى'));
      expect(fr.tr('Annulé'), equals('Annulé'));

      // Filter headers
      expect(en.tr('Méthode'), equals('Method'));
      expect(ar.tr('Méthode'), equals('الطريقة'));
      expect(fr.tr('Méthode'), equals('Méthode'));

      expect(en.tr('Statut'), equals('Status'));
      expect(ar.tr('Statut'), equals('الحالة'));
      expect(fr.tr('Statut'), equals('Statut'));

      expect(en.tr('Type'), equals('Type'));
      expect(ar.tr('Type'), equals('النوع'));
      expect(fr.tr('Type'), equals('Type'));

      expect(en.tr('Tous'), equals('All'));
      expect(ar.tr('Tous'), equals('الكل'));
      expect(fr.tr('Tous'), equals('Tous'));
    });

    test('Verify Stock and Inventory translations', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));
      final fr = AppLocalizations(const Locale('fr'));

      // Navigation & Concepts
      expect(en.tr('Stock'), equals('Inventory'));
      expect(ar.tr('Stock'), equals('المخزون'));
      expect(fr.tr('Stock'), equals('Stock'));

      expect(en.tr('Vue d\'ensemble'), equals('Overview'));
      expect(ar.tr('Vue d\'ensemble'), equals('نظرة عامة'));

      expect(en.tr('Bons d\'entrée'), equals('Entry Vouchers'));
      expect(ar.tr('Bons d\'entrée'), equals('وصولات الدخول'));

      expect(en.tr('Bons de prélèvement'), equals('Withdrawal Vouchers'));
      expect(ar.tr('Bons de prélèvement'), equals('وصولات السحب'));

      expect(en.tr('Bons de transfert'), equals('Transfer Vouchers'));
      expect(ar.tr('Bons de transfert'), equals('وصولات التحويل'));

      expect(en.tr('Fiches d\'inventaire'), equals('Inventory Sheets'));
      expect(ar.tr('Fiches d\'inventaire'), equals('بطاقات الجرد'));

      expect(en.tr('Entrepôts'), equals('Warehouses'));
      expect(ar.tr('Entrepôts'), equals('المستودعات'));

      // KPIs and Overview
      expect(en.tr('Valeur du stock'), equals('Stock Value'));
      expect(ar.tr('Valeur du stock'), equals('قيمة المخزون'));

      expect(en.tr('Alertes stock bas'), equals('Low Stock Alerts'));
      expect(ar.tr('Alertes stock bas'), equals('تنبيهات المخزون المنخفض'));

      expect(en.tr('Nouvel ajustement de stock'), equals('New Stock Adjustment'));
      expect(ar.tr('Nouvel ajustement de stock'), equals('تسوية مخزون جديدة'));

      // Warehouse screen
      expect(en.tr('Ajouter un Entrepôt'), equals('Add Warehouse'));
      expect(ar.tr('Ajouter un Entrepôt'), equals('إضافة مستودع'));

      // Inventory sheet metrics
      expect(en.tr('Surplus'), equals('Surplus'));
      expect(ar.tr('Surplus'), equals('فائض'));

      expect(en.tr('Manquant'), equals('Missing'));
      expect(ar.tr('Manquant'), equals('ناقص'));
    });

    test('Verify Projects translations and actions', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));

      expect(en.tr('Projets'), equals('Projects'));
      expect(ar.tr('Projets'), equals('المشاريع'));

      expect(en.tr('Gérez vos projets et suivez leur avancement'), equals('Manage your projects and track their progress'));
      expect(ar.tr('Gérez vos projets et suivez leur avancement'), equals('إدارة مشاريعك ومتابعة تقدمها'));

      expect(en.tr('Nouveau Projet'), equals('New Project'));
      expect(ar.tr('Nouveau Projet'), equals('مشروع جديد'));

      expect(en.tr('Date de Création'), equals('Creation Date'));
      expect(ar.tr('Date de Création'), equals('تاريخ الإنشاء'));

      expect(en.tr('Projet par défaut'), equals('Default project'));
      expect(ar.tr('Projet par défaut'), equals('المشروع الافتراضي'));

      expect(en.tr('Cet élément est un élément par défaut et ne peut pas être modifié.'), equals('This item is default and cannot be modified.'));
      expect(ar.tr('Cet élément est un élément par défaut et ne peut pas être modifié.'), equals('هذا العنصر افتراضي ولا يمكن تعديله.'));
    });

    test('Verify Product Settings and Families translations', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));

      expect(en.tr('Paramètres des articles'), equals('Product Settings'));
      expect(ar.tr('Paramètres des articles'), equals('إعدادات المنتجات'));

      expect(en.tr('Gérer les familles et sous-familles d\'articles'), equals('Manage product families and subfamilies'));
      expect(ar.tr('Gérer les familles et sous-familles d\'articles'), equals('إدارة عائلات وفئات المواد الفرعية'));

      expect(en.tr('Ajouter une nouvelle famille'), equals('Add a new family'));
      expect(ar.tr('Ajouter une nouvelle famille'), equals('إضافة عائلة جديدة'));

      expect(en.tr('Nom de la famille (ex: Informatique, Mobilier...)'), equals('Family name (e.g. IT, Furniture...)'));
      expect(ar.tr('Nom de la famille (ex: Informatique, Mobilier...)'), equals('اسم العائلة (مثال: أجهزة إلكترونية، أثاث...)'));

      expect(en.tr('Ajouter une famille'), equals('Add family'));
      expect(ar.tr('Ajouter une famille'), equals('إضافة عائلة'));

      expect(en.tr('Aucune famille enregistrée'), equals('No families registered'));
      expect(ar.tr('Aucune famille enregistrée'), equals('لا توجد عائلات مسجلة'));

      expect(en.tr('Changer d\'entreprise'), equals('Switch workspace'));
      expect(ar.tr('Changer d\'entreprise'), equals('تغيير مساحة العمل'));
    });

    test('Verify Settings Interfaces translations across en and ar', () {
      final en = AppLocalizations(const Locale('en'));
      final ar = AppLocalizations(const Locale('ar'));

      // Application Modules
      expect(en.tr('Modules de l\'application'), equals('Application Modules'));
      expect(ar.tr('Modules de l\'application'), equals('وحدات التطبيق'));
      expect(en.tr('Enregistrer les modifications'), equals('Save Changes'));
      expect(ar.tr('Enregistrer les modifications'), equals('حفظ التغييرات'));
      expect(en.tr('Sous-documents'), equals('Sub-documents'));
      expect(ar.tr('Sous-documents'), equals('المستندات الفرعية'));

      // Personal Info
      expect(en.tr('Informations personnelles'), equals('Personal Information'));
      expect(ar.tr('Informations personnelles'), equals('المعلومات الشخصية'));
      expect(en.tr('Coordonnées personnelles'), equals('Personal Details'));
      expect(ar.tr('Coordonnées personnelles'), equals('البيانات الشخصية'));
      expect(en.tr('Sécurité & Mot de passe'), equals('Security & Password'));
      expect(ar.tr('Sécurité & Mot de passe'), equals('الأمان وكلمة المرور'));

      // Company Info
      expect(en.tr('Informations sur la société'), equals('Company Information'));
      expect(ar.tr('Informations sur la société'), equals('معلومات الشركة'));
      expect(en.tr('Logo officiel de l\'entreprise'), equals('Official Company Logo'));
      expect(ar.tr('Logo officiel de l\'entreprise'), equals('الشعار الرسمي للشركة'));
      expect(en.tr('Cachet officiel de l\'entreprise'), equals('Official Company Stamp'));
      expect(ar.tr('Cachet officiel de l\'entreprise'), equals('الختم الرسمي للشركة'));

      // Document Numbering
      expect(en.tr('Numérotation des Documents'), equals('Document Numbering'));
      expect(ar.tr('Numérotation des Documents'), equals('ترقيم المستندات'));
      expect(en.tr('Type de Document'), equals('Document Type'));
      expect(ar.tr('Type de Document'), equals('نوع المستند'));

      // Document Templates
      expect(en.tr('Modèles de documents'), equals('Document Templates'));
      expect(ar.tr('Modèles de documents'), equals('نماذج المستندات'));
      expect(en.tr('Créer un modèle'), equals('Create Template'));
      expect(ar.tr('Créer un modèle'), equals('إنشاء نموذج'));

      // Import / Export
      expect(en.tr('Import / Export des Données'), equals('Data Import / Export'));
      expect(ar.tr('Import / Export des Données'), equals('استيراد وتصدير البيانات'));
      expect(en.tr('Sauvegarde (Export .json)'), equals('Backup (Export .json)'));
      expect(ar.tr('Sauvegarde (Export .json)'), equals('نسخ احتياطي (تصدير .json)'));

      // Support Tickets
      expect(en.tr('Centre de Support & Assistance'), equals('Support & Help Center'));
      expect(ar.tr('Centre de Support & Assistance'), equals('مركز الدعم والمساعدة'));
      expect(en.tr('Créer un ticket'), equals('Create Ticket'));
      expect(ar.tr('Créer un ticket'), equals('إنشاء تذكرة'));

      // User Management
      expect(en.tr('Gestion des Utilisateurs'), equals('User Management'));
      expect(ar.tr('Gestion des Utilisateurs'), equals('إدارة المستخدمين'));
      expect(en.tr('Ajouter un Utilisateur'), equals('Add User'));
      expect(ar.tr('Ajouter un Utilisateur'), equals('إضافة مستخدم'));
      expect(en.tr('Administrateur'), equals('Administrator'));
      expect(ar.tr('Administrateur'), equals('مسؤول'));
      expect(en.tr('Collaborateur'), equals('Collaborator'));
      expect(ar.tr('Collaborateur'), equals('مساعد'));
      expect(en.tr('Accès aux entreprises'), equals('Enterprise Access'));
      expect(ar.tr('Accès aux entreprises'), equals('الوصول إلى الشركات'));
      expect(en.tr('Accéder à toutes les entreprises'), equals('Access all enterprises'));
      expect(ar.tr('Accéder à toutes les entreprises'), equals('الوصول إلى جميع الشركات'));

      // Additional Dialogs & Buttons
      expect(en.tr('Aucun document disponible'), equals('No documents available'));
      expect(ar.tr('Aucun document disponible'), equals('لا توجد مستندات متاحة'));
      expect(en.tr('Remettre à zéro le modèle ?'), equals('Reset template?'));
      expect(ar.tr('Remettre à zéro le modèle ?'), equals('إعادة ضبط النموذج؟'));
      expect(en.tr('Supprimer le modèle ?'), equals('Delete template?'));
      expect(ar.tr('Supprimer le modèle ?'), equals('حذف النموذج؟'));
      expect(en.tr('0 résultat'), equals('0 results'));
      expect(ar.tr('0 résultat'), equals('0 نتيجة'));
    });
  });
}

