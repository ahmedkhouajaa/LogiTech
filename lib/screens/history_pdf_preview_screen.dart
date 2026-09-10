import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class HistoryPdfPreviewScreen extends StatelessWidget {
  final String title;
  final String pdfFileName;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;

  const HistoryPdfPreviewScreen({
    super.key,
    required this.title,
    required this.pdfFileName,
    required this.buildPdf,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxPageWidth = screenWidth > 1000 ? 880.0 : screenWidth * 0.92;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: title,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PdfPreview(
        build: buildPdf,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: maxPageWidth,
        pdfFileName: pdfFileName,
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
