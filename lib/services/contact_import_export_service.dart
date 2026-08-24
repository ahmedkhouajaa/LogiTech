import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';

import '../utils/file_save_helper.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import 'enterprise_service.dart';

enum ContactType {
  customer,
  supplier,
}

extension ContactTypeExt on ContactType {
  String get label => this == ContactType.customer ? 'Client' : 'Fournisseur';
  String get labelPlural => this == ContactType.customer ? 'Clients' : 'Fournisseurs';
  String get firestoreCollection => this == ContactType.customer ? 'clients' : 'fournisseurs';
  String get codePrefix => this == ContactType.customer ? 'CL' : 'FR';
}

/// Parsed row with validation status for import preview
class ContactImportRow {
  final int rowIndex;
  final Map<String, dynamic> rawValues;
  final Map<String, dynamic> mappedValues;
  final bool isUpdate;
  final String? existingId;
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ContactImportRow({
    required this.rowIndex,
    required this.rawValues,
    required this.mappedValues,
    this.isUpdate = false,
    this.existingId,
    this.isValid = true,
    this.errors = const [],
    this.warnings = const [],
  });

  String get displayName {
    final businessType = mappedValues['businessType']?.toString().toLowerCase() ?? 'individual';
    if (businessType == 'business' || businessType == 'entreprise') {
      final comp = mappedValues['companyName']?.toString().trim();
      if (comp != null && comp.isNotEmpty) return comp;
    }
    final name = mappedValues['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final comp = mappedValues['companyName']?.toString().trim();
    if (comp != null && comp.isNotEmpty) return comp;
    return 'Sans nom';
  }

  String get code => mappedValues['code']?.toString().trim() ?? '';
  String get taxId => mappedValues['taxId']?.toString().trim() ?? '';
  String get phone => mappedValues['phone']?.toString().trim() ?? '';
  String get city => mappedValues['city']?.toString().trim() ?? '';
  double get balance => double.tryParse(mappedValues['openingBalance']?.toString() ?? '0') ?? 0.0;
}

/// Result of contact import
class ContactImportResult {
  final bool success;
  final String message;
  final int totalRows;
  final int createdCount;
  final int updatedCount;
  final int skippedCount;
  final int errorCount;
  final List<String> errorMessages;

