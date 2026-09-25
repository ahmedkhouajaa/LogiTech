import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../utils/platform_utils.dart';

typedef DownloadProgressCallback = void Function(int receivedBytes, int totalBytes);

class UpdateCancelToken {
  bool isCancelled = false;
  void cancel() => isCancelled = true;
}

Future<Directory> _getUpdateSaveDirectory() async {
  try {
    if (PlatformUtils.isAndroid) {
      // Use getExternalStorageDirectory (isolated to app, does not require storage permissions on Android 11+)
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return extDir;
      final tempDir = await getTemporaryDirectory();
      return tempDir;
    } else if (PlatformUtils.isWindows) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
      return await getApplicationDocumentsDirectory();
    }
  } catch (e) {
    debugPrint('Erreur obtention dossier de sauvegarde: $e');
  }
  return await getTemporaryDirectory();
}

Future<String> downloadUpdateFile({
  required String url,
  required String fileName,
  required DownloadProgressCallback onProgress,
  UpdateCancelToken? cancelToken,
}) async {
  final dir = await _getUpdateSaveDirectory();
  final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
  final file = File(filePath);

  if (await file.exists()) {
    try {
      await file.delete();
    } catch (_) {}
  }

  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) => true;

  try {
    Uri currentUri = Uri.parse(url);
    HttpClientResponse? response;

    // Follow redirects manually up to 8 hops (handles GitHub releases CDN redirects reliably)
    for (int redirectCount = 0; redirectCount < 8; redirectCount++) {
      final request = await client.getUrl(currentUri);
      request.followRedirects = false;
      final res = await request.close();

      if (res.isRedirect ||
          res.statusCode == HttpStatus.movedPermanently ||
          res.statusCode == HttpStatus.movedTemporarily ||
          res.statusCode == HttpStatus.seeOther ||
          res.statusCode == HttpStatus.temporaryRedirect ||
          res.statusCode == 308) {
        final location = res.headers.value(HttpHeaders.locationHeader);
        if (location != null && location.isNotEmpty) {
          currentUri = Uri.parse(location);
          await res.drain();
          continue;
        }
      }

      response = res;
      break;
    }

    if (response == null || (response.statusCode != 200 && response.statusCode != 206)) {
      throw Exception('Impossible de télécharger le fichier (Code HTTP: ${response?.statusCode})');
    }

    final contentLength = response.contentLength;
    int receivedBytes = 0;
    final sink = file.openWrite();

    try {
      await for (final chunk in response) {
        if (cancelToken?.isCancelled == true) {
          await sink.close();
          try {
            await file.delete();
          } catch (_) {}
          throw Exception('Téléchargement annulé par l\'utilisateur');
        }

        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, contentLength);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    return filePath;
  } finally {
    client.close();
  }
}

Future<bool> installUpdateFile(String filePath) async {
  try {
    if (PlatformUtils.isAndroid) {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } else if (PlatformUtils.isWindows) {
      try {
        // Run Windows installer in detached process
        await Process.start(filePath, [], runInShell: true, mode: ProcessStartMode.detached);
        return true;
      } catch (processError) {
        debugPrint('Process.start error, fallback to OpenFilex: $processError');
        final result = await OpenFilex.open(filePath);
        return result.type == ResultType.done;
      }
    }
  } catch (e) {
    debugPrint('Erreur lors de l\'installation du fichier: $e');
  }
  return false;
}
