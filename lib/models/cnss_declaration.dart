import 'dart:convert';
import 'package:intl/intl.dart';

/// Ligne individuelle de déclaration CNSS par employé (Screenshots 1 & 2)
class CnssDeclarationLine {
  final String id;
  final int page; // Numéro de page (défaut 1)
  final int lineNumber; // Numéro d'ordre / ligne (1, 2, 3...)
  final String employeeId;
  final String employeeName; // Abigail Peterson, Anita Oliver, Alex...
  final String cnssNumber; // Numéro de sécurité sociale / CNSS (ex: 2222222222222222)
  final String employerRegistrationNumber; // Numéro d'enregistrement chez l'employeur
  final String professionalCategory; // Catégorie professionnelle (B, C, H...)
  final double grossMonth1; // brut mois 1
  final double grossMonth2; // brut mois 2
  final double grossMonth3; // brut mois 3
  final String companyName; // My Company (San Francisco)

  CnssDeclarationLine({
    required this.id,
    this.page = 1,
    required this.lineNumber,
    required this.employeeId,
    required this.employeeName,
    this.cnssNumber = '',
    this.employerRegistrationNumber = '',
    this.professionalCategory = 'B',
    this.grossMonth1 = 0.0,
    this.grossMonth2 = 0.0,
    this.grossMonth3 = 0.0,
    this.companyName = '',
  });

  double get total => grossMonth1 + grossMonth2 + grossMonth3;

  String formattedCurrency(double amount, {String symbol = 'DT'}) {
    final f = NumberFormat('#,##0.00', 'fr_FR');
    return '${f.format(amount)} $symbol';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'page': page,
        'line_number': lineNumber,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'cnss_number': cnssNumber,
        'employer_registration_number': employerRegistrationNumber,
        'professional_category': professionalCategory,
        'gross_month_1': grossMonth1,
        'gross_month_2': grossMonth2,
        'gross_month_3': grossMonth3,
        'company_name': companyName,
      };

  factory CnssDeclarationLine.fromMap(Map<String, dynamic> map) => CnssDeclarationLine(
        id: map['id']?.toString() ?? '',
        page: (map['page'] as num?)?.toInt() ?? 1,
        lineNumber: (map['line_number'] as num?)?.toInt() ?? 1,
        employeeId: map['employee_id']?.toString() ?? '',
        employeeName: map['employee_name']?.toString() ?? '',
        cnssNumber: map['cnss_number']?.toString() ?? '',
        employerRegistrationNumber: map['employer_registration_number']?.toString() ?? '',
        professionalCategory: map['professional_category']?.toString() ?? 'B',
        grossMonth1: (map['gross_month_1'] as num?)?.toDouble() ?? 0.0,
        grossMonth2: (map['gross_month_2'] as num?)?.toDouble() ?? 0.0,
        grossMonth3: (map['gross_month_3'] as num?)?.toDouble() ?? 0.0,
        companyName: map['company_name']?.toString() ?? '',
      );

  CnssDeclarationLine copyWith({
    String? id,
    int? page,
    int? lineNumber,
    String? employeeId,
    String? employeeName,
    String? cnssNumber,
    String? employerRegistrationNumber,
    String? professionalCategory,
    double? grossMonth1,
    double? grossMonth2,
    double? grossMonth3,
    String? companyName,
  }) =>
      CnssDeclarationLine(
        id: id ?? this.id,
        page: page ?? this.page,
        lineNumber: lineNumber ?? this.lineNumber,
        employeeId: employeeId ?? this.employeeId,
        employeeName: employeeName ?? this.employeeName,
        cnssNumber: cnssNumber ?? this.cnssNumber,
        employerRegistrationNumber: employerRegistrationNumber ?? this.employerRegistrationNumber,
        professionalCategory: professionalCategory ?? this.professionalCategory,
        grossMonth1: grossMonth1 ?? this.grossMonth1,
        grossMonth2: grossMonth2 ?? this.grossMonth2,
        grossMonth3: grossMonth3 ?? this.grossMonth3,
        companyName: companyName ?? this.companyName,
      );
}

