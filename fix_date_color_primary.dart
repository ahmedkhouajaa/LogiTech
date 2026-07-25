import 'dart:io';

void main() {
  final libDir = Directory('lib/screens');
  final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13)')) {
      content = content.replaceAll('hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13)', 'hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13)');
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
