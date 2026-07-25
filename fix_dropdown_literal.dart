import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  int count = 0;

  String brokenString = "\${match.group(0)}\$injection";
  String replacementString = '''DropdownButtonFormField(
                                  dropdownColor: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),''';

  for (final file in files) {
    String content = file.readAsStringSync();
    
    if (content.contains(brokenString)) {
      String newContent = content.replaceAll(brokenString, replacementString);
      file.writeAsStringSync(newContent);
      print('Fixed \${file.path}');
      count++;
    }
  }
  
  print('Total files fixed: \$count');
}
