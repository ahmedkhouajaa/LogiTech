import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/constants.dart';
import '../utils/support_image_reader.dart';

/// Helper for picking, compressing, and encoding images for support chat
class SupportImageHelper {
  /// Picks an image file using FilePicker, resizes if needed, and returns a Base64 data URI
  static Future<String?> pickAndProcessImage({BuildContext? context}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      // On desktop platforms if bytes is null, read via cross-platform reader
      if (bytes == null && file.path != null) {
        bytes = await SupportImageReader.readFileBytes(file.path!);
      }

      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      // Check and compress if over 400KB to stay well under Firestore's 1MB doc limit
      Uint8List processedBytes = bytes;
      if (bytes.lengthInBytes > 400 * 1024) {
        processedBytes = await compressImageBytes(bytes, maxDimension: 1024);
      }

      // If still over 700KB, compress more aggressively
      if (processedBytes.lengthInBytes > 700 * 1024) {
        processedBytes = await compressImageBytes(processedBytes, maxDimension: 800);
      }

      final ext = (file.extension ?? 'jpeg').toLowerCase().replaceAll('.', '');
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final base64String = base64Encode(processedBytes);

      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      debugPrint('[SupportImageHelper] Error picking image: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger l\'image : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
  }

  /// Compress and downscale an image using Flutter's built-in dart:ui codec
  static Future<Uint8List> compressImageBytes(Uint8List bytes, {int maxDimension = 1024}) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxDimension,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('[SupportImageHelper] Native codec compression fallback: $e');
    }
    return bytes;
  }
}

/// Chat Bubble Image Preview Widget with click-to-enlarge support
class ChatImageWidget extends StatelessWidget {
  final String imageUrl;
  final bool isUser;
  final double maxHeight;
  final double maxWidth;

  const ChatImageWidget({
    super.key,
    required this.imageUrl,
    this.isUser = false,
    this.maxHeight = 220,
    this.maxWidth = 300,
  });

  Uint8List? _extractBytes(String url) {
    try {
      final cleanUrl = url.trim();
      String rawBase64 = cleanUrl;
      if (cleanUrl.startsWith('data:image')) {
        final commaIndex = cleanUrl.indexOf(',');
        if (commaIndex != -1) {
          rawBase64 = cleanUrl.substring(commaIndex + 1);
        }
      }
      rawBase64 = rawBase64.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(rawBase64);
    } catch (e) {
      debugPrint('[ChatImageWidget] Error decoding base64: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    final bytes = isNetwork ? null : _extractBytes(imageUrl);

    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveMaxWidth = screenWidth < 500 ? (screenWidth * 0.62) : maxWidth;

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black87,
          builder: (_) => SupportImageViewerDialog(imageUrl: imageUrl),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: effectiveMaxWidth,
          ),
          decoration: BoxDecoration(
            color: isUser ? Colors.white.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUser ? Colors.white.withValues(alpha: 0.25) : AppColors.border,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isNetwork)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isUser ? Colors.white : AppColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (ctx, err, stack) => _buildErrorWidget(),
                )
              else if (bytes != null)
                Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (ctx, err, stack) => _buildErrorWidget(),
                )
              else
                _buildErrorWidget(),

              // Magnify Icon Overlay on Hover/Tap
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 100,
      width: 140,
      color: Colors.grey.withValues(alpha: 0.2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, size: 28, color: isUser ? Colors.white70 : AppColors.textTertiary),
          const SizedBox(height: 4),
          Text(
            'Image non disponible',
            style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Fullscreen Interactive Image Viewer Dialog with Zoom & Pan
class SupportImageViewerDialog extends StatelessWidget {
  final String imageUrl;

  const SupportImageViewerDialog({super.key, required this.imageUrl});

  Uint8List? _extractBytes(String url) {
    try {
      final cleanUrl = url.trim();
      String rawBase64 = cleanUrl;
      if (cleanUrl.startsWith('data:image')) {
        final commaIndex = cleanUrl.indexOf(',');
        if (commaIndex != -1) {
          rawBase64 = cleanUrl.substring(commaIndex + 1);
        }
      }
      rawBase64 = rawBase64.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(rawBase64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    final bytes = isNetwork ? null : _extractBytes(imageUrl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Interactive Zoomable Image
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isNetwork
                  ? Image.network(imageUrl, fit: BoxFit.contain)
                  : bytes != null
                      ? Image.memory(bytes, fit: BoxFit.contain)
                      : const Center(
                          child: Text(
                            'Erreur lors du chargement de l\'image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
            ),
          ),

          // Close Button
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                tooltip: 'Fermer',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
