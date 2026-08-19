import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/document_wrapper.dart';
import '../services/pdf_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class DocumentPreviewScreen extends StatelessWidget {
  final DocumentWrapper document;

  const DocumentPreviewScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxPageWidth = screenWidth > 1000 ? 880.0 : screenWidth * 0.92;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Aperçu & Impression: ${document.number}',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Télécharger PDF',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => PdfService.instance.downloadDocument(context, document),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreview(
        build: (format) => PdfService.instance.generateDocumentBytes(document),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: maxPageWidth,
        pdfFileName: '${document.documentTitle.replaceAll(' ', '_')}_${document.number}.pdf',
        dpi: 300,
        loadingWidget: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Génération du document en cours...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
