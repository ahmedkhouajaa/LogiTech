import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> saveAndExportFilePlatform({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  try {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // 1. Prompt user to choose where to save
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le fichier de sauvegarde',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
      );

      if (outputPath == null) {
        // Fallback to user's download directory
        Directory? downloadDir;
        try {
          downloadDir = await getDownloadsDirectory();
        } catch (_) {}
        downloadDir ??= await getApplicationDocumentsDirectory();
        outputPath = '${downloadDir.path}${Platform.pathSeparator}$fileName';
      }

      final file = File(outputPath);
      await file.writeAsBytes(bytes);
      return outputPath;
    } else {
      // Mobile (Android / iOS)
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Offer to share/save
      try {
        await Share.shareXFiles(
          [XFile(filePath, mimeType: mimeType ?? 'application/json')],
          text: 'Sauvegarde LogiTech Pro - $fileName',
        );
      } catch (e) {
        debugPrint('Share file error: $e');
      }
      return filePath;
    }
  } catch (e) {
    debugPrint('saveAndExportFilePlatform IO error: $e');
    return null;
  }
}
