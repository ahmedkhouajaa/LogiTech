import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformUtils {
  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
}
