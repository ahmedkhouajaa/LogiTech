import 'package:flutter/material.dart';
import '../models/document_template.dart';
import '../utils/constants.dart';

/// Widget-based preview of the invoice template.
/// Renders a simplified A4-proportioned view that updates reactively.
class TemplatePreviewWidget extends StatelessWidget {
  final DocumentTemplate template;
  final void Function(String itemKey, double newX, double newY)? onPositionChanged;

  const TemplatePreviewWidget({
    super.key, 
    required this.template,
    this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Éditeur de modèle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 210 / 297, // A4 proportions
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.md,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scale = constraints.maxWidth / 210; // scale factor (mm → px)
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(10 * scale),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 85 * scale), // Space for absolute header
                                  _buildTableArea(scale),
                                  const Spacer(),
                                  _buildTotalsArea(scale),
                                  SizedBox(height: 6 * scale),
                                  _buildFooterArea(scale),
                                ],
                              ),
                            ),
                            // Header and Client Elements
                            _buildDraggableLogo(scale),
                            _buildDraggableCompanyName(scale),
                            _buildDraggableCompanyDetails(scale),
                            _buildDraggableDocumentTitle(scale),
                            _buildDraggableClientDetails(scale),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableLogo(double scale) {
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
    final cfg = template.companyNameConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 40;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 15;

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
    final cfg = template.companyDetailsConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 40;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 22;

    return _buildDraggableOverlay(
      'companyDetails', x, y, scale,
      Text('Détails de l\'entreprise', style: TextStyle(fontSize: 3 * scale, color: AppColors.textTertiary)),
    );
  }

  Widget _buildDraggableDocumentTitle(double scale) {
    final cfg = template.documentTitleConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 140;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 15;

    return _buildDraggableOverlay(
      'documentTitle', x, y, scale,
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
    );
  }

  Widget _buildDraggableClientDetails(double scale) {
    final cfg = template.clientDetailsConfig;
    final x = (cfg['positionX'] as num?)?.toDouble() ?? 15;
    final y = (cfg['positionY'] as num?)?.toDouble() ?? 45;
    final w = ((cfg['width'] as num?)?.toDouble() ?? 180) * scale;
    final h = ((cfg['height'] as num?)?.toDouble() ?? 30) * scale;

    return _buildDraggableOverlay(
      'clientDetails', x, y, scale,
      Container(
        width: w,
        height: h,
        padding: EdgeInsets.all(3 * scale),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Détails client', style: TextStyle(fontSize: 3.5 * scale, fontWeight: FontWeight.w600)),
            SizedBox(height: 1 * scale),
            Container(height: 2 * scale, width: w * 0.6, color: AppColors.surfaceAlt),
            SizedBox(height: 1 * scale),
            Container(height: 2 * scale, width: w * 0.4, color: AppColors.surfaceAlt),
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

  Widget _buildTotalsArea(double scale) {
    final cfg = template.totalsConfig;
    final currentX = (cfg['positionX'] as num?)?.toDouble() ?? 130.0;
    final width = ((cfg['width'] as num?)?.toDouble() ?? 70) * scale;

    final child = Container(
      width: width,
      padding: EdgeInsets.all(3 * scale),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          if (template.totalBrutConfig['visible'] == true)
            _buildTotalsRow('Sous-total HT:', scale),
          if (template.totalRemisesConfig['visible'] == true)
            _buildTotalsRow('Remises:', scale),
          _buildTotalsRow('Total HT:', scale),
          _buildTotalsRow('Taxes:', scale),
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
                  'TOTAL:',
                  style: TextStyle(
                    fontSize: 3.5 * scale,
                    fontWeight: FontWeight.bold,
                    color: template.totalTTCConfig['showColoredBg'] == true ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '0,00',
                  style: TextStyle(
                    fontSize: 3.5 * scale,
                    fontWeight: FontWeight.bold,
                    color: template.totalTTCConfig['showColoredBg'] == true ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (template.totalLettersConfig['visible'] == true)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Text(
                'Montant en lettres...',
                style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );

    if (onPositionChanged == null) {
      return Padding(
        padding: EdgeInsets.only(left: currentX * scale),
        child: child,
      );
    }

    return _InteractiveHorizontalOverlay(
      itemKey: 'totals',
      initialX: currentX,
      scale: scale,
      onPositionChanged: onPositionChanged!,
      child: child,
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

  Widget _buildFooterArea(double scale) {
    return Column(
      children: [
        Divider(height: 1, color: AppColors.border),
        SizedBox(height: 2 * scale),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Notes de document', style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textTertiary)),
            Text('Conditions de paiement', style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textTertiary)),
          ],
        ),
        SizedBox(height: 2 * scale),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(2 * scale),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(1),
          ),
          child: Center(
            child: Text('Texte de pied de page', style: TextStyle(fontSize: 2.5 * scale, color: AppColors.textTertiary)),
          ),
        ),
      ],
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

class _InteractiveHorizontalOverlay extends StatefulWidget {
  final String itemKey;
  final double initialX;
  final double scale;
  final void Function(String itemKey, double newX, double newY) onPositionChanged;
  final Widget child;

  const _InteractiveHorizontalOverlay({
    required this.itemKey,
    required this.initialX,
    required this.scale,
    required this.onPositionChanged,
    required this.child,
  });

  @override
  State<_InteractiveHorizontalOverlay> createState() => _InteractiveHorizontalOverlayState();
}

class _InteractiveHorizontalOverlayState extends State<_InteractiveHorizontalOverlay> {
  late double _currentX;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentX = widget.initialX;
  }

  @override
  void didUpdateWidget(covariant _InteractiveHorizontalOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _currentX = widget.initialX;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: _currentX * widget.scale),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _currentX += details.delta.dx / widget.scale;
            // Constrain width somewhat
            // A4 width is 210mm. _currentX + width must be <= 210 to avoid overflow.
            // Width is not passed, but totals width is usually max 120mm. Let's clamp at 140.
            _currentX = _currentX.clamp(0.0, 140.0);
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
          widget.onPositionChanged(widget.itemKey, _currentX, 0); // Y is ignored for totals
        },
        onPanCancel: () {
          setState(() => _isDragging = false);
          widget.onPositionChanged(widget.itemKey, _currentX, 0);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isDragging 
                    ? AppColors.primary 
                    : AppColors.primary.withValues(alpha: 0.1),
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
