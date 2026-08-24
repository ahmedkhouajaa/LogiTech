import 'dart:convert';
import 'deobfuscator.dart';

/// Service responsible for obfuscating and de-obfuscating LogiTech Pro JSON backups.
///
/// Features:
/// 1. Strips all sensitive metadata (userId, enterpriseId, uid, ownerId, isDeleted, timestamps, internal Firestore indices).
/// 2. Obfuscates collection names into short abstract keys (e.g. 'invoices' -> 'd_inv', 'clients' -> 'd_cli').
/// 3. Obfuscates field names into short keys (e.g. 'clientName' -> 'f_02', 'totalHT' -> 'f_07').
/// 4. Handles recursive nested maps and item lists.
/// 5. Automatically restores canonical Firestore field and collection names upon import.
class BackupObfuscationService {
  static final BackupObfuscationService instance = BackupObfuscationService._();
  BackupObfuscationService._();

  static const String version = '2.0';
  static const String appSignature = 'LGBK_OBF';

  // ─── 1. SENSITIVE METADATA EXCLUSION LIST ─────────────────────────
  // These fields are completely stripped from exported JSON files.
  static final Set<String> _excludedFields = {
    'id',
    '_id',
    'doc_id',
    'document_id',
    'enterprise_id',
    'enterpriseId',
    'enterprise_name',
    'enterpriseName',
    'user_id',
    'userId',
    'firebase_uid',
    'firebaseUid',
    'uid',
    'owner_id',
    'ownerId',
    'created_by',
    'createdBy',
    'updated_by',
    'updatedBy',
    'is_deleted',
    'isDeleted',
    'deleted',
    'deleted_at',
    'deletedAt',
    'is_active',
    'isActive',
    'created_at',
    'createdAt',
    'updated_at',
    'updatedAt',
    '_timestamp',
    'timestamp',
    'search_terms',
    'searchTerms',
    'search_index',
    'searchIndex',
    'search_keywords',
    'sync_status',
    'syncStatus',
    'local_id',
    'firestore_id',
  };

  // ─── 2. COLLECTION NAME OBFUSCATION DICTIONARY ─────────────────────
  static const Map<String, String> _collectionToObf = {
    'invoices': 'd_inv',
    'quotes': 'd_qte',
    'clients': 'd_cli',
    'fournisseurs': 'd_sup',
    'articles': 'd_art',
    'stock_entries': 'd_ste',
    'stock_withdrawals': 'd_stw',
    'stock_movements': 'd_stm',
    'stock_transfers': 'd_stt',
    'inventory_sheets': 'd_ivs',
    'treasury_accounts': 'd_tra',
    'treasury_transactions': 'd_trt',
    'paiements': 'd_pay',
    'projects': 'd_prj',
    'warehouses': 'd_wrh',
    'delivery_notes': 'd_dln',
    'customer_orders': 'd_cso',
    'supplier_orders': 'd_spo',
    'purchase_invoices': 'd_pci',
    'receiving_vouchers': 'd_rcv',
    'credit_notes': 'd_crn',
    'supplier_credit_notes': 'd_scn',
    'return_notes': 'd_rtn',
    'supplier_returns': 'd_srt',
    'document_templates': 'd_dtp',
    'company_settings': 'd_cst',
  };

