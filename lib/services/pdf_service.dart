import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; // Will need to add to pubspec
import '../models/invoice.dart';
import '../models/project.dart'; // Contains CompanySettings
import '../models/document_template.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  Future<void> generateAndOpenInvoice(Invoice invoice, {DocumentTemplate? template}) async {
    final companySettings = await DatabaseHelper.instance.getCompanySettings();

    // Load template: use provided, or default, or built-in defaults
    template ??= await DatabaseHelper.instance.getDefaultTemplate('invoice');
    final config = template?.config ?? DocumentTemplate.defaultConfig();

    final pdf = pw.Document();

    // Extract template colors
    final headerBgColor = PdfColor.fromInt(config['headerBgColor'] as int? ?? 0xFF1a56db);
    final headerTextColor = PdfColor.fromInt(config['headerTextColor'] as int? ?? 0xFFFFFFFF);
    final fontSize = (config['fontSize'] as num?)?.toDouble() ?? 10.0;
    final rowHeight = (config['rowHeight'] as num?)?.toDouble() ?? 8.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
          return [
            _buildAbsoluteHeaderStack(invoice, companySettings, config, headerBgColor, headerTextColor),
            pw.SizedBox(height: 20),
            _buildItemsTable(invoice, headerBgColor, headerTextColor, config, fontSize, rowHeight),
            pw.SizedBox(height: 20),
            _buildTotals(invoice, companySettings, config),
            pw.SizedBox(height: 40),
            _buildFooter(companySettings),
          ];
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${invoice.number}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    // Open the generated PDF (requires open_filex package)
    // await OpenFilex.open(file.path);
  }

  pw.Widget _buildAbsoluteHeaderStack(Invoice invoice, CompanySettings settings, Map<String, dynamic> config, PdfColor headerBg, PdfColor headerText) {
    double toPt(double mm) => mm * 2.83465;
    
    // The margin in MultiPage is 32. So we need to offset coordinates.
    // X=0 in config means left edge of page. But Stack is inside the margin.
    // So Stack's 0 is at page's 32pt (11.3mm). 
    // Left = toPt(X) - 32.
    final margin = 32.0;

    final logoCfg = config['logo'] as Map<String, dynamic>? ?? {};
    final compNameCfg = config['companyName'] as Map<String, dynamic>? ?? {};
    final compDetCfg = config['companyDetails'] as Map<String, dynamic>? ?? {};
    final titleCfg = config['documentTitle'] as Map<String, dynamic>? ?? {};
    final clientCfg = config['clientDetails'] as Map<String, dynamic>? ?? {};

    return pw.SizedBox(
      height: toPt(85) - margin, // Reserve space, adjusting for top margin
      child: pw.Stack(
        children: [
          // Logo
          pw.Positioned(
            left: toPt((logoCfg['positionX'] as num?)?.toDouble() ?? 15) - margin,
            top: toPt((logoCfg['positionY'] as num?)?.toDouble() ?? 15) - margin,
            child: pw.Container(
              width: toPt((logoCfg['width'] as num?)?.toDouble() ?? 20),
              height: toPt((logoCfg['height'] as num?)?.toDouble() ?? 15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              ),
              child: pw.Center(child: pw.Text('Logo', style: const pw.TextStyle(color: PdfColors.grey600))),
            ),
          ),
          
          // Company Name
          pw.Positioned(
            left: toPt((compNameCfg['positionX'] as num?)?.toDouble() ?? 40) - margin,
            top: toPt((compNameCfg['positionY'] as num?)?.toDouble() ?? 15) - margin,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColor(headerBg.red, headerBg.green, headerBg.blue, 0.1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Text(
                settings.name,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: headerBg),
              ),
            ),
          ),

          // Company Details
          pw.Positioned(
            left: toPt((compDetCfg['positionX'] as num?)?.toDouble() ?? 40) - margin,
            top: toPt((compDetCfg['positionY'] as num?)?.toDouble() ?? 22) - margin,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (settings.address != null) pw.Text(settings.address!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (settings.city != null) pw.Text(settings.city!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (settings.phone != null) pw.Text('Tel: ${settings.phone}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (settings.email != null) pw.Text('Email: ${settings.email}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (settings.taxId != null) pw.Text('NIF: ${settings.taxId}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                if (settings.rcNumber != null) pw.Text('RC: ${settings.rcNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),

          // Document Title
          pw.Positioned(
            left: toPt((titleCfg['positionX'] as num?)?.toDouble() ?? 140) - margin,
            top: toPt((titleCfg['positionY'] as num?)?.toDouble() ?? 15) - margin,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: headerBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('FACTURE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: headerText)),
                  pw.SizedBox(height: 2),
                  pw.Text('N° ${invoice.number}', style: pw.TextStyle(fontSize: 10, color: headerText)),
                ],
              ),
            ),
          ),

          // Client Details
          pw.Positioned(
            left: toPt((clientCfg['positionX'] as num?)?.toDouble() ?? 15) - margin,
            top: toPt((clientCfg['positionY'] as num?)?.toDouble() ?? 45) - margin,
            child: pw.Container(
              width: toPt((clientCfg['width'] as num?)?.toDouble() ?? 180),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Client:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(invoice.customerName ?? 'Client Inconnu', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(Invoice invoice, PdfColor headerBg, PdfColor headerText, Map<String, dynamic> config, double fontSize, double rowHeight) {
    final defaultCols = DocumentTemplate.defaultConfig()['tableColumns'] as List;
    final columnsConfig = (config['tableColumns'] as List?) ?? defaultCols;
    
    final activeColumns = columnsConfig.where((c) => c['visible'] == true).toList();
    final headers = activeColumns.map((c) => c['label'] as String).toList();

    final data = invoice.items.map((item) {
      return activeColumns.map((c) {
        final id = c['id'] as String;
        final type = c['type'] as String?;
        if (type == 'custom') {
          return item.customFields[id] ?? '';
        }
        switch (id) {
          case 'designation': return item.productName ?? 'Produit Inconnu';
          case 'quantity': return formatQuantity(item.quantity);
          case 'unitPrice': return formatCurrency(item.unitPrice, symbol: '');
          case 'tva': return formatPercentage(item.tvaRate);
          case 'discount': return item.discountPercent > 0 ? formatPercentage(item.discountPercent) : '-';
          case 'totalHT': return formatCurrency(item.computedTotalHT, symbol: '');
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

  pw.Widget _buildTotals(Invoice invoice, CompanySettings settings, Map<String, dynamic> config) {
    final totalsConfig = config['totals'] as Map<String, dynamic>? ?? {};
    final totalTTCConfig = config['totalTTC'] as Map<String, dynamic>? ?? {};
    final isBoldTTC = totalTTCConfig['style'] == 'Gras';

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Row(
        children: [
          pw.Spacer(flex: 6),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildTotalRow('Total HT', formatCurrency(invoice.totalHT, symbol: settings.currency)),
                _buildTotalRow('Total TVA', formatCurrency(invoice.totalTva, symbol: settings.currency)),
                if (invoice.stampTax > 0)
                  _buildTotalRow('Droit de Timbre', formatCurrency(invoice.stampTax, symbol: settings.currency)),
                pw.Divider(color: PdfColors.grey400),
                _buildTotalRow('Total TTC', formatCurrency(invoice.totalTTC + invoice.stampTax, symbol: settings.currency), isBold: isBoldTTC),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(String title, String amount, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null)),
          pw.Text(amount, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null)),
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
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
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

