import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';

import '../utils/file_save_helper.dart';
import '../models/product.dart';
import 'enterprise_service.dart';

/// Parsed row with validation status for article import preview
class ArticleImportRow {
  final int rowIndex;
  final Map<String, dynamic> rawValues;
  final Map<String, dynamic> mappedValues;
  final bool isUpdate;
  final String? existingId;
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ArticleImportRow({
    required this.rowIndex,
    required this.rawValues,
    required this.mappedValues,
    this.isUpdate = false,
    this.existingId,
    this.isValid = true,
    this.errors = const [],
    this.warnings = const [],
  });

  String get displayName => mappedValues['name']?.toString().trim() ?? 'Article sans nom';
  String get code => mappedValues['code']?.toString().trim() ?? '';
  String get productType => mappedValues['productType']?.toString().trim() ?? 'produit';
  String get category => mappedValues['category']?.toString().trim() ?? '';
  double get sellingPrice => double.tryParse(mappedValues['sellingPrice']?.toString() ?? '0') ?? 0.0;
  double get purchasePrice => double.tryParse(mappedValues['purchasePrice']?.toString() ?? '0') ?? 0.0;
  double get tvaRate => double.tryParse(mappedValues['tvaRate']?.toString() ?? '19') ?? 19.0;
  double get stockQty => double.tryParse(mappedValues['stockQty']?.toString() ?? '0') ?? 0.0;
  String get unit => mappedValues['unit']?.toString().trim() ?? 'Unite';
  String get barcode => mappedValues['barcode']?.toString().trim() ?? '';
}

/// Result of article import
class ArticleImportResult {
  final bool success;
  final String message;
  final int totalRows;
  final int createdCount;
  final int updatedCount;
  final int skippedCount;
  final int errorCount;
  final List<String> errorMessages;

  ArticleImportResult({
    required this.success,
    required this.message,
    this.totalRows = 0,
    this.createdCount = 0,
    this.updatedCount = 0,
    this.skippedCount = 0,
    this.errorCount = 0,
    this.errorMessages = const [],
  });
}

/// Comprehensive service for Import/Export of Articles / Products supporting Excel, CSV, JSON
class ArticleImportExportService {
  static final ArticleImportExportService instance = ArticleImportExportService._();
  ArticleImportExportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get _currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId;