  // ─── 3. FIELD NAME OBFUSCATION DICTIONARY ──────────────────────────
  static const Map<String, String> _fieldToObf = {
    // Identifiers & Numbers
    'number': 'f_01',
    'numero': 'f_01',
    'code': 'f_02',
    'reference': 'f_02',
    'sku': 'f_02',
    'barcode': 'f_03',
    'name': 'f_04',
    'nom': 'f_04',
    'title': 'f_04',
    'libelle': 'f_04',

    // Dates & Status
    'date': 'f_05',
    'doc_date': 'f_05',
    'date_facture': 'f_05',
    'due_date': 'f_06',
    'dueDate': 'f_06',
    'echeance': 'f_06',
    'status': 'f_07',
    'statut': 'f_07',
    'state': 'f_07',

    // Financial Totals
    'total_ht': 'f_08',
    'totalHT': 'f_08',
    'total_tva': 'f_09',
    'totalTva': 'f_09',
    'total_ttc': 'f_10',
    'totalTTC': 'f_10',
    'amount_paid': 'f_11',
    'amountPaid': 'f_11',
    'remaining_amount': 'f_12',
    'remainingAmount': 'f_12',
    'timbre_fiscal': 'f_13',
    'timbreFiscal': 'f_13',
    'stampTax': 'f_13',
    'global_discount_percent': 'f_14',
    'globalDiscountPercent': 'f_14',
    'global_discount_amount': 'f_15',
    'globalDiscountAmount': 'f_15',
    'pricing_mode': 'f_16',
    'pricingMode': 'f_16',

    // Notes & General
    'notes': 'f_17',
    'remark': 'f_17',
    'comment': 'f_17',
    'conditions_generales': 'f_18',
    'conditionsGenerales': 'f_18',
    'items': 'f_19',
    'lines': 'f_19',

    // Relations (Customer, Supplier, Project, Warehouse)
    'customer_id': 'f_20',
    'customerId': 'f_20',
    'client_id': 'f_20',
    'customer_name': 'f_21',
    'customerName': 'f_21',
    'client_nom': 'f_21',
    'supplier_id': 'f_22',
    'supplierId': 'f_22',
    'fournisseur_id': 'f_22',
    'supplier_name': 'f_23',
    'supplierName': 'f_23',
    'fournisseur_nom': 'f_23',
    'project_id': 'f_24',
    'projectId': 'f_24',
    'project_name': 'f_25',
    'projectName': 'f_25',
    'warehouse_id': 'f_26',
    'warehouseId': 'f_26',
    'warehouse_name': 'f_27',
    'warehouseName': 'f_27',

    // Document links
    'order_id': 'f_28',
    'orderId': 'f_28',
    'delivery_note_id': 'f_29',
    'deliveryNoteId': 'f_29',
    'devis_id': 'f_30',
    'devisId': 'f_30',
    'credit_note_id': 'f_31',
    'creditNoteId': 'f_31',

    // Product & Pricing details
    'purchase_price': 'f_32',
    'purchasePrice': 'f_32',
    'sale_price': 'f_33',
    'salePrice': 'f_33',
    'unit_price': 'f_33',
    'unitPrice': 'f_33',
    'price': 'f_33',
    'tva_rate': 'f_34',
    'tvaRate': 'f_34',
    'tva': 'f_34',
    'quantity': 'f_35',
    'stock_quantity': 'f_35',
    'stockQuantity': 'f_35',
    'qte': 'f_35',
    'min_stock': 'f_36',
    'minStock': 'f_36',
    'category': 'f_37',
    'categorie': 'f_37',
    'family': 'f_37',
    'unit': 'f_38',
    'unite': 'f_38',
    'brand': 'f_39',
    'marque': 'f_39',
    'model': 'f_40',
    'modele': 'f_40',

    // Contact details
    'phone': 'f_41',
    'telephone': 'f_41',
    'mobile': 'f_41',
    'email': 'f_42',
    'mail': 'f_42',
    'address': 'f_43',
    'adresse': 'f_43',
    'city': 'f_44',
    'ville': 'f_44',
    'postal_code': 'f_45',
    'postalCode': 'f_45',
    'code_postal': 'f_45',
    'country': 'f_46',
    'pays': 'f_46',
    'tax_id': 'f_47',
    'taxId': 'f_47',
    'matricule_fiscale': 'f_47',
    'trade_registry': 'f_48',
    'tradeRegistry': 'f_48',
    'registre_commerce': 'f_48',
    'contact_person': 'f_49',
    'contactPerson': 'f_49',
    'responsable': 'f_49',

    // Treasury & Payment
    'opening_balance': 'f_50',
    'openingBalance': 'f_50',
    'current_balance': 'f_51',
    'currentBalance': 'f_51',
    'payment_method': 'f_52',
    'paymentMethod': 'f_52',
    'bank_name': 'f_53',
    'bankName': 'f_53',
    'rib': 'f_54',
    'iban': 'f_54',
    'type': 'f_55',
    'description': 'f_56',
    'designation': 'f_56',
    'discount': 'f_57',
    'remise': 'f_57',
    'amount': 'f_58',
    'montant': 'f_58',
    'product_id': 'f_59',
    'productId': 'f_59',
    'product_name': 'f_60',
    'productName': 'f_60',
    'source_warehouse_id': 'f_61',
    'sourceWarehouseId': 'f_61',
    'target_warehouse_id': 'f_62',
    'targetWarehouseId': 'f_62',
    'reason': 'f_63',
    'motif': 'f_63',
    'currency': 'f_64',
    'custom_fields': 'f_65',
    'customFields': 'f_66',
  };

