// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

Future<String?> saveAndExportFilePlatform({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  try {
    final blob = html.Blob([bytes], mimeType ?? 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return fileName;
  } catch (e) {
    debugPrint('saveAndExportFilePlatform Web error: $e');
    return null;
  }
}