  ContactImportResult({
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

/// Comprehensive service for Import/Export of Clients and Fournisseurs supporting Excel, CSV, JSON
class ContactImportExportService {
  static final ContactImportExportService instance = ContactImportExportService._();
  ContactImportExportService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  String? get _currentEnterpriseId => EnterpriseService.instance.currentEnterpriseId;

  // ─── Standard Fields for Clients & Suppliers ─────────────────────
  static const List<Map<String, dynamic>> contactFieldDefs = [
    {
      'key': '_id',
      'label': 'ID Interne (_id)',
      'description': 'Laissez vide pour nouveau contact, ou remplissez pour mettre à jour.',
      'required': false,
      'aliases': ['_id', 'id', 'identifier', 'id_contact', 'id_client', 'id_fournisseur'],
    },
    {
      'key': 'code',
      'label': 'Code de référence',
      'description': 'Code client / fournisseur (ex: CL-00001, FR-00001).',
      'required': false,
      'aliases': ['code', 'code_client', 'code_fournisseur', 'reference', 'ref', 'partner_code', 'customercode', 'suppliercode'],
    },
    {
      'key': 'businessType',
      'label': 'Type de contact (businessType)',
      'description': '« business » (entreprise) ou « individual » (particulier).',
      'required': true,
      'aliases': ['businesstype', 'type', 'customertype', 'suppliertype', 'is_company', 'nature', 'statut_juridique'],
    },
    {
      'key': 'companyName',
      'label': 'Raison Sociale / Société',
      'description': 'Nom de l\'entreprise (obligatoire si businessType = business).',
      'required': false,
      'aliases': ['companyname', 'company_name', 'raison_sociale', 'societe', 'company', 'nom_societe', 'denomination'],
    },
    {
      'key': 'name',
      'label': 'Nom & Prénom / Contact',
      'description': 'Nom du particulier ou contact principal.',
      'required': false,
      'aliases': ['name', 'nom', 'contact_name', 'nom_contact', 'nom_prenom', 'display_name', 'client', 'fournisseur', 'person_name'],
    },
    {
      'key': 'responsibleName',
      'label': 'Responsable / Gérant',
      'description': 'Personne à contacter au sein de l\'entreprise.',
      'required': false,
      'aliases': ['responsiblename', 'responsable', 'contact_person', 'gerant', 'interlocuteur'],
    },
    {
      'key': 'taxId',
      'label': 'Matricule Fiscal / NIF',
      'description': 'Numéro d\'identification fiscale (TVA / MF / NIF).',
      'required': false,
      'aliases': ['taxid', 'matricule_fiscal', 'mf', 'nif', 'vat', 'tva', 'num_tva', 'id_fiscal', 'tax_number'],
    },
    {
      'key': 'rc',
      'label': 'Registre de Commerce (RC)',
      'description': 'Numéro de registre du commerce.',
      'required': false,
      'aliases': ['rc', 'registre_commerce', 'num_rc', 'trade_register', 'r_c', 'registre'],
    },
    {
      'key': 'phone',
      'label': 'Téléphone',
      'description': 'Numéro de téléphone principal.',
      'required': false,
      'aliases': ['phone', 'telephone', 'tel', 'mobile', 'gsm', 'contact_phone', 'phone_number'],
    },
    {
      'key': 'email',
      'label': 'Email',
      'description': 'Adresse de messagerie électronique.',
      'required': false,
      'aliases': ['email', 'mail', 'courriel', 'e_mail', 'contact_email'],
    },
    {
      'key': 'address',
      'label': 'Adresse',
      'description': 'Numéro et nom de rue.',
      'required': false,
      'aliases': ['address', 'adresse', 'street', 'rue', 'streetaddress', 'adresse_postale', 'billing_address'],
    },
    {
      'key': 'city',
      'label': 'Ville',
      'description': 'Ville ou gouvernorat.',
      'required': false,
      'aliases': ['city', 'ville', 'gouvernorat', 'region', 'state'],
    },
    {
      'key': 'postalCode',
      'label': 'Code Postal',
      'description': 'Code postal (ex: 1000).',
      'required': false,
      'aliases': ['postalcode', 'code_postal', 'zip', 'zipcode', 'cp'],
    },
    {
      'key': 'country',
      'label': 'Pays',
      'description': 'Pays (ex: Tunisie, Algérie, France).',
      'required': false,
      'aliases': ['country', 'pays', 'nation'],
    },
    {
      'key': 'bankAccount',
      'label': 'Compte Bancaire / RIB',
      'description': 'Relevé d\'Identité Bancaire (RIB / IBAN).',
      'required': false,
      'aliases': ['bankaccount', 'rib', 'iban', 'compte_bancaire', 'banque', 'bank_details'],
    },
    {
      'key': 'openingBalance',
      'label': 'Solde de départ (openingBalance)',
      'description': 'Montant en devises (ex. 4500.000 ou -1200.000). Laissez vide si inchangé.',
      'required': false,
      'aliases': ['openingbalance', 'solde', 'balance', 'solde_initial', 'solde_depart', 'initial_balance'],
    },
    {
      'key': 'creditLimit',
      'label': 'Plafond de Crédit',
      'description': 'Limite maximale de crédit autorisé.',
      'required': false,
      'aliases': ['creditlimit', 'plafond_credit', 'limite_credit', 'max_credit'],
    },
    {
      'key': 'notes',
      'label': 'Remarques / Notes',
      'description': 'Observations particulières ou notes privées.',
      'required': false,
      'aliases': ['notes', 'remarques', 'commentaires', 'memo', 'privatenote', 'observations'],
    },
  ];

  // ─── 1. EXPORT TO EXCEL / CSV / JSON ─────────────────────────────

  /// Exports clients or suppliers to an Excel (.xlsx) file with professional formatting
  Future<String?> exportContactsToExcel({
    required BuildContext context,
    required ContactType type,
    required List<dynamic> contacts, // List<Customer> or List<Supplier>
  }) async {
    final excel = Excel.createExcel();
    final sheetName = type.labelPlural;
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    final headers = [
      '_id',
      'code',
      'businessType',
      'companyName',
      'name',
      'responsibleName',
      'taxId',
      'rc',
      'phone',
      'email',
      'address',
      'city',
      'postalCode',
      'country',
      'bankAccount',
      'openingBalance',
      if (type == ContactType.customer) 'creditLimit',
      'notes',
    ];

    // Header Row with modern style
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Arial),
      );
    }

    // Data Rows
    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final r = i + 1;

      String id = '';
      String code = '';
      String businessType = 'business';
      String companyName = '';
      String name = '';
      String responsibleName = '';
      String taxId = '';
      String rc = '';
      String phone = '';
      String email = '';
      String address = '';
      String city = '';
      String postalCode = '';
      String country = 'Tunisie';
      String bankAccount = '';
      double balance = 0.0;
      double creditLimit = 0.0;
      String notes = '';

      if (contact is Customer) {
        id = contact.id;
        code = contact.code;
        businessType = contact.customerType.isNotEmpty ? contact.customerType : 'individual';
        companyName = contact.companyName ?? '';
        name = contact.name;
        responsibleName = contact.responsibleName ?? '';
        taxId = contact.taxId ?? '';
        rc = contact.rc ?? '';
        phone = contact.phone ?? '';
        email = contact.email ?? '';
        address = contact.address ?? contact.streetAddress ?? '';
        city = contact.city ?? '';
        postalCode = contact.postalCode ?? '';
        country = contact.country.isNotEmpty ? contact.country : 'Tunisie';
        bankAccount = contact.bankAccount ?? '';
        balance = contact.balance;
        creditLimit = contact.creditLimit;
        notes = contact.notes ?? contact.privateNote ?? '';
      } else if (contact is Supplier) {
        id = contact.id;
        code = contact.code;
        businessType = contact.supplierType.isNotEmpty ? contact.supplierType : 'business';
        companyName = contact.companyName ?? '';
        name = contact.name;
        responsibleName = contact.responsibleName ?? '';
        taxId = contact.taxId ?? '';
        rc = contact.rc ?? '';
        phone = contact.phone ?? '';
        email = contact.email ?? '';
        address = contact.address ?? '';
        city = contact.city ?? '';
        postalCode = contact.postalCode ?? '';
        country = contact.country.isNotEmpty ? contact.country : 'Tunisie';
        bankAccount = contact.bankAccount ?? '';
        balance = contact.balance;
        notes = contact.notes ?? '';
      }

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r)).value = TextCellValue(id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).value = TextCellValue(code);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).value = TextCellValue(businessType);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r)).value = TextCellValue(companyName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r)).value = TextCellValue(name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r)).value = TextCellValue(responsibleName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r)).value = TextCellValue(taxId);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: r)).value = TextCellValue(rc);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: r)).value = TextCellValue(phone);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: r)).value = TextCellValue(email);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: r)).value = TextCellValue(address);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: r)).value = TextCellValue(city);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: r)).value = TextCellValue(postalCode);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: r)).value = TextCellValue(country);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: r)).value = TextCellValue(bankAccount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: r)).value = DoubleCellValue(balance);
      int nextCol = 16;
      if (type == ContactType.customer) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: nextCol++, rowIndex: r)).value = DoubleCellValue(creditLimit);
      }
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: nextCol, rowIndex: r)).value = TextCellValue(notes);
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) throw 'Erreur d\'encodage du fichier Excel.';

    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final sanitizedType = type == ContactType.customer ? 'clients' : 'fournisseurs';
    final fileName = 'export_${sanitizedType}_$timestamp.xlsx';

    return await FileSaveHelper.saveFile(
      bytes: Uint8List.fromList(fileBytes),
      fileName: fileName,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Exports contacts to CSV format
  Future<String?> exportContactsToCsv({
    required BuildContext context,
    required ContactType type,
    required List<dynamic> contacts,
  }) async {
    final buffer = StringBuffer();
    final headers = [
      '_id',
      'code',
      'businessType',
      'companyName',
      'name',
      'responsibleName',
      'taxId',
      'rc',
      'phone',
      'email',
      'address',
      'city',
      'postalCode',
      'country',
      'bankAccount',
      'openingBalance',
      if (type == ContactType.customer) 'creditLimit',
      'notes',
    ];

    buffer.writeln(headers.join(';'));

    for (final contact in contacts) {
      final List<String> values = [];
      if (contact is Customer) {
        values.addAll([
          contact.id,
          contact.code,
          contact.customerType,
          contact.companyName ?? '',
          contact.name,
          contact.responsibleName ?? '',
          contact.taxId ?? '',
          contact.rc ?? '',
          contact.phone ?? '',
          contact.email ?? '',
          (contact.address ?? contact.streetAddress ?? '').replaceAll(';', ','),
          contact.city ?? '',
          contact.postalCode ?? '',
          contact.country,
          contact.bankAccount ?? '',
          contact.balance.toStringAsFixed(3),
          contact.creditLimit.toStringAsFixed(3),
          (contact.notes ?? contact.privateNote ?? '').replaceAll(';', ','),
        ]);
      } else if (contact is Supplier) {
        values.addAll([
          contact.id,
          contact.code,
          contact.supplierType,
          contact.companyName ?? '',
          contact.name,
          contact.responsibleName ?? '',
          contact.taxId ?? '',
          contact.rc ?? '',
          contact.phone ?? '',
          contact.email ?? '',
          (contact.address ?? '').replaceAll(';', ','),
          contact.city ?? '',
          contact.postalCode ?? '',
          contact.country,
          contact.bankAccount ?? '',
          contact.balance.toStringAsFixed(3),
          (contact.notes ?? '').replaceAll(';', ','),
        ]);
      }
      buffer.writeln(values.map((v) => '"${v.replaceAll('"', '""')}"').join(';'));
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final sanitizedType = type == ContactType.customer ? 'clients' : 'fournisseurs';
    final fileName = 'export_${sanitizedType}_$timestamp.csv';

    return await FileSaveHelper.saveFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// Exports contacts to JSON format
  Future<String?> exportContactsToJson({
    required BuildContext context,
    required ContactType type,
    required List<dynamic> contacts,
  }) async {
    final List<Map<String, dynamic>> list = [];
    for (final c in contacts) {
      if (c is Customer) {
        list.add(c.toMap());
      } else if (c is Supplier) {
        list.add(c.toMap());
      }
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final sanitizedType = type == ContactType.customer ? 'clients' : 'fournisseurs';
    final fileName = 'export_${sanitizedType}_$timestamp.json';

    return await FileSaveHelper.saveFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/json',
    );
  }

  // ─── 2. DOWNLOADABLE TEMPLATES (LIKE FINCO) ──────────────────────

  /// Generates a standardized Excel (.xlsx) template with sample rows and instructions
  Future<String?> downloadExcelTemplate(ContactType type) async {
    final excel = Excel.createExcel();
    final sheetName = 'Modèle Import ${type.labelPlural}';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    final headers = [
      '_id',
      'code',
      'businessType',
      'companyName',
      'name',
      'responsibleName',
      'taxId',
      'rc',
      'phone',
      'email',
      'address',
      'city',
      'postalCode',
      'country',
      'bankAccount',
      'openingBalance',
      if (type == ContactType.customer) 'creditLimit',
      'notes',
    ];

    // Header Row
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Sample Row 1 (Société / Business)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue(''); // _id empty for new
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('${type.codePrefix}-00001');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = TextCellValue('business');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = TextCellValue('STE EXEMPLE TECH SARL');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = TextCellValue('STE EXEMPLE TECH');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value = TextCellValue('M. Mohamed Ben Salah');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1)).value = TextCellValue('1234567A/M/000');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1)).value = TextCellValue('B1987652024');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 1)).value = TextCellValue('+216 71 234 567');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 1)).value = TextCellValue('contact@exemple-tech.tn');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 1)).value = TextCellValue('15 Avenue Habib Bourguiba');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 1)).value = TextCellValue('Tunis');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 1)).value = TextCellValue('1001');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 1)).value = TextCellValue('Tunisie');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: 1)).value = TextCellValue('08 000 0000123456789 12');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 1)).value = DoubleCellValue(1500.000);
    int nextCol = 16;
    if (type == ContactType.customer) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: nextCol++, rowIndex: 1)).value = DoubleCellValue(10000.000);
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: nextCol, rowIndex: 1)).value = TextCellValue('Client régulier');

    // Sample Row 2 (Particulier / Individual)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue(''); // _id empty for new
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = TextCellValue('${type.codePrefix}-00002');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).value = TextCellValue('individual');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2)).value = TextCellValue('Sami Trabelsi');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 2)).value = TextCellValue('Sami Trabelsi');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 2)).value = TextCellValue('0987654/A/P/000');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 2)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 2)).value = TextCellValue('+216 98 765 432');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 2)).value = TextCellValue('sami.trabelsi@gmail.com');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 2)).value = TextCellValue('Rue des Roses');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 2)).value = TextCellValue('Sousse');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 2)).value = TextCellValue('4000');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 2)).value = TextCellValue('Tunisie');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: 2)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 2)).value = DoubleCellValue(0.000);
    nextCol = 16;
    if (type == ContactType.customer) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: nextCol++, rowIndex: 2)).value = DoubleCellValue(2000.000);
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: nextCol, rowIndex: 2)).value = TextCellValue('Paiement comptant');

    // Sample Row 3 (Mise à jour d'un contact existant via son _id)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = TextCellValue('ex-id-001234'); // sample _id for update
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = TextCellValue('${type.codePrefix}-00003');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3)).value = TextCellValue('business');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3)).value = TextCellValue('CONTACT EXISTANT MIS A JOUR');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3)).value = TextCellValue('CONTACT EXISTANT');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 3)).value = TextCellValue('1122334K');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 3)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 3)).value = TextCellValue('73 111 222');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 3)).value = TextCellValue('info@maj.com');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 3)).value = TextCellValue('Boulevard 14 Janvier');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: 3)).value = TextCellValue('Monastir');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 3)).value = TextCellValue('5000');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 3)).value = TextCellValue('Tunisie');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: 3)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: 3)).value = DoubleCellValue(-350.000);
    nextCol = 16;
    if (type == ContactType.customer) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: nextCol++, rowIndex: 3)).value = DoubleCellValue(5000.000);
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: nextCol, rowIndex: 3)).value = TextCellValue('Mise à jour automatique par _id');

    final fileBytes = excel.encode();
    if (fileBytes == null) throw 'Erreur de génération du modèle Excel.';

    final fileName = 'modele_import_${type == ContactType.customer ? 'clients' : 'fournisseurs'}.xlsx';
    return await FileSaveHelper.saveFile(
      bytes: Uint8List.fromList(fileBytes),
      fileName: fileName,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ─── 3. FILE PARSING (EXCEL, CSV, JSON) ──────────────────────────

  /// Parses uploaded contact file (.xlsx, .csv, .json) into raw row maps and headers
  Map<String, dynamic> parseContactFile(Uint8List bytes, String fileName) {
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

    // Pick first non-empty sheet
    final tableKey = excel.tables.keys.firstWhere(
      (k) => excel.tables[k]!.rows.isNotEmpty,
      orElse: () => excel.tables.keys.first,
    );
    final sheet = excel.tables[tableKey]!;
    final rowsList = sheet.rows;

    if (rowsList.isEmpty) {
      throw 'La feuille Excel sélectionnée est vide.';
    }

    // Extract headers from row 0
    final headerRow = rowsList.first;
    final List<String> headers = [];
    for (int i = 0; i < headerRow.length; i++) {
      final val = headerRow[i]?.value?.toString().trim() ?? '';
      headers.add(val.isNotEmpty ? val : 'Colonne_$i');
    }

    // Extract data rows
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

    // Detect delimiter
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
      // Look for contacts or list
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

  /// Suggests automatic field mapping matching Finco, Odoo, SAP, Sage, GesCom, OptiFact, and Excel
  Map<String, String?> autoSuggestMappings(List<String> sourceHeaders) {
    final Map<String, String?> mapping = {};

    for (final def in contactFieldDefs) {
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

  /// Validates raw rows against mapped fields and existing records in database/Firestore
  Future<List<ContactImportRow>> validateAndPrepareRows({
    required ContactType type,
    required List<Map<String, dynamic>> rawRows,
    required Map<String, String?> fieldMapping,
    required Map<String, dynamic> fallbackValues,
  }) async {
    final entId = _currentEnterpriseId;
    final collection = type.firestoreCollection;

    // Fetch existing contact IDs and codes for the current enterprise
    final Set<String> existingIds = {};
    final Set<String> existingCodes = {};
    if (entId != null && entId.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection(collection)
            .where('enterprise_id', isEqualTo: entId)
            .get();
        for (final doc in snap.docs) {
          existingIds.add(doc.id);
          final c = doc.data()['code']?.toString().trim();
          if (c != null && c.isNotEmpty) existingCodes.add(c.toLowerCase());
        }
      } catch (e) {
        debugPrint('Validation prefetch error: $e');
      }
    }

    final List<ContactImportRow> validatedList = [];

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
        warnings.add('L\'identifiant _id "$rawId" est introuvable. Un nouveau contact sera créé.');
      }

      // Check businessType
      String businessType = mapped['businessType']?.toString().toLowerCase().trim() ?? '';
      if (businessType.contains('business') ||
          businessType.contains('entreprise') ||
          businessType.contains('societe') ||
          businessType.contains('morale') ||
          businessType == 'true' ||
          businessType == '1') {
        businessType = 'business';
      } else {
        businessType = 'individual';
      }
      mapped['businessType'] = businessType;

      // Check required fields
      final companyName = mapped['companyName']?.toString().trim() ?? '';
      final name = mapped['name']?.toString().trim() ?? '';

      if (businessType == 'business' && companyName.isEmpty && name.isEmpty) {
        errors.add('La raison sociale (companyName) est obligatoire pour une entreprise.');
      } else if (businessType == 'individual' && name.isEmpty && companyName.isEmpty) {
        errors.add('Le nom (name) est obligatoire pour un particulier.');
      }

      // Format code if empty
      if (!mapped.containsKey('code') || (mapped['code'] as String).isEmpty) {
        mapped['code'] = '${type.codePrefix}-${(i + 1).toString().padLeft(5, '0')}';
      }

      // Parse balance
      final balanceStr = mapped['openingBalance']?.toString().trim() ?? '';
      if (balanceStr.isNotEmpty) {
        final cleanBal = balanceStr.replaceAll(RegExp(r'[^0-9.-]'), '');
        final parsedBal = double.tryParse(cleanBal);
        if (parsedBal == null) {
          warnings.add('Solde de départ "$balanceStr" invalide (0 par défaut appliqué).');
          mapped['openingBalance'] = 0.0;
        } else {
          mapped['openingBalance'] = parsedBal;
        }
      } else {
        mapped['openingBalance'] = 0.0;
      }

      // Parse credit limit
      final creditStr = mapped['creditLimit']?.toString().trim() ?? '';
      if (creditStr.isNotEmpty) {
        final cleanCred = creditStr.replaceAll(RegExp(r'[^0-9.-]'), '');
        mapped['creditLimit'] = double.tryParse(cleanCred) ?? 0.0;
      } else {
        mapped['creditLimit'] = 0.0;
      }

      validatedList.add(
        ContactImportRow(
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

  /// Executes batch import of validated contact rows into Firestore and SQLite
  Future<ContactImportResult> executeContactImport({
    required BuildContext context,
    required ContactType type,
    required List<ContactImportRow> rows,
    void Function(double progress, String status)? onProgress,
  }) async {
    final entId = _currentEnterpriseId;
    final uid = _currentUid;
    if (entId == null || entId.isEmpty) {
      return ContactImportResult(
        success: false,
        message: 'Aucune entreprise active sélectionnée.',
      );
    }

    final collection = type.firestoreCollection;
    final validRows = rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      return ContactImportResult(
        success: false,
        message: 'Aucune ligne valide à importer.',
        errorCount: rows.length,
      );
    }

    int createdCount = 0;
    int updatedCount = 0;
    int errorCount = rows.length - validRows.length;
    final List<String> errorMessages = [];

    onProgress?.call(0.1, 'Préparation des ${validRows.length} contacts...');

    // Chunk into batches of 300
    final chunks = <List<ContactImportRow>>[];
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
        'Enregistrement dans Firebase ($currentChunk/${chunks.length})...',
      );

      final batch = _firestore.batch();

      for (final row in chunk) {
        try {
          final docId = row.isUpdate && row.existingId != null ? row.existingId! : _uuid.v4();
          final docRef = _firestore.collection(collection).doc(docId);

          final m = row.mappedValues;
          final isBusiness = m['businessType'] == 'business';
          final name = m['name']?.toString().trim() ?? '';
          final companyName = m['companyName']?.toString().trim() ?? '';
          final primaryName = isBusiness && companyName.isNotEmpty ? companyName : (name.isNotEmpty ? name : companyName);

          final Map<String, dynamic> docData = {
            'id': docId,
            'code': m['code'] ?? '${type.codePrefix}-${_uuid.v4().substring(0, 4).toUpperCase()}',
            'name': primaryName,
            'companyName': companyName,
            'responsibleName': m['responsibleName'] ?? '',
            'taxId': m['taxId'] ?? '',
            'rc': m['rc'] ?? '',
            'phone': m['phone'] ?? '',
            'email': m['email'] ?? '',
            'address': m['address'] ?? '',
            'city': m['city'] ?? '',
            'postalCode': m['postalCode'] ?? '',
            'country': m['country']?.toString().isNotEmpty == true ? m['country'] : 'Tunisie',
            'bankAccount': m['bankAccount'] ?? '',
            'balance': m['openingBalance'] ?? 0.0,
            'notes': m['notes'] ?? '',
            'isDeleted': 0,
            'is_deleted': 0,
            'enterprise_id': entId,
            'userId': uid ?? '',
            'firebase_uid': uid ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          };

          if (type == ContactType.customer) {
            docData['customerType'] = isBusiness ? 'business' : 'individual';
            docData['creditLimit'] = m['creditLimit'] ?? 0.0;
          } else {
            docData['supplierType'] = isBusiness ? 'business' : 'individual';
          }

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

    return ContactImportResult(
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
