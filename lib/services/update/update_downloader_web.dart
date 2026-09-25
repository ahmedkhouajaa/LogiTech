// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

typedef DownloadProgressCallback = void Function(int receivedBytes, int totalBytes);

class UpdateCancelToken {
  bool isCancelled = false;
  void cancel() => isCancelled = true;
}

Future<String> downloadUpdateFile({
  required String url,
  required String fileName,
  required DownloadProgressCallback onProgress,
  UpdateCancelToken? cancelToken,
}) async {
  // On web, notify progress complete and reload
  onProgress(100, 100);
  if (url.isNotEmpty && url.startsWith('http')) {
    html.window.open(url, '_blank');
  } else {
    html.window.location.reload();
  }
  return '';
}

Future<bool> installUpdateFile(String filePath) async {
  html.window.location.reload();
  return true;
}
