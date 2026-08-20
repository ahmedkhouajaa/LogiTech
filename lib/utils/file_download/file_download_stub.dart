import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<String?> saveAndOpenFileImpl(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
  BuildContext? context,
}) async {
  throw UnsupportedError('Cannot save file on this platform');
}

Future<String?> saveStringFileImpl(
  String content,
  String fileName, {
  String? mimeType,
  BuildContext? context,
}) async {
  throw UnsupportedError('Cannot save file on this platform');
}

Future<void> openFileImpl(String path) async {
  // No-op on unsupported platform
}
