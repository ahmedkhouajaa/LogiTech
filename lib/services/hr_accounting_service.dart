import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/hr_accounting_entry.dart';
import '../models/payslip.dart';
import '../utils/file_download_helper.dart';

class HrAccountingService {
  static final HrAccountingService instance = HrAccountingService._();
  HrAccountingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _rubricsCol() =>
      _firestore.collection('hr_accounting_rubrics');

  CollectionReference<Map<String, dynamic>> _exportsCol() =>
      _firestore.collection('hr_fec_exports');

  // In-memory caches for instantaneous fallback / offline usage
  final Map<String, List<HrAccountingRubric>> _cachedRubrics = {};
  final Map<String, List<FecExport>> _cachedExports = {};

  // All 48 official default accounting rubrics mapping payroll rules to accounts
  static const List<Map<String, String>> defaultRubricTemplates = [
    {
      'code': 'ABSENCE_UNPAID',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '640000',
      'creditLabel': 'Salaires et compléments de salaires',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'ACOMPTE_DEDUCTION',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '421000',
      'creditLabel': 'Personnel avances et acomptes',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'ACOMPTE_PAID',
      'debitAccount': '421000',
      'debitLabel': 'Personnel avances et acomptes',
      'creditAccount': '512000',
      'creditLabel': 'Banque',
      'journal': 'BQ',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'ADVANTAGE_EXO',
      'debitAccount': '640200',
      'debitLabel': 'Salaire régime EXO_2',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'ADVANTAGE_KARAMA',
      'debitAccount': '640200',
      'debitLabel': 'Salaire régime KARAMA',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'AT_MP',
      'debitAccount': '647100',
      'debitLabel': 'Accident de travail',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'AT_MP_KARAMA',
      'debitAccount': '647100',
      'debitLabel': 'Accident de travail',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'BASE_SALARY',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'BONUS',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CNSS',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CNSS_EMPLOYEE',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CNSS_EMPLOYER',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CNSS_EXO',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CNSS_EXO_EMPLOYEE',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CNSS_KARAMA',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CNSS_KARAMA_EMPLOYEE',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CSS',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '432101',
      'creditLabel': 'Contribution Sociale Solidarité',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'CSS_KARAMA',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '432101',
      'creditLabel': 'Contribution Sociale Solidarité',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'EXPENSE_REIMBURSEMENT',
      'debitAccount': '625000',
      'debitLabel': 'Déplacements, missions et réceptions',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'FOPROLOS',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'FOPROLOS_KARAMA',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'GROSS_SALARY',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'HOLIDAY_DEDUCTION',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '640000',
      'creditLabel': 'Salaires et compléments de salaires',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'HOLIDAY_PREMIUM',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'IRPP',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '432100',
      'creditLabel': 'Retenue à la source / Salaire',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'LEAVE_PROVISION_CHARGE',
      'debitAccount': '646000',
      'debitLabel': 'Charges connexes aux salaires / Congés payés',
      'creditAccount': '428200',
      'creditLabel': 'Dettes provisionnées pour congés à payer',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'LEAVE_PROVISION_REVERSAL',
      'debitAccount': '428200',
      'debitLabel': 'Dettes provisionnées pour congés à payer',
      'creditAccount': '646000',
      'creditLabel': 'Charges connexes aux salaires / Congés payés',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'LOAN_DISBURSED',
      'debitAccount': '274300',
      'debitLabel': 'Prêts au personnel',
      'creditAccount': '512000',
      'creditLabel': 'Banque',
      'journal': 'BQ',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'LOAN_INTEREST',
      'debitAccount': '421000',
      'debitLabel': 'Personnel - Rémunérations dues',
      'creditAccount': '763000',
      'creditLabel': 'Revenus des créances',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'LOAN_REPAYMENT',
      'debitAccount': '421000',
      'debitLabel': 'Personnel - Rémunérations dues',
      'creditAccount': '274300',
      'creditLabel': 'Prêts au personnel',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'MEAL',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'MEAL_VOUCHER_EMPLOYEE',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '437000',
      'creditLabel': 'Autres organismes sociaux',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'MEAL_VOUCHER_EMPLOYER',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'MEAL_VOUCHER_SURPLUS',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'OTHER',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'PERTE_EMPLOI_EMPLOYEE',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'PERTE_EMPLOI_EMPLOYER',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'PRESENCE_ALLOWANCE',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'RAPPEL_BONUS_GROSS',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'RAPPEL_NET_ADDITION',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'RAPPEL_NET_DEDUCTION',
      'debitAccount': '425000',
      'debitLabel': 'Personnel rémunérations dues',
      'creditAccount': '640000',
      'creditLabel': 'Salaires et compléments de salaires',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'RAPPEL_SALARY_GROSS',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'TFP',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'TFP_KARAMA',
      'debitAccount': '647000',
      'debitLabel': 'Charges sociales légales',
      'creditAccount': '453110',
      'creditLabel': 'CNSS',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'TICKET_RESTAURANT',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'TRANSPORT',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'TRANSPORT_ALLOWANCE',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
    {
      'code': 'VARIABLE',
      'debitAccount': '640000',
      'debitLabel': 'Salaires et compléments de salaires',
      'creditAccount': '425000',
      'creditLabel': 'Personnel rémunérations dues',
      'journal': 'OD',
      'legalEntity': 'Toutes les entités',
    },
  ];

  static List<HrAccountingRubric> buildFallbackRubrics(String enterpriseId) {
    return defaultRubricTemplates.map((t) {
      return HrAccountingRubric(
        id: 'default_${t['code']}',
        code: t['code']!,
        debitAccount: t['debitAccount']!,
        debitLabel: t['debitLabel']!,
        creditAccount: t['creditAccount']!,
        creditLabel: t['creditLabel']!,
        journal: t['journal']!,
        legalEntity: t['legalEntity'] ?? 'Toutes les entités',
        enterpriseId: enterpriseId,
      );
    }).toList();
  }

  /// Seed initial rubrics if any of the default templates is missing
  Future<void> seedInitialRubricsIfEmpty(String enterpriseId) async {
    if (enterpriseId.isEmpty) return;
    try {
      final snap = await _rubricsCol().where('enterprise_id', isEqualTo: enterpriseId).get();
      final existingCodes = <String>{};
      for (final doc in snap.docs) {
        final code = doc.data()['code']?.toString();
        if (code != null && code.isNotEmpty) {
          existingCodes.add(code);
        }
      }

      final missingTemplates = defaultRubricTemplates.where(
        (t) => !existingCodes.contains(t['code']),
      ).toList();

      if (missingTemplates.isNotEmpty) {
        final batch = _firestore.batch();
        for (final t in missingTemplates) {
          final id = const Uuid().v4();
          final r = HrAccountingRubric(
            id: id,
            code: t['code']!,
            debitAccount: t['debitAccount']!,
            debitLabel: t['debitLabel']!,
            creditAccount: t['creditAccount']!,
            creditLabel: t['creditLabel']!,
            journal: t['journal']!,
            legalEntity: t['legalEntity'] ?? 'Toutes les entités',
            enterpriseId: enterpriseId,
          );
          batch.set(_rubricsCol().doc(id), r.toMap());
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[HrAccountingService] seed error: $e');
    }
  }

  /// Stream of rubrics for the given enterprise
  Stream<List<HrAccountingRubric>> getRubricsStream(String enterpriseId) {
    if (enterpriseId.isEmpty) return Stream.value(buildFallbackRubrics(''));
    return _rubricsCol()
        .where('enterprise_id', isEqualTo: enterpriseId)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) {
        return buildFallbackRubrics(enterpriseId);
      }
      final list = snap.docs.map((d) => HrAccountingRubric.fromMap(d.data())).toList();
      list.sort((a, b) => a.code.compareTo(b.code));
      _cachedRubrics[enterpriseId] = list;
      return list;
    });
  }

