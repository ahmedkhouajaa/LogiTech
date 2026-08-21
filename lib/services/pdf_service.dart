import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/document_wrapper.dart';
import '../models/project.dart'; // Contains CompanySettings
import '../models/document_template.dart';
import '../models/canvas/canvas_element.dart';
import '../utils/helpers.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
import 'canvas_pdf_generator.dart';
import '../utils/file_download_helper.dart';
import '../utils/constants.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  Future<Uint8List> generateDocumentBytes(DocumentWrapper document, {DocumentTemplate? template}) async {
    final rawSettings = await DatabaseHelper.instance.getCompanySettings();
    final CompanySettings companySettings = (rawSettings is CompanySettings) ? rawSettings : CompanySettings();

    // Fetch product references and designations for all items
    final db = DatabaseHelper.instance;
    final allProducts = await db.getProducts();
    for (var item in document.items) {
      if (item.productName.isNotEmpty && item.productName != 'Produit Inconnu') {
        item.customFields['designation'] ??= item.productName;
      }
      Product? product;
      if (item.productId != null && item.productId!.isNotEmpty) {
        product = await db.getProduct(item.productId!);
      }
      if (product == null && allProducts.isNotEmpty) {
        final searchName = (item.customFields['designation'] ?? item.productName).trim().toLowerCase();
        if (searchName.isNotEmpty && searchName != 'produit inconnu') {
          product = allProducts.cast<Product?>().firstWhere(
            (p) => p != null && (
              p.name.trim().toLowerCase() == searchName ||
              (p.reference != null && p.reference!.trim().toLowerCase() == searchName) ||
              p.code.trim().toLowerCase() == searchName
            ),
            orElse: () => null,
          );
        }
      }
      if (product != null) {
        final ref = (product.reference != null && product.reference!.trim().isNotEmpty)
            ? product.reference!.trim()
            : product.code.trim();
        item.customFields['reference'] = ref;
        item.customFields['ref'] = ref;
        item.customFields['code'] = product.code;
        item.customFields['designation'] = product.name;
        item.customFields['unit'] = product.unit;
        item.customFields['purchasePrice'] = product.purchasePrice;
      }
    }

    // Load template: use provided, or default, or built-in defaults
    template ??= await DatabaseHelper.instance.getDefaultTemplate('invoice');
    final config = template?.config ?? DocumentTemplate.defaultConfig();

    if (config.containsKey('canvas_document')) {
      final jsonStr = config['canvas_document'] as String;
      final canvasDoc = CanvasDocument.fromJson(jsonStr);
      return await CanvasPdfGenerator.generateDocumentBytes(document, canvasDoc);
    }

    // Load fonts
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Check if this is a stock document
    final isStockDoc = document.documentTitle == "BON D'ENTRÉE" || document.documentTitle == "BON DE SORTIE" || document.documentTitle == "BON DE TRANSFERT" || document.documentTitle == "FICHE D'INVENTAIRE";
    if (isStockDoc) {
      return await _buildStockDocument(document, companySettings, fontRegular, fontBold);
    }

    final pdf = pw.Document();

    // Extract template colors
    final headerBgColor = PdfColor.fromInt(config['headerBgColor'] as int? ?? 0xFF1a56db);
    final headerTextColor = PdfColor.fromInt(config['headerTextColor'] as int? ?? 0xFFFFFFFF);
    final fontSize = (config['fontSize'] as num?)?.toDouble() ?? 11.0;
    final rowHeight = (config['rowHeight'] as num?)?.toDouble() ?? 8.0;
    
    // Force currency to TND if requested, or use settings if not DZD
    final currency = companySettings.currency == 'DZD' || companySettings.currency.isEmpty ? 'TND' : companySettings.currency;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10 * PdfPageFormat.mm, vertical: 10 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) {
          return _buildProfessionalHeader(document, companySettings, headerBgColor, headerTextColor, fontRegular, fontBold, config);
        },
        footer: (context) {
          final showPageNumbers = config['footer']?['showPageNumbers'] != false;
          if (!showPageNumbers) return pw.SizedBox.shrink();

          return pw.Column(
            children: [
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    companySettings.name.isNotEmpty ? companySettings.name : 'Document commercial',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} / ${context.pagesCount}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
        build: (context) {
          return [
            _buildItemsTable(document, headerBgColor, headerTextColor, config, fontSize, rowHeight),
            pw.SizedBox(height: 20),
            _buildTotals(document, companySettings, config, currency),
            pw.SizedBox(height: 30),
            _buildFooter(companySettings, config),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<void> generateAndOpenDocument(DocumentWrapper document, {DocumentTemplate? template}) async {
    final bytes = await generateDocumentBytes(document, template: template);
    final fileName = '${document.number}.pdf';
    await FileDownloadHelper.saveAndOpenFile(bytes, fileName, mimeType: 'application/pdf');
  }

  /// Downloads PDF to the platform's Downloads folder or browser downloads and shows feedback via SnackBar.
  Future<void> downloadDocument(BuildContext context, DocumentWrapper document, {DocumentTemplate? template}) async {
    try {
      final bytes = await generateDocumentBytes(document, template: template);
      final fileName = '${document.number}.pdf';
      await FileDownloadHelper.saveAndOpenFile(
        bytes,
        fileName,
        mimeType: 'application/pdf',
        context: context,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de téléchargement : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> printDocument(DocumentWrapper document, {DocumentTemplate? template}) async {
    final bytes = await generateDocumentBytes(document, template: template);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${document.documentTitle}_${document.number}.pdf',
    );
  }

  pw.Widget _buildProfessionalHeader(
    DocumentWrapper document,
    CompanySettings settings,
    PdfColor headerBg,
    PdfColor headerText,
    pw.Font font,
    pw.Font fontBold, [
    Map<String, dynamic>? config,
  ]) {
    const double mm = PdfPageFormat.mm;
    final comp = config?['companyInfo'] as Map<String, dynamic>? ?? {};
    final docInfo = config?['documentInfo'] as Map<String, dynamic>? ?? {};
    final cli = config?['clientInfo'] as Map<String, dynamic>? ?? {};

    // 1. Logo Configuration
    final logoCfg = config?['logo'] as Map<String, dynamic>? ?? {};
    final showLogo = comp['showLogo'] == true;
    final logoX = (logoCfg['positionX'] as num?)?.toDouble() ?? 15.0;
    final logoY = (logoCfg['positionY'] as num?)?.toDouble() ?? 15.0;
    final logoW = (logoCfg['width'] as num?)?.toDouble() ?? 20.0;
    final logoH = (logoCfg['height'] as num?)?.toDouble() ?? 15.0;

    // 2. Company Name Configuration
    final defaultCompX = showLogo ? 40.0 : 15.0;
    final nameCfg = config?['companyName'] as Map<String, dynamic>? ?? {};
    final showCompanyName = comp['showName'] != false;
    final nameX = (nameCfg['positionX'] as num?)?.toDouble() ?? defaultCompX;
    final nameY = (nameCfg['positionY'] as num?)?.toDouble() ?? 15.0;

    // 3. Company Details Configuration
    final detailsCfg = config?['companyDetails'] as Map<String, dynamic>? ?? {};
    final detailsX = (detailsCfg['positionX'] as num?)?.toDouble() ?? defaultCompX;
    final detailsY = (detailsCfg['positionY'] as num?)?.toDouble() ?? 22.0;
    final showAddress = comp['showAddress'] != false;
    final showPhone = comp['showPhone'] != false;
    final showEmail = comp['showEmail'] != false;
    final showWebsite = comp['showWebsite'] != false;
    final showTaxId = comp['showTaxId'] != false;
    final showRcNumber = comp['showRcNumber'] != false;

    // 4. Document Title and Metadata Configuration
    final titleCfg = config?['documentTitle'] as Map<String, dynamic>? ?? {};
    final titleX = (titleCfg['positionX'] as num?)?.toDouble() ?? 140.0;
    final titleY = (titleCfg['positionY'] as num?)?.toDouble() ?? 15.0;
    final showTitle = docInfo['showTitle'] != false;
    final showNumber = docInfo['showNumber'] != false;
    final showDate = docInfo['showDate'] != false;
    final showDueDate = docInfo['showDueDate'] != false;

    // 5. Client Details Configuration
    final clientCfg = config?['clientDetails'] as Map<String, dynamic>? ?? {};
    final clientX = (clientCfg['positionX'] as num?)?.toDouble() ?? 15.0;
    final clientY = (clientCfg['positionY'] as num?)?.toDouble() ?? 45.0;
    final clientW = (clientCfg['width'] as num?)?.toDouble() ?? 180.0;
    final clientH = (clientCfg['height'] as num?)?.toDouble() ?? 30.0;
    final showClientName = cli['showName'] != false;
    final showClientAddress = cli['showAddress'] != false;
    final showClientPhone = cli['showPhone'] != false;
    final showClientEmail = cli['showEmail'] != false;
    final showClientCode = cli['showCode'] != false;
    final showClientTaxId = cli['showTaxId'] != false;

    // 6. E-Facture elements (QR code & TTN Reference)
    final qrCfg = config?['qrCode'] as Map<String, dynamic>? ?? {};
    final showQr = qrCfg['enabled'] == true;
    final qrX = (qrCfg['positionX'] as num?)?.toDouble() ?? 15.0;
    final qrY = (qrCfg['positionY'] as num?)?.toDouble() ?? 98.0;
    final qrW = (qrCfg['width'] as num?)?.toDouble() ?? 25.0;
    final qrH = (qrCfg['height'] as num?)?.toDouble() ?? 25.0;

    final ttnCfg = config?['ttnReference'] as Map<String, dynamic>? ?? {};
    final showTtn = ttnCfg['enabled'] == true;
    final ttnX = (ttnCfg['positionX'] as num?)?.toDouble() ?? 45.0;
    final ttnY = (ttnCfg['positionY'] as num?)?.toDouble() ?? 99.0;

    final tableCfg = config?['table'] as Map<String, dynamic>? ?? {};
    final tableY = (tableCfg['positionY'] as num?)?.toDouble() ?? 82.0;

    // Dynamic header height so no elements overlap the items table and table position is respected
    final clientBottom = (clientY - 10.0) + clientH;
    final docBottom = (titleY - 10.0) + 34.0;
    final detailsBottom = (detailsY - 10.0) + 28.0;
    final maxBottom = [clientBottom, docBottom, detailsBottom, (tableY - 10.0), 60.0].reduce(math.max);
    final headerHeight = (maxBottom + 4.0) * mm;

    return pw.Container(
      height: headerHeight,
      width: 190 * mm,
      child: pw.Stack(
        children: [
          // Logo
          if (showLogo)
            pw.Positioned(
              left: (logoX - 10.0).clamp(0.0, 180.0) * mm,
              top: (logoY - 10.0).clamp(0.0, 200.0) * mm,
              child: pw.Container(
                width: logoW * mm,
                height: logoH * mm,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
                child: pw.Center(
                  child: pw.Text('Logo', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                ),
              ),
            ),

          // Company Name
          if (showCompanyName)
            pw.Positioned(
              left: (nameX - 10.0).clamp(0.0, 180.0) * mm,
              top: (nameY - 10.0).clamp(0.0, 200.0) * mm,
              child: pw.Text(
                settings.name.isNotEmpty ? settings.name : 'Ma Société',
                style: pw.TextStyle(font: fontBold, fontSize: 18, color: headerBg),
              ),
            ),

          // Company Details
          pw.Positioned(
            left: (detailsX - 10.0).clamp(0.0, 180.0) * mm,
            top: (detailsY - 10.0).clamp(0.0, 200.0) * mm,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (showAddress && settings.address != null && settings.address!.isNotEmpty)
                  pw.Text(settings.address!, style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700)),
                if (showAddress && settings.city != null && settings.city!.isNotEmpty)
                  pw.Text(settings.city!, style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700)),
                if (showPhone && settings.phone != null && settings.phone!.isNotEmpty)
                  pw.Text('Tel: ${settings.phone}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700)),
                if (showEmail && settings.email != null && settings.email!.isNotEmpty)
                  pw.Text('Email: ${settings.email}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700)),
                if (showWebsite && settings.website != null && settings.website!.isNotEmpty)
                  pw.Text('Web: ${settings.website}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700)),
                if (showTaxId && settings.taxId != null && settings.taxId!.isNotEmpty)
                  pw.Text('NIF: ${settings.taxId}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700)),
                if (showRcNumber && settings.rcNumber != null && settings.rcNumber!.isNotEmpty)
                  pw.Text('RC: ${settings.rcNumber}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700)),
              ],
            ),
          ),

          // Document Title and Header Badge
          if (showTitle || showNumber || showDate || showDueDate)
            pw.Positioned(
              left: (titleX - 10.0).clamp(0.0, 180.0) * mm,
              top: (titleY - 10.0).clamp(0.0, 200.0) * mm,
              child: pw.Column(
                crossAxisAlignment: (titleX > 90) ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                children: [
                  if (showTitle || showNumber)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: headerBg,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: (titleX > 90) ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                        children: [
                          if (showTitle)
                            pw.Text(
                              document.documentTitle,
                              style: pw.TextStyle(font: fontBold, fontSize: 16, color: headerText, letterSpacing: 1.1),
                            ),
                          if (showNumber) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'N° ${document.number}',
                              style: pw.TextStyle(font: font, fontSize: 10, color: headerText),
                            ),
                          ],
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 4),
                  if (showDate)
                    pw.Text('Date: ${formatDate(document.date)}', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800)),
                  if (showDueDate && document.dueDate != null)
                    pw.Text('Echéance: ${formatDate(document.dueDate!)}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                ],
              ),
            ),

          // Client Details Box
          pw.Positioned(
            left: (clientX - 10.0).clamp(0.0, 180.0) * mm,
            top: (clientY - 10.0).clamp(0.0, 200.0) * mm,
            child: pw.Container(
              width: clientW * mm,
              constraints: pw.BoxConstraints(minHeight: clientH * mm),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (document.documentTitle == "BON D'ENTRÉE" || document.documentTitle == "BON DE SORTIE" || document.documentTitle == "BON DE TRANSFERT" || document.documentTitle == "FICHE D'INVENTAIRE") ...[
                    pw.Text('Entrepôt :', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text(document.customData['warehouseName'] ?? 'Non spécifié', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black)),
                  ] else ...[
                    pw.Text('Adressé à :', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    if (showClientName)
                      pw.Text(document.customerName ?? 'Client Inconnu', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black)),
                    if (showClientAddress && document.customerAddress != null && document.customerAddress!.isNotEmpty)
                      pw.Text('Adresse : ${document.customerAddress}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey800)),
                    if (showClientPhone && document.customerPhone != null && document.customerPhone!.isNotEmpty)
                      pw.Text('Tél : ${document.customerPhone}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey800)),
                    if (showClientEmail && document.customerEmail != null && document.customerEmail!.isNotEmpty)
                      pw.Text('Email : ${document.customerEmail}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey800)),
                    if (showClientCode && document.customerCode != null && document.customerCode!.isNotEmpty)
                      pw.Text('Code Client : ${document.customerCode}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey800)),
                    if (showClientTaxId && document.customerTaxId != null && document.customerTaxId!.isNotEmpty)
                      pw.Text('Matricule Fiscale : ${document.customerTaxId}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey800)),
                    if (document.customData.containsKey('projectName') && document.customData['projectName'] != null && document.customData['projectName'].toString().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text('Projet : ${document.customData['projectName']}', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey800)),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // QR Code Overlay
          if (showQr)
            pw.Positioned(
              left: (qrX - 10.0).clamp(0.0, 180.0) * mm,
              top: (qrY - 10.0).clamp(0.0, 200.0) * mm,
              child: pw.Container(
                width: qrW * mm,
                height: qrH * mm,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: '${settings.name}|${document.number}|${document.totalTTC + document.stampTax}',
                    width: qrW * mm * 0.85,
                    height: qrH * mm * 0.85,
                  ),
                ),
              ),
            ),

          // TTN Reference Overlay
          if (showTtn)
            pw.Positioned(
              left: (ttnX - 10.0).clamp(0.0, 180.0) * mm,
              top: (ttnY - 10.0).clamp(0.0, 200.0) * mm,
              child: pw.Text(
                'Réf TTN: XXXXXXXXX',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(DocumentWrapper document, PdfColor headerBg, PdfColor headerText, Map<String, dynamic> config, double fontSize, double rowHeight) {
    final defaultCols = DocumentTemplate.defaultConfig()['tableColumns'] as List;
    var columnsConfig = (config['tableColumns'] as List?) ?? defaultCols;

    // Ensure all default columns exist in columnsConfig (e.g., if a new column was added to defaults)
    final existingIds = columnsConfig.map((c) => c['id']).toSet();
    for (int i = 0; i < defaultCols.length; i++) {
      if (!existingIds.contains(defaultCols[i]['id'])) {
        final newCols = List<dynamic>.from(columnsConfig);
        newCols.insert(i.clamp(0, newCols.length), defaultCols[i]);
        columnsConfig = newCols;
        existingIds.add(defaultCols[i]['id']);
      }
    }

    final activeColumns = columnsConfig.where((c) => c['visible'] == true).toList();
    final headers = activeColumns.map((c) => c['label'] as String).toList();

    final data = document.items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      return activeColumns.map((c) {
        final id = c['id'] as String;
        switch (id) {
          case 'index':
            return index.toString();
          case 'reference':
          case 'ref':
            final ref = item.customFields['reference'] ??
                item.customFields['ref'] ??
                item.customFields['code'];
            return (ref != null && ref.toString().trim().isNotEmpty) ? ref.toString().trim() : '';
          case 'code':
            final c = item.customFields['code'] ?? item.customFields['reference'];
            return (c != null && c.toString().trim().isNotEmpty) ? c.toString().trim() : '';
          case 'designation':
            final des = item.customFields['designation'];
            if (des != null && des.isNotEmpty && des != 'Produit Inconnu') {
              return des;
            }
            return (item.productName.isNotEmpty && item.productName != 'Produit Inconnu')
                ? item.productName
                : (item.customFields['description'] ?? item.productName);
          case 'quantity':
            return formatQuantity(item.quantity);
          case 'unitPrice':
            return formatCurrency(item.unitPrice, symbol: '');
          case 'unitPriceTTC':
            return formatCurrency(item.unitPrice * (1 + item.tvaRate / 100), symbol: '');
          case 'tva':
            return formatPercentage(item.tvaRate);
          case 'discount':
            return item.discountPercent > 0 ? formatPercentage(item.discountPercent) : '-';
          case 'totalHT':
            return formatCurrency(item.totalHT, symbol: '');
          case 'totalTTCLine':
            return formatCurrency(item.totalHT * (1 + item.tvaRate / 100), symbol: '');
          default:
            return item.customFields[id] ?? '';
        }
      }).toList();
    }).toList();

    final tableStyle = config['tableStyle'] as String? ?? 'classique';

    // Build alignments dynamically
    final Map<int, pw.Alignment> alignments = {};
    for (int i = 0; i < activeColumns.length; i++) {
      final id = activeColumns[i]['id'] as String;
      if (id == 'designation' || id == 'reference') {
        alignments[i] = pw.Alignment.centerLeft;
      } else if (id == 'quantity' || id == 'index') {
        alignments[i] = pw.Alignment.center;
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
    const double mm = PdfPageFormat.mm;
    final showBrut = config['totalBrut']?['visible'] == true;
    final showRemises = config['totalRemises']?['visible'] != false;
    final showHT = config['totalHT']?['visible'] != false;
    final showTaxes = config['taxes']?['visible'] != false;
    final showTimbre = config['timbre']?['visible'] != false;
    final showTTC = config['totalTTC']?['visible'] != false;
    final showLetters = config['totalLetters']?['visible'] == true;

    final totalsCfg = config['totals'] as Map<String, dynamic>? ?? {};
    final totalsW = ((totalsCfg['width'] as num?)?.toDouble() ?? 80.0).clamp(50.0, 160.0);

    return pw.Container(
      width: 190 * mm,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(right: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (document.notes != null && document.notes!.trim().isNotEmpty) ...[
                    pw.Text('Notes :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(document.notes!, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black)),
                    pw.SizedBox(height: 10),
                  ],
                  if (document.conditionsGenerales != null && document.conditionsGenerales!.trim().isNotEmpty) ...[
                    pw.Text('Conditions Générales :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(document.conditionsGenerales!, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black)),
                  ],
                  if (showLetters) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Arrêté le présent document à la somme de : ${formatCurrency(document.totalTTC + document.stampTax, symbol: currency)}',
                      style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800),
                    ),
                  ],
                ],
              ),
            ),
          ),
          pw.Container(
            width: totalsW * mm,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (showBrut)
                  _buildTotalRow('Sous-total HT', formatCurrency(document.totalHT + document.totalDiscount, symbol: currency)),
                if (showRemises && document.totalDiscount > 0)
                  _buildTotalRow('Total Remise', formatCurrency(document.totalDiscount, symbol: currency)),
                if (showHT)
                  _buildTotalRow('Total HT', formatCurrency(document.totalHT, symbol: currency)),
                if (showTaxes)
                  _buildTotalRow('Total TVA', formatCurrency(document.totalTva, symbol: currency)),
                if (showTimbre && document.stampTax > 0)
                  _buildTotalRow('Droit de Timbre', formatCurrency(document.stampTax, symbol: currency)),
                if (showTTC) ...[
                  pw.SizedBox(height: 4),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.8),
                  pw.SizedBox(height: 2),
                  _buildTotalRow('Total TTC', formatCurrency(document.totalTTC + document.stampTax, symbol: currency), isBold: true, size: 14),
                ],
              ],
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

  pw.Widget _buildFooter(CompanySettings settings, [Map<String, dynamic>? config]) {
    final styleCode = config?['styleCode'] as String? ?? 'classic';
    final isProfessional = styleCode == 'professional';
    final foot = config?['footer'] as Map<String, dynamic>? ?? {};

    final showLegalNotice = foot['showLegalNotice'] != false;
    final showSignature = foot['showSignature'] != false;

    if (!showLegalNotice && !showSignature) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: showLegalNotice ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (settings.bankName != null && settings.bankAccount != null) ...[
                    pw.Text('Règlement par virement bancaire sur le compte:', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text('${settings.bankName} - RIB: ${settings.rib ?? settings.bankAccount}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ] else if (settings.rib != null && settings.rib!.isNotEmpty) ...[
                    pw.Text('RIB Bancaire:', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text(settings.rib!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ],
                ],
              ) : pw.SizedBox.shrink(),
            ),
            if (showSignature) ...[
              if (isProfessional) ...[
                pw.Container(
                  width: 130,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Pour la Société', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('(Cachet & Signature)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 35),
                      pw.Container(height: 1, width: 110, color: PdfColors.grey800),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Container(
                  width: 130,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Bon pour Accord Client', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('(Date et Signature)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 35),
                      pw.Container(height: 1, width: 110, color: PdfColors.grey800),
                    ],
                  ),
                ),
              ] else ...[
                pw.Container(
                  width: 150,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Signature',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                      ),
                      pw.SizedBox(height: 40),
                      pw.Container(
                        height: 1,
                        width: 130,
                        color: PdfColors.grey800,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }

  /// Dedicated professional PDF layout for stock documents (Bon d'entrée, Bon de sortie, etc.)
  Future<Uint8List> _buildStockDocument(DocumentWrapper document, CompanySettings settings, pw.Font fontRegular, pw.Font fontBold) async {
    final pdf = pw.Document();
    const accentColor = PdfColor.fromInt(0xFF1a56db);
    const accentLight = PdfColor.fromInt(0xFFe8edfb);

    final warehouseName = document.customData['warehouseName'] ?? 'Non spécifié';
    final createdBy = document.customData['createdBy'] ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (context) {
          return [
            // ── Header Row ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Company info
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settings.name.isNotEmpty ? settings.name : 'Ma Société',
                        style: pw.TextStyle(font: fontBold, fontSize: 22, color: accentColor),
                      ),
                      pw.SizedBox(height: 4),
                      if (settings.address != null && settings.address!.isNotEmpty)
                        pw.Text(settings.address!, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                      if (settings.phone != null && settings.phone!.isNotEmpty)
                        pw.Text('Tél: ${settings.phone}', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                      if (settings.email != null && settings.email!.isNotEmpty)
                        pw.Text(settings.email!, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                // Document badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(document.documentTitle, style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white, letterSpacing: 1)),
                      pw.SizedBox(height: 2),
                      pw.Text('N° ${document.number}', style: pw.TextStyle(font: fontRegular, fontSize: 11, color: PdfColors.white)),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // ── Info cards row ──
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: accentLight,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFc7d2fe), width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _stockInfoCell('Référence', document.number, fontRegular, fontBold),
                  _stockInfoCell('Date', formatDate(document.date), fontRegular, fontBold),
                  _stockInfoCell('Entrepôt', warehouseName, fontRegular, fontBold),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // ── Articles table ──
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(32),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(4),
                3: const pw.FlexColumnWidth(2.5),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                  children: [
                    _stockTableHeaderCell('#', fontBold, color: PdfColors.grey800, align: pw.Alignment.centerLeft),
                    _stockTableHeaderCell('Référence', fontBold, color: PdfColors.grey800),
                    _stockTableHeaderCell('Produit', fontBold, color: PdfColors.grey800),
                    _stockTableHeaderCell('Coût prod. unit.', fontBold, color: PdfColors.grey800),
                    _stockTableHeaderCell('Quantité', fontBold, color: PdfColors.grey800),
                  ],
                ),
                // Data rows
                ...document.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final code = item.customFields['code'] ?? '';
                  final unit = item.customFields['unit'] ?? 'pièce';
                  final purchasePrice = item.customFields['purchasePrice'];
                  final costStr = (purchasePrice != null && purchasePrice is num && purchasePrice > 0)
                      ? formatCurrency(purchasePrice.toDouble(), symbol: '')
                      : '-';
                  final qtyStr = '${formatQuantity(item.quantity)} $unit';
                  return pw.TableRow(
                    children: [
                      _stockTableCell('${idx + 1}', fontRegular),
                      _stockTableCell(code, fontRegular),
                      _stockTableCell(item.productName, fontBold),
                      _stockTableCell(costStr, fontRegular),
                      _stockTableCell(qtyStr, fontRegular),
                    ],
                  );
                }),
              ],
            ),

            // ── Notes ──
            if (document.notes != null && document.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.amber200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Notes :', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey800)),
                    pw.SizedBox(height: 4),
                    pw.Text(document.notes!, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],

            pw.SizedBox(height: 40),

            // ── Signature section ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _signatureBlock('Signature', fontRegular, fontBold),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _stockInfoCell(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey900)),
      ],
    );
  }

  pw.Widget _stockTableHeaderCell(String text, pw.Font fontBold, {pw.Alignment align = pw.Alignment.centerLeft, PdfColor color = PdfColors.white}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text, style: pw.TextStyle(font: fontBold, fontSize: 11, color: color)),
      ),
    );
  }

  pw.Widget _stockTableCell(String text, pw.Font font, {pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10)),
      ),
    );
  }

  pw.Widget _signatureBlock(String title, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      width: 150,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey800)),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 60,
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

