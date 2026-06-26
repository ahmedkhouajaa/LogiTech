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
    // Calculate max width to fit the A4 page (ratio ~1.414) in the available screen height
    final availableHeight = MediaQuery.of(context).size.height - 150; // accounting for AppBar and toolbars
    final fitHeightWidth = availableHeight / 1.414;

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
        maxPageWidth: fitHeightWidth,
        pdfFileName: '${document.documentTitle}_${document.number}.pdf',
        dpi: 300,
      ),
    );
  }
}
