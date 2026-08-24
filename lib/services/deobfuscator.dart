import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Service responsible for deobfuscating and normalizing LogiTech Pro backup files.
/// Handles both:
/// 1. Obfuscated JSON backups (with short field names like f_01, f_10, k_hex, and d_inv, d_cli)
/// 2. Normal / Standard JSON backups (with full field names like number, total_ht, items, created_at)
class Deobfuscator {
  static const _uuid = Uuid();

  // ─── 1. COLLECTION MAPPING ─────────────────────────────────────────
  static const Map<String, String> collectionMap = {
    'd_inv': 'invoices',
    'd_qte': 'quotes',
    'd_cli': 'clients',
    'd_sup': 'fournisseurs',
    'd_art': 'articles',
    'd_ste': 'stock_entries',
    'd_stw': 'stock_withdrawals',
    'd_stm': 'stock_movements',
    'd_stt': 'stock_transfers',
    'd_ivs': 'inventory_sheets',
    'd_tra': 'treasury_accounts',
    'd_trt': 'treasury_transactions',
    'd_pay': 'paiements',
    'd_prj': 'projects',
    'd_wrh': 'warehouses',
    'd_dln': 'delivery_notes',
    'd_cso': 'customer_orders',
    'd_spo': 'supplier_orders',
    'd_pci': 'purchase_invoices',
    'd_rcv': 'receiving_vouchers',
    'd_crn': 'credit_notes',
    'd_scn': 'supplier_credit_notes',
    'd_rtn': 'return_notes',
    'd_srt': 'supplier_returns',
    'd_dtp': 'document_templates',
    'd_cst': 'company_settings',
  };

  // ─── 2. CANONICAL FIELD MAPPING (f_XX -> Firestore field) ──────────
  static const Map<String, String> fieldMap = {
    // Identifiers & Numbers
    'f_01': 'number',
    'f_02': 'code',
    'f_03': 'barcode',
    'f_04': 'name',

    // Dates & Status
    'f_05': 'date',
    'f_06': 'due_date',
    'f_07': 'status',

    // Financial Totals
    'f_08': 'total_ht',
    'f_09': 'total_tva',
    'f_10': 'total_ttc',
    'f_11': 'amount_paid',
    'f_12': 'remaining_amount',
    'f_13': 'timbre_fiscal',
    'f_14': 'global_discount_percent',
    'f_15': 'global_discount_amount',
    'f_16': 'pricing_mode',

    // Notes & General
    'f_17': 'notes',
    'f_18': 'conditions_generales',
    'f_19': 'items',

    // Relations (Customer, Supplier, Project, Warehouse)
    'f_20': 'customer_id',
    'f_21': 'customer_name',
    'f_22': 'supplier_id',
    'f_23': 'supplier_name',
    'f_24': 'project_id',
    'f_25': 'project_name',
    'f_26': 'warehouse_id',
    'f_27': 'warehouse_name',

    // Document links
    'f_28': 'order_id',
    'f_29': 'delivery_note_id',
    'f_30': 'devis_id',
    'f_31': 'credit_note_id',

    // Product & Pricing details
    'f_32': 'purchase_price',
    'f_33': 'unit_price',
    'f_34': 'tva_rate',
    'f_35': 'quantity',
    'f_36': 'min_stock_qty',
    'f_37': 'reference',
    'f_38': 'unit',
    'f_39': 'brand_id',
    'f_40': 'model',

    // Contact details
    'f_41': 'phone',
    'f_42': 'email',
    'f_43': 'address',
    'f_44': 'city',
    'f_45': 'postal_code',
    'f_46': 'country',
    'f_47': 'tax_id',
    'f_48': 'rc',
    'f_49': 'contact_person',

    // Treasury & Payment
    'f_50': 'opening_balance',
    'f_51': 'current_balance',
    'f_52': 'payment_method',
    'f_53': 'bank_name',
    'f_54': 'rib',
    'f_55': 'type',
    'f_56': 'description',
    'f_57': 'discount_percent',
    'f_58': 'amount',
    'f_59': 'product_id',
    'f_60': 'product_name',
    'f_61': 'source_warehouse_id',
    'f_62': 'target_warehouse_id',
    'f_63': 'reason',
    'f_64': 'currency',
    'f_65': 'custom_fields',
    'f_66': 'custom_fields_json',
  };

  // ─── 3. AUTO-DETECTION ─────────────────────────────────────────────

