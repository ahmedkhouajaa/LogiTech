import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../utils/file_save_helper.dart';
import 'enterprise_service.dart';
import 'backup_security_service.dart';
import 'backup_obfuscation_service.dart';
import 'deobfuscator.dart';

/// Target collection types supported for flexible multi-ERP import
enum ImportTargetType {
  invoices,
  quotes,
  customers,
  suppliers,
  products,
  deliveryNotes,
  purchaseInvoices,
}

extension ImportTargetTypeExt on ImportTargetType {
  String get label {
    switch (this) {
      case ImportTargetType.invoices:
        return 'Factures de vente';
      case ImportTargetType.quotes:
        return 'Devis clients';
      case ImportTargetType.customers:
        return 'Clients';
      case ImportTargetType.suppliers:
        return 'Fournisseurs';
      case ImportTargetType.products:
        return 'Articles & Produits';
      case ImportTargetType.deliveryNotes:
        return 'Bons de livraison';
      case ImportTargetType.purchaseInvoices:
        return 'Factures d\'achat';
    }
  }

  String get firestoreCollection {
    switch (this) {
      case ImportTargetType.invoices:
        return 'invoices';
      case ImportTargetType.quotes:
        return 'quotes';
      case ImportTargetType.customers:
        return 'clients';
      case ImportTargetType.suppliers:
        return 'fournisseurs';
      case ImportTargetType.products:
        return 'articles';
      case ImportTargetType.deliveryNotes:
        return 'delivery_notes';
      case ImportTargetType.purchaseInvoices:
        return 'purchase_invoices';
    }
  }
}

/// Description of a target field for mapping
class TargetFieldDefinition {
  final String key;
  final String label;
  final String description;
  final bool isRequired;
  final String type; // 'string', 'number', 'date', 'list', 'boolean'
  final List<String> commonAliases;

  const TargetFieldDefinition({
    required this.key,
    required this.label,
    required this.description,
    this.isRequired = false,
    this.type = 'string',
    this.commonAliases = const [],
  });
}

/// Duplicate handling strategies
enum DuplicateHandlingStrategy {
  skip,
  overwrite,
  merge,
}

extension DuplicateHandlingStrategyExt on DuplicateHandlingStrategy {
  String get label {
    switch (this) {
      case DuplicateHandlingStrategy.skip:
        return 'Ignorer les doublons (conserver l\'existant)';
      case DuplicateHandlingStrategy.overwrite:
        return 'Écraser / Remplacer par la nouvelle version';
      case DuplicateHandlingStrategy.merge:
        return 'Fusionner les champs (compléter les données)';
    }
  }
}

/// Result of an import operation
class ImportOperationResult {
  final bool success;
  final String message;
  final int totalProcessed;
  final int totalImported;
  final int totalSkipped;
  final int totalErrors;
  final Map<String, int> collectionCounts;
  final List<String> errors;

  ImportOperationResult({
    required this.success,
    required this.message,
    this.totalProcessed = 0,
    this.totalImported = 0,
    this.totalSkipped = 0,
    this.totalErrors = 0,
    this.collectionCounts = const {},
    this.errors = const [],
  });
}

/// Comprehensive service for exporting and importing ERP data in LogiTech Pro
class ImportExportService {
  static final ImportExportService instance = ImportExportService._();
  ImportExportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get _currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId;
  String get _currentEnterpriseName =>
      EnterpriseService.instance.currentEnterprise?.name ?? 'Entreprise';

  /// Supported collections for native backup and restore
  static const Map<String, String> backupCollections = {
    'invoices': 'Factures de vente',
    'quotes': 'Devis clients',
    'clients': 'Clients',
    'fournisseurs': 'Fournisseurs',
    'articles': 'Articles & Produits',
    'stock_entries': 'Bons d\'entrée',
    'stock_withdrawals': 'Bons de prélèvement',
    'stock_movements': 'Mouvements de stock',
    'stock_transfers': 'Bons de transfert',
    'inventory_sheets': 'Fiches d\'inventaire',
    'treasury_accounts': 'Comptes de trésorerie',
    'treasury_transactions': 'Transactions de trésorerie',
    'paiements': 'Paiements & Encaissements',
    'projects': 'Projets',
    'warehouses': 'Entrepôts / Dépôts',
    'delivery_notes': 'Bons de livraison',
    'customer_orders': 'Commandes clients',
    'supplier_orders': 'Commandes fournisseurs',
    'purchase_invoices': 'Factures d\'achat',
    'receiving_vouchers': 'Bons de réception',
    'credit_notes': 'Avoirs clients',
    'supplier_credit_notes': 'Avoirs fournisseurs',
    'return_notes': 'Bons de retour client',
    'supplier_returns': 'Retours fournisseurs',
    'document_templates': 'Modèles de documents',
    'company_settings': 'Paramètres entreprise',
  };

  // ─── 1. EXPORT / BACKUP ──────────────────────────────────────────

  /// Fetches real counts of documents per collection for the active enterprise
  Future<Map<String, int>> getCollectionCounts() async {
    final entId = _currentEnterpriseId;
    if (entId == null || entId.isEmpty) return {};

    final Map<String, int> counts = {};
    for (final col in backupCollections.keys) {
      try {
        final snap = await _firestore
            .collection(col)
            .where('enterprise_id', isEqualTo: entId)
            .where('is_deleted', isEqualTo: 0)
            .count()
            .get()
            .timeout(const Duration(seconds: 4));
        counts[col] = snap.count ?? 0;
      } catch (_) {
        counts[col] = 0;
      }
    }
    return counts;
  }