/// Modèle principal de Déclaration CNSS Trimestrielle (Screenshots 1, 2 & 3)
class CnssDeclaration {
  final String id;
  final String reference; // e.g. "hr.cnss 4-2024" ou "CNSS/2024/T4"
  final int quarter; // 1, 2, 3, 4
  final int year; // 2024, 2025...
  final String contractType; // Permanent, CDD, CDI, Tous...
  final DateTime declarationDate; // Date de déclaration (ex: 26/12/2024)
  final String status; // 'draft' (Brouillon) ou 'done' (Fait)
  final String employerNumber; // N° Employeur CNSS (ex: 0123456789)
  final String exploitationCode; // Code d'exploitation (ex: A)
  final String taxIdNumber; // NIF / Matricule fiscal
  final String companyName; // Nom et adresse de l'employeur
  final String companyAddress; // 250 Executive Park Blvd, Suite 3400
  final String currency; // DT, $, €
  final List<CnssDeclarationLine> lines;
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  CnssDeclaration({
    required this.id,
    String? reference,
    required this.quarter,
    required this.year,
    this.contractType = 'Permanent',
    DateTime? declarationDate,
    this.status = 'draft',
    this.employerNumber = '0123456789',
    this.exploitationCode = 'A',
    this.taxIdNumber = '',
    this.companyName = 'Société My Company (San Francisco)',
    this.companyAddress = '250 Executive Park Blvd, Suite 3400',
    this.currency = '\$',
    this.lines = const [],
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : reference = reference ?? 'hr.cnss $quarter-$year',
        declarationDate = declarationDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isDraft => status == 'draft';
  bool get isDone => status == 'done';

  String get quarterLabel {
    switch (quarter) {
      case 1:
        return '1er Trimestre $year (Janv - Mars)';
      case 2:
        return '2ème Trimestre $year (Avr - Juin)';
      case 3:
        return '3ème Trimestre $year (Juil - Sept)';
      case 4:
        return '4ème Trimestre $year (Oct - Déc)';
      default:
        return 'T$quarter $year';
    }
  }

  // Noms des mois selon le trimestre
  List<String> get monthLabels {
    switch (quarter) {
      case 1:
        return ['Janvier', 'Février', 'Mars'];
      case 2:
        return ['Avril', 'Mai', 'Juin'];
      case 3:
        return ['Juillet', 'Août', 'Septembre'];
      case 4:
        return ['Octobre', 'Novembre', 'Décembre'];
      default:
        return ['Mois 1', 'Mois 2', 'Mois 3'];
    }
  }

  double get totalGrossMonth1 => lines.fold(0.0, (acc, l) => acc + l.grossMonth1);
  double get totalGrossMonth2 => lines.fold(0.0, (acc, l) => acc + l.grossMonth2);
  double get totalGrossMonth3 => lines.fold(0.0, (acc, l) => acc + l.grossMonth3);
  double get totalQuarter => lines.fold(0.0, (acc, l) => acc + l.total);

  String formattedTotal(double amount) {
    final f = NumberFormat('#,##0.00', 'fr_FR');
    return '${f.format(amount)} $currency';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'reference': reference,
        'quarter': quarter,
        'year': year,
        'contract_type': contractType,
        'declaration_date': declarationDate.toIso8601String(),
        'status': status,
        'employer_number': employerNumber,
        'exploitation_code': exploitationCode,
        'tax_id_number': taxIdNumber,
        'company_name': companyName,
        'company_address': companyAddress,
        'currency': currency,
        'lines': lines.map((l) => l.toMap()).toList(),
        'notes': notes,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory CnssDeclaration.fromMap(Map<String, dynamic> map) {
    List<CnssDeclarationLine> parsedLines = [];
    if (map['lines'] != null) {
      if (map['lines'] is List) {
        parsedLines = (map['lines'] as List)
            .map((item) => CnssDeclarationLine.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } else if (map['lines'] is String) {
        try {
          final decoded = jsonDecode(map['lines'] as String);
          if (decoded is List) {
            parsedLines = decoded
                .map((item) => CnssDeclarationLine.fromMap(Map<String, dynamic>.from(item as Map)))
                .toList();
          }
        } catch (_) {}
      }
    }

    return CnssDeclaration(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString(),
      quarter: (map['quarter'] as num?)?.toInt() ?? 4,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      contractType: map['contract_type']?.toString() ?? 'Permanent',
      declarationDate: DateTime.tryParse(map['declaration_date']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'draft',
      employerNumber: map['employer_number']?.toString() ?? '0123456789',
      exploitationCode: map['exploitation_code']?.toString() ?? 'A',
      taxIdNumber: map['tax_id_number']?.toString() ?? '',
      companyName: map['company_name']?.toString() ?? 'Société My Company (San Francisco)',
      companyAddress: map['company_address']?.toString() ?? '250 Executive Park Blvd, Suite 3400',
      currency: map['currency']?.toString() ?? '\$',
      lines: parsedLines,
      notes: map['notes']?.toString(),
      enterpriseId: map['enterprise_id']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
    );
  }

  CnssDeclaration copyWith({
    String? id,
    String? reference,
    int? quarter,
    int? year,
    String? contractType,
    DateTime? declarationDate,
    String? status,
    String? employerNumber,
    String? exploitationCode,
    String? taxIdNumber,
    String? companyName,
    String? companyAddress,
    String? currency,
    List<CnssDeclarationLine>? lines,
    String? notes,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      CnssDeclaration(
        id: id ?? this.id,
        reference: reference ?? this.reference,
        quarter: quarter ?? this.quarter,
        year: year ?? this.year,
        contractType: contractType ?? this.contractType,
        declarationDate: declarationDate ?? this.declarationDate,
        status: status ?? this.status,
        employerNumber: employerNumber ?? this.employerNumber,
        exploitationCode: exploitationCode ?? this.exploitationCode,
        taxIdNumber: taxIdNumber ?? this.taxIdNumber,
        companyName: companyName ?? this.companyName,
        companyAddress: companyAddress ?? this.companyAddress,
        currency: currency ?? this.currency,
        lines: lines ?? this.lines,
        notes: notes ?? this.notes,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
