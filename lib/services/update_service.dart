import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../utils/platform_utils.dart';
import 'update/update_downloader.dart';

enum UpdateState {
  idle,
  checking,
  available,
  downloading,
  installing,
  completed,
  error,
}

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final String changelog;
  final String androidUrl;
  final String windowsUrl;
  final String webUrl;
  final DateTime? releaseDate;

  const AppUpdateInfo({
    required this.version,
    this.buildNumber = 0,
    this.forceUpdate = false,
    this.changelog = '',
    this.androidUrl = '',
    this.windowsUrl = '',
    this.webUrl = '',
    this.releaseDate,
  });

  factory AppUpdateInfo.fromMap(Map<String, dynamic> data) {
    DateTime? parsedDate;
    if (data['releaseDate'] is Timestamp) {
      parsedDate = (data['releaseDate'] as Timestamp).toDate();
    } else if (data['releaseDate'] is String) {
      parsedDate = DateTime.tryParse(data['releaseDate']);
    }

    return AppUpdateInfo(
      version: data['version']?.toString().trim() ?? '1.0.0',
      buildNumber: (data['buildNumber'] as num?)?.toInt() ?? 0,
      forceUpdate: data['forceUpdate'] == true || data['force_update'] == true,
      changelog: data['changelog']?.toString() ?? '',
      androidUrl: data['androidUrl']?.toString() ?? data['android_url']?.toString() ?? '',
      windowsUrl: data['windowsUrl']?.toString() ?? data['windows_url']?.toString() ?? '',
      webUrl: data['webUrl']?.toString() ?? data['web_url']?.toString() ?? '',
      releaseDate: parsedDate,
    );
  }

  String get targetUrl {
    if (kIsWeb) return webUrl;
    if (PlatformUtils.isAndroid) return androidUrl;
    if (PlatformUtils.isWindows) return windowsUrl;
    if (androidUrl.isNotEmpty) return androidUrl;
    return windowsUrl;
  }

  String get fileName {
    final cleanVersion = version.replaceAll(RegExp(r'[^0-9.]'), '');
    if (PlatformUtils.isAndroid) {
      return 'LogiTech_v$cleanVersion.apk';
    } else if (PlatformUtils.isWindows) {
      return 'LogiTech_Setup_v$cleanVersion.exe';
    }
    return 'LogiTech_v$cleanVersion.bin';
  }
}

class UpdateService {
  UpdateService._internal();
  static final UpdateService instance = UpdateService._internal();

  final ValueNotifier<AppUpdateInfo?> updateInfoNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isDismissedNotifier = ValueNotifier(false);
  final ValueNotifier<UpdateState> stateNotifier = ValueNotifier(UpdateState.idle);
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> statusTextNotifier = ValueNotifier('');
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);

  UpdateCancelToken? _cancelToken;
  String? _downloadedFilePath;

  /// Semantic version comparison: returns true if [remote] > [current]
  static bool isNewerVersion(String remote, String current) {
    try {
      final rClean = remote.trim().replaceFirst(RegExp(r'^[vV]'), '');
      final cClean = current.trim().replaceFirst(RegExp(r'^[vV]'), '');

      final rParts = rClean.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
      final cParts = cClean.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();

      final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
      for (int i = 0; i < maxLen; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
    } catch (e) {
      debugPrint('Erreur comparaison version: $e');
    }
    return false;
  }

  /// Checks Firestore for app_config/version document
  Future<AppUpdateInfo?> checkForUpdate({bool silent = true}) async {
    try {
      stateNotifier.value = UpdateState.checking;
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!doc.exists || doc.data() == null) {
        stateNotifier.value = UpdateState.idle;
        return null;
      }

      final info = AppUpdateInfo.fromMap(doc.data()!);
      final isNewer = isNewerVersion(info.version, AppConfig.appVersion);

      if (isNewer) {
        updateInfoNotifier.value = info;
        stateNotifier.value = UpdateState.available;
        // If it's a forced update, cannot be dismissed
        if (info.forceUpdate) {
          isDismissedNotifier.value = false;
        }
        return info;
      } else {
        updateInfoNotifier.value = null;
        stateNotifier.value = UpdateState.idle;
        return null;
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification de mise à jour: $e');
      stateNotifier.value = UpdateState.idle;
      return null;
    }
  }

  /// Starts downloading the update package and triggers the installer
  Future<void> startDownloadAndInstall({AppUpdateInfo? info}) async {
    final targetInfo = info ?? updateInfoNotifier.value;
    if (targetInfo == null) return;

    final url = targetInfo.targetUrl;
    if (url.isEmpty) {
      errorMessageNotifier.value = 'Aucun lien de téléchargement disponible pour cette plateforme.';
      stateNotifier.value = UpdateState.error;
      return;
    }

    try {
      stateNotifier.value = UpdateState.downloading;
      progressNotifier.value = 0.0;
      statusTextNotifier.value = 'Démarrage du téléchargement...';
      errorMessageNotifier.value = null;

      _cancelToken = UpdateCancelToken();

      final filePath = await downloadUpdateFile(
        url: url,
        fileName: targetInfo.fileName,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            progressNotifier.value = progress;
            final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
            final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
            final pct = (progress * 100).toInt();
            statusTextNotifier.value = '$recMb Mo / $totMb Mo ($pct%)';
          } else {
            final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
            statusTextNotifier.value = '$recMb Mo téléchargés...';
          }
        },
      );

      _downloadedFilePath = filePath;
      stateNotifier.value = UpdateState.installing;
      statusTextNotifier.value = 'Lancement de l\'installation...';

      final installed = await installUpdateFile(filePath);
      if (installed) {
        stateNotifier.value = UpdateState.completed;
      } else {
        // Even if the system installer opened, mark completed
        stateNotifier.value = UpdateState.completed;
      }
    } catch (e) {
      debugPrint('Erreur téléchargement mise à jour: $e');
      errorMessageNotifier.value = e.toString().replaceFirst('Exception: ', '');
      stateNotifier.value = UpdateState.error;
    }
  }

  /// Cancel current download
  void cancelDownload() {
    _cancelToken?.cancel();
    stateNotifier.value = UpdateState.available;
    progressNotifier.value = 0.0;
    statusTextNotifier.value = '';
  }

  /// Retry installation if already downloaded
  Future<void> retryInstall() async {
    if (_downloadedFilePath != null) {
      await installUpdateFile(_downloadedFilePath!);
    } else {
      await startDownloadAndInstall();
    }
  }

  /// Dismiss the update banner for this session
  void dismissBanner() {
    final current = updateInfoNotifier.value;
    if (current != null && current.forceUpdate) {
      return; // Cannot dismiss forced updates
    }
    isDismissedNotifier.value = true;
  }
}
