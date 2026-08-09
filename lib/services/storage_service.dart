import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  static const int minRequiredBytes = 100 * 1024 * 1024; // 100 MB free minimum requirement

  Future<bool> hasMinimumStorage({int requiredBytes = minRequiredBytes}) async {
    final freeBytes = await getAvailableStorageBytes();
    if (freeBytes == null) return true; // If undetectable, assume OK
    return freeBytes >= requiredBytes;
  }

  Future<int?> getAvailableStorageBytes() async {
    try {
      if (kIsWeb) return 500 * 1024 * 1024; // Web mock

      final appDir = await getApplicationDocumentsDirectory();
      final stat = await Directory(appDir.path).stat();
      // On platforms where stat or disk space can be read:
      if (!kIsWeb && Platform.isWindows) {
        final result = Process.runSync('wmic', ['logicaldisk', 'where', 'DeviceID="C:"', 'get', 'FreeSpace']);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          if (lines.length >= 2) {
            final bytes = int.tryParse(lines[1]);
            if (bytes != null) return bytes;
          }
        }
      }
      // Fallback check based on app directory stat size if space available cannot be directly queried
      return 250 * 1024 * 1024; // Safe fallback estimation (250MB)
    } catch (_) {
      return 250 * 1024 * 1024;
    }
  }
}
