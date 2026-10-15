import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/cnss_declaration.dart';
import '../models/employee.dart';
import '../models/payslip.dart';
import 'enterprise_service.dart';

/// Service de gestion et persistance des Déclarations CNSS Trimestrielles
/// Compatible Desktop, Android et Web.
class CnssDeclarationService extends ChangeNotifier {
  static final CnssDeclarationService instance = CnssDeclarationService._();
  CnssDeclarationService._();

  static const String _storageKey = 'cnss_declarations_data_v1';
  final List<CnssDeclaration> _declarations = [];
  bool _initialized = false;

  List<CnssDeclaration> get declarations => List.unmodifiable(_declarations.where((d) => !d.isDeleted));

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _declarations.clear();
        for (final item in list) {
          try {
            _declarations.add(CnssDeclaration.fromMap(Map<String, dynamic>.from(item as Map)));
          } catch (_) {}
        }
      }

      // Si aucune déclaration n'existe, injecter la déclaration pré-configurée conforme aux Screenshots 1 & 2
      if (_declarations.isEmpty) {
        _seedInitialDeclaration();
        await _persistLocal();
      }

      // Synchronisation Cloud Firestore en arrière-plan
      _syncFromFirestore();
    } catch (e) {
      debugPrint('[CnssDeclarationService] Error during init: $e');
      if (_declarations.isEmpty) {
        _seedInitialDeclaration();
      }
    }
    notifyListeners();
  }

  void _seedInitialDeclaration() {
    final seedDeclaration = CnssDeclaration(
      id: 'cnss-seed-4-2024',
      reference: 'hr.cnss 4-2024',
      quarter: 4,
      year: 2024,
      contractType: 'Permanent',
      declarationDate: DateTime(2024, 12, 26),
      status: 'draft',
      employerNumber: '0123456789',
      exploitationCode: 'A',
      taxIdNumber: '',
      companyName: 'Société My Company (San Francisco)',
      companyAddress: '250 Executive Park Blvd, Suite 3400',
      currency: '\$',
      lines: [
        CnssDeclarationLine(
          id: const Uuid().v4(),
          page: 1,
          lineNumber: 1,
          employeeId: 'emp-abigail',
          employeeName: 'Abigail Peterson',
          cnssNumber: '2222222222222222',
          employerRegistrationNumber: '',
          professionalCategory: 'B',
          grossMonth1: 3299.62,
          grossMonth2: 1654.81,
          grossMonth3: 0.00,
          companyName: 'My Company (San Francisco)',
        ),
        CnssDeclarationLine(
          id: const Uuid().v4(),
          page: 1,
          lineNumber: 2,
          employeeId: 'emp-anita',
          employeeName: 'Anita Oliver',
          cnssNumber: '3333333333',
          employerRegistrationNumber: '',
          professionalCategory: 'C',
          grossMonth1: 4640.00,
          grossMonth2: 4661.54,
          grossMonth3: 0.00,
          companyName: 'My Company (San Francisco)',
        ),
        CnssDeclarationLine(
          id: const Uuid().v4(),
          page: 1,
          lineNumber: 3,
          employeeId: 'emp-alex',
          employeeName: 'Alex',
          cnssNumber: '1111111111111111',
          employerRegistrationNumber: '',
          professionalCategory: 'H',
          grossMonth1: 0.00,
          grossMonth2: 4005.32,
          grossMonth3: 3984.07,
          companyName: 'My Company (San Francisco)',
        ),
      ],
      createdAt: DateTime(2024, 12, 26, 10, 0, 0),
      updatedAt: DateTime(2024, 12, 26, 10, 0, 0),
    );

    _declarations.add(seedDeclaration);
  }

  CnssDeclaration? getDeclaration(String id) {
    try {
      return _declarations.firstWhere((d) => d.id == id && !d.isDeleted);
    } catch (_) {
      return null;
    }
  }

  CnssDeclaration createNewDeclaration({
    int? quarter,
    int? year,
    String? contractType,
    String? companyName,
    String? companyAddress,
    String? employerNumber,
  }) {
    final now = DateTime.now();
    final q = quarter ?? ((now.month - 1) ~/ 3) + 1;
    final y = year ?? now.year;

    return CnssDeclaration(
      id: const Uuid().v4(),
      reference: 'hr.cnss $q-$y',
      quarter: q,
      year: y,
      contractType: contractType ?? 'Permanent',
      declarationDate: now,
      status: 'draft',
      employerNumber: employerNumber ?? '0123456789',
      exploitationCode: 'A',
      taxIdNumber: '',
      companyName: companyName ?? 'Société My Company (San Francisco)',
      companyAddress: companyAddress ?? '250 Executive Park Blvd, Suite 3400',
      currency: '\$',
      lines: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Remplit ou met à jour les lignes de déclaration à partir de la liste des employés sélectionnés
  /// et des bulletins de paie de la période
  CnssDeclaration populateLinesFromEmployees(
    CnssDeclaration declaration,
    List<Employee> selectedEmployees, {
    List<Payslip> payslips = const [],
  }) {
    final List<CnssDeclarationLine> newLines = [];
    final quarter = declaration.quarter;
    final year = declaration.year;

    // Déterminer les 3 mois du trimestre
    final int startMonth = (quarter - 1) * 3 + 1;
    final int month1 = startMonth;
    final int month2 = startMonth + 1;
    final int month3 = startMonth + 2;

    int lineIdx = 1;
    for (final emp in selectedEmployees) {
      // Trouver les salaires bruts dans les fiches de paie existantes pour chaque mois du trimestre
      double brutMois1 = 0.0;
      double brutMois2 = 0.0;
      double brutMois3 = 0.0;

      for (final p in payslips) {
        if (p.employeeId == emp.id && p.periodYear == year) {
          if (p.periodMonth == month1) {
            brutMois1 += p.grossSalary;
          } else if (p.periodMonth == month2) {
            brutMois2 += p.grossSalary;
          } else if (p.periodMonth == month3) {
            brutMois3 += p.grossSalary;
          }
        }
      }

      // Si aucune fiche de paie générée pour ce mois, utiliser le salaire de base contractuel comme valeur par défaut
      if (brutMois1 == 0 && brutMois2 == 0 && brutMois3 == 0 && emp.baseSalary > 0) {
        brutMois1 = emp.baseSalary;
        brutMois2 = emp.baseSalary;
        brutMois3 = emp.baseSalary;
      }

      // Catégorie professionnelle (par défaut 'B', 'C', ou 'H' selon poste)
      String category = 'B';
      final jobLower = emp.jobTitle.toLowerCase();
      if (jobLower.contains('cadre') || jobLower.contains('direct') || jobLower.contains('manag') || jobLower.contains('ing')) {
        category = 'H';
      } else if (jobLower.contains('technic') || jobLower.contains('compt') || jobLower.contains('agent')) {
        category = 'C';
      }

      newLines.add(
        CnssDeclarationLine(
          id: const Uuid().v4(),
          page: ((lineIdx - 1) ~/ 20) + 1,
          lineNumber: lineIdx,
          employeeId: emp.id,
          employeeName: emp.fullName,
          cnssNumber: emp.cnssNumber?.isNotEmpty == true
              ? emp.cnssNumber!
              : (emp.socialSecurityNumber?.isNotEmpty == true ? emp.socialSecurityNumber! : '0000000000'),
          employerRegistrationNumber: emp.employerCode ?? emp.code,
          professionalCategory: category,
          grossMonth1: brutMois1,
          grossMonth2: brutMois2,
          grossMonth3: brutMois3,
          companyName: declaration.companyName,
        ),
      );
      lineIdx++;
    }

    return declaration.copyWith(
      lines: newLines,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> saveDeclaration(CnssDeclaration declaration) async {
    final idx = _declarations.indexWhere((d) => d.id == declaration.id);
    final updated = declaration.copyWith(updatedAt: DateTime.now());

    if (idx >= 0) {
      _declarations[idx] = updated;
    } else {
      _declarations.insert(0, updated);
    }

    await _persistLocal();
    notifyListeners();
    _saveToFirestore(updated);
  }

  Future<void> deleteDeclaration(String id) async {
    final idx = _declarations.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      _declarations[idx] = _declarations[idx].copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _persistLocal();
      notifyListeners();
      _deleteFromFirestore(id);
    }
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _declarations.map((d) => d.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[CnssDeclarationService] Error persisting to SharedPreferences: $e');
    }
  }

  Future<void> _syncFromFirestore() async {
    try {
      final enterpriseId = EnterpriseService.instance.currentEnterpriseId;
      var query = FirebaseFirestore.instance.collection('cnss_declarations').where('is_deleted', isEqualTo: false);
      if (enterpriseId != null && enterpriseId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: enterpriseId);
      }

      final snap = await query.get();
      if (snap.docs.isNotEmpty) {
        for (final doc in snap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          final remote = CnssDeclaration.fromMap(data);
          final idx = _declarations.indexWhere((d) => d.id == remote.id);
          if (idx >= 0) {
            if (remote.updatedAt.isAfter(_declarations[idx].updatedAt)) {
              _declarations[idx] = remote;
            }
          } else {
            _declarations.add(remote);
          }
        }
        await _persistLocal();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveToFirestore(CnssDeclaration declaration) async {
    try {
      final enterpriseId = EnterpriseService.instance.currentEnterpriseId;
      final data = declaration.toMap();
      if (enterpriseId != null) data['enterprise_id'] = enterpriseId;
      await FirebaseFirestore.instance.collection('cnss_declarations').doc(declaration.id).set(data);
    } catch (_) {}
  }

  Future<void> _deleteFromFirestore(String id) async {
    try {
      await FirebaseFirestore.instance.collection('cnss_declarations').doc(id).update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