  /// Checks whether a parsed JSON map is obfuscated (short field tokens) or normal.
  static bool isObfuscated(Map<String, dynamic> json) {
    // 1. App signature or version check
    if (json['app'] == 'LGBK_OBF' || json['v'] == '2.0') {
      if (json.containsKey('data') && !json.containsKey('collections')) {
        return true;
      }
    }

    // 2. Check if top-level keys in 'data' or root start with 'd_'
    final targetMap = json['data'] is Map ? (json['data'] as Map) : json;
    for (final k in targetMap.keys) {
      final keyStr = k.toString();
      if (keyStr.startsWith('d_') || collectionMap.containsKey(keyStr)) {
        return true;
      }
    }

    // 3. Inspect document keys inside collections
    final collections = json['collections'] is Map
        ? (json['collections'] as Map)
        : (json['data'] is Map ? (json['data'] as Map) : json);

    for (final entry in collections.entries) {
      if (entry.value is List && (entry.value as List).isNotEmpty) {
        final firstDoc = (entry.value as List).first;
        if (firstDoc is Map) {
          final docKeys = firstDoc.keys.map((k) => k.toString()).toList();
          final hasObfField = docKeys.any((k) =>
              (k.startsWith('f_') && k.length == 4) || k.startsWith('k_'));
          if (hasObfField) return true;
        }
      }
    }

    return false;
  }

  // ─── 4. MAIN DEOBFUSCATION / NORMALIZATION ENTRY POINT ──────────────

  /// Parses and deobfuscates or normalizes the backup data into the canonical format:
  /// {
  ///   'version': '2.0',
  ///   'exportDate': '...',
  ///   'appName': 'LogiTech Pro',
  ///   'collections': {
  ///     'invoices': [...],
  ///     'clients': [...],
  ///     ...
  ///   }
  /// }
  static Map<String, dynamic> processBackup(Map<String, dynamic> json) {
    if (isObfuscated(json)) {
      debugPrint('[Deobfuscator] Obfuscated backup detected. Deobfuscating fields...');
      return deobfuscate(json);
    } else {
      debugPrint('[Deobfuscator] Normal backup detected. Normalizing schema...');
      return normalize(json);
    }
  }

  // ─── 5. DEOBFUSCATE OBFUSCATED JSON ────────────────────────────────

  /// Deobfuscates all collections and nested items back to their canonical Firestore fields.
  static Map<String, dynamic> deobfuscate(Map<String, dynamic> json) {
    final rawData = json['data'] is Map
        ? (json['data'] as Map<String, dynamic>)
        : (json['collections'] is Map ? (json['collections'] as Map<String, dynamic>) : json);

    final Map<String, dynamic> restoredCollections = {};

    rawData.forEach((obfColKey, docsList) {
      if (docsList is List) {
        // Map collection name back
        String realCol = collectionMap[obfColKey] ?? decodeDynamicKey(obfColKey);
        if (realCol.startsWith('col_')) {
          realCol = realCol.substring(4);
        }

        final restoredDocs = <Map<String, dynamic>>[];
        for (final doc in docsList) {
          if (doc is Map) {
            final docMap = Map<String, dynamic>.from(doc);
            final deobfDoc = deobfuscateDocument(docMap, realCol);
            restoredDocs.add(deobfDoc);
          }
        }

        restoredCollections[realCol] = restoredDocs;
      }
    });

    return {
      'version': json['v']?.toString() ?? '2.0',
      'exportDate': json['gen']?.toString() ?? json['exportDate']?.toString() ?? DateTime.now().toIso8601String(),
      'appName': 'LogiTech Pro',
      'collections': restoredCollections,
    };
  }

  /// Deobfuscates a single document in a specific collection
  static Map<String, dynamic> deobfuscateDocument(Map<String, dynamic> doc, String collectionName) {
    final Map<String, dynamic> result = {};

    doc.forEach((key, value) {
      final realKey = fieldMap[key] ?? decodeDynamicKey(key);
      result[realKey] = _deobfuscateValue(value, realKey);
    });

    // Apply collection-specific canonicalization and fill essential defaults
    _sanitizeAndEnrichDocument(result, collectionName);

    return result;
  }

  // ─── 6. NORMALIZE STANDARD / NORMAL JSON ───────────────────────────

