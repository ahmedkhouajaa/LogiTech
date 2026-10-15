// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<void> openPdfInChromeImpl(Uint8List bytes, String fileName, BuildContext context) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future.delayed(const Duration(minutes: 5), () {
    html.Url.revokeObjectUrl(url);
  });
}