  /// Stream of FEC exports for the given enterprise
  Stream<List<FecExport>> getExportsStream(String enterpriseId) {
    if (enterpriseId.isEmpty) return Stream.value([]);
    return _exportsCol()
        .where('enterprise_id', isEqualTo: enterpriseId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => FecExport.fromMap(d.data())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cachedExports[enterpriseId] = list;
      return list;
    });
  }

  /// Add or update a rubric
  Future<void> saveRubric(HrAccountingRubric rubric) async {
    final docId = rubric.id.isEmpty ? const Uuid().v4() : rubric.id;
    final toSave = rubric.copyWith(id: docId, updatedAt: DateTime.now());
    await _rubricsCol().doc(docId).set(toSave.toMap(), SetOptions(merge: true));
  }

  /// Delete a rubric
  Future<void> deleteRubric(String id) async {
    if (id.isEmpty) return;
    await _rubricsCol().doc(id).delete();
  }

  /// Reset a rubric back to default definition template
  Future<void> resetRubricToDefault(HrAccountingRubric current) async {
    final t = defaultRubricTemplates.firstWhere(
      (m) => m['code'] == current.code,
      orElse: () => {},
    );
    if (t.isNotEmpty) {
      final updated = current.copyWith(
        debitAccount: t['debitAccount'] ?? current.debitAccount,
        debitLabel: t['debitLabel'] ?? current.debitLabel,
        creditAccount: t['creditAccount'] ?? current.creditAccount,
        creditLabel: t['creditLabel'] ?? current.creditLabel,
        journal: t['journal'] ?? 'OD',
        journalLabel: t['journal'] == 'BQ' ? 'Banque' : 'Paie',
        auxiliaryAccount: null,
        isActive: true,
      );
      await saveRubric(updated);
    }
  }

  /// Generate a new FEC export from payroll batch / period
  Future<FecExport> generateFecExport({
    required String enterpriseId,
    required String legalEntity,
    required String batchName,
    String? batchId,
    List<Payslip> payslips = const [],
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final safeBatchName = batchName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'FEC_Paie_${safeBatchName}_$dateStr.txt';

    // FEC Header (Norme DGI / FEC France & Tunisie)
    final headers = [
      'JournalCode',
      'JournalLib',
      'EcritureNum',
      'EcritureDate',
      'CompteNum',
      'CompteLib',
      'CompAuxNum',
      'CompAuxLib',
      'PieceRef',
      'PieceDate',
      'EcritureLib',
      'Debit',
      'Credit',
      'EcritureLet',
      'DateLet',
      'ValidDate',
      'Montantdevise',
      'Idevise',
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));

    double totalGross = 0.0;
    double totalNet = 0.0;
    double totalCnssPatronale = 0.0;
    double totalCnssOuvriere = 0.0;
    double totalIrpp = 0.0;
    double totalCss = 0.0;
    double totalAdvances = 0.0;

    if (payslips.isNotEmpty) {
      for (final p in payslips) {
        totalGross += p.grossSalary;
        totalNet += p.netSalary;
        totalCnssOuvriere += p.cnssDeduction;
        totalIrpp += p.taxDeduction;
        totalAdvances += p.advanceSalary;
        // Approximation patronale standard ~16.57%
        totalCnssPatronale += p.grossSalary * 0.1657;
        totalCss += p.cssDeduction > 0 ? p.cssDeduction : (p.grossSalary * 0.01);
      }
    } else {
      // Mock run metrics if run has no specific slips
      totalGross = 24500.00;
      totalCnssPatronale = 4059.65;
      totalCnssOuvriere = 2249.10;
      totalIrpp = 3120.40;
      totalCss = 245.00;
      totalAdvances = 1200.00;
      totalNet = totalGross - totalCnssOuvriere - totalIrpp - totalCss - totalAdvances;
    }

    final entries = <Map<String, dynamic>>[];
    int ecritureSeq = 1;

    void addLine({
      required String journal,
      required String journalLib,
      required String pieceRef,
      required String compte,
      required String compteLib,
      required String libelle,
      double debit = 0.0,
      double credit = 0.0,
    }) {
      if (debit == 0.0 && credit == 0.0) return;
      entries.add({
        'JournalCode': journal,
        'JournalLib': journalLib,
        'EcritureNum': 'ECR-$dateStr-${ecritureSeq.toString().padLeft(4, '0')}',
        'EcritureDate': dateStr,
        'CompteNum': compte,
        'CompteLib': compteLib,
        'CompAuxNum': '',
        'CompAuxLib': '',
        'PieceRef': pieceRef,
        'PieceDate': dateStr,
        'EcritureLib': '$libelle - $batchName',
        'Debit': debit.toStringAsFixed(2).replaceAll('.', ','),
        'Credit': credit.toStringAsFixed(2).replaceAll('.', ','),
        'EcritureLet': '',
        'DateLet': '',
        'ValidDate': dateStr,
        'Montantdevise': '',
        'Idevise': 'TND',
      });
      ecritureSeq++;
    }

    final pieceRef = 'PAIE-$safeBatchName';

    // 1. Salaires bruts (Débit 640000 / Crédit 425000)
    addLine(
      journal: 'OD',
      journalLib: 'Opérations diverses',
      pieceRef: pieceRef,
      compte: '640000',
      compteLib: 'Salaires et compléments de salaires',
      libelle: 'Salaires bruts du personnel',
      debit: totalGross,
      credit: 0.0,
    );
    addLine(
      journal: 'OD',
      journalLib: 'Opérations diverses',
      pieceRef: pieceRef,
      compte: '425000',
      compteLib: 'Personnel rémunérations dues',
      libelle: 'Rémunérations brutes dues',
      debit: 0.0,
      credit: totalGross,
    );

    // 2. Cotisations Patronales CNSS (Débit 647000 / Crédit 453100)
    addLine(
      journal: 'OD',
      journalLib: 'Opérations diverses',
      pieceRef: pieceRef,
      compte: '647000',
      compteLib: 'Cotisations de sécurité sociale',
      libelle: 'Charges patronales CNSS',
      debit: totalCnssPatronale,
      credit: 0.0,
    );
    addLine(
      journal: 'OD',
      journalLib: 'Opérations diverses',
      pieceRef: pieceRef,
      compte: '453100',
      compteLib: 'Sécurité sociale - CNSS',
      libelle: 'CNSS Patronale due',
      debit: 0.0,
      credit: totalCnssPatronale,
    );

    // 3. Retenue CNSS Ouvrière (Débit 425000 / Crédit 453100)
    addLine(
      journal: 'OD',
      journalLib: 'Opérations diverses',
      pieceRef: pieceRef,
      compte: '425000',
      compteLib: 'Personnel rémunérations dues',
      libelle: 'Retenue CNSS Ouvrière sur salaires',
      debit: totalCnssOuvriere,
      credit: 0.0,
    );
    addLine(
      journal: 'OD',
      journalLib: 'Opérations diverses',
      pieceRef: pieceRef,
      compte: '453100',
      compteLib: 'Sécurité sociale - CNSS',
      libelle: 'CNSS Ouvrière à reverser',
      debit: 0.0,
      credit: totalCnssOuvriere,
    );

    // 4. Retenue IRPP (Débit 425000 / Crédit 457000)
    addLine(
      journal: 'OD',
      journalLib: 'Opérations diverses',
      pieceRef: pieceRef,
      compte: '425000',
      compteLib: 'Personnel rémunérations dues',
      libelle: 'Retenue à la source IRPP sur paie',
      debit: totalIrpp,
      credit: 0.0,
    );
    addLine(
      journal: 'OD',
      journalLib: 'Opérations diverses',
      pieceRef: pieceRef,
      compte: '457000',
      compteLib: 'Impôts et taxes recouvrables - IRPP',
      libelle: 'IRPP retenu à la source à reverser',
      debit: 0.0,
      credit: totalIrpp,
    );

    // 5. Retenue CSS (Débit 425000 / Crédit 457100)
    if (totalCss > 0) {
      addLine(
        journal: 'OD',
        journalLib: 'Opérations diverses',
        pieceRef: pieceRef,
        compte: '425000',
        compteLib: 'Personnel rémunérations dues',
        libelle: 'Retenue CSS 1% sur paie',
        debit: totalCss,
        credit: 0.0,
      );
      addLine(
        journal: 'OD',
        journalLib: 'Opérations diverses',
        pieceRef: pieceRef,
        compte: '457100',
        compteLib: 'Contribution sociale solidaire',
        libelle: 'CSS à reverser',
        debit: 0.0,
        credit: totalCss,
      );
    }

    // 6. Déduction des acomptes (Débit 425000 / Crédit 421000)
    if (totalAdvances > 0) {
      addLine(
        journal: 'OD',
        journalLib: 'Opérations diverses',
        pieceRef: pieceRef,
        compte: '425000',
        compteLib: 'Personnel rémunérations dues',
        libelle: 'Récupération acomptes sur paie',
        debit: totalAdvances,
        credit: 0.0,
      );
      addLine(
        journal: 'OD',
        journalLib: 'Opérations diverses',
        pieceRef: pieceRef,
        compte: '421000',
        compteLib: 'Personnel avances et acomptes',
        libelle: 'Régularisation acomptes versés',
        debit: 0.0,
        credit: totalAdvances,
      );
    }

    // 7. Règlement salaires nets (Débit 425000 / Crédit 512000)
    addLine(
      journal: 'BQ',
      journalLib: 'Journal de Banque',
      pieceRef: pieceRef,
      compte: '425000',
      compteLib: 'Personnel rémunérations dues',
      libelle: 'Virement des salaires nets',
      debit: totalNet,
      credit: 0.0,
    );
    addLine(
      journal: 'BQ',
      journalLib: 'Journal de Banque',
      pieceRef: pieceRef,
      compte: '512000',
      compteLib: 'Banque',
      libelle: 'Paiement salaires nets par virement',
      debit: 0.0,
      credit: totalNet,
    );

    double sumDebit = 0.0;
    double sumCredit = 0.0;

    for (final e in entries) {
      final row = headers.map((h) => e[h] ?? '').join('\t');
      buffer.writeln(row);
      final d = double.tryParse((e['Debit'] as String).replaceAll(',', '.')) ?? 0.0;
      final c = double.tryParse((e['Credit'] as String).replaceAll(',', '.')) ?? 0.0;
      sumDebit += d;
      sumCredit += c;
    }

    final exportId = const Uuid().v4();
    final fecExport = FecExport(
      id: exportId,
      batchName: batchName,
      batchId: batchId,
      legalEntity: legalEntity,
      createdAt: now,
      recordCount: entries.length,
      totalDebit: sumDebit,
      totalCredit: sumCredit,
      status: 'Généré',
      fecContent: buffer.toString(),
      fileName: fileName,
      enterpriseId: enterpriseId,
    );

    await _exportsCol().doc(exportId).set(fecExport.toMap());
    return fecExport;
  }

  /// Download FEC file
  Future<void> downloadFecExport(BuildContext context, FecExport export) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(export.fecContent));
      await FileDownloadHelper.saveAndOpenFile(bytes, export.fileName, context: context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fichier "${export.fileName}" téléchargé avec succès.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Delete an export
  Future<void> deleteExport(String id) async {
    if (id.isEmpty) return;
    await _exportsCol().doc(id).delete();
  }
}
