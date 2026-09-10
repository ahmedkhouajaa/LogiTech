import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'support_image_reader.dart';

/// Helper utility for picking, compressing, decoding, and rendering enterprise logos.
class CompanyLogoHelper {
  /// Safely extracts and decodes binary image bytes from a Base64 string or data URI.
  static Uint8List? decodeBase64Logo(String? logoString) {
    if (logoString == null || logoString.trim().isEmpty) {
      return null;
    }

    try {
      final clean = logoString.trim();
      String rawBase64 = clean;
      final commaIndex = clean.indexOf(',');
      if (clean.startsWith('data:') && commaIndex != -1) {
        rawBase64 = clean.substring(commaIndex + 1);
      }
      rawBase64 = rawBase64.replaceAll(RegExp(r'\s+'), '');
      if (rawBase64.isEmpty) return null;
      return base64Decode(rawBase64);
    } catch (e) {
      debugPrint('[CompanyLogoHelper] Failed to decode logo base64: $e');
      return null;
    }
  }

  /// Compresses and downscales image bytes using Flutter's built-in [ui.instantiateImageCodec].
  static Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    int maxDimension = 512,
  }) async {
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
      debugPrint('[CompanyLogoHelper] Image compression fallback: $e');
    }
    return bytes;
  }

  /// Opens the platform file picker, compresses the selected image,
  /// and returns a ready-to-store Base64 data URI string (`data:image/png;base64,...`).
  static Future<String?> pickAndProcessLogo({
    BuildContext? context,
    int maxDimension = 512,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      // Desktop platforms fallback: read using SupportImageReader
      if (bytes == null && file.path != null) {
        bytes = await SupportImageReader.readFileBytes(file.path!);
      }

      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      // Downscale/compress to keep doc size minimal (~20-80KB)
      final processedBytes = await compressImageBytes(bytes, maxDimension: maxDimension);
      final base64String = base64Encode(processedBytes);
      return 'data:image/png;base64,$base64String';
    } catch (e) {
      debugPrint('[CompanyLogoHelper] Error picking company logo: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger le logo : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
  }

  /// Convenience widget to display an enterprise logo or a fallback widget.
  static Widget buildLogoWidget({
    required String? logoUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? fallback,
  }) {
    final bytes = decodeBase64Logo(logoUrl);
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            fallback ?? const SizedBox.shrink(),
      );
    }
    return fallback ?? const SizedBox.shrink();
  }
}
