import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  int count = 0;

  for (final file in files) {
    String content = file.readAsStringSync();
    String newContent = content;
    bool changed = false;

    // Remove the bad 'const'
    String badStyle = "style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),";
    String goodStyle = "style: TextStyle(fontSize: 13, color: AppColors.textPrimary),";
    
    if (newContent.contains(badStyle)) {
      newContent = newContent.replaceAll(badStyle, goodStyle);
      changed = true;
    }

    if (changed) {
      file.writeAsStringSync(newContent);
      print('Fixed const in \${file.path}');
      count++;
    }
  }
  print('Total files fixed: \$count');
}
