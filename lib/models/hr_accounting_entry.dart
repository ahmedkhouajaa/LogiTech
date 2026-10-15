import 'package:intl/intl.dart';

/// Modèle pour une ligne de mapping comptable de la paie (Plan comptable de paie)
class HrAccountingRubric {
  final String id;
  final String code; // ex: ABSENCE_UNPAID, SALARY_BASIC, CNSS_OUVRIERE, etc.
  final String debitAccount; // ex: 425000
  final String debitLabel; // ex: Personnel rémunérations dues
  final String creditAccount; // ex: 640000
  final String creditLabel; // ex: Salaires et compléments de salaires
  final String journal; // ex: OD, BQ
  final String journalLabel; // ex: Paie, Opérations diverses
  final String? auxiliaryAccount; // ex: 401000 (optionnel)
  final String legalEntity; // ex: Toutes les entités
  final bool isActive; // true si la ligne alimente les prochains exports
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  HrAccountingRubric({
    required this.id,
    required this.code,
    required this.debitAccount,
    required this.debitLabel,
    required this.creditAccount,
    required this.creditLabel,
    this.journal = 'OD',
    this.journalLabel = 'Paie',
    this.auxiliaryAccount,
    this.legalEntity = 'Toutes les entités',
    this.isActive = true,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  HrAccountingRubric copyWith({
    String? id,
    String? code,
    String? debitAccount,
    String? debitLabel,
    String? creditAccount,
    String? creditLabel,
    String? journal,
    String? journalLabel,
    String? auxiliaryAccount,
    String? legalEntity,
    bool? isActive,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HrAccountingRubric(
      id: id ?? this.id,
      code: code ?? this.code,
      debitAccount: debitAccount ?? this.debitAccount,
      debitLabel: debitLabel ?? this.debitLabel,
      creditAccount: creditAccount ?? this.creditAccount,
      creditLabel: creditLabel ?? this.creditLabel,
      journal: journal ?? this.journal,
      journalLabel: journalLabel ?? this.journalLabel,
      auxiliaryAccount: auxiliaryAccount ?? this.auxiliaryAccount,
      legalEntity: legalEntity ?? this.legalEntity,
      isActive: isActive ?? this.isActive,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'debit_account': debitAccount,
      'debit_label': debitLabel,
      'credit_account': creditAccount,
      'credit_label': creditLabel,
      'journal': journal,
      'journal_label': journalLabel,
      'auxiliary_account': auxiliaryAccount,
      'legal_entity': legalEntity,
      'is_active': isActive,
      'enterprise_id': enterpriseId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HrAccountingRubric.fromMap(Map<String, dynamic> map) {
    return HrAccountingRubric(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      debitAccount: map['debit_account'] ?? '',
      debitLabel: map['debit_label'] ?? '',
      creditAccount: map['credit_account'] ?? '',
      creditLabel: map['credit_label'] ?? '',
      journal: map['journal'] ?? 'OD',
      journalLabel: map['journal_label'] ?? (map['journal'] == 'BQ' ? 'Banque' : 'Paie'),
      auxiliaryAccount: map['auxiliary_account'],
      legalEntity: map['legal_entity'] ?? 'Toutes les entités',
      isActive: map['is_active'] ?? true,
      enterpriseId: map['enterprise_id'],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Modèle pour un fichier d'export d'écritures de paie au format FEC (Fichier des Écritures Comptables)
class FecExport {
  final String id;
  final String batchName; // ex: Septembre 2026
  final String? batchId;
  final String legalEntity; // ex: red / Toutes les entités
  final DateTime createdAt;
  final int recordCount;
  final double totalDebit;
  final double totalCredit;
  final String status; // Généré, Téléchargé
  final String fecContent; // Contenu textuel tabulé FEC
  final String fileName; // ex: FEC_Paie_09_2026.txt
  final String? enterpriseId;

  FecExport({
    required this.id,
    required this.batchName,
    this.batchId,
    required this.legalEntity,
    DateTime? createdAt,
    required this.recordCount,
    required this.totalDebit,
    required this.totalCredit,
    this.status = 'Généré',
    required this.fecContent,
    required this.fileName,
    this.enterpriseId,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedDate => DateFormat('dd/MM/yyyy HH:mm').format(createdAt);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_name': batchName,
      'batch_id': batchId,
      'legal_entity': legalEntity,
      'created_at': createdAt.toIso8601String(),
      'record_count': recordCount,
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'status': status,
      'fec_content': fecContent,
      'file_name': fileName,
      'enterprise_id': enterpriseId,
    };
  }

  factory FecExport.fromMap(Map<String, dynamic> map) {
    return FecExport(
      id: map['id'] ?? '',
      batchName: map['batch_name'] ?? '',
      batchId: map['batch_id'],
      legalEntity: map['legal_entity'] ?? 'Toutes les entités',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
      recordCount: (map['record_count'] as num?)?.toInt() ?? 0,
      totalDebit: (map['total_debit'] as num?)?.toDouble() ?? 0.0,
      totalCredit: (map['total_credit'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'Généré',
      fecContent: map['fec_content'] ?? '',
      fileName: map['file_name'] ?? 'export_fec.txt',
      enterpriseId: map['enterprise_id'],
    );
  }
}
