import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../blocs/canvas_editor/canvas_editor_state.dart';
import '../../models/canvas/canvas_element.dart';
import '../../utils/constants.dart';

/// The central workspace that renders the A4 canvas with grid, margins,
/// and all placed elements with selection handles.
class CanvasWorkspace extends StatefulWidget {
  const CanvasWorkspace({super.key});

  @override
  State<CanvasWorkspace> createState() => _CanvasWorkspaceState();
}

class _CanvasWorkspaceState extends State<CanvasWorkspace> {
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CanvasEditorState>(
      builder: (context, state, _) {
        return Container(
          color: const Color(0xFF1E1E2E),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A4 aspect ratio: 210 × 297 mm
              // We'll use a scale where 1mm = some pixels
              const pageW = 210.0;
              const pageH = 297.0;

              // Calculate scale so the page fits nicely in the view
              final availW = constraints.maxWidth - 60; // padding
              final availH = constraints.maxHeight - 60;
              final fitScale = min(availW / pageW, availH / pageH);
              final scale = fitScale * state.zoom;

              final canvasW = pageW * scale;
              final canvasH = pageH * scale;

              return GestureDetector(
                onTap: () => state.deselectAll(),
                behavior: HitTestBehavior.opaque,
                child: InteractiveViewer(
                  transformationController: _transformCtrl,
                  boundaryMargin: const EdgeInsets.all(400),
                  minScale: 0.25,
                  maxScale: 4.0,
                  constrained: false,
                  child: Container(
                    width: canvasW + 80,
                    height: canvasH + 80,
                    alignment: Alignment.center,
                    child: _buildPage(state, scale, canvasW, canvasH),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPage(CanvasEditorState state, double scale, double canvasW, double canvasH) {
    final doc = state.document;

    return Container(
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: Color(doc.backgroundColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Grid
          if (doc.showGrid) _buildGrid(scale, canvasW, canvasH, doc.gridSize),
          // Margin guides
          _buildMargins(scale, canvasW, canvasH, doc),
          // Elements
          ...state.sortedElements.where((e) => e.isVisible).map(
                (el) => _buildCanvasElement(state, el, scale),
              ),
        ],
      ),
    );
  }

  Widget _buildGrid(double scale, double w, double h, double gridSizeMm) {
    return CustomPaint(
      size: Size(w, h),
      painter: _GridPainter(
        gridSize: gridSizeMm * scale,
        color: const Color(0x0A000000),
      ),
    );
  }

  Widget _buildMargins(double scale, double w, double h, CanvasDocument doc) {
    final left = doc.marginLeft * scale;
    final top = doc.marginTop * scale;
    final right = doc.marginRight * scale;
    final bottom = doc.marginBottom * scale;

    return IgnorePointer(
      child: CustomPaint(
        size: Size(w, h),
        painter: _MarginPainter(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
      ),
    );
  }

  // ─── Element Rendering ──────────────────────────────────────────

  Widget _buildCanvasElement(CanvasEditorState state, CanvasElement el, double scale) {
    final isSelected = state.selectedElementId == el.id;
    final px = el.x * scale;
    final py = el.y * scale;
    final pw = el.width * scale;
    final ph = el.height * scale;

    return Positioned(
      left: px,
      top: py,
      child: GestureDetector(
        onTap: () {
          if (!el.isLocked) {
            state.selectElement(el.id);
          }
        },
        onPanStart: (details) {
          if (!el.isLocked) {
            state.selectElement(el.id);
            state.startDrag(el.id, details.globalPosition);
          }
        },
        onPanUpdate: (details) {
          state.updateDrag(details.globalPosition, scale);
        },
        onPanEnd: (_) => state.endDrag(),
        child: Transform.rotate(
          angle: el.rotation * pi / 180,
          child: Opacity(
            opacity: el.opacity,
            child: SizedBox(
              width: pw,
              height: ph,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Element visual
                  Positioned.fill(
                    child: ClipRect(
                      child: _renderElement(el, scale),
                    ),
                  ),
                  // Selection border + handles
                  if (isSelected) ...[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primaryLight,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Resize handles
                    ..._buildResizeHandles(state, el, scale, pw, ph),
                  ],
                  // Lock indicator
                  if (el.isLocked)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.lock, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderElement(CanvasElement el, double scale) {
    if (el is TextElement) return _renderText(el, scale);
    if (el is ShapeElement) return _renderShape(el, scale);
    if (el is ImageElement) return _renderImage(el, scale);
    if (el is DividerElement) return _renderDivider(el, scale);
    if (el is DynamicFieldElement) return _renderDynamicField(el, scale);
    if (el is CanvasTableElement) return _renderTable(el, scale);
    return const SizedBox.shrink();
  }

  Widget _renderText(TextElement el, double scale) {
    TextAlign align;
    switch (el.textAlign) {
      case CanvasTextAlign.center:
        align = TextAlign.center;
        break;
      case CanvasTextAlign.right:
        align = TextAlign.right;
        break;
      default:
        align = TextAlign.left;
    }

    return Container(
      alignment: Alignment.topLeft,
      child: Text(
        el.text,
        textAlign: align,
        style: TextStyle(
          fontSize: el.fontSize * scale / 2.83, // pt to px approx
          fontWeight: el.isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: el.isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: el.isUnderline ? TextDecoration.underline : null,
          color: Color(el.color),
          height: el.lineHeight,
        ),
        overflow: TextOverflow.clip,
      ),
    );
  }

  Widget _renderShape(ShapeElement el, double scale) {
    BoxDecoration decoration;
    switch (el.shapeKind) {
      case ShapeKind.circle:
        decoration = BoxDecoration(
          color: Color(el.fillColor),
          shape: BoxShape.circle,
          border: el.borderWidth > 0
              ? Border.all(color: Color(el.borderColor), width: el.borderWidth * scale / 3)
              : null,
        );
        break;
      case ShapeKind.roundedRect:
        decoration = BoxDecoration(
          color: Color(el.fillColor),
          borderRadius: BorderRadius.circular(el.borderRadius * scale / 3),
          border: el.borderWidth > 0
              ? Border.all(color: Color(el.borderColor), width: el.borderWidth * scale / 3)
              : null,
        );
        break;
      default:
        decoration = BoxDecoration(
          color: Color(el.fillColor),
          border: el.borderWidth > 0
              ? Border.all(color: Color(el.borderColor), width: el.borderWidth * scale / 3)
              : null,
        );
    }
    return Container(decoration: decoration);
  }

  Widget _renderImage(ImageElement el, double scale) {
    // TODO: Render actual image from file
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_rounded, size: 20 * scale / 3, color: const Color(0xFF94A3B8)),
          SizedBox(height: 2 * scale / 3),
          Text(
            el.placeholder,
            style: TextStyle(
              fontSize: 8 * scale / 3,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderDivider(DividerElement el, double scale) {
    if (el.isVertical) {
      return Center(
        child: Container(
          width: el.thickness * scale / 2,
          height: double.infinity,
          color: Color(el.color),
        ),
      );
    }
    return Center(
      child: Container(
        width: double.infinity,
        height: el.thickness * scale / 2,
        color: Color(el.color),
      ),
    );
  }

  Widget _renderDynamicField(DynamicFieldElement el, double scale) {
    final textScale = scale / 2.83;
    TextAlign align;
    switch (el.textAlign) {
      case CanvasTextAlign.center:
        align = TextAlign.center;
        break;
      case CanvasTextAlign.right:
        align = TextAlign.right;
        break;
      default:
        align = TextAlign.left;
    }

    return ClipRect(
      child: Container(
        padding: EdgeInsets.all(1 * scale / 3),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(2),
          color: const Color(0xFF3B82F6).withValues(alpha: 0.03),
        ),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          minWidth: 0,
          maxWidth: double.infinity,
          child: Column(
            crossAxisAlignment: align == TextAlign.right
                ? CrossAxisAlignment.end
                : align == TextAlign.center
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (el.showLabel && el.label.isNotEmpty)
                Text(
                  el.label,
                  style: TextStyle(
                    fontSize: (el.fontSize - 1) * textScale,
                    color: Color(el.color).withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              Text(
                el.sampleValue,
                textAlign: align,
                style: TextStyle(
                  fontSize: el.fontSize * textScale,
                  fontWeight: el.isBold ? FontWeight.bold : FontWeight.normal,
                  color: Color(el.color),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderTable(CanvasTableElement el, double scale) {
    final textScale = scale / 2.83;
    final headerBg = Color(el.headerBgColor);
    final headerFg = Color(el.headerTextColor);
    final borderCol = Color(el.borderColor);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderCol, width: el.borderWidth * scale / 3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: el.cellPadding * scale / 3,
              vertical: el.cellPadding * scale / 4,
            ),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(1)),
            ),
            child: Row(
              children: el.headers
                  .map((h) => Expanded(
                        flex: h == el.headers.first ? 3 : 1,
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: el.headerFontSize * textScale,
                            fontWeight: FontWeight.bold,
                            color: headerFg,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // Rows
          Expanded(
            child: Column(
              children: List.generate(
                min(el.rowCount, 5),
                (i) => Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: el.cellPadding * scale / 3),
                    decoration: BoxDecoration(
                      color: i.isOdd ? borderCol.withValues(alpha: 0.05) : null,
                      border: Border(bottom: BorderSide(color: borderCol, width: 0.3)),
                    ),
                    child: Row(
                      children: el.headers.map((h) {
                        return Expanded(
                          flex: h == el.headers.first ? 3 : 1,
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 2 * scale / 3),
                            height: 3 * scale / 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Resize Handles ─────────────────────────────────────────────

  List<Widget> _buildResizeHandles(
      CanvasEditorState state, CanvasElement el, double scale, double pw, double ph) {
    const handleSize = 8.0;
    const half = handleSize / 2;

    final handles = <(String, double, double)>[
      ('tl', -half, -half),
      ('tr', pw - half, -half),
      ('bl', -half, ph - half),
      ('br', pw - half, ph - half),
      ('t', pw / 2 - half, -half),
      ('b', pw / 2 - half, ph - half),
      ('l', -half, ph / 2 - half),
      ('r', pw - half, ph / 2 - half),
    ];

    return handles.map((h) {
      MouseCursor cursor;
      switch (h.$1) {
        case 'tl':
        case 'br':
          cursor = SystemMouseCursors.resizeUpLeftDownRight;
          break;
        case 'tr':
        case 'bl':
          cursor = SystemMouseCursors.resizeUpRightDownLeft;
          break;
        case 't':
        case 'b':
          cursor = SystemMouseCursors.resizeUpDown;
          break;
        default:
          cursor = SystemMouseCursors.resizeLeftRight;
      }

      return Positioned(
        left: h.$2,
        top: h.$3,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            onPanStart: (d) => state.startResize(el.id, h.$1, d.globalPosition),
            onPanUpdate: (d) => state.updateResize(d.globalPosition, scale),
            onPanEnd: (_) => state.endResize(),
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ─── Custom Painters ──────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double gridSize;
  final Color color;

  _GridPainter({required this.gridSize, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.gridSize != gridSize || oldDelegate.color != color;
}

class _MarginPainter extends CustomPainter {
  final double left, top, right, bottom;

  _MarginPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x15FF6B6B)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw margin rectangle
    final rect = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    canvas.drawRect(rect, paint);

    // Draw dashed guide lines at margins
    final dashPaint = Paint()
      ..color = const Color(0x20FF6B6B)
      ..strokeWidth = 0.5;

    // Left margin line
    _drawDashedLine(canvas, Offset(left, 0), Offset(left, size.height), dashPaint);
    // Right margin line
    _drawDashedLine(canvas, Offset(size.width - right, 0), Offset(size.width - right, size.height), dashPaint);
    // Top margin line
    _drawDashedLine(canvas, Offset(0, top), Offset(size.width, top), dashPaint);
    // Bottom margin line
    _drawDashedLine(canvas, Offset(0, size.height - bottom), Offset(size.width, size.height - bottom), dashPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final distance = (end - start).distance;
    const dashLength = 4.0;
    const gapLength = 3.0;
    final direction = (end - start) / distance;
    double pos = 0;
    while (pos < distance) {
      final segEnd = min(pos + dashLength, distance);
      canvas.drawLine(
        start + direction * pos,
        start + direction * segEnd,
        paint,
      );
      pos += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _MarginPainter oldDelegate) =>
      oldDelegate.left != left ||
      oldDelegate.top != top ||
      oldDelegate.right != right ||
      oldDelegate.bottom != bottom;
}
