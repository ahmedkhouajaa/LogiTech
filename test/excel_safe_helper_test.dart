import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/utils/excel_safe_helper.dart';
import 'package:business_manager_pro/services/article_import_export_service.dart';
import 'package:business_manager_pro/services/contact_import_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExcelSafeHelper & Import Tests', () {
    test('Correctly decodes and parses Article Excel files with WPS/Excel formatting quirks', () {
      final file = File(r'C:\Users\Client\Downloads\modele_import_articles_20_articles_ajoutes(1).xlsx');
      if (!file.existsSync()) {
        return;
      }

      final bytes = file.readAsBytesSync();
      final sanitized = ExcelSafeHelper.sanitizeXlsxBytes(bytes);
      expect(sanitized, isNotNull);

      final parsed = ArticleImportExportService.instance.parseArticleFile(bytes, file.uri.pathSegments.last);
      expect(parsed['format'], equals('xlsx'));
      expect(parsed['totalRows'], equals(23));

      final rows = parsed['rows'] as List;
      expect(rows.length, equals(23));

      final row0 = rows[0] as Map<String, dynamic>;
      expect(row0['name'], equals('Ordinateur Portable Dell Vostro'));
      expect(row0['code'], equals('ART-00001'));
      expect(row0['productType'], equals('produit'));
    });

    test('Correctly decodes and parses Contact (Client & Fournisseur) Excel files', () {
      // Test with existing exported clients file if present
      final clientFile = File(r'C:\Users\Client\Downloads\export_clients_2026-08-23.xlsx');
      if (clientFile.existsSync()) {
        final bytes = clientFile.readAsBytesSync();
        final parsed = ContactImportExportService.instance.parseContactFile(bytes, clientFile.uri.pathSegments.last);
        expect(parsed['format'], equals('xlsx'));
        expect((parsed['rows'] as List).isNotEmpty, isTrue);

        final headers = (parsed['headers'] as List).map((e) => e.toString()).toList();
        final customerMapping = ContactImportExportService.instance.autoSuggestMappings(headers);
        expect(customerMapping['companyName'], isNotNull);

        final supplierMapping = ContactImportExportService.instance.autoSuggestMappings(headers);
        expect(supplierMapping['companyName'], isNotNull);
      }

      // Also test with article file to ensure contact parser handles external files gracefully
      final articleFile = File(r'C:\Users\Client\Downloads\modele_import_articles_20_articles_ajoutes(1).xlsx');
      if (articleFile.existsSync()) {
        final bytes = articleFile.readAsBytesSync();
        final parsed = ContactImportExportService.instance.parseContactFile(bytes, 'articles.xlsx');
        expect(parsed['format'], equals('xlsx'));
        expect(parsed['totalRows'], equals(23));
      }
    });

    test('Article importer strictly validates missing required fields, data types, duplicates, and invalid references', () async {
      final rawRows = [
        // Row 1: Valid row
        {
          'code': 'ART-TEST-001',
          'name': 'Écran 24 pouces Dell',
          'productType': 'produit',
          'sellingPrice': '450.500',
          'purchasePrice': '350.000',
          'tvaRate': '19',
          'stockQty': '15',
          'minStockQty': '2',
          'barcode': '1234567890123',
        },
        // Row 2: Missing required name
        {
          'code': 'ART-TEST-002',
          'name': '',
          'productType': 'produit',
          'sellingPrice': '100',
        },
        // Row 3: Invalid numeric sellingPrice (letters)
        {
          'code': 'ART-TEST-003',
          'name': 'Clavier mécanique',
          'sellingPrice': 'Gratuit',
        },
        // Row 4: Negative sellingPrice
        {
          'code': 'ART-TEST-004',
          'name': 'Souris sans fil',
          'sellingPrice': '-25.0',
        },
        // Row 5: Invalid TVA rate (> 100)
        {
          'code': 'ART-TEST-005',
          'name': 'Tapis de souris',
          'tvaRate': '150',
        },
        // Row 6: Invalid productType
        {
          'code': 'ART-TEST-006',
          'name': 'Produit spécial',
          'productType': 'inconnu_ou_vehicule',
        },
        // Row 7: Duplicate code in the file (identical to Row 1)
        {
          'code': 'ART-TEST-001',
          'name': 'Deuxième écran Dell',
          'productType': 'produit',
        },
        // Row 8: Duplicate barcode in the file (identical to Row 1)
        {
          'code': 'ART-TEST-008',
          'name': 'Écran Dell reconditionné',
          'barcode': '1234567890123',
        },
        // Row 9: Non-existent _id reference
        {
          '_id': 'fake_non_existent_doc_id_99999',
          'code': 'ART-TEST-009',
          'name': 'Article fantôme',
        },
      ];

      final fieldMapping = {
        '_id': '_id',
        'code': 'code',
        'name': 'name',
        'productType': 'productType',
        'sellingPrice': 'sellingPrice',
        'purchasePrice': 'purchasePrice',
        'tvaRate': 'tvaRate',
        'stockQty': 'stockQty',
        'minStockQty': 'minStockQty',
        'barcode': 'barcode',
      };

      final results = await ArticleImportExportService.instance.validateAndPrepareRows(
        rawRows: rawRows,
        fieldMapping: fieldMapping,
        fallbackValues: {},
      );

      expect(results.length, equals(9));

      // Row 1: Valid
      expect(results[0].isValid, isTrue);
      expect(results[0].errors, isEmpty);
      expect(results[0].sellingPrice, equals(450.5));
      expect(results[0].purchasePrice, equals(350.0));
      expect(results[0].tvaRate, equals(19.0));
      expect(results[0].stockQty, equals(15.0));

      // Row 2: Missing name
      expect(results[1].isValid, isFalse);
      expect(results[1].errors.any((e) => e.contains('obligatoire')), isTrue);

      // Row 3: Invalid sellingPrice ("Gratuit")
      expect(results[2].isValid, isFalse);
      expect(results[2].errors.any((e) => e.contains('Prix de vente HT') && e.contains('invalide')), isTrue);

      // Row 4: Negative price
      expect(results[3].isValid, isFalse);
      expect(results[3].errors.any((e) => e.contains('négatif')), isTrue);

      // Row 5: TVA > 100
      expect(results[4].isValid, isFalse);
      expect(results[4].errors.any((e) => e.contains('Taux TVA') && e.contains('inférieur ou égal à 100')), isTrue);

      // Row 6: Invalid productType
      expect(results[5].isValid, isFalse);
      expect(results[5].errors.any((e) => e.contains('Type d\'article') && e.contains('invalide')), isTrue);

      // Row 7: Duplicate code (Row 1)
      expect(results[6].isValid, isFalse);
      expect(results[6].errors.any((e) => e.contains('Code / Référence') && e.contains('en double')), isTrue);

      // Row 8: Duplicate barcode (Row 1)
      expect(results[7].isValid, isFalse);
      expect(results[7].errors.any((e) => e.contains('Code-barres') && e.contains('en double')), isTrue);

      // Row 9: Non-existent _id
      expect(results[8].isValid, isFalse);
      expect(results[8].errors.any((e) => e.contains('Référence _id') && e.contains('introuvable')), isTrue);
    });

    test('Contact importer strictly validates missing required fields, duplicates, and formats', () async {
      final rawRows = [
        // Row 1: Valid Business Contact
        {
          'code': 'CL-TEST-001',
          'companyName': 'STE EXEMPLE TUNISIE',
          'businessType': 'business',
          'taxId': '1234567/A/M/000',
          'phone': '71123456',
          'openingBalance': '1500.000',
        },
        // Row 2: Missing required companyName & name
        {
          'code': 'CL-TEST-002',
          'businessType': 'business',
          'companyName': '',
          'name': '',
        },
        // Row 3: In-file duplicate code (identical to Row 1)
        {
          'code': 'CL-TEST-001',
          'companyName': 'STE AUTRE',
          'businessType': 'business',
        },
        // Row 4: In-file duplicate taxId (identical to Row 1)
        {
          'code': 'CL-TEST-004',
          'companyName': 'STE TROISIEME',
          'businessType': 'business',
          'taxId': '1234567/A/M/000',
        },
        // Row 5: Invalid businessType
        {
          'code': 'CL-TEST-005',
          'name': 'Ali Ben Salah',
          'businessType': 'inconnu_ou_autre',
        },
        // Row 6: Invalid openingBalance (letters)
        {
          'code': 'CL-TEST-006',
          'name': 'Mohamed Trabelsi',
          'businessType': 'individual',
          'openingBalance': 'NonDéfini',
        },
        // Row 7: Non-existent _id reference
        {
          '_id': 'fake_contact_id_99999',
          'code': 'CL-TEST-007',
          'name': 'Contact Fantôme',
          'businessType': 'individual',
        },
      ];

      final fieldMapping = {
        '_id': '_id',
        'code': 'code',
        'companyName': 'companyName',
        'name': 'name',
        'businessType': 'businessType',
        'taxId': 'taxId',
        'phone': 'phone',
        'openingBalance': 'openingBalance',
      };

      final results = await ContactImportExportService.instance.validateAndPrepareRows(
        type: ContactType.customer,
        rawRows: rawRows,
        fieldMapping: fieldMapping,
        fallbackValues: {},
      );

      expect(results.length, equals(7));

      // Row 1: Valid
      expect(results[0].isValid, isTrue);
      expect(results[0].displayName, equals('STE EXEMPLE TUNISIE'));
      expect(results[0].balance, equals(1500.0));

      // Row 2: Missing name/companyName
      expect(results[1].isValid, isFalse);
      expect(results[1].errors.any((e) => e.contains('obligatoire')), isTrue);

      // Row 3: Duplicate code
      expect(results[2].isValid, isFalse);
      expect(results[2].errors.any((e) => e.contains('Code') && e.contains('en double')), isTrue);

      // Row 4: Duplicate taxId
      expect(results[3].isValid, isFalse);
      expect(results[3].errors.any((e) => e.contains('Matricule fiscal') && e.contains('en double')), isTrue);

      // Row 5: Invalid businessType
      expect(results[4].isValid, isFalse);
      expect(results[4].errors.any((e) => e.contains('Type de contact') && e.contains('invalide')), isTrue);

      // Row 6: Invalid balance
      expect(results[5].isValid, isFalse);
      expect(results[5].errors.any((e) => e.contains('Solde de départ') && e.contains('invalide')), isTrue);

      // Row 7: Non-existent _id
      expect(results[6].isValid, isFalse);
      expect(results[6].errors.any((e) => e.contains('Référence _id') && e.contains('introuvable')), isTrue);
    });
  });
}

