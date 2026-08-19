import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/document_wrapper.dart';
import 'pdf_service.dart';

class DocumentShareService {
  static final DocumentShareService instance = DocumentShareService._();
  DocumentShareService._();

  static Future<File> _generatePdfFile(DocumentWrapper doc) async {
    final bytes = await PdfService.instance.generateDocumentBytes(doc);
    final tempDir = await getTemporaryDirectory();
    final sanitizedNumber = doc.number.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final fileName = '$sanitizedNumber.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareViaEmail({
    required DocumentWrapper document,
    BuildContext? context,
  }) async {
    try {
      final file = await _generatePdfFile(document);
      final sanitizedNumber = document.number.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final fileName = '$sanitizedNumber.pdf';
      final subject = 'Votre ${document.documentTitle} ${document.number}';
      final xFile = XFile(file.path, mimeType: 'application/pdf', name: fileName);
      await Share.shareXFiles(
        [xFile],
        subject: subject,
        text: 'Veuillez trouver ci-joint votre document : ${document.documentTitle} N° ${document.number}.',
      );
    } catch (e) {
      debugPrint('Error sharing via email: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage : $e')),
        );
      }
    }
  }

  static Future<void> shareViaWhatsApp({
    required DocumentWrapper document,
    BuildContext? context,
  }) async {
    try {
      final file = await _generatePdfFile(document);
      final sanitizedNumber = document.number.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final fileName = '$sanitizedNumber.pdf';
      final xFile = XFile(file.path, mimeType: 'application/pdf', name: fileName);
      await Share.shareXFiles(
        [xFile],
        text: '${document.documentTitle} N° ${document.number}',
      );
    } catch (e) {
      debugPrint('Error sharing via WhatsApp: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage : $e')),
        );
      }
    }
  }

  static Future<void> shareDocument(
    DocumentWrapper doc, {
    required bool isEmail,
    BuildContext? context,
  }) async {
    if (isEmail) {
      await shareViaEmail(document: doc, context: context);
    } else {
      await shareViaWhatsApp(document: doc, context: context);
    }
  }
}
