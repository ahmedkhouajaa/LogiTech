import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/document_wrapper.dart';
import 'pdf_service.dart';

class DocumentShareService {
  static final DocumentShareService instance = DocumentShareService._();
  DocumentShareService._();

  static Future<void> shareViaEmail({
    required DocumentWrapper document,
    BuildContext? context,
  }) async {
    try {
      final bytes = await PdfService.instance.generateDocumentBytes(document);
      final sanitizedNumber = document.number.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final fileName = '$sanitizedNumber.pdf';
      final subject = 'Votre ${document.documentTitle} ${document.number}';

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return;
      }

      final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName);
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
      final bytes = await PdfService.instance.generateDocumentBytes(document);
      final sanitizedNumber = document.number.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final fileName = '$sanitizedNumber.pdf';

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return;
      }

      final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName);
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
