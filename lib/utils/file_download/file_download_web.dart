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
      ..click();

    html.Url.revokeObjectUrl(url);

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
