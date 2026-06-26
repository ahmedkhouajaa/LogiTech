import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/document_wrapper.dart';
import '../models/project.dart'; // Contains CompanySettings
import '../models/canvas/canvas_element.dart';
import '../utils/helpers.dart';
import '../database/database_helper.dart';

class CanvasPdfGenerator {
  static Future<Uint8List> generateDocumentBytes(DocumentWrapper document, CanvasDocument doc) async {
    final companySettings = await DatabaseHelper.instance.getCompanySettings();
    final pdf = pw.Document();
    
    // 1mm = 2.83465 pt in PDF
    const scale = 2.83465;

    // Check if there's a table
    final tableElIndex = doc.elements.indexWhere((e) => e is CanvasTableElement);
    
    if (tableElIndex == -1) {
      // Single page with all elements placed absolutely
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: doc.elements.where((e) => e.isVisible).map((el) {
                return _translateElement(el, scale, document, companySettings);
              }).toList(),
            );
          },
        ),
      );
    } else {
      final tableEl = doc.elements[tableElIndex] as CanvasTableElement;
      final tableY = tableEl.y;
      final tableHeight = tableEl.height;
      final tableBottom = tableY + tableHeight;

      // Group elements
      final headerElements = doc.elements.where((e) => e.isVisible && e.id != tableEl.id && e.y < tableY).toList();
      final footerElements = doc.elements.where((e) => e.isVisible && e.id != tableEl.id && e.y >= tableY).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.only(
            left: doc.marginLeft * scale,
            right: doc.marginRight * scale,
            top: doc.marginTop * scale,
            bottom: doc.marginBottom * scale,
          ),
          build: (context) {
            final double headerHeightPt = (tableY - doc.marginTop) * scale;
            
            // 1. Header Stack
            final headerWidget = pw.SizedBox(
              width: (doc.pageWidth - doc.marginLeft - doc.marginRight) * scale,
              height: headerHeightPt > 0 ? headerHeightPt : 0,
              child: pw.Stack(
                children: headerElements.map((el) {
                  // Subtract page margins to get coordinate relative to margin box
                  final relEl = el.copyWith(
                    x: el.x - doc.marginLeft,
                    y: el.y - doc.marginTop,
                  );
                  return _translateElement(relEl, scale, document, companySettings);
                }).toList(),
              ),
            );

            // 2. Table
            final tableWidget = _translateTable(tableEl, scale, document, companySettings);

            // 3. Footer Stack
            double maxFooterY = tableBottom;
            for (final el in footerElements) {
              if (el.y + el.height > maxFooterY) {
                maxFooterY = el.y + el.height;
              }
            }
            final double footerHeightPt = (maxFooterY - tableBottom) * scale;

            final footerWidget = pw.SizedBox(
              width: (doc.pageWidth - doc.marginLeft - doc.marginRight) * scale,
              height: footerHeightPt > 0 ? footerHeightPt : 0,
              child: pw.Stack(
                children: footerElements.map((el) {
                  // X relative to margin: el.x - marginLeft
                  // Y relative to table bottom: el.y - tableBottom
                  final relEl = el.copyWith(
                    x: el.x - doc.marginLeft,
                  );
                  return _translateElement(relEl, scale, document, companySettings, offsetY: tableBottom);
                }).toList(),
              ),
            );

            return [
              headerWidget,
              pw.SizedBox(height: 10),
              tableWidget,
              pw.SizedBox(height: 10),
              footerWidget,
            ];
          },
        ),
      );
    }

    return await pdf.save();
  }

  static Future<void> generateAndOpenDocument(DocumentWrapper document, CanvasDocument doc) async {
    final bytes = await generateDocumentBytes(document, doc);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${document.number}.pdf');
    await file.writeAsBytes(bytes);
    
    // Open the PDF using OpenFilex
    await OpenFilex.open(file.path);
  }

  static pw.Positioned _translateElement(
    CanvasElement el,
    double scale,
    DocumentWrapper document,
    CompanySettings company, {
    double offsetY = 0,
  }) {
    if (el is TextElement) return _translateText(el, scale, offsetY: offsetY);
    if (el is ShapeElement) return _translateShape(el, scale, offsetY: offsetY);
    if (el is DividerElement) return _translateDivider(el, scale, offsetY: offsetY);
    if (el is ImageElement) return _translateImage(el, scale, offsetY: offsetY);
    if (el is DynamicFieldElement) {
      return _translateDynamicField(el, scale, document, company, offsetY: offsetY);
    }
    return pw.Positioned(child: pw.SizedBox.shrink());
  }

  static pw.Positioned _translateText(TextElement el, double scale, {double offsetY = 0}) {
    final textFont = _resolveFont(el.fontFamily, isBold: el.isBold, isItalic: el.isItalic);
    final textStyle = pw.TextStyle(
      font: textFont,
      fontSize: el.fontSize * scale / 2.83, // Match preview ratio
      color: PdfColor.fromInt(el.color),
      decoration: el.isUnderline ? pw.TextDecoration.underline : null,
      height: el.lineHeight,
    );

    pw.TextAlign align;
    switch (el.textAlign) {
      case CanvasTextAlign.center:
        align = pw.TextAlign.center;
        break;
      case CanvasTextAlign.right:
        align = pw.TextAlign.right;
        break;
      default:
        align = pw.TextAlign.left;
    }

    return pw.Positioned(
      left: el.x * scale,
      top: (el.y - offsetY) * scale,
      child: pw.SizedBox(
        width: el.width * scale,
        height: el.height * scale,
        child: pw.Text(
          el.text,
          style: textStyle,
          textAlign: align,
        ),
      ),
    );
  }

  static pw.Positioned _translateShape(ShapeElement el, double scale, {double offsetY = 0}) {
    pw.BoxDecoration decoration;
    final fillColor = PdfColor.fromInt(el.fillColor);
    final borderColor = PdfColor.fromInt(el.borderColor);

    switch (el.shapeKind) {
      case ShapeKind.circle:
        decoration = pw.BoxDecoration(
          color: fillColor,
          shape: pw.BoxShape.circle,
          border: el.borderWidth > 0
              ? pw.Border.all(color: borderColor, width: el.borderWidth * scale / 3)
              : null,
        );
        break;
      case ShapeKind.roundedRect:
        decoration = pw.BoxDecoration(
          color: fillColor,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(el.borderRadius * scale / 3)),
          border: el.borderWidth > 0
              ? pw.Border.all(color: borderColor, width: el.borderWidth * scale / 3)
              : null,
        );
        break;
      default:
        decoration = pw.BoxDecoration(
          color: fillColor,
          border: el.borderWidth > 0
              ? pw.Border.all(color: borderColor, width: el.borderWidth * scale / 3)
              : null,
        );
    }

    return pw.Positioned(
      left: el.x * scale,
      top: (el.y - offsetY) * scale,
      child: pw.SizedBox(
        width: el.width * scale,
        height: el.height * scale,
        child: pw.Container(decoration: decoration),
      ),
    );
  }

  static pw.Positioned _translateDivider(DividerElement el, double scale, {double offsetY = 0}) {
    final color = PdfColor.fromInt(el.color);
    pw.Widget line;
    if (el.isVertical) {
      line = pw.Center(
        child: pw.Container(
          width: el.thickness * scale / 2,
          height: double.infinity,
          color: color,
        ),
      );
    } else {
      line = pw.Center(
        child: pw.Container(
          width: double.infinity,
          height: el.thickness * scale / 2,
          color: color,
        ),
      );
    }

    return pw.Positioned(
      left: el.x * scale,
      top: (el.y - offsetY) * scale,
      child: pw.SizedBox(
        width: el.width * scale,
        height: el.height * scale,
        child: line,
      ),
    );
  }

  static pw.Positioned _translateImage(ImageElement el, double scale, {double offsetY = 0}) {
    return pw.Positioned(
      left: el.x * scale,
      top: (el.y - offsetY) * scale,
      child: pw.Container(
        width: el.width * scale,
        height: el.height * scale,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
        child: pw.Center(
          child: pw.Text(
            el.placeholder,
            style: pw.TextStyle(
              fontSize: 8 * scale / 3,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  static pw.Positioned _translateDynamicField(
    DynamicFieldElement el,
    double scale,
    DocumentWrapper document,
    CompanySettings company, {
    double offsetY = 0,
  }) {
    final val = _resolveDynamicValue(el, document, company);
    final textFont = _resolveFont(el.fontFamily, isBold: el.isBold);
    final textScale = scale / 2.83;
    
    pw.TextAlign align;
    switch (el.textAlign) {
      case CanvasTextAlign.center:
        align = pw.TextAlign.center;
        break;
      case CanvasTextAlign.right:
        align = pw.TextAlign.right;
        break;
      default:
        align = pw.TextAlign.left;
    }

    final labelColor = PdfColor.fromInt(el.color);

    return pw.Positioned(
      left: el.x * scale,
      top: (el.y - offsetY) * scale,
      child: pw.SizedBox(
        width: el.width * scale,
        height: el.height * scale,
        child: pw.Column(
          crossAxisAlignment: align == pw.TextAlign.right
              ? pw.CrossAxisAlignment.end
              : align == pw.TextAlign.center
                  ? pw.CrossAxisAlignment.center
                  : pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (el.showLabel && el.label.isNotEmpty)
              pw.Text(
                el.label,
                style: pw.TextStyle(
                  fontSize: (el.fontSize - 1) * textScale,
                  color: PdfColor(labelColor.red, labelColor.green, labelColor.blue, 0.6),
                ),
              ),
            pw.Text(
              val,
              textAlign: align,
              style: pw.TextStyle(
                font: textFont,
                fontSize: el.fontSize * textScale,
                fontWeight: el.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _translateTable(CanvasTableElement el, double scale, DocumentWrapper document, CompanySettings company) {
    final headerBg = PdfColor.fromInt(el.headerBgColor);
    final headerFg = PdfColor.fromInt(el.headerTextColor);
    final borderCol = PdfColor.fromInt(el.borderColor);
    final textScale = scale / 2.83;

    final headers = el.headers;

    final data = document.items.map((item) {
      return List.generate(headers.length, (idx) {
        if (idx == 0) return item.productName;
        if (idx == 1) return formatQuantity(item.quantity);
        if (idx == 2) return formatCurrency(item.unitPrice, symbol: '');
        if (idx == 3) return formatPercentage(item.tvaRate);
        if (idx == 4) return formatCurrency(item.totalHT, symbol: '');
        return '';
      });
    }).toList();

    final Map<int, pw.Alignment> alignments = {};
    for (int i = 0; i < headers.length; i++) {
      if (i == 0) {
        alignments[i] = pw.Alignment.centerLeft;
      } else {
        alignments[i] = pw.Alignment.centerRight;
      }
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: borderCol, width: el.borderWidth * scale / 3),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: headerFg, fontSize: el.headerFontSize * textScale),
      headerDecoration: pw.BoxDecoration(color: headerBg),
      cellHeight: el.cellPadding * scale * 2,
      cellAlignments: alignments,
      cellStyle: pw.TextStyle(fontSize: el.cellFontSize * textScale),
    );
  }

  static String _resolveDynamicValue(DynamicFieldElement el, DocumentWrapper document, CompanySettings company) {
    final currency = company.currency == 'DZD' || company.currency.isEmpty ? 'TND' : company.currency;
    switch (el.fieldType) {
      case DynamicFieldType.companyName:
        return company.name;
      case DynamicFieldType.companyAddress:
        return [company.address, company.city].where((s) => s != null && s.isNotEmpty).join(', ');
      case DynamicFieldType.companyPhone:
        return company.phone ?? '';
      case DynamicFieldType.companyEmail:
        return company.email ?? '';
      case DynamicFieldType.companyVat:
        return company.taxId ?? '';
      case DynamicFieldType.clientName:
        return document.customerName ?? '';
      case DynamicFieldType.clientAddress:
        return '';
      case DynamicFieldType.clientPhone:
        return '';
      case DynamicFieldType.clientEmail:
        return '';
      case DynamicFieldType.invoiceNumber:
        return document.number;
      case DynamicFieldType.invoiceDate:
        return _formatDate(document.date);
      case DynamicFieldType.invoiceDueDate:
        return document.dueDate != null ? _formatDate(document.dueDate!) : '';
      case DynamicFieldType.totalHT:
        return formatCurrency(document.totalHT, symbol: currency);
      case DynamicFieldType.totalTVA:
        return formatCurrency(document.totalTva, symbol: currency);
      case DynamicFieldType.totalTTC:
        return formatCurrency(document.totalTTC + document.stampTax, symbol: currency);
      case DynamicFieldType.currency:
        return currency;
      case DynamicFieldType.notes:
        return document.notes ?? '';
      case DynamicFieldType.conditions:
        return document.conditionsGenerales ?? '';
      case DynamicFieldType.custom:
        return el.customKey ?? '';
    }
  }

  static String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  static pw.Font _resolveFont(String family, {bool isBold = false, bool isItalic = false}) {
    final fam = family.toLowerCase();
    if (fam.contains('times') || fam.contains('serif')) {
      if (isBold && isItalic) return pw.Font.timesBoldItalic();
      if (isBold) return pw.Font.timesBold();
      if (isItalic) return pw.Font.timesItalic();
      return pw.Font.times();
    } else if (fam.contains('courier') || fam.contains('mono')) {
      if (isBold && isItalic) return pw.Font.courierBoldOblique();
      if (isBold) return pw.Font.courierBold();
      if (isItalic) return pw.Font.courierOblique();
      return pw.Font.courier();
    } else {
      if (isBold && isItalic) return pw.Font.helveticaBoldOblique();
      if (isBold) return pw.Font.helveticaBold();
      if (isItalic) return pw.Font.helveticaOblique();
      return pw.Font.helvetica();
    }
  }
}
