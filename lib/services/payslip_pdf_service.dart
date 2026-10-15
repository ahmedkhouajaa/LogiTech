import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/payslip.dart';
import '../models/employee.dart';
import '../models/project.dart'; // CompanySettings
import '../database/database_helper.dart';

/// Service complet de génération et d'impression des bulletins de paie
/// Supporte "Standard Payslip" et "Payslip Report" (unitaire ou par lot)
/// Compatible Android, Desktop (Windows/macOS/Linux) et Web.
class PayslipPdfService {
  static final PayslipPdfService instance = PayslipPdfService._();
  PayslipPdfService._();

  pw.Font? _cachedRegular;
  pw.Font? _cachedBold;

  Future<(pw.Font, pw.Font)> _getFonts() async {
    if (_cachedRegular != null && _cachedBold != null) {
      return (_cachedRegular!, _cachedBold!);
    }
    try {
      final reg = await PdfGoogleFonts.robotoRegular().timeout(const Duration(milliseconds: 2500));
      final bold = await PdfGoogleFonts.robotoBold().timeout(const Duration(milliseconds: 2500));
      _cachedRegular = reg;
      _cachedBold = bold;
      return (reg, bold);
    } catch (_) {
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  // ---------------------------------------------------------------------------
  // PUBLIC PRINT & PREVIEW API
  // ---------------------------------------------------------------------------

  /// Imprime directement via le spouleur d'impression natif (Desktop/Android/Web)
  Future<void> printPayslip(
    BuildContext context,
    Payslip payslip, {
    required String type, // 'standard' or 'report'
    Employee? employee,
  }) async {
    try {
      final docName = type == 'report'
          ? 'Rapport_Paie_${payslip.reference.replaceAll('/', '_')}'
          : 'Bulletin_Paie_${payslip.reference.replaceAll('/', '_')}';

      final bytes = type == 'report'
          ? await generatePayslipReportPdf([payslip], employeeMap: employee != null ? {employee.id: employee} : null)
          : await generateStandardPayslipPdf(payslip, employee: employee);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: '$docName.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'impression : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Imprime un lot de bulletins sélectionnés (Image 1: 4 sélectionné(s))
  Future<void> printBatchPayslips(
    BuildContext context,
    List<Payslip> payslips, {
    required String type, // 'standard' or 'report'
    Map<String, Employee>? employeeMap,
  }) async {
    if (payslips.isEmpty) return;

    try {
      final periodStr = '${payslips.first.periodMonth}-${payslips.first.periodYear}';
      final docName = type == 'report'
          ? 'Rapport_Recapitulatif_Paie_$periodStr'
          : 'Bulletins_Paie_Lot_$periodStr';

      final bytes = type == 'report'
          ? await generatePayslipReportPdf(payslips, employeeMap: employeeMap)
          : await generateBatchStandardPayslipsPdf(payslips, employeeMap: employeeMap);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: '$docName.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'impression du lot : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 1. STANDARD PAYSLIP GENERATION (Bulletin de Paie Officiel)
  // ---------------------------------------------------------------------------

  Future<Uint8List> generateStandardPayslipPdf(
    Payslip payslip, {
    Employee? employee,
    CompanySettings? companySettings,
  }) async {
    companySettings ??= await DatabaseHelper.instance.getCompanySettings();
    final (fontReg, fontBold) = await _getFonts();

    final doc = pw.Document(
      title: payslip.payslipName ?? 'Bulletin de paie ${payslip.reference}',
      author: companySettings.name,
    );

    final page = _buildStandardPayslipPage(
      payslip: payslip,
      employee: employee,
      company: companySettings,
      fontReg: fontReg,
      fontBold: fontBold,
    );

    doc.addPage(page);
    return doc.save();
  }

  Future<Uint8List> generateBatchStandardPayslipsPdf(
    List<Payslip> payslips, {
    Map<String, Employee>? employeeMap,
    CompanySettings? companySettings,
  }) async {
    companySettings ??= await DatabaseHelper.instance.getCompanySettings();
    final (fontReg, fontBold) = await _getFonts();

    final doc = pw.Document(
      title: 'Bulletins de Paie des Employés',
      author: companySettings.name,
    );

    for (final p in payslips) {
      final emp = employeeMap?[p.employeeId];
      final page = _buildStandardPayslipPage(
        payslip: p,
        employee: emp,
        company: companySettings,
        fontReg: fontReg,
        fontBold: fontBold,
      );
      doc.addPage(page);
    }

    return doc.save();
  }

  pw.Page _buildStandardPayslipPage({
    required Payslip payslip,
    Employee? employee,
    required CompanySettings company,
    required pw.Font fontReg,
    required pw.Font fontBold,
  }) {
    final fmtCurr = NumberFormat('#,##0.000', 'fr_FR');
    final monthsFr = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final periodName = '${monthsFr[payslip.periodMonth - 1]} ${payslip.periodYear}';
    final lastDay = DateTime(payslip.periodYear, payslip.periodMonth + 1, 0).day;
    final periodRange = 'Du 01/${payslip.periodMonth.toString().padLeft(2, '0')}/${payslip.periodYear} au $lastDay/${payslip.periodMonth.toString().padLeft(2, '0')}/${payslip.periodYear}';

    // Status styling
    final isPaid = payslip.paymentStatus.toLowerCase() == 'paid';
    final isValidated = payslip.paymentStatus.toLowerCase() == 'validated';
    final statusText = isPaid ? 'PAYÉ' : (isValidated ? 'CONFIRMÉ' : 'BROUILLON');
    final statusColor = isPaid
        ? const PdfColor.fromInt(0xFF10B981)
        : (isValidated ? const PdfColor.fromInt(0xFF06B6D4) : const PdfColor.fromInt(0xFFF59E0B));

    // Base, Brut, Net Imposable
    final gross = payslip.grossSalary;
    final cnss = payslip.cnssDeduction;
    final taxableNet = (gross - cnss) > 0 ? (gross - cnss) : 0.0;
    final irpp = payslip.taxDeduction;
    final css = payslip.cssDeduction;
    final advances = payslip.advanceSalary;
    final loan = payslip.loanDeduction;
    final otherDed = payslip.otherDeductions;
    final totalDeductions = cnss + irpp + css + advances + loan + otherDed;
    final netWage = payslip.netSalary;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── 1. Top Header: Company Info + Document Title + Status ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Company block
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        company.name.toUpperCase(),
                        style: pw.TextStyle(font: fontBold, fontSize: 16, color: const PdfColor.fromInt(0xFF1E293B)),
                      ),
                      pw.SizedBox(height: 3),
                      if (company.address != null && company.address!.isNotEmpty)
                        pw.Text(
                          '${company.address}${company.city != null ? ', ${company.city}' : ''}',
                          style: pw.TextStyle(font: fontReg, fontSize: 8.5, color: const PdfColor.fromInt(0xFF64748B)),
                        ),
                      if (company.taxId != null && company.taxId!.isNotEmpty)
                        pw.Text(
                          'Matricule Fiscal / RNE : ${company.taxId}',
                          style: pw.TextStyle(font: fontReg, fontSize: 8.5, color: const PdfColor.fromInt(0xFF64748B)),
                        ),
                      if (company.phone != null && company.phone!.isNotEmpty)
                        pw.Text(
                          'Tél : ${company.phone}${company.email != null ? ' | Email : ${company.email}' : ''}',
                          style: pw.TextStyle(font: fontReg, fontSize: 8.5, color: const PdfColor.fromInt(0xFF64748B)),
                        ),
                    ],
                  ),
                ),

                // Document Title & Reference
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFF1A56DB), // Odoo Purple
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'BULLETIN DE PAIE',
                          style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Réf : ${payslip.reference}',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: const PdfColor.fromInt(0xFF1E293B)),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: statusColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          statusText,
                          style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 14),
            pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFFCBD5E1)),
            pw.SizedBox(height: 10),

            // ── 2. Employee & Contract Details Box (Two Columns) ──
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Col 1: Salarié
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Salarié :', payslip.employeeName, fontBold, fontReg, isBoldVal: true),
                        _buildInfoRow('Matricule :', employee?.id ?? payslip.employeeId, fontBold, fontReg),
                        _buildInfoRow('CIN :', payslip.employeeCin ?? employee?.cin ?? '—', fontBold, fontReg),
                        _buildInfoRow('N° CNSS :', payslip.employeeCnss ?? employee?.cnssNumber ?? '—', fontBold, fontReg),
                        _buildInfoRow('Poste / Emploi :', payslip.employeeJobTitle ?? employee?.jobTitle ?? 'Employé', fontBold, fontReg),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 14),

                  // Col 2: Période & Contrat
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Période :', '$periodName ($periodRange)', fontBold, fontReg, isBoldVal: true),
                        _buildInfoRow('Contrat :', payslip.contractReference ?? 'C02', fontBold, fontReg),
                        _buildInfoRow('Structure :', payslip.salaryStructure.isNotEmpty ? payslip.salaryStructure : 'Standard', fontBold, fontReg),
                        _buildInfoRow('Jours travaillés :', '${payslip.workedDays.toStringAsFixed(2)} j (${payslip.workedHours.toStringAsFixed(2)} h)', fontBold, fontReg),
                        if (payslip.unpaidAbsenceDays > 0 || payslip.unpaidAbsenceDeduction > 0)
                          _buildInfoRow(
                            'Absences déduites :',
                            '- ${payslip.unpaidAbsenceDays.toStringAsFixed(2)} j (- ${fmtCurr.format(payslip.unpaidAbsenceDeduction)} DT)',
                            fontBold,
                            fontReg,
                            valueColor: const PdfColor.fromInt(0xFFDC2626),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // ── 3. Table of Salary Rubrics (Gains & Retenues) ──
            pw.Text(
              'DÉTAILS DES ÉLÉMENTS DE SALAIRE',
              style: pw.TextStyle(font: fontBold, fontSize: 10, color: const PdfColor.fromInt(0xFF475569), letterSpacing: 0.5),
            ),
            pw.SizedBox(height: 6),

            _buildSalaryTable(
              payslip: payslip,
              fontReg: fontReg,
              fontBold: fontBold,
              fmtCurr: fmtCurr,
            ),

            pw.SizedBox(height: 12),

            // ── 4. Summary & Net Wage Box ──
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildTotalColumn('SALAIRE BRUT', '${fmtCurr.format(gross)} DT', fontBold, fontReg),
                  _buildTotalColumn('COTISATION CNSS (9.18%)', '- ${fmtCurr.format(cnss)} DT', fontBold, fontReg, isNeg: true),
                  _buildTotalColumn('NET IMPOSABLE', '${fmtCurr.format(taxableNet)} DT', fontBold, fontReg),
                  _buildTotalColumn('TOTAL RETENUES', '- ${fmtCurr.format(totalDeductions)} DT', fontBold, fontReg, isNeg: true),
                ],
              ),
            ),

            pw.SizedBox(height: 10),

            // Net à Payer Highlight Box
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFECFDF5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFF10B981), width: 1.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NET À PAYER (Net Wage)',
                        style: pw.TextStyle(font: fontBold, fontSize: 11.5, color: const PdfColor.fromInt(0xFF065F46)),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Arrêté à la somme de : ${_convertNumberToFrenchWords(netWage)} Dinars Tunisiens',
                        style: pw.TextStyle(font: fontReg, fontSize: 8.5, color: const PdfColor.fromInt(0xFF047857), fontStyle: pw.FontStyle.italic),
                      ),
                    ],
                  ),
                  pw.Text(
                    '${fmtCurr.format(netWage)} DT',
                    style: pw.TextStyle(font: fontBold, fontSize: 17, color: const PdfColor.fromInt(0xFF047857)),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 10),

            // Paiement details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Mode de règlement : ${payslip.paymentMethod}${payslip.paymentDate != null ? ' le ${DateFormat('dd/MM/yyyy').format(payslip.paymentDate!)}' : ''}',
                  style: pw.TextStyle(font: fontReg, fontSize: 8.5, color: const PdfColor.fromInt(0xFF64748B)),
                ),
                pw.Text(
                  'Journal de paie : ${payslip.salaryJournal ?? 'Opérations diverses'}',
                  style: pw.TextStyle(font: fontReg, fontSize: 8.5, color: const PdfColor.fromInt(0xFF64748B)),
                ),
              ],
            ),

            pw.Spacer(),

            // ── 5. Signatures Block ──
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Pour la Direction / Cachet :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: const PdfColor.fromInt(0xFF475569))),
                      pw.SizedBox(height: 38),
                      pw.Text('(Signature autorisée)', style: pw.TextStyle(font: fontReg, fontSize: 7.5, color: const PdfColor.fromInt(0xFF94A3B8))),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Émargement du Salarié :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: const PdfColor.fromInt(0xFF475569))),
                      pw.SizedBox(height: 38),
                      pw.Text('« Pour acquit »', style: pw.TextStyle(font: fontReg, fontSize: 7.5, color: const PdfColor.fromInt(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'Ce bulletin de paie doit être conservé sans limitation de durée (Code du travail tunisien).',
                style: pw.TextStyle(font: fontReg, fontSize: 7, color: const PdfColor.fromInt(0xFF94A3B8), fontStyle: pw.FontStyle.italic),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PAYSLIP REPORT GENERATION (Livre & Rapport Récapitulatif de Paie)
  // ---------------------------------------------------------------------------

  Future<Uint8List> generatePayslipReportPdf(
    List<Payslip> payslips, {
    Map<String, Employee>? employeeMap,
    CompanySettings? companySettings,
  }) async {
    companySettings ??= await DatabaseHelper.instance.getCompanySettings();
    final (fontReg, fontBold) = await _getFonts();
    final fmtCurr = NumberFormat('#,##0.000', 'fr_FR');

    final doc = pw.Document(
      title: 'Rapport Récapitulatif de Paie',
      author: companySettings.name,
    );

    // Totals across all payslips
    double sumGross = 0;
    double sumCnss = 0;
    double sumIrpp = 0;
    double sumCss = 0;
    double sumAdvances = 0;
    double sumLoans = 0;
    double sumAbsences = 0;
    double sumNet = 0;

    for (final p in payslips) {
      sumGross += p.grossSalary;
      sumCnss += p.cnssDeduction;
      sumIrpp += p.taxDeduction;
      sumCss += p.cssDeduction;
      sumAdvances += p.advanceSalary;
      sumLoans += p.loanDeduction;
      sumAbsences += p.unpaidAbsenceDeduction;
      sumNet += p.netSalary;
    }

    final periodLabel = payslips.isNotEmpty
        ? 'Période : ${payslips.first.periodMonth.toString().padLeft(2, '0')}/${payslips.first.periodYear}'
        : 'Période globale';

    // ── PAGE 1: Executive Summary & Consolidated Payroll Table ──
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companySettings!.name.toUpperCase(),
                        style: pw.TextStyle(font: fontBold, fontSize: 14, color: const PdfColor.fromInt(0xFF1E293B)),
                      ),
                      pw.Text(
                        'Rapport & Livre de Paie des Employés ($periodLabel)',
                        style: pw.TextStyle(font: fontBold, fontSize: 12, color: const PdfColor.fromInt(0xFF1A56DB)),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date d\'édition : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(font: fontReg, fontSize: 8.5, color: const PdfColor.fromInt(0xFF64748B)),
                      ),
                      pw.Text(
                        'Total bulletins : ${payslips.length}',
                        style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: const PdfColor.fromInt(0xFF1E293B)),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // KPI Cards Row
              pw.Row(
                children: [
                  _buildKpiCard('Masse Salariale Brute', '${fmtCurr.format(sumGross)} DT', const PdfColor.fromInt(0xFF1A56DB), fontBold, fontReg),
                  pw.SizedBox(width: 8),
                  _buildKpiCard('Cotisations CNSS (9.18%)', '${fmtCurr.format(sumCnss)} DT', const PdfColor.fromInt(0xFFDC2626), fontBold, fontReg),
                  pw.SizedBox(width: 8),
                  _buildKpiCard('Impôts Retenus (IRPP + CSS)', '${fmtCurr.format(sumIrpp + sumCss)} DT', const PdfColor.fromInt(0xFFD97706), fontBold, fontReg),
                  pw.SizedBox(width: 8),
                  _buildKpiCard('Absences Déduites', '- ${fmtCurr.format(sumAbsences)} DT', const PdfColor.fromInt(0xFFBE123C), fontBold, fontReg),
                  pw.SizedBox(width: 8),
                  _buildKpiCard('Net Total Décaissé', '${fmtCurr.format(sumNet)} DT', const PdfColor.fromInt(0xFF10B981), fontBold, fontReg),
                ],
              ),

              pw.SizedBox(height: 12),

              // Consolidated Table
              pw.Expanded(
                child: pw.Table(
                  border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.2), // Réf
                    1: pw.FlexColumnWidth(2.0), // Salarié
                    2: pw.FlexColumnWidth(1.2), // Contrat
                    3: pw.FlexColumnWidth(1.0), // Jours
                    4: pw.FlexColumnWidth(1.3), // Base
                    5: pw.FlexColumnWidth(1.3), // Brut
                    6: pw.FlexColumnWidth(1.2), // CNSS
                    7: pw.FlexColumnWidth(1.2), // IRPP
                    8: pw.FlexColumnWidth(1.0), // CSS
                    9: pw.FlexColumnWidth(1.2), // Avances/Prêt
                    10: pw.FlexColumnWidth(1.4), // Net à Payer
                    11: pw.FlexColumnWidth(1.0), // Statut
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                      children: [
                        _buildTableHeaderCell('Référence', fontBold),
                        _buildTableHeaderCell('Employé', fontBold),
                        _buildTableHeaderCell('Contrat', fontBold),
                        _buildTableHeaderCell('Jours', fontBold),
                        _buildTableHeaderCell('Base (DT)', fontBold),
                        _buildTableHeaderCell('Brut (DT)', fontBold),
                        _buildTableHeaderCell('CNSS (DT)', fontBold),
                        _buildTableHeaderCell('IRPP (DT)', fontBold),
                        _buildTableHeaderCell('CSS (DT)', fontBold),
                        _buildTableHeaderCell('Avances/Prêt', fontBold),
                        _buildTableHeaderCell('Net (DT)', fontBold),
                        _buildTableHeaderCell('Statut', fontBold),
                      ],
                    ),

                    // Data Rows
                    ...payslips.map((p) {
                      final isPaid = p.paymentStatus.toLowerCase() == 'paid';
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isPaid ? const PdfColor.fromInt(0xFFF0FDF4) : PdfColors.white,
                        ),
                        children: [
                          _buildTableCell(p.reference, fontReg),
                          _buildTableCell(p.employeeName, fontBold),
                          _buildTableCell(p.contractReference ?? 'C02', fontReg),
                          _buildTableCell('${p.workedDays.toStringAsFixed(1)} j', fontReg, align: pw.TextAlign.center),
                          _buildTableCell(fmtCurr.format(p.baseSalary), fontReg, align: pw.TextAlign.right),
                          _buildTableCell(fmtCurr.format(p.grossSalary), fontBold, align: pw.TextAlign.right),
                          _buildTableCell(fmtCurr.format(p.cnssDeduction), fontReg, align: pw.TextAlign.right),
                          _buildTableCell(fmtCurr.format(p.taxDeduction), fontReg, align: pw.TextAlign.right),
                          _buildTableCell(fmtCurr.format(p.cssDeduction), fontReg, align: pw.TextAlign.right),
                          _buildTableCell(fmtCurr.format(p.advanceSalary + p.loanDeduction), fontReg, align: pw.TextAlign.right),
                          _buildTableCell(fmtCurr.format(p.netSalary), fontBold, align: pw.TextAlign.right, color: const PdfColor.fromInt(0xFF047857)),
                          _buildTableCell(p.paymentStatus.toUpperCase(), fontBold, align: pw.TextAlign.center, color: isPaid ? const PdfColor.fromInt(0xFF10B981) : const PdfColor.fromInt(0xFFD97706)),
                        ],
                      );
                    }),

                    // Grand Totals Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
                      children: [
                        _buildTableCell('TOTAL', fontBold, align: pw.TextAlign.center),
                        _buildTableCell('${payslips.length} salariés', fontBold),
                        _buildTableCell('—', fontReg, align: pw.TextAlign.center),
                        _buildTableCell('—', fontReg, align: pw.TextAlign.center),
                        _buildTableCell('—', fontReg, align: pw.TextAlign.center),
                        _buildTableCell(fmtCurr.format(sumGross), fontBold, align: pw.TextAlign.right),
                        _buildTableCell(fmtCurr.format(sumCnss), fontBold, align: pw.TextAlign.right),
                        _buildTableCell(fmtCurr.format(sumIrpp), fontBold, align: pw.TextAlign.right),
                        _buildTableCell(fmtCurr.format(sumCss), fontBold, align: pw.TextAlign.right),
                        _buildTableCell(fmtCurr.format(sumAdvances + sumLoans), fontBold, align: pw.TextAlign.right),
                        _buildTableCell(fmtCurr.format(sumNet), fontBold, align: pw.TextAlign.right, color: const PdfColor.fromInt(0xFF047857)),
                        _buildTableCell('—', fontReg, align: pw.TextAlign.center),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Bottom note
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Rapport généré automatiquement par le module Paie & RH - LogiTech Pro.',
                    style: pw.TextStyle(font: fontReg, fontSize: 8, color: const PdfColor.fromInt(0xFF94A3B8)),
                  ),
                  pw.Text(
                    'Page 1/1',
                    style: pw.TextStyle(font: fontReg, fontSize: 8, color: const PdfColor.fromInt(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS FOR PDF
  // ---------------------------------------------------------------------------

  pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font fontReg, {
    bool isBoldVal = false,
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: const PdfColor.fromInt(0xFF64748B))),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: isBoldVal ? fontBold : fontReg,
                fontSize: 9,
                color: valueColor ?? const PdfColor.fromInt(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSalaryTable({
    required Payslip payslip,
    required pw.Font fontReg,
    required pw.Font fontBold,
    required NumberFormat fmtCurr,
  }) {
    final base = payslip.baseSalary;
    final transport = payslip.transportAllowance;
    final primes = payslip.primes;
    final absenceDed = payslip.unpaidAbsenceDeduction;
    final gross = payslip.grossSalary;
    final cnss = payslip.cnssDeduction;
    final taxableNet = (gross - cnss) > 0 ? (gross - cnss) : 0.0;
    final irpp = payslip.taxDeduction;
    final css = payslip.cssDeduction;
    final advances = payslip.advanceSalary;
    final loan = payslip.loanDeduction;
    final otherDed = payslip.otherDeductions;

    final rows = <pw.TableRow>[
      // Table Header
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
        children: [
          _buildTableHeaderCell('Code', fontBold),
          _buildTableHeaderCell('Rubrique / Désignation', fontBold),
          _buildTableHeaderCell('Base', fontBold, align: pw.TextAlign.right),
          _buildTableHeaderCell('Taux', fontBold, align: pw.TextAlign.center),
          _buildTableHeaderCell('Gains (DT)', fontBold, align: pw.TextAlign.right),
          _buildTableHeaderCell('Retenues (DT)', fontBold, align: pw.TextAlign.right),
        ],
      ),

      // 1. Salaire de base
      _buildSalaryTableRow('BASIC', 'Salaire de base', fmtCurr.format(base), '100%', fmtCurr.format(base), '—', fontReg, fontBold),

      // 2. Absence non rémunérée (si présente)
      if (absenceDed > 0)
        _buildSalaryTableRow(
          'ABS',
          'Absence non rémunérée (${payslip.unpaidAbsenceDays.toStringAsFixed(1)} j)',
          fmtCurr.format(base / 22.0),
          '—',
          '—',
          fmtCurr.format(absenceDed),
          fontReg,
          fontBold,
          isDeduction: true,
        ),

      // 3. Indemnité de transport
      if (transport > 0)
        _buildSalaryTableRow('IND_TR', 'Indemnité de transport', fmtCurr.format(transport), 'Fixe', fmtCurr.format(transport), '—', fontReg, fontBold),

      // 4. Primes & indemnités
      if (primes > 0)
        _buildSalaryTableRow('PRIME', 'Primes & Indemnités spécifiques', fmtCurr.format(primes), '—', fmtCurr.format(primes), '—', fontReg, fontBold),

      // 5. CNSS Salariale
      _buildSalaryTableRow('CNSS', 'Cotisation CNSS Salariale', fmtCurr.format(gross), '9.18%', '—', fmtCurr.format(cnss), fontReg, fontBold, isDeduction: true),

      // 6. Retenue IRPP
      if (irpp > 0)
        _buildSalaryTableRow('IRPP', 'Retenue à la source IRPP', fmtCurr.format(taxableNet), 'Barème', '—', fmtCurr.format(irpp), fontReg, fontBold, isDeduction: true),

      // 7. CSS
      if (css > 0)
        _buildSalaryTableRow('CSS', 'Contribution Sociale de Solidarité', fmtCurr.format(taxableNet), '1.00%', '—', fmtCurr.format(css), fontReg, fontBold, isDeduction: true),

      // 8. Avances sur salaire
      if (advances > 0)
        _buildSalaryTableRow('ADV', 'Avance sur salaire déduite', fmtCurr.format(advances), '—', '—', fmtCurr.format(advances), fontReg, fontBold, isDeduction: true),

      // 9. Remboursements de prêt
      if (loan > 0)
        _buildSalaryTableRow('LOAN', 'Remboursement de prêt déduit', fmtCurr.format(loan), '—', '—', fmtCurr.format(loan), fontReg, fontBold, isDeduction: true),

      // 10. Autres retenues
      if (otherDed > 0)
        _buildSalaryTableRow('DED', 'Autres retenues diverses', fmtCurr.format(otherDed), '—', '—', fmtCurr.format(otherDed), fontReg, fontBold, isDeduction: true),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0), // Code
        1: pw.FlexColumnWidth(3.0), // Libellé
        2: pw.FlexColumnWidth(1.4), // Base
        3: pw.FlexColumnWidth(1.0), // Taux
        4: pw.FlexColumnWidth(1.4), // Gains
        5: pw.FlexColumnWidth(1.4), // Retenues
      },
      children: rows,
    );
  }

  pw.TableRow _buildSalaryTableRow(
    String code,
    String desc,
    String base,
    String rate,
    String gains,
    String retenues,
    pw.Font fontReg,
    pw.Font fontBold, {
    bool isDeduction = false,
  }) {
    return pw.TableRow(
      children: [
        _buildTableCell(code, fontBold, color: isDeduction ? const PdfColor.fromInt(0xFFDC2626) : const PdfColor.fromInt(0xFF1E293B)),
        _buildTableCell(desc, fontReg, color: isDeduction ? const PdfColor.fromInt(0xFFB91C1C) : const PdfColor.fromInt(0xFF1E293B)),
        _buildTableCell(base, fontReg, align: pw.TextAlign.right),
        _buildTableCell(rate, fontReg, align: pw.TextAlign.center),
        _buildTableCell(gains, fontReg, align: pw.TextAlign.right),
        _buildTableCell(retenues, fontBold, align: pw.TextAlign.right, color: isDeduction ? const PdfColor.fromInt(0xFFDC2626) : const PdfColor.fromInt(0xFF64748B)),
      ],
    );
  }

  pw.Widget _buildTableHeaderCell(String text, pw.Font fontBold, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: const PdfColor.fromInt(0xFF334155)),
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.5,
          color: color ?? const PdfColor.fromInt(0xFF1E293B),
        ),
      ),
    );
  }

  pw.Widget _buildTotalColumn(String title, String val, pw.Font fontBold, pw.Font fontReg, {bool isNeg = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: const PdfColor.fromInt(0xFF64748B))),
        pw.SizedBox(height: 2),
        pw.Text(
          val,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 10,
            color: isNeg ? const PdfColor.fromInt(0xFFDC2626) : const PdfColor.fromInt(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildKpiCard(String title, String amount, PdfColor color, pw.Font fontBold, pw.Font fontReg) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: fontReg, fontSize: 7.5, color: const PdfColor.fromInt(0xFF64748B))),
            pw.SizedBox(height: 3),
            pw.Text(amount, style: pw.TextStyle(font: fontBold, fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER: CONVERT NUMBER TO FRENCH WORDS
  // ---------------------------------------------------------------------------
  String _convertNumberToFrenchWords(double number) {
    final int dinars = number.floor();
    final int millimes = ((number - dinars) * 1000).round();

    final dinarsStr = _integerToFrenchWords(dinars);
    if (millimes > 0) {
      final millimesStr = _integerToFrenchWords(millimes);
      return '$dinarsStr Dinars et $millimesStr Millimes';
    } else {
      return '$dinarsStr Dinars';
    }
  }

  String _integerToFrenchWords(int n) {
    if (n == 0) return 'zéro';
    if (n < 0) return 'moins ${_integerToFrenchWords(-n)}';

    final units = [
      '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
      'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept',
      'dix-huit', 'dix-neuf'
    ];

    final tens = [
      '', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'soixante-dix',
      'quatre-vingt', 'quatre-vingt-dix'
    ];

    if (n < 20) return units[n];

    if (n < 70) {
      final ten = n ~/ 10;
      final rem = n % 10;
      if (rem == 1) return '${tens[ten]} et un';
      if (rem > 0) return '${tens[ten]}-${units[rem]}';
      return tens[ten];
    }

    if (n < 80) {
      final rem = n - 60;
      if (rem == 11) return 'soixante et onze';
      return 'soixante-${units[rem]}';
    }

    if (n < 100) {
      final rem = n - 80;
      if (rem == 0) return 'quatre-vingts';
      return 'quatre-vingt-${units[rem]}';
    }

    if (n < 200) {
      final rem = n - 100;
      if (rem == 0) return 'cent';
      return 'cent ${_integerToFrenchWords(rem)}';
    }

    if (n < 1000) {
      final hundreds = n ~/ 100;
      final rem = n % 100;
      final hStr = '${units[hundreds]} cent${rem == 0 ? 's' : ''}';
      if (rem == 0) return hStr;
      return '$hStr ${_integerToFrenchWords(rem)}';
    }

    if (n < 2000) {
      final rem = n - 1000;
      if (rem == 0) return 'mille';
      return 'mille ${_integerToFrenchWords(rem)}';
    }

    if (n < 1000000) {
      final thousands = n ~/ 1000;
      final rem = n % 1000;
      final tStr = '${_integerToFrenchWords(thousands)} mille';
      if (rem == 0) return tStr;
      return '$tStr ${_integerToFrenchWords(rem)}';
    }

    final millions = n ~/ 1000000;
    final rem = n % 1000000;
    final mStr = '${_integerToFrenchWords(millions)} million${millions > 1 ? 's' : ''}';
    if (rem == 0) return mStr;
    return '$mStr ${_integerToFrenchWords(rem)}';
  }
}
