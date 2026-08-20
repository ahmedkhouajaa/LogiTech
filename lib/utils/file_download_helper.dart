import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'file_download/file_download_stub.dart'
    if (dart.library.html) 'file_download/file_download_web.dart'
    if (dart.library.io) 'file_download/file_download_io.dart';

class FileDownloadHelper {
  /// Saves the provided bytes and prompts open/download depending on the platform.
  static Future<String?> saveAndOpenFile(
    Uint8List bytes,
    String fileName, {
    String? mimeType,
    BuildContext? context,
  }) {
    return saveAndOpenFileImpl(
      bytes,
      fileName,
      mimeType: mimeType,
      context: context,
    );
  }

  /// Saves a UTF-8 string content (e.g. XML, CSV, JSON) as a file download.
  static Future<String?> saveStringFile(
    String content,
    String fileName, {
    String? mimeType,
    BuildContext? context,
  }) {
    return saveStringFileImpl(
      content,
      fileName,
      mimeType: mimeType,
      context: context,
    );
  }

  /// Opens or reveals the file on platforms that support file exploration.
  static Future<void> openFile(String path) {
    return openFileImpl(path);
  }
}
