import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/document_wrapper.dart';
import '../services/pdf_service.dart';
import '../widgets/custom_app_bar.dart';

class DocumentPreviewScreen extends StatelessWidget {
  final DocumentWrapper document;

  const DocumentPreviewScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    // Adjust the max width to make the document appear more zoomed in by default
    final screenWidth = MediaQuery.of(context).size.width;
    final maxPageWidth = screenWidth > 1000 ? 850.0 : screenWidth * 0.9;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Aperçu du document: ${document.number}',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PdfPreview(
        build: (format) => PdfService.instance.generateDocumentBytes(document),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: maxPageWidth,
        pdfFileName: '${document.documentTitle}_${document.number}.pdf',
        dpi: 300,
      ),
    );
  }
}
