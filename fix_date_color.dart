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

    // Fix invoices_screen.dart and purchase_invoices_screen.dart hintStyle
    if (newContent.contains('hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13)')) {
      newContent = newContent.replaceAll(
        'hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13)',
        'hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13)',
      );
      changed = true;
    }
    
    // Sometimes it might have const TextStyle
    if (newContent.contains('hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13)')) {
      newContent = newContent.replaceAll(
        'hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13)',
        'hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13)',
      );
      changed = true;
    }

    // Fix quotes_screen.dart and others
    if (newContent.contains('_dateFrom != null ? AppColors.textPrimary : AppColors.textTertiary')) {
      newContent = newContent.replaceAll(
        '_dateFrom != null ? AppColors.textPrimary : AppColors.textTertiary',
        'AppColors.textPrimary',
      );
      changed = true;
    }

    if (newContent.contains('_dateTo != null ? AppColors.textPrimary : AppColors.textTertiary')) {
      newContent = newContent.replaceAll(
        '_dateTo != null ? AppColors.textPrimary : AppColors.textTertiary',
        'AppColors.textPrimary',
      );
      changed = true;
    }

    if (changed) {
      file.writeAsStringSync(newContent);
      print('Fixed \${file.path}');
      count++;
    }
  }
  
  print('Total files fixed: \$count');
}