  // ─── HELPER: Dynamic key fallback encoding ─────────────────────────
  static String _encodeDynamicKey(String key) {
    // If not in static dictionary, encode as 'k_' + hex representation
    final bytes = utf8.encode(key);
    final hexStr = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'k_$hexStr';
  }

  // ─── 4. OBFUSCATE EXPORT MAP ───────────────────────────────────────

  /// Converts a full raw Firestore enterprise export map into an obfuscated JSON representation.
  /// Removes all internal metadata and encodes collections and fields into short tokens.
  Map<String, dynamic> obfuscateBackupData(Map<String, dynamic> rawExportData) {
    final rawCollections = rawExportData['collections'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> obfuscatedCollections = {};

    rawCollections.forEach((colName, docsList) {
      if (docsList is List) {
        final obfColKey = _collectionToObf[colName] ?? _encodeDynamicKey('col_$colName');
        final obfDocs = <Map<String, dynamic>>[];

        for (final doc in docsList) {
          if (doc is Map<String, dynamic>) {
            final obfDoc = _obfuscateMap(doc);
            if (obfDoc.isNotEmpty) {
              obfDocs.add(obfDoc);
            }
          }
        }

        obfuscatedCollections[obfColKey] = obfDocs;
      }
    });

    return {
      'v': version,
      'app': appSignature,
      'gen': DateTime.now().toUtc().toIso8601String(),
      'data': obfuscatedCollections,
    };
  }

  Map<String, dynamic> _obfuscateMap(Map<String, dynamic> source) {
    final Map<String, dynamic> result = {};

    source.forEach((key, value) {
      // 1. Skip sensitive/internal metadata
      if (_excludedFields.contains(key) || _excludedFields.contains(key.toLowerCase())) {
        return;
      }

      // 2. Determine obfuscated key name
      final obfKey = _fieldToObf[key] ?? _encodeDynamicKey(key);

      // 3. Obfuscate value recursively if nested
      result[obfKey] = _obfuscateValue(value);
    });

    return result;
  }

  dynamic _obfuscateValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _obfuscateMap(value);
    } else if (value is Map) {
      return _obfuscateMap(Map<String, dynamic>.from(value));
    } else if (value is List) {
      return value.map((item) => _obfuscateValue(item)).toList();
    }
    return value;
  }

  // ─── 5. DE-OBFUSCATE & NORMALIZE IMPORT MAP ─────────────────────────

  /// Checks if parsed JSON content is in the obfuscated format and converts it back to standard Firestore schema,
  /// or normalizes plain JSON backups so all required fields are present.
  Map<String, dynamic> deobfuscateBackupData(Map<String, dynamic> parsedJson) {
    return Deobfuscator.processBackup(parsedJson);
  }
}
