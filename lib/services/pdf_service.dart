import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; // Will need to add to pubspec
import '../models/invoice.dart';
import '../models/project.dart'; // Contains CompanySettings
import '../utils/helpers.dart';
import '../database/database_helper.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  Future<void> generateAndOpenInvoice(Invoice invoice) async {
    final companySettings = await DatabaseHelper.instance.getCompanySettings();
    final pdf = pw.Document();

    // Load fonts if needed
    // final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    // final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            _buildHeader(invoice, companySettings),
            pw.SizedBox(height: 20),
            _buildInvoiceInfo(invoice),
            pw.SizedBox(height: 20),
            _buildItemsTable(invoice),
            pw.SizedBox(height: 20),
            _buildTotals(invoice, companySettings),
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

  pw.Widget _buildHeader(Invoice invoice, CompanySettings settings) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(settings.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            if (settings.address != null) pw.Text(settings.address!),
            if (settings.city != null) pw.Text(settings.city!),
            if (settings.phone != null) pw.Text('Tel: ${settings.phone}'),
            if (settings.email != null) pw.Text('Email: ${settings.email}'),
            if (settings.taxId != null) pw.Text('NIF: ${settings.taxId}'),
            if (settings.rcNumber != null) pw.Text('RC: ${settings.rcNumber}'),
            if (settings.nis != null) pw.Text('NIS: ${settings.nis}'),
            if (settings.ai != null) pw.Text('AI: ${settings.ai}'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('FACTURE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Text('N° ${invoice.number}', style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 4),
            pw.Text('Date: ${formatDate(invoice.date)}'),
            pw.Text('Echeance: ${formatDate(invoice.dueDate)}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceInfo(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Client:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(invoice.customerName ?? 'Client Inconnu'),
              // Add more customer details here when fetched
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(Invoice invoice) {
    final headers = ['Designation', 'Qte', 'Prix Unitaire', 'TVA', 'Remise', 'Total HT'];
    final data = invoice.items.map((item) {
      return [
        item.productName ?? 'Produit Inconnu',
        formatQuantity(item.quantity),
        formatCurrency(item.unitPrice, symbol: ''),
        formatPercentage(item.tvaRate),
        item.discountPercent > 0 ? formatPercentage(item.discountPercent) : '-',
        formatCurrency(item.computedTotalHT, symbol: ''),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildTotals(Invoice invoice, CompanySettings settings) {
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
                _buildTotalRow('Total TTC', formatCurrency(invoice.totalTTC + invoice.stampTax, symbol: settings.currency), isBold: true),
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
