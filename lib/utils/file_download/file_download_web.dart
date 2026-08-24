// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants.dart';

Future<String?> saveAndOpenFileImpl(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
  BuildContext? context,
}) async {
  try {
    final type = mimeType ?? 'application/octet-stream';
    final blob = html.Blob([bytes], type);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();

    Future.delayed(const Duration(seconds: 5), () {
      html.Url.revokeObjectUrl(url);
    });

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Téléchargement démarré : $fileName'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    return fileName;
  } catch (e) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du téléchargement : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    rethrow;
  }
}

Future<String?> saveStringFileImpl(
  String content,
  String fileName, {
  String? mimeType,
  BuildContext? context,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  return saveAndOpenFileImpl(
    bytes,
    fileName,
    mimeType: mimeType ?? 'text/plain;charset=utf-8',
    context: context,
  );
}

Future<void> openFileImpl(String path) async {
  // On Web, files are saved directly to the user's browser downloads folder
}

Future<void> downloadUrlImpl(String url, String fileName) async {
  final candidateUrls = [
    url,
    fileName,
    'downloads/$fileName',
    'assets/downloads/$fileName',
    'assets/$fileName',
    'assets/assets/downloads/$fileName',
  ];

  for (final targetUrl in candidateUrls) {
    try {
      final req = await html.HttpRequest.request(
        targetUrl,
        responseType: 'blob',
      );
      if (req.status == 200 && req.response != null) {
        final blob = req.response as html.Blob;
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        anchor.remove();
        Future.delayed(const Duration(seconds: 10), () {
          html.Url.revokeObjectUrl(blobUrl);
        });
        return;
      }
    } catch (_) {
      // Try next candidate
    }
  }

  // Fallback direct anchor click
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
