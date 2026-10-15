import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cnss_declaration.dart';
import '../models/project.dart'; // CompanySettings
import '../database/database_helper.dart';

/// Service officiel de génération et partage de la Déclaration Trimestrielle CNSS (Image 3)
/// Conforme à la République Tunisienne / Caisse Nationale de Sécurité Sociale
class CnssPdfService {
  static final CnssPdfService instance = CnssPdfService._();
  CnssPdfService._();

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

  /// Génère le fichier PDF officiel (Image 3)
  Future<Uint8List> generateDeclarationPdf(
    CnssDeclaration declaration, {
    CompanySettings? companySettings,
  }) async {
    companySettings ??= await DatabaseHelper.instance.getCompanySettings();
    final (fontReg, fontBold) = await _getFonts();

    final doc = pw.Document(
      title: 'Declaration_CNSS_${declaration.reference.replaceAll(' ', '_')}',
      author: declaration.companyName,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
        build: (pw.Context context) {
          return _buildDeclarationDocument(
            declaration: declaration,
            company: companySettings!,
            fontReg: fontReg,
            fontBold: fontBold,
          );
        },
      ),
    );

    return doc.save();
  }

  /// Aperçu et actions complètes (Télécharger, Voir, Email, WhatsApp)
  Future<void> showPreviewDialog(BuildContext context, CnssDeclaration declaration) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 780),
          child: _CnssPreviewModal(declaration: declaration),
        ),
      ),
    );
  }

  /// Imprime directement le document
  Future<void> printDeclaration(BuildContext context, CnssDeclaration declaration) async {
    try {
      final bytes = await generateDeclarationPdf(declaration);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Declaration_CNSS_${declaration.quarter}_${declaration.year}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'impression : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Télécharge / Sauvegarde le PDF
  Future<void> downloadPdf(BuildContext context, CnssDeclaration declaration) async {
    try {
      final bytes = await generateDeclarationPdf(declaration);
      final filename = 'Declaration_CNSS_T${declaration.quarter}_${declaration.year}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Envoie par Email
  Future<void> shareViaEmail(BuildContext context, CnssDeclaration declaration) async {
    try {
      final bytes = await generateDeclarationPdf(declaration);
      final filename = 'Declaration_CNSS_T${declaration.quarter}_${declaration.year}.pdf';
      final subject = 'Déclaration Trimestrielle CNSS T${declaration.quarter} ${declaration.year} - ${declaration.companyName}';
      final body = 'Bonjour,\n\nVeuillez trouver ci-joint la Déclaration Trimestrielle des Salariés et des Salaires pour le ${declaration.quarterLabel}.\n\nTotal déclaré : ${declaration.formattedTotal(declaration.totalQuarter)}\n\nCordialement,\n${declaration.companyName}';

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        return;
      }

      final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: filename);
      await Share.shareXFiles(
        [xFile],
        subject: subject,
        text: body,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi par email : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Envoie par WhatsApp
  Future<void> shareViaWhatsApp(BuildContext context, CnssDeclaration declaration) async {
    try {
      final bytes = await generateDeclarationPdf(declaration);
      final filename = 'Declaration_CNSS_T${declaration.quarter}_${declaration.year}.pdf';
      final message = '📄 *Déclaration Trimestrielle CNSS T${declaration.quarter} ${declaration.year}*\n'
          '🏢 *Entreprise :* ${declaration.companyName}\n'
          '💰 *Total Déclaré :* ${declaration.formattedTotal(declaration.totalQuarter)}\n'
          '📅 *Date :* ${DateFormat('dd/MM/yyyy').format(declaration.declarationDate)}';

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        return;
      }

      final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: filename);
      await Share.shareXFiles(
        [xFile],
        text: message,
      );
    } catch (e) {
      // Fallback sur url_launcher WhatsApp Web
      final whatsappUrl = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent('Déclaration Trimestrielle CNSS T${declaration.quarter} ${declaration.year} - Total: ${declaration.formattedTotal(declaration.totalQuarter)}')}',
      );
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage WhatsApp : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CONSTRUCTION DE LA PAGE PDF CONFORME À L'IMAGE 3
  // ---------------------------------------------------------------------------
  pw.Widget _buildDeclarationDocument({
    required CnssDeclaration declaration,
    required CompanySettings company,
    required pw.Font fontReg,
    required pw.Font fontBold,
  }) {
    final currency = declaration.currency;
    final totalQuarter = declaration.totalQuarter;
    final totalInWords = _numberToFrenchWords(totalQuarter, currency: currency);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. EN-TÊTE OFFICIEL CNSS TUNISIE (Image 3)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Colonne gauche officielle
            pw.Container(
              width: 175,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('REPUBLIQUE TUNISIENNE', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                  pw.Text('MINISTERE DES AFFAIRES SOCIALES', style: pw.TextStyle(font: fontBold, fontSize: 6.5)),
                  pw.Text('CAISSE NATIONALE DE SECURITE SOCIALE', style: pw.TextStyle(font: fontBold, fontSize: 6.5)),
                  pw.Text('49, Av. TAIEB MHIRI - TUNIS - Tel: 71.796.744', style: pw.TextStyle(font: fontReg, fontSize: 5.8)),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            // Titre central
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'DECLARATION TRIMESTRIELLE DES SALARIES ET DES SALAIRES',
                    style: pw.TextStyle(font: fontBold, fontSize: 13, letterSpacing: 0.5),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'doit être remise à la Caisse sous peine de pénalités dans les 15 premiers jours qui suivent le trimestre',
                    style: pw.TextStyle(font: fontReg, fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 8),

        // 2. CADRES D'IDENTIFICATION DE L'EMPLOYEUR (Image 3)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // CADRE 1 (Gauche) : N° Employeur, BR, Page, Trimestre, Année
            pw.Container(
              width: 180,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                    ),
                    child: pw.Text(
                      'N° Employeur : ${declaration.employerNumber}',
                      style: pw.TextStyle(font: fontBold, fontSize: 8),
                    ),
                  ),
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: pw.Text('BR :', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                          ),
                        ),
                        pw.Container(width: 0.8, height: 18, color: PdfColors.black),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: pw.Text('Page N°: 1', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: pw.Text('Trimestre: ${declaration.quarter}', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                        ),
                      ),
                      pw.Container(width: 0.8, height: 18, color: PdfColors.black),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: pw.Text('Année: ${declaration.year}', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 10),

            // CADRE 2 (Milieu) : Code d'exploitation & NIF
            pw.Container(
              width: 155,
              height: 56,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Code d\'exploitation', style: pw.TextStyle(font: fontBold, fontSize: 7)),
                        pw.Text(declaration.exploitationCode, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                      'Numéro d\'identification fiscale : ${declaration.taxIdNumber.isNotEmpty ? declaration.taxIdNumber : (company.taxId ?? '')}',
                      style: pw.TextStyle(font: fontReg, fontSize: 6.5),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 10),

            // CADRE 3 (Droite) : Nom et adresse de l'employeur
            pw.Expanded(
              child: pw.Container(
                height: 56,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                      ),
                      child: pw.Text(
                        'NOM ET ADRESSE DE L\'EMPLOYEUR',
                        style: pw.TextStyle(font: fontBold, fontSize: 7),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(declaration.companyName, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                          pw.SizedBox(height: 1),
                          pw.Text(declaration.companyAddress, style: pw.TextStyle(font: fontReg, fontSize: 6.8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 8),

        // 3. TABLEAU DES SALARIÉS ET DES SALAIRES (Image 3)
        pw.Expanded(
          child: _buildSalariesTable(
            declaration: declaration,
            fontReg: fontReg,
            fontBold: fontBold,
          ),
        ),

        pw.SizedBox(height: 6),

        // 4. BAS DE PAGE / CERTIFICATION ET TOTAUX (Image 3)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Bloc de certification gauche
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Certifié sincère et conforme à nos documents comptables et arrêté à la somme de : (en toutes lettres) (2)',
                    style: pw.TextStyle(font: fontBold, fontSize: 6.8),
                  ),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.6)),
                    ),
                    child: pw.Text(
                      totalInWords,
                      style: pw.TextStyle(font: fontBold, fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('(1) L\'identité doit être conforme à la carte d\'assuré ou à l\'extrait de naissance.',
                      style: pw.TextStyle(font: fontReg, fontSize: 5.8)),
                  pw.Text('(2) L\'arrêté doit correspondre au total des salaires déclarés pendant le trimestre (à indiquer sur la dernière page).',
                      style: pw.TextStyle(font: fontReg, fontSize: 5.8)),
                ],
              ),
            ),

            pw.SizedBox(width: 14),

            // Tableau des totaux à droite (Total / Total à reporter)
            pw.Container(
              width: 160,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
              child: pw.Column(
                children: [
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(3.5),
                            child: pw.Text('Total', style: pw.TextStyle(font: fontBold, fontSize: 7.5), textAlign: pw.TextAlign.right),
                          ),
                        ),
                        pw.Container(width: 0.8, height: 18, color: PdfColors.black),
                        pw.Expanded(
                          flex: 6,
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(3.5),
                            child: pw.Text(
                              declaration.formattedTotal(totalQuarter),
                              style: pw.TextStyle(font: fontBold, fontSize: 7.5),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(3.5),
                          child: pw.Text('Total à reporter', style: pw.TextStyle(font: fontBold, fontSize: 7.5), textAlign: pw.TextAlign.right),
                        ),
                      ),
                      pw.Container(width: 0.8, height: 18, color: PdfColors.black),
                      pw.Expanded(
                        flex: 6,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(3.5),
                          child: pw.Text(
                            declaration.formattedTotal(totalQuarter),
                            style: pw.TextStyle(font: fontBold, fontSize: 7.5),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 6),

        // Signature et cachet de l'entreprise
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Fait à ...................................... le .................................... 20..........',
                  style: pw.TextStyle(font: fontReg, fontSize: 6.8),
                ),
                pw.SizedBox(height: 1),
                pw.Text('Cachet et signature de l\'Entreprise', style: pw.TextStyle(font: fontBold, fontSize: 7)),
                pw.Text('(sur toutes les pages)', style: pw.TextStyle(font: fontReg, fontSize: 5.8)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSalariesTable({
    required CnssDeclaration declaration,
    required pw.Font fontReg,
    required pw.Font fontBold,
  }) {
    final currency = declaration.currency;
    final lines = declaration.lines;

    // Colonnes :
    // 0: N° Ordre (~35)
    // 1: Numéro CNSS (~130)
    // 2: Identité de l'employé (~160)
    // 3: N° chez l'employeur (~45)
    // 4: Catégorie prof (~55)
    // 5: 1er mois (~80)
    // 6: 2ème mois (~80)
    // 7: 3ème mois (~80)
    // 8: Total (~85)

    final f = NumberFormat('#,##0.00', 'fr_FR');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
      columnWidths: const {
        0: pw.FixedColumnWidth(34),
        1: pw.FixedColumnWidth(130),
        2: pw.FlexColumnWidth(2.2),
        3: pw.FixedColumnWidth(48),
        4: pw.FixedColumnWidth(55),
        5: pw.FixedColumnWidth(76),
        6: pw.FixedColumnWidth(76),
        7: pw.FixedColumnWidth(76),
        8: pw.FixedColumnWidth(82),
      },
      children: [
        // En-têtes du tableau (Exactement Image 3)
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            _th('N°\nOrdre', fontBold),
            _th('Numéro CNSS', fontBold),
            _th('Identité de l\'employé', fontBold),
            _th('N° chez\nl\'Employeur', fontBold),
            _th('Catégorie\nprofessionnelle', fontBold),
            _th('SALAIRE MENSUEL\n1er mois', fontBold),
            _th('SALAIRE MENSUEL\n2ème mois', fontBold),
            _th('SALAIRE MENSUEL\n3ème mois', fontBold),
            _th('Total', fontBold),
          ],
        ),

        // Lignes de données
        ...lines.map((l) {
          return pw.TableRow(
            children: [
              _td(l.lineNumber.toString(), fontReg, align: pw.TextAlign.center),
              _td(l.cnssNumber, fontReg, align: pw.TextAlign.left),
              _td(l.employeeName, fontBold, align: pw.TextAlign.left),
              _td(l.employerRegistrationNumber, fontReg, align: pw.TextAlign.center),
              _td(l.professionalCategory, fontReg, align: pw.TextAlign.center),
              _td('${f.format(l.grossMonth1)} $currency', fontReg, align: pw.TextAlign.right),
              _td('${f.format(l.grossMonth2)} $currency', fontReg, align: pw.TextAlign.right),
              _td('${f.format(l.grossMonth3)} $currency', fontReg, align: pw.TextAlign.right),
              _td('${f.format(l.total)} $currency', fontBold, align: pw.TextAlign.right),
            ],
          );
        }),

        // Compléter avec des lignes vides esthétiques comme sur le formulaire officiel
        if (lines.length < 8)
          ...List.generate(8 - lines.length, (index) {
            return pw.TableRow(
              children: [
                _td((lines.length + index + 1).toString(), fontReg, align: pw.TextAlign.center, color: PdfColors.grey400),
                _td('', fontReg),
                _td('', fontReg),
                _td('', fontReg),
                _td('', fontReg),
                _td('', fontReg),
                _td('', fontReg),
                _td('', fontReg),
                _td('', fontReg),
              ],
            );
          }),
      ],
    );
  }

  pw.Widget _th(String title, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      alignment: pw.Alignment.center,
      child: pw.Text(
        title,
        style: pw.TextStyle(font: fontBold, fontSize: 6.8),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _td(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : (align == pw.TextAlign.center ? pw.Alignment.center : pw.Alignment.centerLeft),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 6.5, color: color ?? PdfColors.black),
        textAlign: align,
        maxLines: 1,
      ),
    );
  }

  /// Conversion de montants en toutes lettres françaises
  String _numberToFrenchWords(double number, {String currency = '\$'}) {
    final intPart = number.truncate();
    final decPart = ((number - intPart) * 100).round();

    String intWords = _intToFrench(intPart);
    String currencyLabel = currency == 'DT' ? 'Dinars' : (currency == '€' ? 'Euros' : 'Dollars');
    String centLabel = currency == 'DT' ? 'millimes' : 'cents';

    if (decPart > 0) {
      return '$intWords $currencyLabel et ${_intToFrench(decPart)} $centLabel';
    } else {
      return '$intWords $currencyLabel';
    }
  }

  String _intToFrench(int n) {
    if (n == 0) return 'zéro';
    if (n < 0) return 'moins ${_intToFrench(-n)}';

    final units = [
      '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
      'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf'
    ];
    final tens = [
      '', 'dix', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'soixante-dix', 'quatre-vingts', 'quatre-vingt-dix'
    ];

    if (n < 20) return units[n];
    if (n < 100) {
      final t = n ~/ 10;
      final rem = n % 10;
      if (t == 7) return 'soixante-${units[10 + rem]}';
      if (t == 9) return 'quatre-vingt-${units[10 + rem]}';
      if (rem == 0) return tens[t];
      if (rem == 1 && t < 8) return '${tens[t]} et un';
      return '${tens[t]}-${units[rem]}';
    }
    if (n < 1000) {
      final h = n ~/ 100;
      final rem = n % 100;
      final hStr = h == 1 ? 'cent' : '${units[h]} cent${rem == 0 ? 's' : ''}';
      if (rem == 0) return hStr;
      return '$hStr ${_intToFrench(rem)}';
    }
    if (n < 1000000) {
      final th = n ~/ 1000;
      final rem = n % 1000;
      final thStr = th == 1 ? 'mille' : '${_intToFrench(th)} mille';
      if (rem == 0) return thStr;
      return '$thStr ${_intToFrench(rem)}';
    }
    return n.toString();
  }
}

