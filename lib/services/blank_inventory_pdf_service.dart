import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';

class BlankInventoryPdfService {
  static final BlankInventoryPdfService instance = BlankInventoryPdfService._();
  BlankInventoryPdfService._();

  Future<Uint8List> generateBlankInventoryPdf({
    required String warehouseName,
    required List<Product> products,
    required String reference,
    DateTime? date,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final inventoryDate = date ?? DateTime.now();
    final creationDateStr = DateFormat('dd/MM/yyyy').format(inventoryDate);

    // Group products by category/family
    final Map<String, List<Product>> groupedProducts = {};
    for (final product in products) {
      final family = (product.category != null && product.category!.trim().isNotEmpty)
          ? product.category!.trim()
          : 'Famille par défaut';
      groupedProducts.putIfAbsent(family, () => []).add(product);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (context) {
          final List<pw.Widget> content = [];

          // Top divider
          content.add(pw.Container(height: 1, color: PdfColor.fromHex('#E2E8F0')));
          content.add(pw.SizedBox(height: 14));

          // Document Title
          content.add(
            pw.Text(
              "Fiche d'inventaire — Vierge",
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 20,
                color: PdfColor.fromHex('#0F172A'),
              ),
            ),
          );
          content.add(pw.SizedBox(height: 4));

          // Reference line
          content.add(
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Référence : ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10.5,
                      color: PdfColor.fromHex('#475569'),
                    ),
                  ),
                  pw.TextSpan(
                    text: reference,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10.5,
                      color: PdfColor.fromHex('#334155'),
                    ),
                  ),
                ],
              ),
            ),
          );
          content.add(pw.SizedBox(height: 8));

          // Status Badge: En attente d'inventaire
          content.add(
            pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FFFBEB'),
                    border: pw.Border.all(color: PdfColor.fromHex('#F59E0B'), width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Text(
                    "En attente d'inventaire",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9,
                      color: PdfColor.fromHex('#B45309'),
                    ),
                  ),
                ),
              ],
            ),
          );
          content.add(pw.SizedBox(height: 14));

          // Magasin & Date Box
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Magasin : $warehouseName',
                        style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColor.fromHex('#1E293B')),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Date de création : $creationDateStr',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#475569')),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Date d'inventaire : _____ / _____ / _________",
                        style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#475569')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          content.add(pw.SizedBox(height: 14));

          // Table per family
          groupedProducts.forEach((family, items) {
            // Family Header banner
            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 6),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(width: 4, height: 16, color: PdfColor.fromHex('#1A56DB')),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      family,
                      style: pw.TextStyle(font: fontBold, fontSize: 11.5, color: PdfColor.fromHex('#0F172A')),
                    ),
                  ],
                ),
              ),
            );

            // Table of items
            content.add(
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#CCCCCC'),
                  width: 0.8,
                ),
                columnWidths: const {
                  0: pw.FixedColumnWidth(34),   // #
                  1: pw.FixedColumnWidth(95),   // Reference
                  2: pw.FlexColumnWidth(3),     // Designation
                  3: pw.FixedColumnWidth(65),   // Unit
                  4: pw.FixedColumnWidth(110),  // Qte comptee
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#D4D4D8'),
                    ),
                    children: [
                      _buildHeaderCell('#', fontBold, center: true),
                      _buildHeaderCell('Référence', fontBold),
                      _buildHeaderCell('Désignation', fontBold),
                      _buildHeaderCell('Unité', fontBold, center: true),
                      _buildHeaderCell('Qté comptée', fontBold, center: true),
                    ],
                  ),
                  // Table Data Rows
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final p = entry.value;
                    final ref = (p.reference != null && p.reference!.trim().isNotEmpty)
                        ? p.reference!.trim()
                        : p.code.trim();
                    final unit = (p.unit.trim().isNotEmpty) ? p.unit.trim() : 'piece';

                    return pw.TableRow(
                      verticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8),
                          child: pw.Text(
                            '$idx',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#1F2937')),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: pw.Text(
                            ref,
                            style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#1F2937')),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: pw.Text(
                            p.name,
                            style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#000000')),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8),
                          child: pw.Text(
                            unit,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#1F2937')),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: pw.Center(
                            child: pw.Container(
                              width: 90,
                              height: 26,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                border: pw.Border.all(color: PdfColor.fromHex('#9CA3AF'), width: 1),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );

            content.add(pw.SizedBox(height: 12));
          });

          // Signature Block
          content.add(pw.SizedBox(height: 32));
          content.add(
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Compté par',
                    style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColor.fromHex('#1E293B')),
                  ),
                  pw.SizedBox(height: 26),
                  pw.Container(width: 220, height: 0.8, color: PdfColor.fromHex('#475569')),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Nom & Signature',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColor.fromHex('#64748B')),
                  ),
                ],
              ),
            ),
          );

          return content;
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildHeaderCell(String text, pw.Font fontBold, {bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 10,
          color: PdfColor.fromHex('#111827'),
        ),
      ),
    );
  }
}
