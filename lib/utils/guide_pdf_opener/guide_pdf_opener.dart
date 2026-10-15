import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'guide_pdf_opener_stub.dart'
    if (dart.library.html) 'guide_pdf_opener_web.dart'
    if (dart.library.io) 'guide_pdf_opener_io.dart';

class GuidePdfOpener {
  /// Opens the PDF document in Google Chrome (or default browser / PDF reader)
  /// seamlessly on Web, Desktop (Windows, macOS, Linux) and Android.
  static Future<void> openPdfInChrome(
    Uint8List bytes,
    String fileName,
    BuildContext context,
  ) {
    return openPdfInChromeImpl(bytes, fileName, context);
  }
}
