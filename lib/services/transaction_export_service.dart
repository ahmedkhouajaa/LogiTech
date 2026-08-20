import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';

import '../models/treasury_transaction.dart';
import '../utils/constants.dart';
import '../utils/file_download_helper.dart';

class TransactionExportService {
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
                    pw.Text('Journal des Transactions', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                    pw.Text(
                      'Date: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Total Lignes: ${transactions.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'Transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
            content: Text('Erreur lors de l\'export PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
        final fileName = 'Transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        await FileDownloadHelper.saveAndOpenFile(
          Uint8List.fromList(fileBytes),
          fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          context: context,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export Excel: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