  /// Exports selected collections of the active enterprise to a JSON file and triggers save/download
  Future<String?> exportEnterpriseBackup({
    required Set<String> selectedCollections,
    void Function(double progress, String status)? onProgress,
  }) async {
    final entId = _currentEnterpriseId;
    final uid = _currentUid;
    if (entId == null || entId.isEmpty) {
      throw 'Veuillez sélectionner une entreprise active avant d\'effectuer une sauvegarde.';
    }

    onProgress?.call(0.05, 'Préparation de la sauvegarde...');

    final Map<String, dynamic> exportData = {
      'version': '1.0.0',
      'exportDate': DateTime.now().toUtc().toIso8601String(),
      'appName': 'LogiTech Pro',
      'enterpriseId': entId,
      'enterpriseName': _currentEnterpriseName,
      'userId': uid ?? '',
      'collections': <String, dynamic>{},
    };

    final totalCols = selectedCollections.length;
    int currentIdx = 0;

    for (final col in selectedCollections) {
      currentIdx++;
      final colName = backupCollections[col] ?? col;
      onProgress?.call(
        0.1 + (0.8 * (currentIdx / totalCols)),
        'Exportation de $colName ($currentIdx/$totalCols)...',
      );

      try {
        final snapshot = await _firestore
            .collection(col)
            .where('enterprise_id', isEqualTo: entId)
            .get()
            .timeout(const Duration(seconds: 15));

        final List<Map<String, dynamic>> docsList = [];
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          docsList.add(data);
        }
        (exportData['collections'] as Map<String, dynamic>)[col] = docsList;
      } catch (e) {
        debugPrint('Export error on $col: $e');
        (exportData['collections'] as Map<String, dynamic>)[col] = [];
      }
    }

    onProgress?.call(0.92, 'Génération du fichier de sauvegarde sécurisé...');

    // 1. Obfuscate all collections and fields, strip internal/sensitive metadata
    final obfuscatedExportData = BackupObfuscationService.instance.obfuscateBackupData(exportData);
    final jsonString = const JsonEncoder.withIndent('  ').convert(obfuscatedExportData);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    final sanitizedEntName = _currentEnterpriseName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();
    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final fileName = 'logitech_backup_${sanitizedEntName}_$dateStr.json';

