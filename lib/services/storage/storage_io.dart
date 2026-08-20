import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../utils/platform_utils.dart';

Future<int?> getPlatformAvailableStorageBytes() async {
  try {
    if (PlatformUtils.isWindows) {
      final result = Process.runSync('wmic', ['logicaldisk', 'where', 'DeviceID="C:"', 'get', 'FreeSpace']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (lines.length >= 2) {
          final bytes = int.tryParse(lines[1]);
          if (bytes != null) return bytes;
        }
      }
    }
    final appDir = await getApplicationDocumentsDirectory();
    final stat = await Directory(appDir.path).stat();
    if (stat.size > 0) return 250 * 1024 * 1024;
    return 250 * 1024 * 1024;
  } catch (_) {
    return 250 * 1024 * 1024;
  }
}
