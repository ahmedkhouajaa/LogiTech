import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/hr_document.dart';
import '../services/electronic_invoice_guide_pdf_service.dart';
import '../services/hr_document_service.dart';
import '../utils/platform_utils.dart';

class HrDocumentPreviewDialog extends StatelessWidget {
  final HrDocument document;

  const HrDocumentPreviewDialog({
    super.key,
    required this.document,
  });

  static Future<void> show(BuildContext context, HrDocument document) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: HrDocumentPreviewDialog(document: document),
      ),
    );
  }

  bool get isPdf {
    final ext = document.fileExtension.toLowerCase();
    final name = document.fileName.toLowerCase();
    return ext == 'pdf' || name.endsWith('.pdf') || document.type.toLowerCase() == 'déclaration';
  }

  bool get isImage {
    final ext = document.fileExtension.toLowerCase();
    final name = document.fileName.toLowerCase();
    return ['png', 'jpg', 'jpeg', 'webp'].contains(ext) ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = !PlatformUtils.isDesktop && !PlatformUtils.isWeb;

    return Container(
      width: isMobile ? size.width * 0.96 : (size.width > 1200 ? 1100 : size.width * 0.92),
      height: size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Header matching Images 2 & 4
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Retour',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    document.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => HrDocumentService.instance.downloadDocument(context, document),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  ),
                  child: const Text(
                    'Télécharger',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Document Viewer Body
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: _buildViewerContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerContent(BuildContext context) {
    if (isPdf) {
      return DarkPdfChromeViewer(document: document);
    } else if (isImage) {
      return _buildImageViewer(context);
    } else {
      return _buildGenericViewer(context);
    }
  }

  Widget _buildImageViewer(BuildContext context) {
    Uint8List? bytes;
    if (document.fileBase64 != null && document.fileBase64!.isNotEmpty) {
      try {
        String clean = document.fileBase64!;
        if (clean.contains(',')) clean = clean.split(',').last;
        bytes = base64Decode(clean);
      } catch (e) {
        debugPrint('[HrDocumentPreviewDialog] Base64 decode error: $e');
      }
    }

    return Container(
      color: const Color(0xFFFAFAFA),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes != null
              ? InteractiveViewer(
                  maxScale: 4.0,
                  minScale: 0.5,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : _buildDemoImageFallback(),
        ),
      ),
    );
  }

  Widget _buildDemoImageFallback() {
    return InteractiveViewer(
      maxScale: 4.0,
      minScale: 0.8,
      child: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('17', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 180,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: const Row(
                    children: [
                      Icon(Icons.search, size: 14, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('Search (Ctrl+K)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                const Spacer(),
                const Text('EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56DB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Get started', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.currency_bitcoin, color: Colors.orange, size: 20),
                SizedBox(width: 4),
                Text('BTCUSDT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(width: 8),
                Text('77,283.04', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(width: 8),
                Text('-1,023.39 -1.31%', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: _ChartWavePainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericViewer(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.insert_drive_file_rounded, size: 64, color: Color(0xFF1A56DB)),
          ),
          const SizedBox(height: 16),
          Text(
            document.fileName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            'Type : ${document.type} • Taille : ${document.formattedFileSize}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => HrDocumentService.instance.downloadDocument(context, document),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Télécharger le fichier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark Theme Chrome-Style PDF Viewer exactly matching Image 2
class DarkPdfChromeViewer extends StatefulWidget {
  final HrDocument document;

  const DarkPdfChromeViewer({super.key, required this.document});

  @override
  State<DarkPdfChromeViewer> createState() => _DarkPdfChromeViewerState();
}

class _DarkPdfChromeViewerState extends State<DarkPdfChromeViewer> {
  Uint8List? _pdfBytes;
  final List<Uint8List> _renderedPages = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool _showThumbnails = true;
  int _currentPage = 1;
  double _zoom = 0.66; // 66% initial matching Image 2
  int _rotationQuarterTurns = 0;

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _thumbnailScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPdfAndRender();
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPdfAndRender() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Uint8List bytes;
      if (widget.document.fileBase64 != null && widget.document.fileBase64!.isNotEmpty) {
        String clean = widget.document.fileBase64!;
        if (clean.contains(',')) clean = clean.split(',').last;
        bytes = base64Decode(clean);
      } else {
        // Fallback to the official 10-page guide PDF (shown in Image 2)
        bytes = await ElectronicInvoiceGuidePdfService.instance.generateGuidePdf();
      }

      _pdfBytes = bytes;

      // Rasterize pages using Printing.raster
      final List<Uint8List> pagesList = [];
      await for (final page in Printing.raster(bytes, dpi: 150)) {
        final pngBytes = await page.toPng();
        pagesList.add(pngBytes);
        if (mounted) {
          setState(() {
            _renderedPages.clear();
            _renderedPages.addAll(pagesList);
            _isLoading = false;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DarkPdfChromeViewer] raster error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _zoomIn() {
    setState(() {
      _zoom = (_zoom + 0.15).clamp(0.40, 2.50);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom = (_zoom - 0.15).clamp(0.40, 2.50);
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _jumpToPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _renderedPages.length) return;
    setState(() => _currentPage = pageNumber);

    // Scroll main view to the target page
    // Approximate A4 page height with zoom
    final estimatedPageHeight = (842.0 * _zoom) + 24.0;
    final targetOffset = (pageNumber - 1) * estimatedPageHeight;
    if (_mainScrollController.hasClients) {
      _mainScrollController.animateTo(
        targetOffset.clamp(0.0, _mainScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  String _formatDocHeaderName() {
    final name = widget.document.fileName.isNotEmpty ? widget.document.fileName : widget.document.title;
    if (name.length > 22) {
      return '${name.substring(0, 18)}...';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _renderedPages.length;

    return Container(
      color: const Color(0xFF323639), // Dark Chrome PDF background
      child: Column(
        children: [
          // Top Dark Toolbar matching Image 2
          Container(
            height: 48,
            color: const Color(0xFF282828),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Hamburger icon (toggle thumbnails)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                  tooltip: 'Vignettes',
                  onPressed: () => setState(() => _showThumbnails = !_showThumbnails),
                ),
                const SizedBox(width: 8),

                // Document filename
                Text(
                  _formatDocHeaderName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 14),

                // Vertical Divider
                Container(height: 20, width: 1, color: Colors.white24),
                const SizedBox(width: 14),

                // Page indicator e.g. 1 / 10
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '$_currentPage',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ ${totalPages > 0 ? totalPages : 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 14),

                // Vertical Divider
                Container(height: 20, width: 1, color: Colors.white24),
                const SizedBox(width: 8),

                // Zoom Out (-)
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white, size: 18),
                  tooltip: 'Zoom arrière',
                  onPressed: _zoomOut,
                ),
                // Zoom percentage (e.g. 66%)
                Text(
                  '${(_zoom * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                // Zoom In (+)
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  tooltip: 'Zoom avant',
                  onPressed: _zoomIn,
                ),
                const SizedBox(width: 8),

                // Vertical Divider
                Container(height: 20, width: 1, color: Colors.white24),
                const SizedBox(width: 8),

                // Fit Page Icon
                IconButton(
                  icon: const Icon(Icons.fit_screen_outlined, color: Colors.white, size: 18),
                  tooltip: 'Ajuster à la page',
                  onPressed: () => setState(() => _zoom = 0.66),
                ),
                // Rotate Icon
                IconButton(
                  icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 18),
                  tooltip: 'Faire pivoter',
                  onPressed: _rotateClockwise,
                ),

                const Spacer(),

                // Download Button
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                  tooltip: 'Télécharger',
                  onPressed: () => HrDocumentService.instance.downloadDocument(context, widget.document),
                ),
                // Print Button
                if (_pdfBytes != null)
                  IconButton(
                    icon: const Icon(Icons.print_outlined, color: Colors.white, size: 20),
                    tooltip: 'Imprimer',
                    onPressed: () => Printing.layoutPdf(
                      name: widget.document.fileName,
                      onLayout: (_) async => _pdfBytes!,
                    ),
                  ),
                // More options menu
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  tooltip: 'Options',
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Main Viewport: Thumbnails (Left) + Page View (Right)
          Expanded(
            child: _isLoading && _renderedPages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  )
                : _errorMessage != null && _renderedPages.isEmpty
                    ? Center(
                        child: Text(
                          'Erreur de chargement du PDF : $_errorMessage',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : Row(
                        children: [
                          // Left Thumbnails Panel (toggleable)
                          if (_showThumbnails && _renderedPages.isNotEmpty)
                            Container(
                              width: 175,
                              color: const Color(0xFF222426),
                              child: ListView.separated(
                                controller: _thumbnailScrollController,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                                itemCount: _renderedPages.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 18),
                                itemBuilder: (context, index) {
                                  final pageNum = index + 1;
                                  final isCurrent = pageNum == _currentPage;

                                  return InkWell(
                                    onTap: () => _jumpToPage(pageNum),
                                    child: Column(
                                      children: [
                                        // Thumbnail Card with blue border when selected
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isCurrent ? const Color(0xFF3B82F6) : Colors.transparent,
                                              width: isCurrent ? 2.5 : 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.35),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: AspectRatio(
                                            aspectRatio: 1 / 1.414, // Standard A4 ratio
                                            child: Image.memory(
                                              _renderedPages[index],
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        // Page Number
                                        Text(
                                          '$pageNum',
                                          style: TextStyle(
                                            color: isCurrent ? const Color(0xFF60A5FA) : Colors.white70,
                                            fontSize: 12,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                          // Vertical subtle divider between panels
                          if (_showThumbnails && _renderedPages.isNotEmpty)
                            Container(width: 1, color: Colors.black45),

                          // Right Main Page Viewer
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (scrollInfo) {
                                // Track current page while scrolling
                                if (scrollInfo.metrics.hasContentDimensions && _renderedPages.isNotEmpty) {
                                  final estimatedPageHeight = (842.0 * _zoom) + 24.0;
                                  final page = (scrollInfo.metrics.pixels / estimatedPageHeight).floor() + 1;
                                  if (page != _currentPage && page >= 1 && page <= _renderedPages.length) {
                                    setState(() => _currentPage = page);
                                  }
                                }
                                return false;
                              },
                              child: SingleChildScrollView(
                                controller: _mainScrollController,
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int i = 0; i < _renderedPages.length; i++)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 24),
                                          child: RotatedBox(
                                            quarterTurns: _rotationQuarterTurns,
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxWidth: 595.0 * _zoom * 1.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.5),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Image.memory(
                                                _renderedPages[i],
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChartWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFEF4444).withValues(alpha: 0.25),
          const Color(0xFFEF4444).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.40);

    final points = [
      Offset(size.width * 0.10, size.height * 0.38),
      Offset(size.width * 0.20, size.height * 0.44),
      Offset(size.width * 0.28, size.height * 0.36),
      Offset(size.width * 0.38, size.height * 0.48),
      Offset(size.width * 0.46, size.height * 0.45),
      Offset(size.width * 0.52, size.height * 0.60),
      Offset(size.width * 0.58, size.height * 0.85),
      Offset(size.width * 0.64, size.height * 0.75),
      Offset(size.width * 0.70, size.height * 0.65),
      Offset(size.width * 0.76, size.height * 0.68),
      Offset(size.width * 0.82, size.height * 0.78),
      Offset(size.width * 0.90, size.height * 0.70),
      Offset(size.width, size.height * 0.72),
    ];

    for (final pt in points) {
      path.lineTo(pt.dx, pt.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
