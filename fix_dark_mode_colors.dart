import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  int totalUpdated = 0;
  for (final file in files) {
    if (file.path.contains('constants.dart') || file.path.contains('pdf_service.dart')) {
      continue;
    }

    String content = file.readAsStringSync();
    String original = content;

    // Replace hardcoded Colors.black87 with AppColors.textPrimary
    content = content.replaceAll('color: Colors.black87', 'color: AppColors.textPrimary');
    content = content.replaceAll('color: const Color(0xFFF1F5F9)', 'color: AppColors.surfaceAlt');
    content = content.replaceAll('color: Color(0xFFF1F5F9)', 'color: AppColors.surfaceAlt');
    content = content.replaceAll('color: Colors.black54', 'color: AppColors.textSecondary');
    content = content.replaceAll('color: Colors.black38', 'color: AppColors.textTertiary');
    
    // Also replace in _tableHeaderStyle across all create screens using regex
    content = content.replaceAllMapped(
      RegExp(r'(_tableHeaderStyle\(\)\s*\{[^}]*color:\s*)AppColors\.textSecondary', multiLine: true),
      (match) => '${match.group(1)}AppColors.textPrimary',
    );

    if (content != original) {
      file.writeAsStringSync(content);
      print('Updated dark mode colors in \${file.path}');
      totalUpdated++;
    }
  }
  print('Total files updated: \$totalUpdated');
}
