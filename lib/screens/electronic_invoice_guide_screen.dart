import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/electronic_invoice_guide_pdf_service.dart';
import '../utils/guide_pdf_opener/guide_pdf_opener.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class ElectronicInvoiceGuideScreen extends StatelessWidget {
  const ElectronicInvoiceGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxPageWidth = screenWidth > 900 ? 760.0 : screenWidth * 0.95;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: context.tr('Retour'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Guide de Connexion elFatoora & Facturation Électronique'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              context.tr('Accompagnement officiel pas à pas en 10 étapes - LogiTech & TTN'),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: context.tr('Ouvrir dans Google Chrome'),
            onPressed: () async {
              final bytes = await ElectronicInvoiceGuidePdfService.instance.generateGuidePdf();
              if (context.mounted) {
                await GuidePdfOpener.openPdfInChrome(
                  bytes,
                  'Guide_Facturation_Electronique_LogiTech_elFatoora.pdf',
                  context,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: PdfPreview(
        build: (format) => ElectronicInvoiceGuidePdfService.instance.generateGuidePdf(),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: maxPageWidth,
        pdfFileName: 'Guide_Connexion_elFatoora_Facture_Electronique_LogiTech.pdf',
        dpi: 240,
        loadingWidget: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                context.tr('Génération du guide en cours...'),
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