  /// Normalizes a non-obfuscated JSON backup to ensure all required model fields exist.
  static Map<String, dynamic> normalize(Map<String, dynamic> json) {
    final rawCols = json['collections'] is Map
        ? (json['collections'] as Map<String, dynamic>)
        : (json['data'] is Map ? (json['data'] as Map<String, dynamic>) : json);

    final Map<String, dynamic> normalizedCols = {};

    rawCols.forEach((colName, docsList) {
      if (docsList is List) {
        final normalizedDocs = <Map<String, dynamic>>[];
        for (final doc in docsList) {
          if (doc is Map) {
            final docMap = Map<String, dynamic>.from(doc);
            _sanitizeAndEnrichDocument(docMap, colName);
            normalizedDocs.add(docMap);
          }
        }
        normalizedCols[colName] = normalizedDocs;
      }
    });

    return {
      'version': json['version']?.toString() ?? json['v']?.toString() ?? '2.0',
      'exportDate': json['exportDate']?.toString() ?? json['gen']?.toString() ?? DateTime.now().toIso8601String(),
      'appName': 'LogiTech Pro',
      'collections': normalizedCols,
    };
  }

  // ─── 7. RECURSIVE VALUE DEOBFUSCATION ──────────────────────────────

  static dynamic _deobfuscateValue(dynamic value, String currentKey) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final Map<String, dynamic> deobfMap = {};
      map.forEach((k, v) {
        final realK = fieldMap[k] ?? decodeDynamicKey(k);
        deobfMap[realK] = _deobfuscateValue(v, realK);
      });
      return deobfMap;
    } else if (value is List) {
      return value.map((item) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          final Map<String, dynamic> deobfItem = {};
          itemMap.forEach((k, v) {
            final realK = fieldMap[k] ?? decodeDynamicKey(k);
            deobfItem[realK] = _deobfuscateValue(v, realK);
          });
          // Sanitize item if it belongs to items list
          _sanitizeLineItem(deobfItem);
          return deobfItem;
        }
        return item;
      }).toList();
    }
    return value;
  }

  // ─── 8. SANITIZATION & FIELD ENRICHMENT ────────────────────────────

  /// Ensures that all Firestore models can deserialize without null errors
  static void _sanitizeAndEnrichDocument(Map<String, dynamic> doc, String collection) {
    final nowStr = DateTime.now().toIso8601String();

    // 1. Ensure primary ID & Timestamps
    final docId = doc['id']?.toString() ??
        doc['doc_id']?.toString() ??
        doc['_id']?.toString() ??
        _uuid.v4();
    doc['id'] = docId;

    if (doc['created_at'] == null) {
      doc['created_at'] = nowStr;
    }
    if (doc['updated_at'] == null) {
      doc['updated_at'] = nowStr;
    }
    doc['is_deleted'] ??= 0;

    // 2. Collection-specific sanitization
    switch (collection) {
      case 'invoices':
      case 'purchase_invoices':
        doc['number'] ??= 'FAC-${DateTime.now().millisecondsSinceEpoch}';
        doc['date'] ??= nowStr;
        doc['due_date'] ??= doc['date'] ?? nowStr;
        doc['status'] ??= 'unpaid';
        doc['pricing_mode'] ??= 'ht';
        doc['total_ht'] = _toDouble(doc['total_ht']);
        doc['total_tva'] = _toDouble(doc['total_tva']);
        doc['total_ttc'] = _toDouble(doc['total_ttc']);
        doc['amount_paid'] = _toDouble(doc['amount_paid']);
        doc['stamp_tax'] = _toDouble(doc['stamp_tax'] ?? doc['timbre_fiscal']);
        doc['timbre_fiscal'] = _toDouble(doc['timbre_fiscal'] ?? doc['stamp_tax']);
        doc['conditions'] ??= doc['conditions_generales'] ?? '';
        doc['conditions_generales'] ??= doc['conditions'] ?? '';
        _sanitizeItemsList(doc, docId, 'invoice_id');
        break;

      case 'quotes':
        doc['number'] ??= 'DEV-${DateTime.now().millisecondsSinceEpoch}';
        doc['date'] ??= nowStr;
        doc['validity_date'] ??= DateTime.now().add(const Duration(days: 30)).toIso8601String();
        doc['status'] ??= 'draft';
        doc['pricing_mode'] ??= 'ht';
        doc['total_ht'] = _toDouble(doc['total_ht']);
        doc['total_tva'] = _toDouble(doc['total_tva']);
        doc['total_ttc'] = _toDouble(doc['total_ttc']);
        doc['timbre_fiscal'] = _toDouble(doc['timbre_fiscal'] ?? doc['stamp_tax'] ?? 1.0);
        doc['conditions_generales'] ??= doc['conditions'] ?? '';
        _sanitizeItemsList(doc, docId, 'quote_id');
        break;

      case 'clients':
        doc['code'] ??= 'CLI-${DateTime.now().millisecondsSinceEpoch}';
        doc['name'] ??= doc['company_name'] ?? 'Client';
        doc['customer_type'] ??= 'entreprise';
        doc['country'] ??= 'Tunisia';
        doc['delivery_country'] ??= 'Tunisia';
        doc['balance'] = _toDouble(doc['balance'] ?? doc['current_balance']);
        doc['current_balance'] = doc['balance'];
        doc['credit_limit'] = _toDouble(doc['credit_limit']);
        doc['price_list'] ??= 'default';
        doc['is_default'] = doc['is_default'] == 1 || doc['is_default'] == true;
        break;

      case 'fournisseurs':
        doc['code'] ??= 'FRN-${DateTime.now().millisecondsSinceEpoch}';
        doc['name'] ??= doc['company_name'] ?? 'Fournisseur';
        doc['supplier_type'] ??= 'entreprise';
        doc['country'] ??= 'Tunisia';
        doc['delivery_country'] ??= 'Tunisia';
        doc['balance'] = _toDouble(doc['balance'] ?? doc['current_balance']);
        doc['current_balance'] = doc['balance'];
        doc['is_default'] = doc['is_default'] == 1 || doc['is_default'] == true;
        break;

      case 'articles':
        final ref = doc['reference']?.toString() ?? doc['code']?.toString() ?? '';
        final name = doc['name']?.toString() ?? ref;
        doc['code'] = (doc['code'] != null && doc['code'].toString().isNotEmpty) ? doc['code'] : ref;
        doc['name'] = name;
        doc['reference'] = ref;
        doc['product_type'] ??= 'produit';
        doc['unit'] ??= 'Unite';
        final sp = _toDouble(doc['selling_price'] ?? doc['unit_price'] ?? doc['sale_price'] ?? doc['price']);
        doc['selling_price'] = sp;
        doc['purchase_price'] = _toDouble(doc['purchase_price'] ?? doc['cost_price']);
        doc['tva_rate'] = _toDouble(doc['tva_rate'] ?? 19.0);
        doc['stock_qty'] = _toDouble(doc['stock_qty'] ?? doc['stock_quantity'] ?? doc['quantity']);
        doc['min_stock_qty'] = _toDouble(doc['min_stock_qty'] ?? doc['min_stock'] ?? 0.0);
        doc['is_active'] = doc['is_active'] != 0 && doc['is_active'] != false;
        break;

      case 'delivery_notes':
        doc['number'] ??= 'BL-${DateTime.now().millisecondsSinceEpoch}';
        doc['date'] ??= nowStr;
        doc['status'] ??= 'draft';
        doc['pricing_mode'] ??= 'ht';
        doc['total_ht'] = _toDouble(doc['total_ht']);
        doc['total_tva'] = _toDouble(doc['total_tva']);
        doc['total_ttc'] = _toDouble(doc['total_ttc']);
        doc['conditions'] ??= doc['conditions_generales'] ?? '';
        _sanitizeItemsList(doc, docId, 'delivery_note_id');
        break;

      case 'customer_orders':
      case 'supplier_orders':
        doc['number'] ??= 'CMD-${DateTime.now().millisecondsSinceEpoch}';
        doc['date'] ??= nowStr;
        doc['status'] ??= 'draft';
        doc['total_ht'] = _toDouble(doc['total_ht']);
        doc['total_tva'] = _toDouble(doc['total_tva']);
        doc['total_ttc'] = _toDouble(doc['total_ttc']);
        _sanitizeItemsList(doc, docId, 'order_id');
        break;

      case 'stock_entries':
      case 'stock_withdrawals':
      case 'stock_transfers':
      case 'inventory_sheets':
      case 'receiving_vouchers':
      case 'credit_notes':
      case 'supplier_credit_notes':
      case 'return_notes':
      case 'supplier_returns':
        doc['number'] ??= 'DOC-${DateTime.now().millisecondsSinceEpoch}';
        doc['date'] ??= nowStr;
        doc['status'] ??= 'completed';
        _sanitizeItemsList(doc, docId, 'document_id');
        break;

      case 'treasury_accounts':
        doc['name'] ??= 'Compte';
        doc['type'] ??= 'bank';
        doc['currency'] ??= 'TND';
        doc['opening_balance'] = _toDouble(doc['opening_balance']);
        doc['current_balance'] = _toDouble(doc['current_balance'] ?? doc['balance'] ?? doc['opening_balance']);
        doc['balance'] = _toDouble(doc['balance'] ?? doc['current_balance'] ?? doc['opening_balance']);
        break;

      case 'treasury_transactions':
      case 'paiements':
        doc['number'] ??= 'PAY-${DateTime.now().millisecondsSinceEpoch}';
        doc['date'] ??= nowStr;
        doc['amount'] = _toDouble(doc['amount'] ?? doc['montant']);
        doc['payment_method'] ??= 'virement';
        doc['type'] ??= 'encaissement';
        doc['status'] ??= 'completed';
        break;

      case 'warehouses':
        doc['name'] ??= 'Dépôt';
        doc['code'] ??= 'DEP-${DateTime.now().millisecondsSinceEpoch}';
        break;

      case 'projects':
        doc['name'] ??= 'Projet';
        doc['code'] ??= 'PRJ-${DateTime.now().millisecondsSinceEpoch}';
        doc['status'] ??= 'in_progress';
        break;
    }
  }

  static void _sanitizeItemsList(Map<String, dynamic> doc, String parentId, String parentIdKey) {
    if (doc['items'] != null && doc['items'] is List) {
      final items = (doc['items'] as List);
      final List<Map<String, dynamic>> updatedItems = [];
      for (final item in items) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          _sanitizeLineItem(itemMap);
          itemMap[parentIdKey] = itemMap[parentIdKey]?.toString() ?? parentId;
          itemMap['quote_id'] = itemMap['quote_id']?.toString() ?? parentId;
          itemMap['invoice_id'] = itemMap['invoice_id']?.toString() ?? parentId;
          itemMap['delivery_note_id'] = itemMap['delivery_note_id']?.toString() ?? parentId;
          itemMap['order_id'] = itemMap['order_id']?.toString() ?? parentId;
          itemMap['stock_entry_id'] = itemMap['stock_entry_id']?.toString() ?? parentId;
          itemMap['stock_withdrawal_id'] = itemMap['stock_withdrawal_id']?.toString() ?? parentId;
          itemMap['product_id'] = itemMap['product_id']?.toString() ?? 'PROD_${_uuid.v4().substring(0, 8)}';
          itemMap['id'] = itemMap['id']?.toString() ?? _uuid.v4();
          updatedItems.add(itemMap);
        }
      }
      doc['items'] = updatedItems;
    }
  }

  static void _sanitizeLineItem(Map<String, dynamic> item) {
    item['id'] = item['id']?.toString() ?? _uuid.v4();
    item['product_id'] = item['product_id']?.toString() ?? 'PROD_${_uuid.v4().substring(0, 8)}';
    final pName = item['product_name']?.toString() ?? item['designation']?.toString() ?? item['description']?.toString() ?? 'Article';
    item['product_name'] = pName;
    item['description'] = item['description']?.toString() ?? pName;
    item['quantity'] = _toDouble(item['quantity'] ?? item['qte'] ?? 1.0);
    item['unit_price'] = _toDouble(item['unit_price'] ?? item['price'] ?? item['selling_price'] ?? 0.0);
    item['tva_rate'] = _toDouble(item['tva_rate'] ?? item['tva'] ?? 19.0);
    item['discount_percent'] = _toDouble(item['discount_percent'] ?? item['discount'] ?? item['remise'] ?? 0.0);

    final subtotal = (item['quantity'] as double) * (item['unit_price'] as double);
    final disc = item['discount_percent'] as double;
    final totalHT = subtotal - (subtotal * disc / 100);
    item['total_ht'] = _toDouble(item['total_ht'] ?? totalHT);
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  // ─── 9. DYNAMIC HEX KEY DECODER ────────────────────────────────────

  static String decodeDynamicKey(String key) {
    if (key.startsWith('k_')) {
      try {
        final hexStr = key.substring(2);
        final bytes = <int>[];
        for (int i = 0; i < hexStr.length; i += 2) {
          bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
        }
        return utf8.decode(bytes);
      } catch (_) {
        return key;
      }
    }
    return key;
  }
}
