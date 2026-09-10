import 'dart:typed_data';
import 'support_image_reader_io.dart'
    if (dart.library.html) 'support_image_reader_web.dart' as platform_reader;

class SupportImageReader {
  static Future<Uint8List?> readFileBytes(String path) {
    return platform_reader.readLocalFileBytes(path);
  }
}
