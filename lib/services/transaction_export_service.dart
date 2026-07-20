import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:open_filex/open_filex.dart';

import '../models/treasury_transaction.dart';
import '../utils/platform_utils.dart';
import '../utils/constants.dart';

class TransactionExportService {
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

  static Future<void> exportToPdf(BuildContext context, List<TreasuryTransaction> transactions) async {
    try {
      final pdf = pw.Document();

      final headers = ['Reference', 'Compte', 'Debit', 'Credit', 'Solde', 'Motif'];

      final data = transactions.map((tx) {
        final isDebit = tx.type == 'income';
        final isCredit = tx.type == 'expense';
        return [
          '${tx.transactionNumber}\n${DateFormat('dd/MM/yyyy HH:mm').format(tx.dateTransaction)}',
          tx.accountName ?? '—',
          isDebit ? '+ ${NumberFormat('#,##0.000', 'fr_FR').format(tx.amount)}' : '-',
          isCredit ? '- ${NumberFormat('#,##0.000', 'fr_FR').format(tx.amount)}' : '-',
          '${NumberFormat('#,##0.000', 'fr_FR').format(tx.balance ?? 0.0)}',
          tx.description ?? '',
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
                    pw.Text('Transactions de Tresorerie', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerLeft,
                },
                cellStyle: const pw.TextStyle(fontSize: 8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.2),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.3),
                  3: pw.FlexColumnWidth(1.3),
                  4: pw.FlexColumnWidth(1.3),
                  5: pw.FlexColumnWidth(2.2),
                },
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              ),
            ];
          },
        ),
      );

      final dir = await _getDownloadsDirectory();
      final file = File('${dir.path}/Transactions_${DateTime.now().millisecondsSinceEpoch}.pdf');
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

  static Future<void> exportToExcel(BuildContext context, List<TreasuryTransaction> transactions) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Transactions'];
      excel.setDefaultSheet('Transactions');

      final headers = ['Reference', 'Date', 'Compte', 'Debit', 'Credit', 'Solde', 'Motif'];
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true, fontFamily: getFontFamily(FontFamily.Arial));
      }

      for (var i = 0; i < transactions.length; i++) {
        final tx = transactions[i];
        final rowIndex = i + 1;
        final isDebit = tx.type == 'income';
        final isCredit = tx.type == 'expense';

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(tx.transactionNumber);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(tx.dateTransaction));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(tx.accountName ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(isDebit ? tx.amount : 0.0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(isCredit ? tx.amount : 0.0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(tx.balance ?? 0.0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(tx.description ?? '');
      }

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final dir = await _getDownloadsDirectory();
        final file = File('${dir.path}/Transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx');
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
