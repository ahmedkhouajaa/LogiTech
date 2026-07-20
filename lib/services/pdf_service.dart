import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import '../models/document_wrapper.dart';
import '../models/project.dart'; // Contains CompanySettings
import '../models/document_template.dart';
import '../models/canvas/canvas_element.dart';
import '../utils/helpers.dart';
import '../utils/platform_utils.dart';
import '../database/database_helper.dart';
import 'canvas_pdf_generator.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  Future<Uint8List> generateDocumentBytes(DocumentWrapper document, {DocumentTemplate? template}) async {
    final companySettings = await DatabaseHelper.instance.getCompanySettings();

    // Load template: use provided, or default, or built-in defaults
    template ??= await DatabaseHelper.instance.getDefaultTemplate('invoice');
    final config = template?.config ?? DocumentTemplate.defaultConfig();

    if (config.containsKey('canvas_document')) {
      final jsonStr = config['canvas_document'] as String;
      final canvasDoc = CanvasDocument.fromJson(jsonStr);
      return await CanvasPdfGenerator.generateDocumentBytes(document, canvasDoc);
    }

    final pdf = pw.Document();

    // Extract template colors
    final headerBgColor = PdfColor.fromInt(config['headerBgColor'] as int? ?? 0xFF1a56db);
    final headerTextColor = PdfColor.fromInt(config['headerTextColor'] as int? ?? 0xFFFFFFFF);
    final fontSize = (config['fontSize'] as num?)?.toDouble() ?? 11.0;
    final rowHeight = (config['rowHeight'] as num?)?.toDouble() ?? 8.0;

    // Load fonts
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    
    // Force currency to TND if requested, or use settings if not DZD
    final currency = companySettings.currency == 'DZD' || companySettings.currency.isEmpty ? 'TND' : companySettings.currency;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) {
          return pw.Column(
            children: [
              _buildProfessionalHeader(document, companySettings, headerBgColor, headerTextColor, fontRegular, fontBold),
              pw.SizedBox(height: 20),
            ]
          );
        },
        build: (context) {
          return [
            _buildItemsTable(document, headerBgColor, headerTextColor, config, fontSize, rowHeight),
            pw.SizedBox(height: 20),
            _buildTotals(document, companySettings, config, currency),
            pw.SizedBox(height: 40),
            _buildFooter(companySettings),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<void> generateAndOpenDocument(DocumentWrapper document, {DocumentTemplate? template}) async {
    final bytes = await generateDocumentBytes(document, template: template);
    final fileName = '${document.number}.pdf';
    
    // Save to platform Downloads folder
    final downloadsDir = await _getDownloadsDirectory();
    final file = File('${downloadsDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    
    // Open the generated PDF
    await OpenFilex.open(file.path);
  }

  /// Downloads PDF to the platform's Downloads folder and shows feedback via SnackBar.
  /// Use this from screens that have a BuildContext available.
  Future<void> downloadDocument(BuildContext context, DocumentWrapper document, {DocumentTemplate? template}) async {
    try {
      final bytes = await generateDocumentBytes(document, template: template);
      final fileName = '${document.number}.pdf';
      
      final downloadsDir = await _getDownloadsDirectory();
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Téléchargé avec succès',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    OpenFilex.open(file.path);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Ouvrir'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF282A2D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 5),
            elevation: 4,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Erreur de téléchargement',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.toString(),
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF282A2D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(seconds: 5),
            elevation: 4,
          ),
        );
      }
    }
  }

  /// Returns the platform's public Downloads directory.
  Future<Directory> _getDownloadsDirectory() async {
    if (PlatformUtils.isAndroid) {
      // Android: use the public Downloads directory
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
      // Fallback to external storage
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return extDir;
      return await getApplicationDocumentsDirectory();
    } else if (PlatformUtils.isWindows) {
      // Windows: use USERPROFILE/Downloads
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final dir = Directory('$userProfile\\Downloads');
        if (await dir.exists()) return dir;
      }
      // Fallback to getDownloadsDirectory from path_provider
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir;
      return await getApplicationDocumentsDirectory();
    }
    // Fallback for other platforms
    return await getApplicationDocumentsDirectory();
  }

  Future<void> printDocument(DocumentWrapper document, {DocumentTemplate? template}) async {
    final bytes = await generateDocumentBytes(document, template: template);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${document.documentTitle}_${document.number}.pdf',
    );
  }

  pw.Widget _buildProfessionalHeader(DocumentWrapper document, CompanySettings settings, PdfColor headerBg, PdfColor headerText, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Left side: Company Info
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.name.isNotEmpty ? settings.name : 'Ma Société',
                    style: pw.TextStyle(font: fontBold, fontSize: 28, color: headerBg),
                  ),
                  pw.SizedBox(height: 6),
                  if (settings.address != null && settings.address!.isNotEmpty) pw.Text(settings.address!, style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                  if (settings.city != null && settings.city!.isNotEmpty) pw.Text(settings.city!, style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  if (settings.phone != null && settings.phone!.isNotEmpty) pw.Text('Tel: ${settings.phone}', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                  if (settings.email != null && settings.email!.isNotEmpty) pw.Text('Email: ${settings.email}', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                  if (settings.taxId != null && settings.taxId!.isNotEmpty) pw.Text('NIF: ${settings.taxId}', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                  if (settings.rcNumber != null && settings.rcNumber!.isNotEmpty) pw.Text('RC: ${settings.rcNumber}', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
            ),
            
            // Right side: Document Title and Details
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: headerBg,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(document.documentTitle, style: pw.TextStyle(font: fontBold, fontSize: 26, color: headerText, letterSpacing: 1.2)),
                      pw.SizedBox(height: 4),
                      pw.Text('N° ${document.number}', style: pw.TextStyle(font: font, fontSize: 14, color: headerText)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text('Date: ${formatDate(document.date)}', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.grey800)),
                if (document.dueDate != null)
                  pw.Text('Echéance: ${formatDate(document.dueDate!)}', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey800)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 30),
        // Client Details
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Adressé à :', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text(document.customerName ?? 'Client Inconnu', style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.black)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(DocumentWrapper document, PdfColor headerBg, PdfColor headerText, Map<String, dynamic> config, double fontSize, double rowHeight) {
    final defaultCols = DocumentTemplate.defaultConfig()['tableColumns'] as List;
    final columnsConfig = (config['tableColumns'] as List?) ?? defaultCols;
    
    final activeColumns = columnsConfig.where((c) => c['visible'] == true).toList();
    final headers = activeColumns.map((c) => c['label'] as String).toList();

    final data = document.items.map((item) {
      return activeColumns.map((c) {
        final id = c['id'] as String;
        final type = c['type'] as String?;
        if (type == 'custom') {
          return item.customFields[id] ?? '';
        }
        switch (id) {
          case 'designation': return item.productName;
          case 'quantity': return formatQuantity(item.quantity);
          case 'unitPrice': return formatCurrency(item.unitPrice, symbol: '');
          case 'tva': return formatPercentage(item.tvaRate);
          case 'discount': return item.discountPercent > 0 ? formatPercentage(item.discountPercent) : '-';
          case 'totalHT': return formatCurrency(item.totalHT, symbol: '');
          default: return '';
        }
      }).toList();
    }).toList();

    final tableStyle = config['tableStyle'] as String? ?? 'classique';

    // Build alignments dynamically
    final Map<int, pw.Alignment> alignments = {};
    for (int i = 0; i < activeColumns.length; i++) {
      final id = activeColumns[i]['id'] as String;
      if (id == 'designation') {
        alignments[i] = pw.Alignment.centerLeft;
      } else {
        alignments[i] = pw.Alignment.centerRight;
      }
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: tableStyle == 'minimaliste'
          ? pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5))
          : pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: headerText, fontSize: fontSize),
      headerDecoration: pw.BoxDecoration(color: headerBg),
      cellHeight: rowHeight * 3.78, // mm to pt
      cellAlignments: alignments,
      cellStyle: pw.TextStyle(fontSize: fontSize),
      oddRowDecoration: tableStyle == 'alterne'
          ? pw.BoxDecoration(color: headerBg.shade(0.95))
          : null,
    );
  }

  pw.Widget _buildTotals(DocumentWrapper document, CompanySettings settings, Map<String, dynamic> config, String currency) {
    final totalTTCConfig = config['totalTTC'] as Map<String, dynamic>? ?? {};
    final isBoldTTC = totalTTCConfig['style'] == 'Gras';

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Row(
        children: [
          pw.Spacer(flex: 6),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildTotalRow('Total HT', formatCurrency(document.totalHT, symbol: currency)),
                  _buildTotalRow('Total TVA', formatCurrency(document.totalTva, symbol: currency)),
                  if (document.stampTax > 0)
                    _buildTotalRow('Droit de Timbre', formatCurrency(document.stampTax, symbol: currency)),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.grey400, thickness: 1),
                  pw.SizedBox(height: 4),
                  _buildTotalRow('Total TTC', formatCurrency(document.totalTTC + document.stampTax, symbol: currency), isBold: true, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(String title, String amount, {bool isBold = false, double size = 11}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: size)),
          pw.Text(amount, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: size)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(CompanySettings settings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        pw.Text(
          'Merci de votre confiance!',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        if (settings.bankName != null && settings.bankAccount != null) ...[
          pw.SizedBox(height: 4),
          pw.Text('Reglement par virement bancaire sur le compte:'),
          pw.Text('${settings.bankName} - RIB: ${settings.rib ?? settings.bankAccount}'),
        ]
      ],
    );
  }
}