    onProgress?.call(0.98, 'Téléchargement du fichier...');
    final resultPath = await FileSaveHelper.saveFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/json',
    );

    onProgress?.call(1.0, 'Sauvegarde terminée avec succès !');
    return resultPath;
  }

  // ─── 2. NATIVE IMPORT (OBFUSCATED JSON & LEGACY JSON BACKUP) ─────

  /// Inspects, de-obfuscates, and parses a native LogiTech backup JSON file
  Map<String, dynamic> parseNativeBackup(String fileContent) {
    final trimmed = fileContent.trim();

    // Check if it's an encrypted .lgbk format for backwards compatibility
    if (trimmed.startsWith(BackupSecurityService.headerBegin)) {
      final result = BackupSecurityService.instance.verifyAndDecryptBackup(fileContent);
      if (!result.isValid || result.decryptedData == null) {
        throw result.errorMessage ?? 'Impossible de déchiffrer ou de valider le fichier de sauvegarde.';
      }
      return result.decryptedData!;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        throw 'Le fichier JSON sélectionné n\'est pas un objet valide.';
      }
      final map = Map<String, dynamic>.from(decoded);
      return BackupObfuscationService.instance.deobfuscateBackupData(map);
    } catch (e) {
      throw 'Erreur de lecture du fichier JSON: $e';
    }
  }

  /// Deletes all documents for specific collections for the active enterprise before replacement
  Future<int> deleteCollectionsForEnterprise({
    required String enterpriseId,
    required List<String> collections,
    void Function(double progress, String status)? onProgress,
  }) async {
    int totalDeleted = 0;
    int current = 0;
    for (final col in collections) {
      current++;
      onProgress?.call(
        0.05 + 0.3 * (current / (collections.isEmpty ? 1 : collections.length)),
        'Nettoyage des anciennes données de ${backupCollections[col] ?? col}...',
      );
      try {
        final snap = await _firestore
            .collection(col)
            .where('enterprise_id', isEqualTo: enterpriseId)
            .get();
        for (int i = 0; i < snap.docs.length; i += 300) {
          final batch = _firestore.batch();
          final chunk = snap.docs.sublist(
            i,
            (i + 300) > snap.docs.length ? snap.docs.length : (i + 300),
          );
          for (final doc in chunk) {
            batch.delete(doc.reference);
            totalDeleted++;
          }
          await batch.commit();
        }
      } catch (e) {
        debugPrint('Error deleting collection $col: $e');
      }
    }
    return totalDeleted;
  }

  /// Restores native backup data into Firestore under the active enterprise
  Future<ImportOperationResult> restoreNativeBackup({
    required Map<String, dynamic> backupData,
    required Set<String> selectedCollections,
    required DuplicateHandlingStrategy duplicateStrategy,
    void Function(double progress, String status)? onProgress,
    bool shouldDeleteBeforeRestore = false,
  }) async {
    final entId = _currentEnterpriseId;
    final uid = _currentUid;
    if (entId == null || entId.isEmpty) {
      return ImportOperationResult(
        success: false,
        message: 'Aucune entreprise active sélectionnée.',
      );
    }

    onProgress?.call(0.05, 'Validation de la structure...');

    final rawCollections = backupData['collections'] ?? backupData['data'];
    if (rawCollections is! Map) {
      return ImportOperationResult(
        success: false,
        message: 'Structure de sauvegarde invalide (clé "collections" manquante).',
      );
    }

    int totalProcessed = 0;
    int totalImported = 0;
    int totalSkipped = 0;
    int totalErrors = 0;
    final Map<String, int> collectionCounts = {};
    final List<String> errorMessages = [];

    final targetCols = selectedCollections.where((c) => rawCollections.containsKey(c)).toList();
    final totalCols = targetCols.length;

    if (shouldDeleteBeforeRestore) {
      await deleteCollectionsForEnterprise(
        enterpriseId: entId,
        collections: targetCols,
        onProgress: onProgress,
      );
    }

    int colIdx = 0;
    for (final col in targetCols) {
      colIdx++;
      final items = rawCollections[col];
      if (items is! List) continue;

      final colLabel = backupCollections[col] ?? col;
      onProgress?.call(
        0.1 + (0.85 * (colIdx / (totalCols > 0 ? totalCols : 1))),
        'Restauration de $colLabel (${items.length} éléments)...',
      );

      int colImported = 0;
      final chunks = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < items.length; i += 300) {
        chunks.add(
          items
              .sublist(i, (i + 300) > items.length ? items.length : (i + 300))
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }

      for (final chunk in chunks) {
        final batch = _firestore.batch();

        for (final item in chunk) {
          totalProcessed++;
          try {
            // Guarantee canonical schema and deobfuscation
            final dataToSave = Deobfuscator.deobfuscateDocument(
              Map<String, dynamic>.from(item),
              col,
            );

            final docId = dataToSave['id']?.toString() ?? _uuid.v4();
            dataToSave['id'] = docId;
            final docRef = _firestore.collection(col).doc(docId);

            // Re-attach to current enterprise & user
            dataToSave['enterprise_id'] = entId;
            if (uid != null && uid.isNotEmpty) {
              dataToSave['userId'] = uid;
              dataToSave['firebase_uid'] = uid;
            }
            dataToSave['updated_at'] = DateTime.now().toIso8601String();
            if (!dataToSave.containsKey('created_at') || dataToSave['created_at'] == null) {
              dataToSave['created_at'] = DateTime.now().toIso8601String();
            }

            if (duplicateStrategy == DuplicateHandlingStrategy.overwrite) {
              batch.set(docRef, dataToSave, SetOptions(merge: false));
              colImported++;
              totalImported++;
            } else if (duplicateStrategy == DuplicateHandlingStrategy.merge) {
              batch.set(docRef, dataToSave, SetOptions(merge: true));
              colImported++;
              totalImported++;
            } else {
              // skip: use set with merge or create
              batch.set(docRef, dataToSave, SetOptions(merge: true));
              colImported++;
              totalImported++;
            }
          } catch (e) {
            totalErrors++;
            errorMessages.add('Erreur sur $col: $e');
          }
        }

        try {
          await batch.commit();
        } catch (e) {
          totalErrors += chunk.length;
          errorMessages.add('Échec écriture par lot $col: $e');
        }
      }

      collectionCounts[col] = colImported;
    }

    onProgress?.call(1.0, 'Restauration terminée.');

    return ImportOperationResult(
      success: totalErrors == 0 || totalImported > 0,
      message: totalImported > 0
          ? 'Restauration réussie : $totalImported documents importés dans $_currentEnterpriseName.'
          : 'Aucun document importé ou des erreurs sont survenues.',
      totalProcessed: totalProcessed,
      totalImported: totalImported,
      totalSkipped: totalSkipped,
      totalErrors: totalErrors,
      collectionCounts: collectionCounts,
      errors: errorMessages,
    );
  }

  // ─── 3. MULTI-ERP PARSING (JSON & CSV) ──────────────────────────

  /// Definitions of target fields for each supported ERP collection
  static Map<ImportTargetType, List<TargetFieldDefinition>> get targetFieldDefinitions => {
        ImportTargetType.invoices: [
          const TargetFieldDefinition(
            key: 'number',
            label: 'Numéro de facture',
            description: 'Identifiant ou numéro officiel (ex: FA-2026-0001)',
            isRequired: true,
            commonAliases: ['invoicenumber', 'num_facture', 'numero', 'reference', 'code', 'num', 'facture_no', 'doc_number'],
          ),
          const TargetFieldDefinition(
            key: 'customerName',
            label: 'Nom du client',
            description: 'Nom ou raison sociale du client',
            isRequired: true,
            commonAliases: ['clientsnapshot.name', 'client_name', 'nom_client', 'customer_name', 'client', 'tiers', 'nom', 'name'],
          ),
          const TargetFieldDefinition(
            key: 'customerId',
            label: 'Identifiant / Code client',
            description: 'ID ou référence interne du client',
            commonAliases: ['clientid', 'code_client', 'customer_id', 'id_client', 'client_code'],
          ),
          const TargetFieldDefinition(
            key: 'customerTaxId',
            label: 'Matricule Fiscal client',
            description: 'N° fiscal / TVA du client',
            commonAliases: ['clientsnapshot.taxid', 'mf_client', 'taxid', 'matricule_fiscal', 'tva_client', 'nif'],
          ),
          const TargetFieldDefinition(
            key: 'customerAddress',
            label: 'Adresse client',
            description: 'Adresse physique ou postale',
            commonAliases: ['clientsnapshot.address', 'adresse_client', 'address', 'adresse', 'rue', 'city'],
          ),
          const TargetFieldDefinition(
            key: 'date',
            label: 'Date de facture',
            description: 'Date d\'émission (YYYY-MM-DD ou DD/MM/YYYY)',
            isRequired: true,
            type: 'date',
            commonAliases: ['invoicedate', 'date_facture', 'date', 'created_at', 'date_emission'],
          ),
          const TargetFieldDefinition(
            key: 'dueDate',
            label: 'Date d\'échéance',
            description: 'Date limite de paiement',
            type: 'date',
            commonAliases: ['duedate', 'date_echeance', 'echeance', 'date_limite'],
          ),
          const TargetFieldDefinition(
            key: 'status',
            label: 'Statut',
            description: 'Payée, brouillon, validée, annulée',
            commonAliases: ['status', 'statut', 'etat', 'invoice_status'],
          ),
          const TargetFieldDefinition(
            key: 'totalHT',
            label: 'Montant Total HT',
            description: 'Total hors taxes',
            type: 'number',
            commonAliases: ['subtotal', 'grosssubtotal', 'total_ht', 'montant_ht', 'brut_ht', 'ht', 'totalht'],
          ),
          const TargetFieldDefinition(
            key: 'totalTva',
            label: 'Montant TVA',
            description: 'Total de la taxe sur valeur ajoutée',
            type: 'number',
            commonAliases: ['totaltva', 'taxdetails.0.amount', 'montant_tva', 'tva', 'taxes', 'tax_amount'],
          ),
          const TargetFieldDefinition(
            key: 'totalTTC',
            label: 'Montant Total TTC',
            description: 'Total toutes taxes comprises',
            isRequired: true,
            type: 'number',
            commonAliases: ['total', 'total_ttc', 'montant_ttc', 'net_a_payer', 'ttc', 'totalttc', 'amount'],
          ),
          const TargetFieldDefinition(
            key: 'amountPaid',
            label: 'Montant déjà payé',
            description: 'Acompte ou total réglé',
            type: 'number',
            commonAliases: ['amountpaid', 'montant_paye', 'paye', 'regle', 'acompte'],
          ),
          const TargetFieldDefinition(
            key: 'timbreFiscal',
            label: 'Timbre Fiscal',
            description: 'Montant du timbre fiscal',
            type: 'number',
            commonAliases: ['timbrefiscal', 'stamptax', 'timbre', 'taxdetails.1.amount'],
          ),
          const TargetFieldDefinition(
            key: 'notes',
            label: 'Notes / Remarques',
            description: 'Commentaires ou conditions de paiement',
            commonAliases: ['notes', 'paymentterms', 'remarques', 'commentaires', 'conditions'],
          ),
          const TargetFieldDefinition(
            key: 'items',
            label: 'Lignes d\'articles (Articles/Items)',
            description: 'Tableau des articles de la facture',
            type: 'list',
            commonAliases: ['items', 'lignes', 'articles', 'details', 'products', 'lignes_facture'],
          ),
        ],
        ImportTargetType.customers: [
          const TargetFieldDefinition(
            key: 'name',
            label: 'Nom / Raison Sociale',
            description: 'Nom complet du client ou entreprise',
            isRequired: true,
            commonAliases: ['name', 'nom', 'raison_sociale', 'client_name', 'client', 'designation'],
          ),
          const TargetFieldDefinition(
            key: 'code',
            label: 'Code client',
            description: 'Code de référence (ex: CL-001)',
            commonAliases: ['code', 'code_client', 'reference', 'ref', 'customer_code'],
          ),
          const TargetFieldDefinition(
            key: 'customerType',
            label: 'Type de client',
            description: 'particulier ou entreprise',
            commonAliases: ['customertype', 'type', 'nature', 'statut_juridique'],
          ),
          const TargetFieldDefinition(
            key: 'taxId',
            label: 'Matricule Fiscal / NIF',
            description: 'Identifiant fiscal légal',
            commonAliases: ['taxid', 'matricule_fiscal', 'mf', 'nif', 'id_fiscal', 'tva_number'],
          ),
          const TargetFieldDefinition(
            key: 'phone',
            label: 'Téléphone',
            description: 'Numéro fixe ou portable',
            commonAliases: ['phone', 'telephone', 'tel', 'mobile', 'gsm', 'contact_phone'],
          ),
          const TargetFieldDefinition(
            key: 'email',
            label: 'Email',
            description: 'Adresse électronique',
            commonAliases: ['email', 'mail', 'courriel', 'e_mail'],
          ),
          const TargetFieldDefinition(
            key: 'address',
            label: 'Adresse',
            description: 'Rue et numéro',
            commonAliases: ['address', 'adresse', 'rue', 'street', 'streetaddress'],
          ),
          const TargetFieldDefinition(
            key: 'city',
            label: 'Ville / Gouvernorat',
            description: 'Ville de résidence',
            commonAliases: ['city', 'ville', 'gouvernorat', 'region', 'postalcode'],
          ),
          const TargetFieldDefinition(
            key: 'rc',
            label: 'Registre de Commerce (RC)',
            description: 'Numéro d\'enregistrement au registre',
            commonAliases: ['rc', 'registre_commerce', 'num_rc', 'trade_register'],
          ),
          const TargetFieldDefinition(
            key: 'bankAccount',
            label: 'RIB / Banque',
            description: 'Compte bancaire du client',
            commonAliases: ['bankaccount', 'rib', 'iban', 'banque', 'bankname'],
          ),
          const TargetFieldDefinition(
            key: 'notes',
            label: 'Notes / Remarques',
            description: 'Observations particulières',
            commonAliases: ['notes', 'remarques', 'privatenote', 'observations'],
          ),
        ],
        ImportTargetType.suppliers: [
          const TargetFieldDefinition(
            key: 'name',
            label: 'Nom / Raison Sociale',
            description: 'Nom du fournisseur',
            isRequired: true,
            commonAliases: ['name', 'nom', 'raison_sociale', 'fournisseur', 'supplier_name', 'societe'],
          ),
          const TargetFieldDefinition(
            key: 'code',
            label: 'Code fournisseur',
            description: 'Référence (ex: FR-001)',
            commonAliases: ['code', 'code_fournisseur', 'reference', 'ref'],
          ),
          const TargetFieldDefinition(
            key: 'taxId',
            label: 'Matricule Fiscal / NIF',
            description: 'Identifiant fiscal du fournisseur',
            commonAliases: ['taxid', 'matricule_fiscal', 'mf', 'nif', 'id_fiscal'],
          ),
          const TargetFieldDefinition(
            key: 'phone',
            label: 'Téléphone',
            description: 'Numéro de téléphone',
            commonAliases: ['phone', 'telephone', 'tel', 'mobile', 'gsm'],
          ),
          const TargetFieldDefinition(
            key: 'email',
            label: 'Email',
            description: 'Courrier électronique',
            commonAliases: ['email', 'mail', 'courriel'],
          ),
          const TargetFieldDefinition(
            key: 'address',
            label: 'Adresse',
            description: 'Adresse physique',
            commonAliases: ['address', 'adresse', 'rue', 'city', 'ville'],
          ),
          const TargetFieldDefinition(
            key: 'bankAccount',
            label: 'RIB / Banque',
            description: 'Coordonnées bancaires',
            commonAliases: ['bankaccount', 'rib', 'iban', 'banque'],
          ),
        ],
        ImportTargetType.products: [
          const TargetFieldDefinition(
            key: 'name',
            label: 'Désignation / Nom de l\'article',
            description: 'Nom ou description du produit/service',
            isRequired: true,
            commonAliases: ['description', 'name', 'nom', 'designation', 'libelle', 'item_name', 'article'],
          ),
          const TargetFieldDefinition(
            key: 'code',
            label: 'Code article',
            description: 'Code unique interne (ex: ART-001)',
            commonAliases: ['code', 'code_article', 'item_code', 'sku', 'product_code'],
          ),
          const TargetFieldDefinition(
            key: 'reference',
            label: 'Référence',
            description: 'Référence fabricant ou distributeur',
            commonAliases: ['reference', 'ref', 'item_ref', 'part_number'],
          ),
          const TargetFieldDefinition(
            key: 'description',
            label: 'Description détaillée',
            description: 'Caractéristiques techniques ou descriptif',
            commonAliases: ['detaileddescription', 'description_detaillee', 'details', 'specifications'],
          ),
          const TargetFieldDefinition(
            key: 'sellingPrice',
            label: 'Prix de vente HT',
            description: 'Prix de vente unitaire hors taxes',
            isRequired: true,
            type: 'number',
            commonAliases: ['unitprice', 'sellingprice', 'prix_vente', 'pv_ht', 'pu_ht', 'price', 'prix_unitaire'],
          ),
          const TargetFieldDefinition(
            key: 'purchasePrice',
            label: 'Prix d\'achat HT',
            description: 'Coût d\'achat fournisseur',
            type: 'number',
            commonAliases: ['buyingprice', 'purchaseprice', 'prix_achat', 'pa_ht', 'cost', 'cout_achat'],
          ),
          const TargetFieldDefinition(
            key: 'tvaRate',
            label: 'Taux TVA (%)',
            description: 'Pourcentage de TVA (19, 13, 9, 7, 0)',
            type: 'number',
            commonAliases: ['tvarate', 'tva', 'taux_tva', 'taxrate', 'tva_percent'],
          ),
          const TargetFieldDefinition(
            key: 'stockQty',
            label: 'Quantité en stock initiale',
            description: 'Quantité physique actuelle',
            type: 'number',
            commonAliases: ['stockqty', 'stock', 'quantite', 'qty', 'stock_initial', 'qte'],
          ),
          const TargetFieldDefinition(
            key: 'unit',
            label: 'Unité de mesure',
            description: 'Unité (pièce, kg, m, litre, etc.)',
            commonAliases: ['unit', 'unite', 'unite_mesure', 'mesure'],
          ),
          const TargetFieldDefinition(
            key: 'productType',
            label: 'Type d\'article',
            description: 'produit, service ou consommable',
            commonAliases: ['producttype', 'type', 'genre', 'type_article'],
          ),
          const TargetFieldDefinition(
            key: 'category',
            label: 'Catégorie / Famille',
            description: 'Classification de l\'article',
            commonAliases: ['category', 'categorie', 'familyid', 'famille', 'groupe'],
          ),
          const TargetFieldDefinition(
            key: 'barcode',
            label: 'Code-barres',
            description: 'Code EAN-13, QR ou UPC',
            commonAliases: ['barcode', 'code_barres', 'ean', 'ean13', 'upc'],
          ),
        ],
        ImportTargetType.quotes: [
          const TargetFieldDefinition(
            key: 'number',
            label: 'Numéro de devis',
            description: 'Identifiant (ex: DV-2026-0001)',
            isRequired: true,
            commonAliases: ['quotenumber', 'number', 'numero', 'num_devis', 'devis_no', 'reference'],
          ),
          const TargetFieldDefinition(
            key: 'customerName',
            label: 'Nom du client',
            description: 'Client destinataire',
            isRequired: true,
            commonAliases: ['clientsnapshot.name', 'client_name', 'nom_client', 'customer_name', 'client', 'nom'],
          ),
          const TargetFieldDefinition(
            key: 'date',
            label: 'Date d\'émission',
            description: 'Date du devis',
            isRequired: true,
            type: 'date',
            commonAliases: ['quotedate', 'date', 'date_devis', 'created_at'],
          ),
          const TargetFieldDefinition(
            key: 'dueDate',
            label: 'Date de validité',
            description: 'Validité de l\'offre',
            type: 'date',
            commonAliases: ['duedate', 'date_validite', 'validite', 'echeance'],
          ),
          const TargetFieldDefinition(
            key: 'totalHT',
            label: 'Total HT',
            description: 'Montant hors taxes',
            type: 'number',
            commonAliases: ['subtotal', 'total_ht', 'montant_ht', 'totalht'],
          ),
          const TargetFieldDefinition(
            key: 'totalTTC',
            label: 'Total TTC',
            description: 'Montant toutes taxes comprises',
            isRequired: true,
            type: 'number',
            commonAliases: ['total', 'total_ttc', 'montant_ttc', 'totalttc'],
          ),
          const TargetFieldDefinition(
            key: 'items',
            label: 'Lignes du devis',
            description: 'Articles et détails chiffrés',
            type: 'list',
            commonAliases: ['items', 'lignes', 'articles', 'details'],
          ),
        ],
        ImportTargetType.deliveryNotes: [
          const TargetFieldDefinition(
            key: 'number',
            label: 'Numéro de bon de livraison',
            description: 'Référence (ex: BL-2026-0001)',
            isRequired: true,
            commonAliases: ['number', 'num_bl', 'numero', 'deliverynotenumber', 'reference'],
          ),
          const TargetFieldDefinition(
            key: 'customerName',
            label: 'Nom du client',
            description: 'Client livré',
            isRequired: true,
            commonAliases: ['clientsnapshot.name', 'nom_client', 'customer_name', 'client'],
          ),
          const TargetFieldDefinition(
            key: 'date',
            label: 'Date de livraison',
            description: 'Date d\'expédition/livraison',
            isRequired: true,
            type: 'date',
            commonAliases: ['date', 'date_livraison', 'created_at'],
          ),
          const TargetFieldDefinition(
            key: 'items',
            label: 'Articles livrés',
            description: 'Quantités et désignations',
            type: 'list',
            commonAliases: ['items', 'lignes', 'articles'],
          ),
        ],
        ImportTargetType.purchaseInvoices: [
          const TargetFieldDefinition(
            key: 'number',
            label: 'Numéro facture d\'achat',
            description: 'N° facture fournisseur (ex: FA-001)',
            isRequired: true,
            commonAliases: ['number', 'numero', 'num_facture', 'reference'],
          ),
          const TargetFieldDefinition(
            key: 'supplierName',
            label: 'Nom du fournisseur',
            description: 'Fournisseur émetteur',
            isRequired: true,
            commonAliases: ['suppliersnapshot.name', 'fournisseur', 'supplier_name', 'nom'],
          ),
          const TargetFieldDefinition(
            key: 'date',
            label: 'Date de facture',
            description: 'Date de réception',
            isRequired: true,
            type: 'date',
            commonAliases: ['date', 'date_facture', 'created_at'],
          ),
          const TargetFieldDefinition(
            key: 'totalHT',
            label: 'Total HT',
            description: 'Montant hors taxes',
            type: 'number',
            commonAliases: ['subtotal', 'total_ht', 'montant_ht'],
          ),
          const TargetFieldDefinition(
            key: 'totalTTC',
            label: 'Total TTC',
            description: 'Montant TTC payé',
            isRequired: true,
            type: 'number',
            commonAliases: ['total', 'total_ttc', 'montant_ttc'],
          ),
        ],
      };

  /// Parses an uploaded file (JSON or CSV) and returns raw row maps along with detected column headers
  Map<String, dynamic> parseSourceFile(String rawContent, String fileExtension) {
    final cleanContent = rawContent.trim();
    if (cleanContent.isEmpty) {
      throw 'Le fichier sélectionné est vide.';
    }

    if (fileExtension.toLowerCase() == 'csv' || (!cleanContent.startsWith('{') && !cleanContent.startsWith('['))) {
      return _parseCsvContent(cleanContent);
    } else {
      return _parseJsonContent(cleanContent);
    }
  }

  /// Parses CSV format handling delimiters and quotes
  Map<String, dynamic> _parseCsvContent(String csvText) {
    final lines = const LineSplitter().convert(csvText).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      throw 'Aucune ligne détectée dans le fichier CSV.';
    }

    // Detect delimiter: comma, semicolon, tab
    final firstLine = lines.first;
    String delimiter = ',';
    if (firstLine.contains(';') && firstLine.split(';').length > firstLine.split(',').length) {
      delimiter = ';';
    } else if (firstLine.contains('\t') && firstLine.split('\t').length > firstLine.split(',').length) {
      delimiter = '\t';
    }

    List<String> splitCsvLine(String line, String delim) {
      final result = <String>[];
      final buffer = StringBuffer();
      bool inQuotes = false;

      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++; // skip escaped quote
          } else {
            inQuotes = !inQuotes;
          }
        } else if (char == delim && !inQuotes) {
          result.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      result.add(buffer.toString().trim());
      return result;
    }

    final headers = splitCsvLine(lines.first, delimiter).map((h) => h.replaceAll('"', '').trim()).toList();
    final List<Map<String, dynamic>> rows = [];

    for (int i = 1; i < lines.length; i++) {
      final values = splitCsvLine(lines[i], delimiter);
      final row = <String, dynamic>{};
      for (int h = 0; h < headers.length; h++) {
        final val = h < values.length ? values[h].replaceAll('"', '').trim() : '';
        row[headers[h]] = val;
      }
      rows.add(row);
    }

    return {
      'format': 'csv',
      'headers': headers,
      'rows': rows,
      'availableDataSets': {'csv_data': rows.length},
    };
  }

  /// Parses JSON format locating arrays and nested structures
  Map<String, dynamic> _parseJsonContent(String jsonText) {
    final decoded = jsonDecode(jsonText);
    final Map<String, int> availableDataSets = {};
    final Map<String, List<Map<String, dynamic>>> namedSets = {};

    void extractArrays(dynamic obj, String prefix) {
      if (obj is Map) {
        obj.forEach((key, val) {
          final path = prefix.isEmpty ? key.toString() : '$prefix.$key';
          if (val is List) {
            final validMaps = val
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            if (validMaps.isNotEmpty) {
              availableDataSets[path] = validMaps.length;
              namedSets[path] = validMaps;
            }
          } else if (val is Map) {
            extractArrays(val, path);
          }
        });
      } else if (obj is List) {
        final validMaps = obj
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (validMaps.isNotEmpty) {
          availableDataSets['root'] = validMaps.length;
          namedSets['root'] = validMaps;
        }
      }
    }

    extractArrays(decoded, '');

    if (availableDataSets.isEmpty) {
      throw 'Aucune liste ou collection d\'éléments n\'a été trouvée dans ce fichier JSON.';
    }

    // Pick first or largest dataset
    final defaultKey = availableDataSets.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final defaultRows = namedSets[defaultKey] ?? [];

    // Extract headers (flat + dot notation for maps)
    final Set<String> allHeaders = {};
    for (final row in defaultRows.take(20)) {
      extractHeadersFromMap(row, '', allHeaders);
    }

    return {
      'format': 'json',
      'headers': allHeaders.toList(),
      'rows': defaultRows,
      'availableDataSets': availableDataSets,
      'namedSets': namedSets,
      'defaultKey': defaultKey,
    };
  }

  void extractHeadersFromMap(Map<String, dynamic> map, String prefix, Set<String> headers) {
    map.forEach((key, val) {
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';
      headers.add(fullKey);
      if (val is Map<String, dynamic>) {
        extractHeadersFromMap(val, fullKey, headers);
      }
    });
  }

  /// Automatically suggests best matches for target fields using fuzzy matching
  Map<String, String?> suggestFieldMappings({
    required ImportTargetType targetType,
    required List<String> sourceHeaders,
  }) {
    final targets = targetFieldDefinitions[targetType] ?? [];
    final Map<String, String?> mapping = {};

    for (final target in targets) {
      String? bestMatch;
      final targetKeyNorm = target.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      // 1. Check exact key match
      for (final src in sourceHeaders) {
        final srcNorm = src.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (srcNorm == targetKeyNorm) {
          bestMatch = src;
          break;
        }
      }

      // 2. Check known aliases
      if (bestMatch == null) {
        for (final alias in target.commonAliases) {
          final aliasNorm = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          for (final src in sourceHeaders) {
            final srcNorm = src.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            if (srcNorm == aliasNorm || srcNorm.endsWith(aliasNorm)) {
              bestMatch = src;
              break;
            }
          }
          if (bestMatch != null) break;
        }
      }

      // 3. Substring matching
      if (bestMatch == null) {
        for (final src in sourceHeaders) {
          final srcNorm = src.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (srcNorm.contains(targetKeyNorm) || targetKeyNorm.contains(srcNorm)) {
            if (srcNorm.length >= 3) {
              bestMatch = src;
              break;
            }
          }
        }
      }

      mapping[target.key] = bestMatch;
    }

    return mapping;
  }

  /// Extracts value using dot notation from a row map
  dynamic _extractNestedValue(Map<String, dynamic> map, String path) {
    if (map.containsKey(path)) return map[path];

    final parts = path.split('.');
    dynamic current = map;
    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        final idx = int.parse(part);
        if (idx < current.length) {
          current = current[idx];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return current;
  }

  /// Transforms raw source rows into LogiTech target maps using visual field mapping
  List<Map<String, dynamic>> transformMappedRows({
    required ImportTargetType targetType,
    required List<Map<String, dynamic>> sourceRows,
    required Map<String, String?> fieldMapping,
    required Map<String, dynamic> fallbackValues,
  }) {
    final List<Map<String, dynamic>> transformed = [];

    for (final row in sourceRows) {
      final mappedDoc = <String, dynamic>{};
      final docId = row['id']?.toString() ?? _uuid.v4();
      mappedDoc['id'] = docId;

      fieldMapping.forEach((targetKey, sourcePath) {
        dynamic val;
        if (sourcePath != null && sourcePath.isNotEmpty && sourcePath != '__skip__') {
          val = _extractNestedValue(row, sourcePath);
        }
        val ??= fallbackValues[targetKey];

        // Type conversion
        if (val != null) {
          if (targetKey.contains('total') ||
              targetKey.contains('Price') ||
              targetKey.contains('Tax') ||
              targetKey.contains('amount') ||
              targetKey.contains('Rate') ||
              targetKey.contains('Qty')) {
            mappedDoc[targetKey] = _parseDouble(val);
          } else if (targetKey == 'date' || targetKey == 'dueDate') {
            mappedDoc[targetKey] = _parseDate(val);
          } else if (targetKey == 'items' && val is List) {
            mappedDoc[targetKey] = _normalizeItemsList(val);
          } else {
            mappedDoc[targetKey] = val.toString().trim();
          }
        }
      });

      // Provide essential defaults based on target type
      _enrichWithDefaults(targetType, mappedDoc);
      transformed.add(mappedDoc);
    }

    return transformed;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final cleanStr = val.toString().replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(cleanStr) ?? 0.0;
  }

  String _parseDate(dynamic val) {
    if (val == null) return DateTime.now().toIso8601String().split('T').first;
    if (val is DateTime) return val.toIso8601String().split('T').first;
    final str = val.toString().trim();
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed.toIso8601String().split('T').first;

    // Try DD/MM/YYYY
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          return DateTime(y, m, d).toIso8601String().split('T').first;
        }
      }
    }
    return str;
  }

  List<Map<String, dynamic>> _normalizeItemsList(List rawList) {
    final List<Map<String, dynamic>> list = [];
    for (final item in rawList) {
      if (item is Map) {
        list.add({
          'id': item['id']?.toString() ?? _uuid.v4(),
          'productId': item['productId']?.toString() ?? item['itemId']?.toString() ?? '',
          'productName': item['description']?.toString() ?? item['name']?.toString() ?? 'Article',
          'description': item['description']?.toString() ?? '',
          'quantity': _parseDouble(item['quantity'] ?? item['qty'] ?? 1),
          'unitPrice': _parseDouble(item['unitPrice'] ?? item['price'] ?? 0),
          'tvaRate': _parseDouble(item['tvaRate'] ?? item['tva'] ?? 19),
          'discount': _parseDouble(item['discount'] ?? 0),
          'unit': item['unit']?.toString() ?? 'U',
        });
      }
    }
    return list;
  }

  void _enrichWithDefaults(ImportTargetType targetType, Map<String, dynamic> doc) {
    if (targetType == ImportTargetType.invoices) {
      doc['number'] ??= 'FAC-${_uuid.v4().substring(0, 6).toUpperCase()}';
      doc['status'] ??= 'unpaid';
      doc['totalHT'] ??= doc['totalTTC'] ?? 0.0;
      doc['totalTTC'] ??= doc['totalHT'] ?? 0.0;
      doc['is_deleted'] = 0;
    } else if (targetType == ImportTargetType.customers) {
      doc['name'] ??= 'Client Importé';
      doc['code'] ??= 'CL-${_uuid.v4().substring(0, 4).toUpperCase()}';
      doc['customerType'] ??= 'particulier';
      doc['is_deleted'] = 0;
    } else if (targetType == ImportTargetType.suppliers) {
      doc['name'] ??= 'Fournisseur Importé';
      doc['code'] ??= 'FR-${_uuid.v4().substring(0, 4).toUpperCase()}';
      doc['is_deleted'] = 0;
    } else if (targetType == ImportTargetType.products) {
      doc['name'] ??= 'Article Importé';
      doc['code'] ??= 'ART-${_uuid.v4().substring(0, 4).toUpperCase()}';
      doc['sellingPrice'] ??= 0.0;
      doc['purchasePrice'] ??= 0.0;
      doc['stockQty'] ??= 0.0;
      doc['unit'] ??= 'Unité';
      doc['productType'] ??= 'produit';
      doc['is_deleted'] = 0;
    }
  }

  /// Commits mapped records into Firestore with enterprise isolation and progress streaming
  Future<ImportOperationResult> executeMappedImport({
    required ImportTargetType targetType,
    required List<Map<String, dynamic>> mappedRecords,
    required DuplicateHandlingStrategy duplicateStrategy,
    void Function(double progress, String status)? onProgress,
    bool shouldDeleteBeforeImport = false,
  }) async {
    final entId = _currentEnterpriseId;
    final uid = _currentUid;
    if (entId == null || entId.isEmpty) {
      return ImportOperationResult(
        success: false,
        message: 'Veuillez d\'abord sélectionner une entreprise active.',
      );
    }

    final collection = targetType.firestoreCollection;
    int totalProcessed = mappedRecords.length;
    int totalImported = 0;
    int totalSkipped = 0;
    int totalErrors = 0;
    final List<String> errorMessages = [];

    if (shouldDeleteBeforeImport) {
      await deleteCollectionsForEnterprise(
        enterpriseId: entId,
        collections: [collection],
        onProgress: onProgress,
      );
    }

    onProgress?.call(0.1, 'Préparation de l\'importation (${mappedRecords.length} lignes)...');

    final chunks = <List<Map<String, dynamic>>>[];
    for (int i = 0; i < mappedRecords.length; i += 300) {
      chunks.add(
        mappedRecords.sublist(
          i,
          (i + 300) > mappedRecords.length ? mappedRecords.length : (i + 300),
        ),
      );
    }

    int currentChunk = 0;
    for (final chunk in chunks) {
      currentChunk++;
      onProgress?.call(
        0.1 + (0.85 * (currentChunk / chunks.length)),
        'Écriture par lot ($currentChunk/${chunks.length})...',
      );

      final batch = _firestore.batch();

      for (final record in chunk) {
        try {
          final docId = record['id']?.toString() ?? _uuid.v4();
          final docRef = _firestore.collection(collection).doc(docId);

          final data = Map<String, dynamic>.from(record);
          data['enterprise_id'] = entId;
          if (uid != null && uid.isNotEmpty) {
            data['userId'] = uid;
            data['firebase_uid'] = uid;
          }
          data['updated_at'] = DateTime.now().toIso8601String();
          if (!data.containsKey('created_at') || data['created_at'] == null) {
            data['created_at'] = DateTime.now().toIso8601String();
          }

          batch.set(docRef, data, SetOptions(merge: true));
          totalImported++;
        } catch (e) {
          totalErrors++;
          errorMessages.add('Erreur élément : $e');
        }
      }

      try {
        await batch.commit();
      } catch (e) {
        totalErrors += chunk.length;
        totalImported -= chunk.length;
        errorMessages.add('Erreur écriture lot: $e');
      }
    }

    onProgress?.call(1.0, 'Importation terminée !');

    return ImportOperationResult(
      success: totalImported > 0,
      message: 'Importation réussie : $totalImported ${targetType.label} importés dans $_currentEnterpriseName.',
      totalProcessed: totalProcessed,
      totalImported: totalImported,
      totalSkipped: totalSkipped,
      totalErrors: totalErrors,
      collectionCounts: {collection: totalImported},
      errors: errorMessages,
    );
  }
}
