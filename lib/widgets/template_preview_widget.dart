import 'package:flutter/material.dart';
import '../models/document_template.dart';
import '../services/enterprise_service.dart';
import '../utils/company_logo_helper.dart';
import '../utils/constants.dart';

/// Widget-based preview of the invoice template.
/// Renders a simplified A4-proportioned view that updates reactively.
class TemplatePreviewWidget extends StatelessWidget {
  final DocumentTemplate template;
  final void Function(String itemKey, double newX, double newY)? onPositionChanged;
  final String? selectedItemKey;
  final void Function(String? itemKey)? onItemSelected;
  final void Function(
    String itemKey, {
    double? width,
    double? height,
    double? sizeDelta,
    double? widthDelta,
    double? heightDelta,
  })? onSizeChanged;
  final bool showHeader;

  const TemplatePreviewWidget({
    super.key, 
    required this.template,
    this.onPositionChanged,
    this.selectedItemKey,
    this.onItemSelected,
    this.onSizeChanged,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final pageCanvas = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
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
                final items = <Widget>[
                  // Header & Client Elements
                  _buildDraggableLogo(scale),
                  _buildDraggableCompanyName(scale),
                  _buildDraggableCompanyDetails(scale),
                  _buildDraggableDocumentTitle(scale),
                  _buildDraggableClientDetails(scale),
                  // Article Table
                  _buildDraggableTable(scale),
                  // Custom Fields (positioned around/under the table)
                  _buildDraggableCustomFields(scale),
                  // Notes & Conditions
                  _buildDraggableNotes(scale),
                  // Custom free-form texts
                  ...template.customTexts.map((ct) => _buildDraggableCustomText(ct, scale)),
                  // Totals
                  _buildDraggableTotals(scale),
                  // Signature
                  _buildDraggableSignature(scale),
                  // Stamp (Cachet de l'entreprise)
                  _buildDraggableStamp(scale),
                  // Mentions légales & Footer
                  _buildDraggableLegalNotice(scale),
                ];

                // Filter out empty widgets
                final activeItems = items.where((w) => w is! SizedBox).toList();

                // If an element is selected, ensure it paints last (on top)
                if (selectedItemKey != null) {
                  final idx = activeItems.indexWhere((w) {
                    if (w is _InteractiveOverlay) {
                      return w.itemKey == selectedItemKey;
                    }
                    return false;
                  });
                  if (idx != -1) {
                    final selectedWidget = activeItems.removeAt(idx);
                    activeItems.add(selectedWidget);
                  }
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onItemSelected?.call(null),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: activeItems,
                    ),
                  ),
                );
              },
            ),
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
          padding: EdgeInsets.all(isNarrow ? 8 : 12),
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
              SizedBox(height: isNarrow ? 6 : 8),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: pageCanvas,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableLogo(double scale) {
    if (template.companyInfoConfig['showLogo'] == false) return const SizedBox.shrink();

    final cfg = template.logoConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 15;
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 20;
    final hMm = (cfg['height'] as num?)?.toDouble() ?? 15;
    final w = wMm * scale;
    final h = hMm * scale;

    final logoData = EnterpriseService.instance.currentEnterprise?.logoUrl;
    final logoBytes = CompanyLogoHelper.decodeBase64Logo(logoData);

    return _buildDraggableOverlay(
      itemKey: 'logo',
      label: 'Logo',
      icon: Icons.image_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      heightMm: hMm,
      canResizeWidth: true,
      canResizeHeight: true,
      canResizeScale: true,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: logoBytes != null && logoBytes.isNotEmpty
              ? Image.memory(logoBytes, fit: BoxFit.contain)
              : Center(
                  child: Text('Logo', style: TextStyle(fontSize: (3.5 * scale).clamp(6.0, 14.0), color: AppColors.textTertiary)),
                ),
        ),
      ),
    );
  }

  Widget _buildDraggableCompanyName(double scale) {
    if (template.companyInfoConfig['showName'] == false) return const SizedBox.shrink();

    final showLogo = template.companyInfoConfig['showLogo'] != false;
    final defaultX = showLogo ? 40.0 : 15.0;
    final cfg = template.companyNameConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? defaultX;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 15.0;
    final fs = (cfg['fontSize'] as num?)?.toDouble() ?? 16.0;

    return _buildDraggableOverlay(
      itemKey: 'companyName',
      label: 'Nom Société',
      icon: Icons.business_rounded,
      x: x,
      y: y,
      scale: scale,
      canResizeScale: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3 * scale, vertical: 1.5 * scale),
        decoration: BoxDecoration(
          color: Color(template.headerBgColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          'Nom de l\'entreprise',
          style: TextStyle(
            fontSize: (fs * 0.28 * scale).clamp(7.0, 32.0),
            fontWeight: FontWeight.bold,
            color: Color(template.headerBgColor),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableCompanyDetails(double scale) {
    final comp = template.companyInfoConfig;
    final showLogo = comp['showLogo'] != false;
    final defaultX = showLogo ? 40.0 : 15.0;
    final cfg = template.companyDetailsConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? defaultX;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 22.0;
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 75.0;
    final fs = (cfg['fontSize'] as num?)?.toDouble() ?? 8.5;

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
      itemKey: 'companyDetails',
      label: 'Coordonnées',
      icon: Icons.info_outline_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      canResizeWidth: true,
      canResizeScale: true,
      child: SizedBox(
        width: wMm * scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: details.take(4).map((d) => Text(
            d,
            style: TextStyle(
              fontSize: (fs * 0.32 * scale).clamp(5.5, 16.0),
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildDraggableDocumentTitle(double scale) {
    final docInfo = template.documentInfoConfig;
    final cfg = template.documentTitleConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 140;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 15;
    final fs = (cfg['fontSize'] as num?)?.toDouble() ?? 13.0;

    return _buildDraggableOverlay(
      itemKey: 'documentTitle',
      label: 'Titre Document',
      icon: Icons.receipt_long_rounded,
      x: x,
      y: y,
      scale: scale,
      canResizeScale: true,
      child: Column(
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
                style: TextStyle(
                  fontSize: (fs * 0.28 * scale).clamp(7.0, 26.0),
                  fontWeight: FontWeight.bold,
                  color: Color(template.headerTextColor),
                ),
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
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 180;
    final hMm = (cfg['height'] as num?)?.toDouble() ?? 30;
    final fs = (cfg['fontSize'] as num?)?.toDouble() ?? 8.5;
    final w = wMm * scale;
    final h = hMm * scale;

    final List<String> clientLines = [];
    if (cli['showName'] != false) clientLines.add('Client Passager / SARL Société');
    if (cli['showAddress'] != false) clientLines.add('Adresse: Rue Principale, Tunis');
    if (cli['showPhone'] != false) clientLines.add('Tél: +216 99 999 999');
    if (cli['showEmail'] != false) clientLines.add('client@email.com');
    if (cli['showCode'] != false) clientLines.add('Code: CLI-0012');
    if (cli['showTaxId'] != false) clientLines.add('MF: 1234567/B/M/000');

    return _buildDraggableOverlay(
      itemKey: 'clientDetails',
      label: 'Cadre Client',
      icon: Icons.person_pin_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      heightMm: hMm,
      canResizeWidth: true,
      canResizeHeight: true,
      canResizeScale: true,
      child: Container(
        width: w,
        constraints: BoxConstraints(minHeight: h),
        padding: EdgeInsets.all(3 * scale),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Adressé à :',
              style: TextStyle(
                fontSize: (fs * 0.35 * scale).clamp(6.0, 16.0),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 1 * scale),
            ...clientLines.map((l) => Text(
              l,
              style: TextStyle(
                fontSize: (fs * 0.30 * scale).clamp(5.0, 14.0),
                color: AppColors.textSecondary,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableCustomFields(double scale) {
    final customFieldsMap = Map<String, dynamic>.from(template.config['customFields'] as Map? ?? {});
    final customLabels = Map<String, dynamic>.from(template.config['customFieldsLabels'] as Map? ?? {});

    final activeFields = <MapEntry<String, String>>[];
    final seenLabels = <String>{};
    for (final entry in customLabels.entries) {
      final key = entry.key;
      final label = entry.value.toString();
      if (seenLabels.contains(label)) continue;
      if (customFieldsMap[key] == false || customFieldsMap[label] == false) {
        continue;
      }
      seenLabels.add(label);
      activeFields.add(MapEntry(key, label));
    }

    if (activeFields.isEmpty) return const SizedBox.shrink();

    final cfg = template.config['customFieldsBox'] as Map<String, dynamic>? ?? {};
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15.0;
    var y = (cfg['positionY'] as num?)?.toDouble() ?? 150.0;
    if (y == 76.0 && cfg['_migratedY'] != true) y = 150.0;
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 180.0;
    final fs = (cfg['fontSize'] as num?)?.toDouble() ?? 8.5;
    final w = wMm * scale;

    return _buildDraggableOverlay(
      itemKey: 'customFieldsBox',
      label: 'Champs Personnalisés',
      icon: Icons.tune_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      canResizeWidth: true,
      canResizeScale: true,
      child: Container(
        width: w,
        padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2.5 * scale),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 0.5),
        ),
        child: Wrap(
          spacing: 8 * scale,
          runSpacing: 2 * scale,
          children: activeFields.map((f) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${f.value} : ',
                  style: TextStyle(
                    fontSize: (fs * 0.32 * scale).clamp(5.0, 14.0),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Exemple',
                  style: TextStyle(
                    fontSize: (fs * 0.30 * scale).clamp(5.0, 14.0),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          }).toList(),
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
    final rowHeightMm = (template.tableConfig['rowHeight'] as num?)?.toDouble() ?? 
        (template.config['rowHeight'] as num?)?.toDouble() ?? 8.0;
    final fs = (template.config['fontSize'] as num?)?.toDouble() ?? 10.0;

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
                    style: TextStyle(
                      fontSize: (fs * 0.25 * scale).clamp(5.0, 14.0),
                      fontWeight: FontWeight.bold,
                      color: headerFg,
                    ),
                    textAlign: isDesignation ? TextAlign.left : TextAlign.right,
                  ),
                );
              }).toList(),
            ),
          ),
          // Data rows
          for (int i = 0; i < 4; i++)
            Container(
              height: (rowHeightMm * scale * 0.45).clamp(8.0, 30.0),
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
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 180.0;
    final rhMm = (cfg['rowHeight'] as num?)?.toDouble() ?? 8.0;
    final w = wMm * scale;

    return _buildDraggableOverlay(
      itemKey: 'table',
      label: 'Tableau Articles',
      icon: Icons.table_chart_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      heightMm: rhMm,
      canResizeWidth: true,
      canResizeHeight: true,
      canResizeScale: true,
      child: SizedBox(
        width: w,
        child: _buildTableArea(scale),
      ),
    );
  }

  Widget _buildDraggableTotals(double scale) {
    final cfg = template.totalsConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 115.0;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 175.0;
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 80.0;
    final w = wMm * scale;

    return _buildDraggableOverlay(
      itemKey: 'totals',
      label: 'Bloc Totaux',
      icon: Icons.calculate_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      canResizeWidth: true,
      canResizeScale: true,
      child: SizedBox(
        width: w,
        child: _buildTotalsCard(scale),
      ),
    );
  }

  Widget _buildTotalsCard(double scale) {
    final cfg = template.totalsConfig;
    final fs = (cfg['fontSize'] as num?)?.toDouble() ?? 10.0;

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
            _buildTotalsRow('Sous-total HT:', scale, fs),
          if (template.totalRemisesConfig['visible'] != false)
            _buildTotalsRow('Remises:', scale, fs),
          if (template.totalHTConfig['visible'] != false)
            _buildTotalsRow('Total HT:', scale, fs),
          if (template.taxesConfig['visible'] != false)
            _buildTotalsRow('TVA:', scale, fs),
          if (template.timbreConfig['visible'] != false)
            _buildTotalsRow('Timbre Fiscal:', scale, fs),
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
                      fontSize: (fs * 0.35 * scale).clamp(6.0, 16.0),
                      fontWeight: FontWeight.bold,
                      color: template.totalTTCConfig['showColoredBg'] == true ? AppColors.surface : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '0,00',
                    style: TextStyle(
                      fontSize: (fs * 0.35 * scale).clamp(6.0, 16.0),
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

  Widget _buildTotalsRow(String label, double scale, [double fontSize = 10.0]) {
    final sz = (fontSize * 0.28 * scale).clamp(5.0, 14.0);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.8 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: sz, color: AppColors.textSecondary)),
          Text('0,00', style: TextStyle(fontSize: sz, fontWeight: FontWeight.w500)),
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
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 95.0;
    final hMm = (cfg['height'] as num?)?.toDouble() ?? 30.0;
    final w = wMm * scale;
    final h = hMm * scale;

    return _buildDraggableOverlay(
      itemKey: 'notes',
      label: 'Notes & Conditions',
      icon: Icons.notes_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      heightMm: hMm,
      canResizeWidth: true,
      canResizeHeight: true,
      canResizeScale: true,
      child: Container(
        width: w,
        constraints: BoxConstraints(minHeight: h),
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
              Text(template.notesText, style: TextStyle(fontSize: 2.3 * scale, color: AppColors.textTertiary)),
              SizedBox(height: 2 * scale),
            ],
            if (foot['showPaymentTerms'] != false) ...[
              Text('Conditions Générales :', style: TextStyle(fontSize: 2.6 * scale, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              SizedBox(height: 1 * scale),
              Text(template.paymentTermsText, style: TextStyle(fontSize: 2.3 * scale, color: AppColors.textTertiary)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableCustomText(Map<String, dynamic> item, double scale) {
    final id = item['id'] as String? ?? 'custom';
    final text = item['text'] as String? ?? '';
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final x = (item['positionX'] as num?)?.toDouble() ?? 15.0;
    final y = (item['positionY'] as num?)?.toDouble() ?? 165.0;
    final wMm = (item['width'] as num?)?.toDouble() ?? 60.0;
    final fontSize = ((item['fontSize'] as num?)?.toDouble() ?? 9.0) * scale * 0.35;
    final isBold = item['isBold'] == true;
    final isItalic = item['isItalic'] == true;
    final color = Color(item['color'] as int? ?? 0xFF000000);
    final alignmentStr = item['alignment'] as String? ?? 'left';
    final textAlign = alignmentStr == 'center'
        ? TextAlign.center
        : alignmentStr == 'right'
            ? TextAlign.right
            : TextAlign.left;

    return _buildDraggableOverlay(
      itemKey: 'customText_$id',
      label: 'Texte: ${text.length > 10 ? '${text.substring(0, 10)}...' : text}',
      icon: Icons.text_fields_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      canResizeWidth: true,
      canResizeScale: true,
      child: Container(
        constraints: BoxConstraints(maxWidth: wMm * scale),
        padding: EdgeInsets.symmetric(horizontal: 2.5 * scale, vertical: 1.5 * scale),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 0.5),
        ),
        child: Text(
          text,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: fontSize.clamp(4.0, 30.0),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            color: color,
          ),
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
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 60.0;
    final hMm = (cfg['height'] as num?)?.toDouble() ?? 25.0;
    final w = wMm * scale;
    final h = hMm * scale;

    return _buildDraggableOverlay(
      itemKey: 'signature',
      label: 'Signature',
      icon: Icons.draw_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      heightMm: hMm,
      canResizeWidth: true,
      canResizeHeight: true,
      canResizeScale: true,
      child: Container(
        width: w,
        constraints: BoxConstraints(minHeight: h),
        padding: EdgeInsets.symmetric(horizontal: 3 * scale, vertical: 2 * scale),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Signature & Cachet', style: TextStyle(fontSize: 2.6 * scale, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            SizedBox(height: (h * 0.35).clamp(6.0, 20.0)),
            Container(height: 0.5 * scale, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableStamp(double scale) {
    final comp = template.companyInfoConfig;
    final stampCfg = template.stampConfig;
    final isVisible = comp['showStamp'] == true || stampCfg['visible'] == true;
    if (!isVisible) return const SizedBox.shrink();

    final x = (stampCfg['positionX'] as num?)?.toDouble() ?? 140.0;
    final y = (stampCfg['positionY'] as num?)?.toDouble() ?? 225.0;
    final wMm = ((stampCfg['width'] as num?)?.toDouble() ?? 35.0).clamp(15.0, 80.0);
    final hMm = ((stampCfg['height'] as num?)?.toDouble() ?? 35.0).clamp(15.0, 80.0);
    final w = wMm * scale;
    final h = hMm * scale;

    final currentStampUrl = EnterpriseService.instance.currentEnterprise?.stampUrl;
    final stampBytes = CompanyLogoHelper.decodeBase64Logo(currentStampUrl);

    return _buildDraggableOverlay(
      itemKey: 'stamp',
      label: 'Cachet',
      icon: Icons.verified_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      heightMm: hMm,
      canResizeWidth: true,
      canResizeHeight: true,
      canResizeScale: true,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF1E40AF).withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: stampBytes != null && stampBytes.isNotEmpty
              ? Image.memory(
                  stampBytes,
                  fit: BoxFit.contain,
                  width: w,
                  height: h,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: (w * 0.35).clamp(8.0, 24.0),
                        color: const Color(0xFF1E40AF),
                      ),
                      SizedBox(height: 1 * scale),
                      Text(
                        'CACHET',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: (2.2 * scale).clamp(5.0, 12.0),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E40AF),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
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
    final wMm = (cfg['width'] as num?)?.toDouble() ?? 180.0;
    final fs = (cfg['fontSize'] as num?)?.toDouble() ?? 7.5;
    final w = wMm * scale;

    return _buildDraggableOverlay(
      itemKey: 'legalNotice',
      label: 'Mentions Légales',
      icon: Icons.gavel_rounded,
      x: x,
      y: y,
      scale: scale,
      widthMm: wMm,
      canResizeWidth: true,
      canResizeScale: true,
      child: Container(
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
              Text(
                'Mentions légales - RIB & Identification fiscale',
                style: TextStyle(
                  fontSize: (fs * 0.32 * scale).clamp(5.0, 12.0),
                  color: AppColors.textTertiary,
                ),
              ),
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

  Widget _buildDraggableOverlay({
    required String itemKey,
    required String label,
    required IconData icon,
    required double x,
    required double y,
    required double scale,
    double? widthMm,
    double? heightMm,
    bool canResizeWidth = false,
    bool canResizeHeight = false,
    bool canResizeScale = true,
    required Widget child,
  }) {
    final isSelected = selectedItemKey == itemKey;
    return _InteractiveOverlay(
      key: ValueKey(itemKey),
      itemKey: itemKey,
      label: label,
      icon: icon,
      initialX: x,
      initialY: y,
      scale: scale,
      widthMm: widthMm,
      heightMm: heightMm,
      canResizeWidth: canResizeWidth,
      canResizeHeight: canResizeHeight,
      canResizeScale: canResizeScale,
      isSelected: isSelected,
      onSelect: () => onItemSelected?.call(isSelected ? null : itemKey),
      onPositionChanged: onPositionChanged,
      onSizeChanged: onSizeChanged,
      child: child,
    );
  }
}

class _InteractiveOverlay extends StatefulWidget {
  final String itemKey;
  final String label;
  final IconData icon;
  final double initialX;
  final double initialY;
  final double scale;
  final double? widthMm;
  final double? heightMm;
  final bool canResizeWidth;
  final bool canResizeHeight;
  final bool canResizeScale;
  final bool isSelected;
  final VoidCallback onSelect;
  final void Function(String itemKey, double newX, double newY)? onPositionChanged;
  final void Function(
    String itemKey, {
    double? width,
    double? height,
    double? sizeDelta,
    double? widthDelta,
    double? heightDelta,
  })? onSizeChanged;
  final Widget child;

  const _InteractiveOverlay({
    super.key,
    required this.itemKey,
    required this.label,
    required this.icon,
    required this.initialX,
    required this.initialY,
    required this.scale,
    this.widthMm,
    this.heightMm,
    this.canResizeWidth = false,
    this.canResizeHeight = false,
    this.canResizeScale = true,
    this.isSelected = false,
    required this.onSelect,
    this.onPositionChanged,
    this.onSizeChanged,
    required this.child,
  });

  @override
  State<_InteractiveOverlay> createState() => _InteractiveOverlayState();
}

class _InteractiveOverlayState extends State<_InteractiveOverlay> {
  late double _currentX;
  late double _currentY;
  bool _isDragging = false;
  bool _isHovered = false;

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

  Widget _buildQuickBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Icon(icon, size: 13, color: color ?? AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: AppColors.border,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final scale = widget.scale;
    final isNearTop = _currentY < 32.0;

    return Positioned(
      left: _currentX * scale,
      top: _currentY * scale,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: isSelected ? SystemMouseCursors.grab : SystemMouseCursors.click,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main content block
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSelect,
              onPanStart: (_) {
                setState(() => _isDragging = true);
                if (!isSelected) widget.onSelect();
              },
              onPanUpdate: (details) {
                setState(() {
                  _currentX += details.delta.dx / scale;
                  _currentY += details.delta.dy / scale;
                  _currentX = _currentX.clamp(0.0, 205.0);
                  _currentY = _currentY.clamp(0.0, 290.0);
                });
              },
              onPanEnd: (_) {
                setState(() => _isDragging = false);
                widget.onPositionChanged?.call(widget.itemKey, _currentX, _currentY);
              },
              onPanCancel: () {
                setState(() => _isDragging = false);
                widget.onPositionChanged?.call(widget.itemKey, _currentX, _currentY);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : _isHovered
                            ? AppColors.primary.withValues(alpha: 0.6)
                            : AppColors.primary.withValues(alpha: 0.25),
                    width: isSelected ? 2.0 : (_isHovered ? 1.5 : 0.8),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: widget.child,
              ),
            ),

            // Selection controls & Handles when active
            if (isSelected) ...[
              // Corner Resize Handle (Bottom-Right: ↘)
              if (widget.canResizeWidth || widget.canResizeHeight || widget.canResizeScale)
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        final dx = details.delta.dx / scale;
                        final dy = details.delta.dy / scale;
                        widget.onSizeChanged?.call(
                          widget.itemKey,
                          widthDelta: widget.canResizeWidth ? dx : null,
                          heightDelta: widget.canResizeHeight ? dy : null,
                          sizeDelta: (dx + dy) / 2,
                        );
                      },
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.open_in_full_rounded, size: 8, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),

              // Right Edge Resize Handle (↔)
              if (widget.canResizeWidth)
                Positioned(
                  right: -6,
                  top: 4,
                  bottom: 4,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          final dx = details.delta.dx / scale;
                          widget.onSizeChanged?.call(widget.itemKey, widthDelta: dx);
                        },
                        child: Container(
                          width: 12,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.primary, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(Icons.drag_indicator_rounded, size: 9, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom Edge Resize Handle (↕)
              if (widget.canResizeHeight)
                Positioned(
                  bottom: -6,
                  left: 4,
                  right: 4,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          final dy = details.delta.dy / scale;
                          widget.onSizeChanged?.call(widget.itemKey, heightDelta: dy);
                        },
                        child: Container(
                          width: 18,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppColors.primary, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Icon(Icons.drag_indicator_rounded, size: 9, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating Mini-Toolbar with Quick Size / Width / Height buttons
              Positioned(
                left: 0,
                bottom: isNearTop ? -32 : null,
                top: isNearTop ? null : -34,
                child: GestureDetector(
                  onTap: () {}, // avoid canvas tap
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label badge
                        Icon(widget.icon, size: 11, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          widget.label,
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        _buildDivider(),

                        // Global Size (Bigger / Smaller)
                        _buildQuickBtn(
                          icon: Icons.remove_rounded,
                          tooltip: 'Plus petit',
                          onPressed: () => widget.onSizeChanged?.call(widget.itemKey, sizeDelta: -1.0),
                        ),
                        Text('Taille', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        _buildQuickBtn(
                          icon: Icons.add_rounded,
                          tooltip: 'Plus grand',
                          onPressed: () => widget.onSizeChanged?.call(widget.itemKey, sizeDelta: 1.0),
                        ),

                        // Width controls
                        if (widget.canResizeWidth) ...[
                          _buildDivider(),
                          _buildQuickBtn(
                            icon: Icons.remove_rounded,
                            tooltip: 'Réduire largeur',
                            onPressed: () => widget.onSizeChanged?.call(widget.itemKey, widthDelta: -3.0),
                          ),
                          Text(
                            widget.widthMm != null ? 'L:${widget.widthMm!.round()}' : 'L',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          _buildQuickBtn(
                            icon: Icons.add_rounded,
                            tooltip: 'Agrandir largeur',
                            onPressed: () => widget.onSizeChanged?.call(widget.itemKey, widthDelta: 3.0),
                          ),
                        ],

                        // Height controls
                        if (widget.canResizeHeight) ...[
                          _buildDivider(),
                          _buildQuickBtn(
                            icon: Icons.remove_rounded,
                            tooltip: 'Réduire hauteur',
                            onPressed: () => widget.onSizeChanged?.call(widget.itemKey, heightDelta: -3.0),
                          ),
                          Text(
                            widget.heightMm != null ? 'H:${widget.heightMm!.round()}' : 'H',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                          _buildQuickBtn(
                            icon: Icons.add_rounded,
                            tooltip: 'Agrandir hauteur',
                            onPressed: () => widget.onSizeChanged?.call(widget.itemKey, heightDelta: 3.0),
                          ),
                        ],

                        _buildDivider(),
                        // Deselect button
                        _buildQuickBtn(
                          icon: Icons.close_rounded,
                          tooltip: 'Désélectionner',
                          color: AppColors.textTertiary,
                          onPressed: widget.onSelect,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