  // ─── Standard Fields for Articles / Products ──────────────────────
  static const List<Map<String, dynamic>> articleFieldDefs = [
    {
      'key': '_id',
      'label': 'ID Interne (_id)',
      'description': 'Laissez vide pour nouvel article, ou remplissez pour mettre à jour.',
      'required': false,
      'aliases': ['_id', 'id', 'identifier', 'id_article', 'id_produit', 'product_id', 'item_id'],
    },
    {
      'key': 'code',
      'label': 'Code / Référence',
      'description': 'Référence article unique (ex: ART-00001, PRD-001).',
      'required': false,
      'aliases': ['code', 'reference', 'ref', 'art_code', 'code_article', 'item_code', 'default_code', 'sku'],
    },
    {
      'key': 'name',
      'label': 'Nom / Désignation',
      'description': 'Nom complet de l\'article ou du service.',
      'required': true,
      'aliases': ['name', 'designation', 'description', 'nom', 'nom_article', 'libelle', 'item_name', 'label', 'product_name'],
    },
    {
      'key': 'productType',
      'label': 'Type d\'article (productType)',
      'description': '« produit » (stock géré) ou « service » ou « matière première ».',
      'required': false,
      'aliases': ['producttype', 'type', 'type_article', 'nature', 'is_service', 'type_produit', 'item_type'],
    },
    {
      'key': 'category',
      'label': 'Catégorie / Famille',
      'description': 'Catégorie ou famille d\'articles.',
      'required': false,
      'aliases': ['category', 'categorie', 'famille', 'item_group', 'product_category', 'category_name'],
    },
    {
      'key': 'sellingPrice',
      'label': 'Prix de Vente HT (sellingPrice)',
      'description': 'Prix de vente unitaire hors taxes en DT.',
      'required': false,
      'aliases': ['sellingprice', 'prix_vente', 'pv_ht', 'price', 'list_price', 'prix_unitaire', 'unitprice', 'prix_ht', 'sale_price'],
    },
    {
      'key': 'purchasePrice',
      'label': 'Prix d\'Achat HT (purchasePrice)',
      'description': 'Prix d\'achat unitaire HT en DT.',
      'required': false,
      'aliases': ['purchaseprice', 'prix_achat', 'pa_ht', 'cost', 'standard_price', 'buyingprice', 'cout_achat', 'cost_price'],
    },
    {
      'key': 'tvaRate',
      'label': 'Taux TVA (%)',
      'description': 'Taux de taxe sur la valeur ajoutée (ex: 19, 7, 13 ou 0).',
      'required': false,
      'aliases': ['tvarate', 'tva', 'tax', 'tax_rate', 'taux_tva', 'taux', 'vat', 'vat_rate'],
    },
    {
      'key': 'stockQty',
      'label': 'Quantité en Stock (stockQty)',
      'description': 'Quantité physique actuellement disponible en stock.',
      'required': false,
      'aliases': ['stockqty', 'stock', 'quantite', 'qty', 'qte', 'qty_available', 'stock_actuel', 'on_hand', 'quantity'],
    },
    {
      'key': 'minStockQty',
      'label': 'Stock Minimum / Alerte',
      'description': 'Seuil d\'alerte de stock minimum.',
      'required': false,
      'aliases': ['minstockqty', 'minstock', 'stock_min', 'seuil_alerte', 'alert_threshold', 'min_qty', 'reorder_point'],
    },
    {
      'key': 'unit',
      'label': 'Unité de Mesure',
      'description': 'Unité (ex: Unité, Pièce, Kg, Mètre, Heure, Litre).',
      'required': false,
      'aliases': ['unit', 'unite', 'uom', 'unite_mesure', 'mesure'],
    },
    {
      'key': 'barcode',
      'label': 'Code-Barres (EAN / UPC)',
      'description': 'Code-barres international ou interne.',
      'required': false,
      'aliases': ['barcode', 'code_barre', 'ean', 'ean13', 'code_barres', 'upc'],
    },
    {
      'key': 'brand',
      'label': 'Marque / Fabricant',
      'description': 'Marque ou fabricant de l\'article.',
      'required': false,
      'aliases': ['brand', 'marque', 'fabricant', 'brand_name', 'manufacturer'],
    },
    {
      'key': 'notes',
      'label': 'Remarques / Notes',
      'description': 'Notes privées ou observations sur l\'article.',
      'required': false,
      'aliases': ['notes', 'remarques', 'commentaires', 'memo', 'privatenotes', 'description_detaillee'],
    },
  ];

  // ─── 1. EXPORT TO EXCEL / CSV / JSON ─────────────────────────────

