import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  int totalUpdated = 0;
  for (final file in files) {
    String content = file.readAsStringSync();
    String original = content;

    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('AppColors.') || lines[i].contains('_tableHeaderStyle()')) {
        // Remove const from Text, TextStyle, DropdownMenuItem on this line
        lines[i] = lines[i].replaceAll('const Text(', 'Text(');
        lines[i] = lines[i].replaceAll('const TextStyle(', 'TextStyle(');
        lines[i] = lines[i].replaceAll('const DropdownMenuItem(', 'DropdownMenuItem(');
        lines[i] = lines[i].replaceAll('const InputDecoration(', 'InputDecoration(');
        lines[i] = lines[i].replaceAll('const BorderSide(', 'BorderSide(');
        lines[i] = lines[i].replaceAll('const BoxDecoration(', 'BoxDecoration(');
        lines[i] = lines[i].replaceAll('const Padding(', 'Padding(');
        lines[i] = lines[i].replaceAll('const Container(', 'Container(');
      }
    }
    content = lines.join('\n');

    if (content != original) {
      file.writeAsStringSync(content);
      print('Fixed const in \${file.path}');
      totalUpdated++;
    }
  }
  print('Total files updated: \$totalUpdated');
}
