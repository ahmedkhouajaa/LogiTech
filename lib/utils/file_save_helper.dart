import 'dart:typed_data';
import 'file_save_helper_io.dart'
    if (dart.library.html) 'file_save_helper_web.dart' as platform_impl;

/// Universal file saver that saves or downloads files on Web, Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
class FileSaveHelper {
  static Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    return platform_impl.saveAndExportFilePlatform(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