  /// Exports articles to an Excel (.xlsx) file
  Future<String?> exportArticlesToExcel({
    required BuildContext context,
    required List<Product> products,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Articles';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    final headers = [
      '_id',
      'code',
      'name',
      'reference',
      'productType',
      'category',
      'sellingPrice',
      'purchasePrice',
      'tvaRate',
      'stockQty',
      'minStockQty',
      'unit',
      'barcode',
      'brand',
      'notes',
    ];

    // Header Row
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Arial),
      );
    }

    // Data Rows
    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final r = i + 1;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(p.id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).value = TextCellValue(p.code);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).value = TextCellValue(p.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r)).value = TextCellValue(p.reference ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r)).value = TextCellValue(p.productType);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r)).value = TextCellValue(p.category ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r)).value = DoubleCellValue(p.sellingPrice);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: r)).value = DoubleCellValue(p.purchasePrice);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: r)).value = DoubleCellValue(p.tvaRate);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: r)).value = DoubleCellValue(p.stockQty);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: r)).value = DoubleCellValue(p.minStockQty);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: r)).value = TextCellValue(p.unit);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: r)).value = TextCellValue(p.barcode ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: r)).value = TextCellValue(p.brandId ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: r)).value = TextCellValue(p.privateNotes ?? p.description ?? '');
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) throw 'Erreur d\'encodage du fichier Excel.';

    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'export_articles_$timestamp.xlsx';

    return await FileSaveHelper.saveFile(
      bytes: Uint8List.fromList(fileBytes),
      fileName: fileName,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Exports articles to CSV format
  Future<String?> exportArticlesToCsv({
    required BuildContext context,
    required List<Product> products,
  }) async {
    final buffer = StringBuffer();
    final headers = [
      '_id',
      'code',
      'name',
      'reference',
      'productType',
      'category',
      'sellingPrice',
      'purchasePrice',
      'tvaRate',
      'stockQty',
      'minStockQty',
      'unit',
      'barcode',
      'brand',
      'notes',
    ];

    buffer.writeln(headers.join(';'));

    for (final p in products) {
      final values = [
        p.id,
        p.code,
        p.name.replaceAll(';', ','),
        p.reference ?? '',
        p.productType,
        p.category ?? '',
        p.sellingPrice.toStringAsFixed(3),
        p.purchasePrice.toStringAsFixed(3),
        p.tvaRate.toStringAsFixed(1),
        p.stockQty.toStringAsFixed(2),
        p.minStockQty.toStringAsFixed(2),
        p.unit,
        p.barcode ?? '',
        p.brandId ?? '',
        (p.privateNotes ?? p.description ?? '').replaceAll(';', ','),
      ];
      buffer.writeln(values.map((v) => '"${v.replaceAll('"', '""')}"').join(';'));
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'export_articles_$timestamp.csv';

    return await FileSaveHelper.saveFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// Exports articles to JSON format
  Future<String?> exportArticlesToJson({
    required BuildContext context,
    required List<Product> products,
  }) async {
    final list = products.map((p) => p.toMap()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'export_articles_$timestamp.json';

    return await FileSaveHelper.saveFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/json',
    );
  }

  // ─── 2. DOWNLOADABLE TEMPLATES (EXCEL & CSV) ─────────────────────

  /// Generates a standardized Excel (.xlsx) template for articles with sample rows
  Future<String?> downloadExcelTemplate() async {
    final excel = Excel.createExcel();
    const sheetName = 'Modèle Import Articles';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    final headers = [
      '_id',
      'code',
      'name',
      'productType',
      'category',
      'sellingPrice',
      'purchasePrice',
      'tvaRate',
      'stockQty',
      'minStockQty',
      'unit',
      'barcode',
      'brand',
      'notes',
    ];

    // Header Row
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Sample Row 1 (Produit standard stocké)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue(''); // _id empty for new
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('ART-00001');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = TextCellValue('Ordinateur Portable Dell Vostro');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = TextCellValue('produit');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = TextCellValue('Informatique');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value = DoubleCellValue(2150.000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1)).value = DoubleCellValue(1750.000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1)).value = DoubleCellValue(19.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1)).value = DoubleCellValue(10.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 1)).value = DoubleCellValue(2.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 1)).value = TextCellValue('Unité');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 1)).value = TextCellValue('6191234567890');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 1)).value = TextCellValue('Dell');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 1)).value = TextCellValue('Garantie 1 an constructeur');

    // Sample Row 2 (Service / Prestation non stockée)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue(''); // _id empty for new
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = TextCellValue('SRV-00001');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value = TextCellValue('Installation & Configuration Réseau');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value = TextCellValue('service');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2)).value = TextCellValue('Prestations');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 2)).value = DoubleCellValue(120.000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 2)).value = DoubleCellValue(0.000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 2)).value = DoubleCellValue(19.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 2)).value = DoubleCellValue(0.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 2)).value = DoubleCellValue(0.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 2)).value = TextCellValue('Heure');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 2)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 2)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 2)).value = TextCellValue('Facturation au temps passé');

    // Sample Row 3 (Mise à jour d'un article existant via son _id)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = TextCellValue('art-exist-12345'); // sample _id
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = TextCellValue('ART-00002');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3)).value = TextCellValue('Imprimante HP LaserJet Pro MAJ');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3)).value = TextCellValue('produit');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3)).value = TextCellValue('Bureautique');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3)).value = DoubleCellValue(580.000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 3)).value = DoubleCellValue(460.000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 3)).value = DoubleCellValue(19.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 3)).value = DoubleCellValue(5.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 3)).value = DoubleCellValue(1.0);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 3)).value = TextCellValue('Unité');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 3)).value = TextCellValue('0198765432109');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 3)).value = TextCellValue('HP');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 3)).value = TextCellValue('Mise à jour automatique par _id');

    final fileBytes = excel.encode();
    if (fileBytes == null) throw 'Erreur de génération du modèle Excel.';

    const fileName = 'modele_import_articles.xlsx';
    return await FileSaveHelper.saveFile(
      bytes: Uint8List.fromList(fileBytes),
      fileName: fileName,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ─── 3. FILE PARSING (EXCEL, CSV, JSON) ──────────────────────────

  Map<String, dynamic> parseArticleFile(Uint8List bytes, String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

    if (ext == 'xlsx' || ext == 'xls') {
      return _parseExcelFile(bytes);
    } else if (ext == 'csv' || ext == 'txt') {
      final content = utf8.decode(bytes, allowMalformed: true);
      return _parseCsvFile(content);
    } else if (ext == 'json') {
      final content = utf8.decode(bytes);
      return _parseJsonFile(content);
    } else {
      throw 'Format de fichier non supporté ($ext). Veuillez utiliser .xlsx, .csv ou .json.';
    }
  }

  Map<String, dynamic> _parseExcelFile(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw 'Le fichier Excel ne contient aucune feuille de calcul.';
    }

    final tableKey = excel.tables.keys.firstWhere(
      (k) => excel.tables[k]!.rows.isNotEmpty,
      orElse: () => excel.tables.keys.first,
    );
    final sheet = excel.tables[tableKey]!;
    final rowsList = sheet.rows;

    if (rowsList.isEmpty) {
      throw 'La feuille Excel sélectionnée est vide.';
    }

    final headerRow = rowsList.first;
    final List<String> headers = [];
    for (int i = 0; i < headerRow.length; i++) {
      final val = headerRow[i]?.value?.toString().trim() ?? '';
      headers.add(val.isNotEmpty ? val : 'Colonne_$i');
    }

    final List<Map<String, dynamic>> rows = [];
    for (int r = 1; r < rowsList.length; r++) {
      final row = rowsList[r];
      bool isRowEmpty = true;
      final rowMap = <String, dynamic>{};

      for (int c = 0; c < headers.length; c++) {
        if (c < row.length) {
          final cell = row[c];
          final rawVal = cell?.value;
          if (rawVal != null) {
            final valStr = rawVal.toString().trim();
            if (valStr.isNotEmpty) isRowEmpty = false;
            rowMap[headers[c]] = valStr;
          } else {
            rowMap[headers[c]] = '';
          }
        } else {
          rowMap[headers[c]] = '';
        }
      }

      if (!isRowEmpty) {
        rows.add(rowMap);
      }
    }

    return {
      'format': 'xlsx',
      'headers': headers,
      'rows': rows,
      'totalRows': rows.length,
    };
  }

  Map<String, dynamic> _parseCsvFile(String csvContent) {
    final lines = const LineSplitter().convert(csvContent).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw 'Le fichier CSV est vide.';

    final firstLine = lines.first;
    String delimiter = ';';
    if (firstLine.split(',').length > firstLine.split(';').length) {
      delimiter = ',';
    } else if (firstLine.split('\t').length > firstLine.split(';').length) {
      delimiter = '\t';
    }

    List<String> splitLine(String l) {
      final list = <String>[];
      final sb = StringBuffer();
      bool inQuote = false;
      for (int i = 0; i < l.length; i++) {
        final c = l[i];
        if (c == '"') {
          if (inQuote && i + 1 < l.length && l[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            inQuote = !inQuote;
          }
        } else if (c == delimiter && !inQuote) {
          list.add(sb.toString().trim());
          sb.clear();
        } else {
          sb.write(c);
        }
      }
      list.add(sb.toString().trim());
      return list;
    }

    final headers = splitLine(lines.first).map((h) => h.replaceAll('"', '').trim()).toList();
    final List<Map<String, dynamic>> rows = [];

    for (int i = 1; i < lines.length; i++) {
      final vals = splitLine(lines[i]);
      final rowMap = <String, dynamic>{};
      for (int c = 0; c < headers.length; c++) {
        rowMap[headers[c]] = c < vals.length ? vals[c].replaceAll('"', '').trim() : '';
      }
      rows.add(rowMap);
    }

    return {
      'format': 'csv',
      'headers': headers,
      'rows': rows,
      'totalRows': rows.length,
    };
  }

  Map<String, dynamic> _parseJsonFile(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    List<Map<String, dynamic>> rows = [];

    if (decoded is List) {
      rows = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else if (decoded is Map) {
      for (final val in decoded.values) {
        if (val is List && val.isNotEmpty && val.first is Map) {
          rows = val.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          break;
        }
      }
      if (rows.isEmpty) {
        rows = [Map<String, dynamic>.from(decoded)];
      }
    }

    final Set<String> headers = {};
    for (final r in rows.take(20)) {
      headers.addAll(r.keys);
    }

    return {
      'format': 'json',
      'headers': headers.toList(),
      'rows': rows,
      'totalRows': rows.length,
    };
  }

  // ─── 4. SMART AUTO-MAPPING FOR COMMON ERPS ───────────────────────

  Map<String, String?> autoSuggestMappings(List<String> sourceHeaders) {
    final Map<String, String?> mapping = {};

    for (final def in articleFieldDefs) {
      final targetKey = def['key'] as String;
      final targetNorm = targetKey.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final aliases = (def['aliases'] as List<String>? ?? []).map((a) => a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')).toList();

      String? bestMatch;

      // 1. Exact match
      for (final src in sourceHeaders) {
        final srcNorm = src.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (srcNorm == targetNorm || aliases.contains(srcNorm)) {
          bestMatch = src;
          break;
        }
      }

      // 2. Contains match
      if (bestMatch == null) {
        for (final src in sourceHeaders) {
          final srcNorm = src.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          for (final a in aliases) {
            if (srcNorm.contains(a) || a.contains(srcNorm)) {
              if (srcNorm.length >= 3) {
                bestMatch = src;
                break;
              }
            }
          }
          if (bestMatch != null) break;
        }
      }

      mapping[targetKey] = bestMatch;
    }

    return mapping;
  }

  // ─── 5. VALIDATION, DATA PREVIEW & DEDUPLICATION ─────────────────

  Future<List<ArticleImportRow>> validateAndPrepareRows({
    required List<Map<String, dynamic>> rawRows,
    required Map<String, String?> fieldMapping,
    required Map<String, dynamic> fallbackValues,
  }) async {
    final entId = _currentEnterpriseId;

    // Fetch existing product IDs and codes in Firestore
    final Set<String> existingIds = {};
    if (entId != null && entId.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('articles')
            .where('enterprise_id', isEqualTo: entId)
            .get();
        for (final doc in snap.docs) {
          existingIds.add(doc.id);
        }
      } catch (e) {
        debugPrint('Validation prefetch error: $e');
      }
    }

    final List<ArticleImportRow> validatedList = [];

    for (int i = 0; i < rawRows.length; i++) {
      final raw = rawRows[i];
      final mapped = <String, dynamic>{};
      final List<String> errors = [];
      final List<String> warnings = [];

      fieldMapping.forEach((targetKey, sourceCol) {
        dynamic val;
        if (sourceCol != null && sourceCol.isNotEmpty && sourceCol != '__skip__' && raw.containsKey(sourceCol)) {
          val = raw[sourceCol];
        }
        val ??= fallbackValues[targetKey];
        if (val != null) {
          mapped[targetKey] = val.toString().trim();
        }
      });

      // Extract _id
      String rawId = mapped['_id']?.toString().trim() ?? '';
      bool isUpdate = false;
      String? existingId;

      if (rawId.isNotEmpty && existingIds.contains(rawId)) {
        isUpdate = true;
        existingId = rawId;
      } else if (rawId.isNotEmpty) {
        warnings.add('L\'identifiant _id "$rawId" est introuvable. Un nouvel article sera créé.');
      }

      // Check name (required)
      final name = mapped['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        errors.add('Le nom / la désignation de l\'article est obligatoire.');
      }

      // Product Type
      String productType = mapped['productType']?.toString().toLowerCase().trim() ?? 'produit';
      if (productType.contains('service') || productType.contains('prestation')) {
        productType = 'service';
      } else if (productType.contains('matiere') || productType.contains('consommable')) {
        productType = 'matiere_premiere';
      } else {
        productType = 'produit';
      }
      mapped['productType'] = productType;

      // Format code if empty
      if (!mapped.containsKey('code') || (mapped['code'] as String).isEmpty) {
        mapped['code'] = 'ART-${(i + 1).toString().padLeft(5, '0')}';
      }

      // Parse sellingPrice
      final sellPriceStr = mapped['sellingPrice']?.toString().trim() ?? '';
      if (sellPriceStr.isNotEmpty) {
        final clean = sellPriceStr.replaceAll(RegExp(r'[^0-9.-]'), '');
        final parsed = double.tryParse(clean);
        if (parsed == null) {
          warnings.add('Prix de vente "$sellPriceStr" invalide (0 par défaut).');
          mapped['sellingPrice'] = 0.0;
        } else {
          mapped['sellingPrice'] = parsed;
        }
      } else {
        mapped['sellingPrice'] = 0.0;
      }

      // Parse purchasePrice
      final buyPriceStr = mapped['purchasePrice']?.toString().trim() ?? '';
      if (buyPriceStr.isNotEmpty) {
        final clean = buyPriceStr.replaceAll(RegExp(r'[^0-9.-]'), '');
        mapped['purchasePrice'] = double.tryParse(clean) ?? 0.0;
      } else {
        mapped['purchasePrice'] = 0.0;
      }

      // Parse tvaRate
      final tvaStr = mapped['tvaRate']?.toString().trim() ?? '';
      if (tvaStr.isNotEmpty) {
        final clean = tvaStr.replaceAll(RegExp(r'[^0-9.]'), '');
        mapped['tvaRate'] = double.tryParse(clean) ?? 19.0;
      } else {
        mapped['tvaRate'] = 19.0;
      }

      // Parse stockQty
      final stockStr = mapped['stockQty']?.toString().trim() ?? '';
      if (stockStr.isNotEmpty) {
        final clean = stockStr.replaceAll(RegExp(r'[^0-9.-]'), '');
        mapped['stockQty'] = double.tryParse(clean) ?? 0.0;
      } else {
        mapped['stockQty'] = 0.0;
      }

      // Parse minStockQty
      final minStockStr = mapped['minStockQty']?.toString().trim() ?? '';
      if (minStockStr.isNotEmpty) {
        final clean = minStockStr.replaceAll(RegExp(r'[^0-9.-]'), '');
        mapped['minStockQty'] = double.tryParse(clean) ?? 0.0;
      } else {
        mapped['minStockQty'] = 0.0;
      }

      // Unit
      if (!mapped.containsKey('unit') || (mapped['unit'] as String).isEmpty) {
        mapped['unit'] = 'Unite';
      }

      validatedList.add(
        ArticleImportRow(
          rowIndex: i + 1,
          rawValues: raw,
          mappedValues: mapped,
          isUpdate: isUpdate,
          existingId: existingId,
          isValid: errors.isEmpty,
          errors: errors,
          warnings: warnings,
        ),
      );
    }

    return validatedList;
  }

  // ─── 6. EXECUTE IMPORT OPERATION ─────────────────────────────────

  Future<ArticleImportResult> executeArticleImport({
    required BuildContext context,
    required List<ArticleImportRow> rows,
    void Function(double progress, String status)? onProgress,
  }) async {
    final entId = _currentEnterpriseId;
    final uid = _currentUid;
    if (entId == null || entId.isEmpty) {
      return ArticleImportResult(
        success: false,
        message: 'Aucune entreprise active sélectionnée.',
      );
    }

    final validRows = rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      return ArticleImportResult(
        success: false,
        message: 'Aucune ligne valide à importer.',
        errorCount: rows.length,
      );
    }

    int createdCount = 0;
    int updatedCount = 0;
    int errorCount = rows.length - validRows.length;
    final List<String> errorMessages = [];

    onProgress?.call(0.1, 'Préparation des ${validRows.length} articles...');

    // Chunk into batches of 300
    final chunks = <List<ArticleImportRow>>[];
    for (int i = 0; i < validRows.length; i += 300) {
      chunks.add(
        validRows.sublist(
          i,
          (i + 300) > validRows.length ? validRows.length : (i + 300),
        ),
      );
    }

    int currentChunk = 0;
    for (final chunk in chunks) {
      currentChunk++;
      onProgress?.call(
        0.1 + (0.85 * (currentChunk / chunks.length)),
        'Enregistrement des articles ($currentChunk/${chunks.length})...',
      );

      final batch = _firestore.batch();

      for (final row in chunk) {
        try {
          final docId = row.isUpdate && row.existingId != null ? row.existingId! : _uuid.v4();
          final docRef = _firestore.collection('articles').doc(docId);

          final m = row.mappedValues;
          final Map<String, dynamic> docData = {
            'id': docId,
            'code': m['code'] ?? 'ART-${_uuid.v4().substring(0, 4).toUpperCase()}',
            'name': m['name'] ?? 'Article sans nom',
            'productType': m['productType'] ?? 'produit',
            'category': m['category'] ?? '',
            'sellingPrice': m['sellingPrice'] ?? 0.0,
            'purchasePrice': m['purchasePrice'] ?? 0.0,
            'tvaRate': m['tvaRate'] ?? 19.0,
            'stockQty': m['stockQty'] ?? 0.0,
            'minStockQty': m['minStockQty'] ?? 0.0,
            'unit': m['unit'] ?? 'Unite',
            'barcode': m['barcode'] ?? '',
            'brandId': m['brand'] ?? '',
            'privateNotes': m['notes'] ?? '',
            'isActive': true,
            'isDeleted': 0,
            'is_deleted': 0,
            'enterprise_id': entId,
            'userId': uid ?? '',
            'firebase_uid': uid ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          };

          if (!row.isUpdate) {
            docData['createdAt'] = DateTime.now().toIso8601String();
            docData['created_at'] = DateTime.now().toIso8601String();
          }

          batch.set(docRef, docData, SetOptions(merge: true));

          if (row.isUpdate) {
            updatedCount++;
          } else {
            createdCount++;
          }
        } catch (e) {
          errorCount++;
          errorMessages.add('Erreur ligne ${row.rowIndex}: $e');
        }
      }

      try {
        await batch.commit();
      } catch (e) {
        errorCount += chunk.length;
        errorMessages.add('Échec de la validation du lot : $e');
      }
    }

    onProgress?.call(1.0, 'Importation terminée avec succès !');

    return ArticleImportResult(
      success: createdCount > 0 || updatedCount > 0,
      message: 'Importation terminée : $createdCount créés, $updatedCount mis à jour sur ${rows.length} lignes.',
      totalRows: rows.length,
      createdCount: createdCount,
      updatedCount: updatedCount,
      skippedCount: rows.length - validRows.length,
      errorCount: errorCount,
      errorMessages: errorMessages,
    );
  }
}
