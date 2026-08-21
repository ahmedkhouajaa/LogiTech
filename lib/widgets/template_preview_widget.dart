import 'package:flutter/material.dart';
import '../models/document_template.dart';
import '../utils/constants.dart';

/// Widget-based preview of the invoice template.
/// Renders a simplified A4-proportioned view that updates reactively.
class TemplatePreviewWidget extends StatelessWidget {
  final DocumentTemplate template;
  final void Function(String itemKey, double newX, double newY)? onPositionChanged;
  final bool showHeader;

  const TemplatePreviewWidget({
    super.key, 
    required this.template,
    this.onPositionChanged,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final pageCanvas = Center(
      child: AspectRatio(
        aspectRatio: 210 / 297, // A4 proportions
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.md,
          ),
          child: LayoutBuilder(
            builder: (context, innerConstraints) {
              final scale = innerConstraints.maxWidth / 210; // scale factor (mm → px)
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    // Header & Client Elements
                    _buildDraggableLogo(scale),
                    _buildDraggableCompanyName(scale),
                    _buildDraggableCompanyDetails(scale),
                    _buildDraggableDocumentTitle(scale),
                    _buildDraggableClientDetails(scale),
                    // Article Table
                    _buildDraggableTable(scale),
                    // Notes & Conditions
                    _buildDraggableNotes(scale),
                    // Totals
                    _buildDraggableTotals(scale),
                    // Signature
                    _buildDraggableSignature(scale),
                    // Mentions légales & Footer
                    _buildDraggableLegalNotice(scale),
                    // E-Facture elements
                    if (template.qrCodeConfig['enabled'] == true)
                      _buildQrCodeOverlay(scale),
                    if (template.ttnReferenceConfig['enabled'] == true)
                      _buildTtnOverlay(scale),
                    if (template.submissionDateConfig['enabled'] == true)
                      _buildSubmissionDateOverlay(scale),
                    if (template.statusBadgeConfig['enabled'] == true)
                      _buildStatusBadgeOverlay(scale),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    if (!showHeader) {
      return pageCanvas;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: EdgeInsets.all(isNarrow ? 10 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.preview_rounded, size: isNarrow ? 16 : 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Aperçu du document A4',
                    style: TextStyle(
                      fontSize: isNarrow ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'Temps réel',
                      style: TextStyle(
                        fontSize: isNarrow ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isNarrow ? 8 : 14),
              Expanded(child: pageCanvas),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableLogo(double scale) {
    if (template.companyInfoConfig['showLogo'] != true) return const SizedBox.shrink();

    final cfg = template.logoConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 15;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 20) * scale;
    final h = ((cfg['height'] as num?)?.toDouble() ?? 15) * scale;

    return _buildDraggableOverlay(
      'logo', x, y, scale,
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Center(
          child: Text('Logo', style: TextStyle(fontSize: 4 * scale, color: AppColors.textTertiary)),
        ),
      ),
    );
  }

  Widget _buildDraggableCompanyName(double scale) {
    if (template.companyInfoConfig['showName'] == false) return const SizedBox.shrink();

    final showLogo = template.companyInfoConfig['showLogo'] == true;
    final defaultX = showLogo ? 40.0 : 15.0;
    final cfg = template.companyNameConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? defaultX;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 15.0;

    return _buildDraggableOverlay(
      'companyName', x, y, scale,
      Container(
        padding: EdgeInsets.symmetric(horizontal: 3 * scale, vertical: 1.5 * scale),
        decoration: BoxDecoration(
          color: Color(template.headerBgColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          'Nom de l\'entreprise',
          style: TextStyle(fontSize: 4.5 * scale, fontWeight: FontWeight.bold, color: Color(template.headerBgColor)),
        ),
      ),
    );
  }

  Widget _buildDraggableCompanyDetails(double scale) {
    final comp = template.companyInfoConfig;
    final showLogo = comp['showLogo'] == true;
    final defaultX = showLogo ? 40.0 : 15.0;
    final cfg = template.companyDetailsConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? defaultX;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 22.0;

    final List<String> details = [];
    if (comp['showAddress'] != false) details.add('Adresse de l\'entreprise');
    if (comp['showPhone'] != false) details.add('Tél: +216 00 000 000');
    if (comp['showEmail'] != false) details.add('contact@entreprise.com');
    if (comp['showWebsite'] != false) details.add('www.entreprise.com');
    if (comp['showTaxId'] != false) details.add('NIF: 0000000/A/P/000');
    if (comp['showRcNumber'] != false) details.add('RC: B0000000000');
    if (comp['showRib'] != false) details.add('RIB: 00 000 0000000000000 00');

    if (details.isEmpty) return const SizedBox.shrink();

    return _buildDraggableOverlay(
      'companyDetails', x, y, scale,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: details.take(4).map((d) => Text(
          d,
          style: TextStyle(fontSize: 2.8 * scale, color: AppColors.textSecondary, height: 1.3),
        )).toList(),
      ),
    );
  }

  Widget _buildDraggableDocumentTitle(double scale) {
    final docInfo = template.documentInfoConfig;
    final cfg = template.documentTitleConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 140;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 15;

    return _buildDraggableOverlay(
      'documentTitle', x, y, scale,
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (docInfo['showTitle'] != false)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2 * scale),
              decoration: BoxDecoration(
                color: Color(template.headerBgColor),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                'FACTURE',
                style: TextStyle(fontSize: 4 * scale, fontWeight: FontWeight.bold, color: Color(template.headerTextColor)),
              ),
            ),
          if (docInfo['showNumber'] != false) ...[
            SizedBox(height: 1 * scale),
            Text('N° FC-2026-0001', style: TextStyle(fontSize: 2.8 * scale, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
          if (docInfo['showDate'] != false) ...[
            SizedBox(height: 0.5 * scale),
            Text('Date: 20/08/2026', style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textSecondary)),
          ],
          if (docInfo['showDueDate'] != false) ...[
            SizedBox(height: 0.5 * scale),
            Text('Échéance: 20/09/2026', style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildDraggableClientDetails(double scale) {
    final cli = template.clientInfoConfig;
    final cfg = template.clientDetailsConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 45;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 180) * scale;
    final h = ((cfg['height'] as num?)?.toDouble() ?? 30) * scale;

    final List<String> clientLines = [];
    if (cli['showName'] != false) clientLines.add('Client Passager / SARL Société');
    if (cli['showAddress'] != false) clientLines.add('Adresse: Rue Principale, Tunis');
    if (cli['showPhone'] != false) clientLines.add('Tél: +216 99 999 999');
    if (cli['showEmail'] != false) clientLines.add('client@email.com');
    if (cli['showCode'] != false) clientLines.add('Code: CLI-0012');
    if (cli['showTaxId'] != false) clientLines.add('MF: 1234567/B/M/000');

    return _buildDraggableOverlay(
      'clientDetails', x, y, scale,
      Container(
        width: w,
        height: h,
        padding: EdgeInsets.all(3 * scale),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adressé à :', style: TextStyle(fontSize: 3 * scale, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: 1 * scale),
            ...clientLines.take(3).map((l) => Text(
              l,
              style: TextStyle(fontSize: 2.6 * scale, color: AppColors.textSecondary, height: 1.2),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTableArea(double scale) {
    final headerBg = Color(template.headerBgColor);
    final headerFg = Color(template.headerTextColor);
    final isAlterne = template.tableStyle == 'alterne';
    final isMinimaliste = template.tableStyle == 'minimaliste';
    final borderColor = Color(template.tableConfig['borderColor'] as int? ?? 0xFFE2E8F0);
    final showOutline = template.tableConfig['showOutline'] as bool? ?? true;

    final defaultCols = DocumentTemplate.defaultConfig()['tableColumns'] as List;
    final columnsConfig = (template.config['tableColumns'] as List?) ?? defaultCols;
    final activeColumns = columnsConfig.where((c) => c['visible'] == true).toList();

    return Container(
      decoration: BoxDecoration(
        border: showOutline ? Border.all(color: borderColor, width: 0.5) : null,
        borderRadius: BorderRadius.circular(1),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2 * scale, vertical: 1.5 * scale),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: showOutline ? const BorderRadius.vertical(top: Radius.circular(1)) : null,
            ),
            child: Row(
              children: activeColumns.map((c) {
                final isDesignation = c['id'] == 'designation';
                return Expanded(
                  flex: isDesignation ? 3 : 1,
                  child: Text(
                    (c['label'] as String).toUpperCase(),
                    style: TextStyle(fontSize: 2.5 * scale, fontWeight: FontWeight.bold, color: headerFg),
                    textAlign: isDesignation ? TextAlign.left : TextAlign.right,
                  ),
                );
              }).toList(),
            ),
          ),
          // Data rows
          for (int i = 0; i < 4; i++)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2 * scale, vertical: 1.2 * scale),
              decoration: BoxDecoration(
                color: isAlterne && i.isOdd
                    ? headerBg.withValues(alpha: 0.05)
                    : Colors.transparent,
                border: isMinimaliste
                    ? null
                    : Border(bottom: BorderSide(color: borderColor, width: 0.3)),
              ),
              child: Row(
                children: activeColumns.map((c) {
                  final isDesignation = c['id'] == 'designation';
                  return Expanded(
                    flex: isDesignation ? 3 : 1,
                    child: Align(
                      alignment: isDesignation ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        height: 2 * scale,
                        width: isDesignation ? 25 * scale : 10 * scale,
                        color: AppColors.surfaceAlt,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraggableTable(double scale) {
    final cfg = template.tableConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15.0;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 82.0;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 180.0) * scale;

    return _buildDraggableOverlay(
      'table',
      x,
      y,
      scale,
      SizedBox(
        width: w,
        child: _buildTableArea(scale),
      ),
    );
  }

  Widget _buildDraggableTotals(double scale) {
    final cfg = template.totalsConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 115.0;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 175.0;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 80.0) * scale;

    return _buildDraggableOverlay(
      'totals',
      x,
      y,
      scale,
      SizedBox(
        width: w,
        child: _buildTotalsCard(scale),
      ),
    );
  }

  Widget _buildTotalsCard(double scale) {
    return Container(
      padding: EdgeInsets.all(3 * scale),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (template.totalBrutConfig['visible'] == true)
            _buildTotalsRow('Sous-total HT:', scale),
          if (template.totalRemisesConfig['visible'] != false)
            _buildTotalsRow('Remises:', scale),
          if (template.totalHTConfig['visible'] != false)
            _buildTotalsRow('Total HT:', scale),
          if (template.taxesConfig['visible'] != false)
            _buildTotalsRow('TVA:', scale),
          if (template.timbreConfig['visible'] != false)
            _buildTotalsRow('Timbre Fiscal:', scale),
          if (template.totalTTCConfig['visible'] != false)
            Container(
              margin: EdgeInsets.only(top: 1.5 * scale),
              padding: EdgeInsets.symmetric(vertical: 1.5 * scale, horizontal: 2 * scale),
              decoration: BoxDecoration(
                color: template.totalTTCConfig['showColoredBg'] == true
                    ? Color(template.totalTTCConfig['bgColor'] as int? ?? 0xFF2D3748)
                    : null,
                borderRadius: BorderRadius.circular(1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL TTC:',
                    style: TextStyle(
                      fontSize: 3.5 * scale,
                      fontWeight: FontWeight.bold,
                      color: template.totalTTCConfig['showColoredBg'] == true ? AppColors.surface : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '0,00',
                    style: TextStyle(
                      fontSize: 3.5 * scale,
                      fontWeight: FontWeight.bold,
                      color: template.totalTTCConfig['showColoredBg'] == true ? AppColors.surface : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          if (template.totalLettersConfig['visible'] == true)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Text(
                'Arrêté la présente facture à...',
                style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalsRow(String label, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.8 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 2.8 * scale, color: AppColors.textSecondary)),
          Text('0,00', style: TextStyle(fontSize: 2.8 * scale)),
        ],
      ),
    );
  }

  Widget _buildDraggableNotes(double scale) {
    final foot = template.footerConfig;
    if (foot['showNotes'] == false && foot['showPaymentTerms'] == false) return const SizedBox.shrink();

    final cfg = template.config['notes'] as Map<String, dynamic>? ?? {};
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15.0;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 175.0;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 95.0) * scale;

    return _buildDraggableOverlay(
      'notes',
      x,
      y,
      scale,
      Container(
        width: w,
        padding: EdgeInsets.all(3 * scale),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (foot['showNotes'] != false) ...[
              Text('Notes :', style: TextStyle(fontSize: 2.6 * scale, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              SizedBox(height: 1 * scale),
              Text('Merci pour votre confiance.', style: TextStyle(fontSize: 2.3 * scale, color: AppColors.textTertiary)),
              SizedBox(height: 2 * scale),
            ],
            if (foot['showPaymentTerms'] != false) ...[
              Text('Conditions Générales :', style: TextStyle(fontSize: 2.6 * scale, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              SizedBox(height: 1 * scale),
              Text('Paiement selon conditions convenues.', style: TextStyle(fontSize: 2.3 * scale, color: AppColors.textTertiary)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableSignature(double scale) {
    final foot = template.footerConfig;
    if (foot['showSignature'] == false) return const SizedBox.shrink();

    final cfg = template.config['signature'] as Map<String, dynamic>? ?? {};
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 135.0;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 230.0;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 60.0) * scale;

    return _buildDraggableOverlay(
      'signature',
      x,
      y,
      scale,
      Container(
        width: w,
        padding: EdgeInsets.symmetric(horizontal: 3 * scale, vertical: 2 * scale),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Text('Signature & Cachet', style: TextStyle(fontSize: 2.6 * scale, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            SizedBox(height: 10 * scale),
            Container(height: 0.5 * scale, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableLegalNotice(double scale) {
    final foot = template.footerConfig;
    if (foot['showLegalNotice'] == false && foot['showPageNumbers'] == false) return const SizedBox.shrink();

    final cfg = template.config['legalNotice'] as Map<String, dynamic>? ?? {};
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15.0;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 272.0;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 180.0) * scale;

    return _buildDraggableOverlay(
      'legalNotice',
      x,
      y,
      scale,
      Container(
        width: w,
        padding: EdgeInsets.symmetric(horizontal: 3 * scale, vertical: 1.5 * scale),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(1),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (foot['showLegalNotice'] != false)
              Text('Mentions légales - RIB & Identification fiscale', style: TextStyle(fontSize: 2.4 * scale, color: AppColors.textTertiary)),
            if (foot['showPageNumbers'] != false) ...[
              SizedBox(height: 1 * scale),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Page 1 / 1', style: TextStyle(fontSize: 2.0 * scale, color: AppColors.textTertiary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableOverlay(
    String itemKey,
    double x,
    double y,
    double scale,
    Widget child,
  ) {
    if (onPositionChanged == null) {
      return Positioned(left: x * scale, top: y * scale, child: child);
    }
    return _InteractiveOverlay(
      itemKey: itemKey,
      initialX: x,
      initialY: y,
      scale: scale,
      onPositionChanged: onPositionChanged!,
      child: child,
    );
  }

  Widget _buildQrCodeOverlay(double scale) {
    final cfg = template.qrCodeConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 98;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 25) * scale;
    final h = ((cfg['height'] as num?)?.toDouble() ?? 25) * scale;

    return _buildDraggableOverlay(
      'qrCode', x, y, scale,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cfg['showLabel'] == true)
            Text(
              cfg['labelText'] as String? ?? 'E-Facture',
              style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textSecondary),
            ),
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.textTertiary, width: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
            child: Center(
              child: Icon(Icons.qr_code_2_rounded, size: w * 0.7, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTtnOverlay(double scale) {
    final cfg = template.ttnReferenceConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 45;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 99;
    final fontSize = ((cfg['fontSize'] as num?)?.toDouble() ?? 9) * scale * 0.4;

    return _buildDraggableOverlay(
      'ttnReference', x, y, scale,
      Text(
        'Réf TTN: XXXXXXXXX',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: cfg['fontWeight'] == 'Gras' || cfg['fontWeight'] == 'Graisse'
              ? FontWeight.bold
              : FontWeight.normal,
          color: Color(cfg['color'] as int? ?? 0xFF1a56db),
        ),
      ),
    );
  }

  Widget _buildSubmissionDateOverlay(double scale) {
    final cfg = template.submissionDateConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 45;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 232;
    final fontSize = ((cfg['fontSize'] as num?)?.toDouble() ?? 8) * scale * 0.4;

    return _buildDraggableOverlay(
      'submissionDate', x, y, scale,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cfg['showLabel'] == true)
            Text(
              cfg['labelText'] as String? ?? 'Envoyé le:',
              style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textSecondary),
            ),
          Text(
            '12/10/2024 14:30',
            style: TextStyle(
              fontSize: fontSize,
              color: Color(cfg['color'] as int? ?? 0xFF000000),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadgeOverlay(double scale) {
    final cfg = template.statusBadgeConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 45;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 239;

    final statuses = [
      ('EN ATTENTE', const Color(0xFFF59E0B)),
      ('ENVOYÉ', const Color(0xFF3B82F6)),
      ('VALIDÉ', const Color(0xFF10B981)),
      ('REJETÉ', const Color(0xFFEF4444)),
    ];

    return _buildDraggableOverlay(
      'statusBadge', x, y, scale,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: statuses
            .map((s) => Container(
                  margin: EdgeInsets.only(right: 1.5 * scale),
                  padding: EdgeInsets.symmetric(horizontal: 2 * scale, vertical: 0.8 * scale),
                  decoration: BoxDecoration(
                    color: s.$2,
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: Text(s.$1, style: TextStyle(fontSize: 2 * scale, color: Colors.white, fontWeight: FontWeight.w600)),
                ))
            .toList(),
      ),
    );
  }
}

class _InteractiveOverlay extends StatefulWidget {
  final String itemKey;
  final double initialX;
  final double initialY;
  final double scale;
  final void Function(String itemKey, double newX, double newY) onPositionChanged;
  final Widget child;

  const _InteractiveOverlay({
    required this.itemKey,
    required this.initialX,
    required this.initialY,
    required this.scale,
    required this.onPositionChanged,
    required this.child,
  });

  @override
  State<_InteractiveOverlay> createState() => _InteractiveOverlayState();
}

class _InteractiveOverlayState extends State<_InteractiveOverlay> {
  late double _currentX;
  late double _currentY;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentX = widget.initialX;
    _currentY = widget.initialY;
  }

  @override
  void didUpdateWidget(covariant _InteractiveOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _currentX = widget.initialX;
      _currentY = widget.initialY;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _currentX * widget.scale,
      top: _currentY * widget.scale,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _currentX += details.delta.dx / widget.scale;
            _currentY += details.delta.dy / widget.scale;
            // Constrain
            _currentX = _currentX.clamp(0.0, 210.0);
            _currentY = _currentY.clamp(0.0, 297.0);
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          widget.onPositionChanged(widget.itemKey, _currentX, _currentY);
        },
        onPanCancel: () {
          setState(() => _isDragging = false);
          widget.onPositionChanged(widget.itemKey, _currentX, _currentY);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isDragging 
                    ? AppColors.primary 
                    : AppColors.primary.withValues(alpha: 0.3),
                width: _isDragging ? 2 : 1,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