/// Modal plein écran de prévisualisation PDF avec boutons d'actions (Télécharger, Imprimer, Email, WhatsApp)
class _CnssPreviewModal extends StatelessWidget {
  final CnssDeclaration declaration;
  const _CnssPreviewModal({required this.declaration});

  static const Color _odooPurple = Color(0xFF1A56DB);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12) as EdgeInsets,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Déclaration Trimestrielle CNSS - ${declaration.quarterLabel}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Action Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFF8FAFC),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              // Télécharger
              ElevatedButton.icon(
                onPressed: () => CnssPdfService.instance.downloadPdf(context, declaration),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Télécharger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),

              // Imprimer
              ElevatedButton.icon(
                onPressed: () => CnssPdfService.instance.printDeclaration(context, declaration),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Imprimer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _odooPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),

              // Envoyer par Email
              ElevatedButton.icon(
                onPressed: () => CnssPdfService.instance.shareViaEmail(context, declaration),
                icon: const Icon(Icons.email_outlined, size: 16),
                label: const Text('Envoyer Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF475569),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),

              // Envoyer par WhatsApp
              ElevatedButton.icon(
                onPressed: () => CnssPdfService.instance.shareViaWhatsApp(context, declaration),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // PDF Preview Widget
        Expanded(
          child: PdfPreview(
            build: (format) => CnssPdfService.instance.generateDeclarationPdf(declaration),
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            initialPageFormat: PdfPageFormat.a4.landscape,
            loadingWidget: const Center(
              child: CircularProgressIndicator(color: _odooPurple),
            ),
          ),
        ),
      ],
    );
  }
}
