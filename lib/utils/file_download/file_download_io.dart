import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../platform_utils.dart';
import '../constants.dart';

Future<Directory> _getDownloadsDirectory() async {
  if (PlatformUtils.isAndroid) {
    final dir = Directory('/storage/emulated/0/Download');
    if (await dir.exists()) return dir;
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) return extDir;
    return await getApplicationDocumentsDirectory();
  } else if (PlatformUtils.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      final dir = Directory('$userProfile\\Downloads');
      if (await dir.exists()) return dir;
    }
    final dir = await getDownloadsDirectory();
    if (dir != null) return dir;
    return await getApplicationDocumentsDirectory();
  }
  return await getApplicationDocumentsDirectory();
}

Future<String?> saveAndOpenFileImpl(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
  BuildContext? context,
}) async {
  try {
    final dir = await _getDownloadsDirectory();
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier enregistré : $fileName'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    try {
      await OpenFilex.open(filePath);
    } catch (_) {}

    return filePath;
  } catch (e) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'enregistrement : $e'),
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
  try {
    final dir = await _getDownloadsDirectory();
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsString(content, flush: true);

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier enregistré : $fileName'),
          backgroundColor: AppColors.success,
        ),
      );
    }

    try {
      await OpenFilex.open(filePath);
    } catch (_) {}

    return filePath;
  } catch (e) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'enregistrement : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    rethrow;
  }
}

Future<void> openFileImpl(String path) async {
  try {
    if (PlatformUtils.isWindows) {
      await Process.run('explorer.exe', ['/select,', path]);
    } else {
      await OpenFilex.open(path);
    }
  } catch (_) {
    try {
      await OpenFilex.open(path);
    } catch (_) {}
  }
}
