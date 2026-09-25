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
  throw UnsupportedError('Téléchargement non supporté sur cette plateforme');
}

Future<bool> installUpdateFile(String filePath) async {
  throw UnsupportedError('Installation non supportée sur cette plateforme');
}
