import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:open_filex/open_filex.dart';

import '../screens/stock_screen.dart';
import '../utils/platform_utils.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class StockExportService {
  static Future<Directory> _getDownloadsDirectory() async {
    if (PlatformUtils.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return extDir;
      return await getApplicationDocumentsDirectory();
    } else if (PlatformUtils.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final dir = Directory('$userProfile\\Downloads');
        if (await dir.exists()) return dir;
      }
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir;
      return await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  static Future<void> exportToPdf(BuildContext context, List<StockLevelItem> items) async {
    try {
      final pdf = pw.Document();
      final headers = ['Produit', 'Reference', 'Entrepot', 'Disponible', 'Reserve', 'Total', 'Statut'];

      final data = items.map((item) {
        final qtyStr = formatQuantity(item.quantity);
        final status = item.quantity > 0 ? 'En Stock' : 'En Rupture';
        return [
          item.product.name,
          item.product.reference ?? item.product.code,
          item.warehouse.name,
          qtyStr,
          '0',
          qtyStr,
          status,
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Niveaux de Stock Actuels', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
                cellHeight: 25,
                cellPadding: const pw.EdgeInsets.all(4),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                },
                cellStyle: const pw.TextStyle(fontSize: 8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.5),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(2.0),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1.0),
                  5: pw.FlexColumnWidth(1.2),
                  6: pw.FlexColumnWidth(1.2),
                },
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              ),
            ];
          },
        ),
      );

      final dir = await _getDownloadsDirectory();
      final file = File('${dir.path}/Stock_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF sauvegarde : ${file.path}'), backgroundColor: AppColors.success));
        OpenFilex.open(file.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de l\'export PDF: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  static Future<void> exportToExcel(BuildContext context, List<StockLevelItem> items) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Stock'];
      excel.setDefaultSheet('Stock');

      final headers = ['Produit', 'Reference', 'Entrepot', 'Disponible', 'Reserve', 'Total', 'Statut'];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true, fontFamily: getFontFamily(FontFamily.Arial));
      }

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final rowIndex = i + 1;
        
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(item.product.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(item.product.reference ?? item.product.code);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(item.warehouse.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(item.quantity);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(0.0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(item.quantity);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(item.quantity > 0 ? 'En Stock' : 'En Rupture');
      }

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final dir = await _getDownloadsDirectory();
        final file = File('${dir.path}/Stock_${DateTime.now().millisecondsSinceEpoch}.xlsx');
        await file.writeAsBytes(fileBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel sauvegarde : ${file.path}'), backgroundColor: AppColors.success));
          OpenFilex.open(file.path);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de l\'export Excel: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}
