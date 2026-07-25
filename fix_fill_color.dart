import 'dart:io';

void main() {
  final libDir = Directory('lib/screens');
  final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('fillColor: AppColors.surface,')) {
      content = content.replaceAll('fillColor: AppColors.surface,', 'fillColor: AppColors.surfaceAlt,');
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
