import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<void> openPdfInChromeImpl(Uint8List bytes, String fileName, BuildContext context) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      final programFiles = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';

      final chromeCandidates = [
        '$programFiles\\Google\\Chrome\\Application\\chrome.exe',
        '$programFilesX86\\Google\\Chrome\\Application\\chrome.exe',
        if (localAppData.isNotEmpty) '$localAppData\\Google\\Chrome\\Application\\chrome.exe',
      ];

      for (final candidate in chromeCandidates) {
        if (await File(candidate).exists()) {
          try {
            await Process.start(candidate, [filePath]);
            return;
          } catch (e) {
            debugPrint('[GuideOpener] Failed to launch $candidate: $e');
          }
        }
      }

      // Try running via cmd start chrome
      try {
        final res = await Process.run('cmd', ['/c', 'start', 'chrome', filePath]);
        if (res.exitCode == 0) return;
      } catch (e) {
        debugPrint('[GuideOpener] Failed to start chrome via cmd: $e');
      }

      // Fallback: start with default handler
      try {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
        return;
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        final res = await Process.run('open', ['-a', 'Google Chrome', filePath]);
        if (res.exitCode == 0) return;
      } catch (_) {}
      try {
        await Process.run('open', [filePath]);
        return;
      } catch (_) {}
    } else if (Platform.isLinux) {
      try {
        final res = await Process.run('google-chrome', [filePath]);
        if (res.exitCode == 0) return;
      } catch (_) {}
      try {
        await Process.run('xdg-open', [filePath]);
        return;
      } catch (_) {}
    }

    // Android or general fallback
    try {
      await OpenFilex.open(filePath, type: 'application/pdf');
    } catch (e) {
      debugPrint('[GuideOpener] OpenFilex error: $e');
    }
  } catch (e) {
    debugPrint('[GuideOpener] Error writing/opening PDF in Chrome: $e');
  }
}
