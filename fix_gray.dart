import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('constants.dart')) continue;

    String content = file.readAsStringSync();
    
    if (content.contains('0xFFF8FAFC')) {
      content = content.replaceAll('const Color(0xFFF8FAFC)', 'AppColors.background');
      content = content.replaceAll('Color(0xFFF8FAFC)', 'AppColors.background');
      file.writeAsStringSync(content);
      print('Fixed \${file.path}');
    }
  }
}
