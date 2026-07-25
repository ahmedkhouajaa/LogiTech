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

    // 1. Invoices and Purchase Invoices
    if (newContent.contains('hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13)')) {
      newContent = newContent.replaceAll(
        'hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13)',
        'hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13)'
      );
      changed = true;
    }

    // 2. dateFrom logic
    // Look for: _dateFrom != null ? formatDateLong(_dateFrom!) : 'Selectionner une date',
    // and the following line: style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
    // We want to replace AppColors.textPrimary on the NEXT line with _dateFrom != null ? AppColors.textPrimary : AppColors.textSecondary
    
    // A robust way is regex:
    RegExp dateFromExp = RegExp(
      r"(_dateFrom != null \? formatDateLong\(_dateFrom!\) : 'Selectionner une date',\s*style:\s*TextStyle\(fontSize:\s*13,\s*color:\s*)AppColors\.textPrimary(\),)"
    );
    if (dateFromExp.hasMatch(newContent)) {
      newContent = newContent.replaceAllMapped(dateFromExp, (match) {
        return "\${match.group(1)}_dateFrom != null ? AppColors.textPrimary : AppColors.textSecondary\${match.group(2)}";
      });
      changed = true;
    }

    // 3. dateTo logic
    RegExp dateToExp = RegExp(
      r"(_dateTo != null \? formatDateLong\(_dateTo!\) : 'Selectionner une date',\s*style:\s*TextStyle\(fontSize:\s*13,\s*color:\s*)AppColors\.textPrimary(\),)"
    );
    if (dateToExp.hasMatch(newContent)) {
      newContent = newContent.replaceAllMapped(dateToExp, (match) {
        return "\${match.group(1)}_dateTo != null ? AppColors.textPrimary : AppColors.textSecondary\${match.group(2)}";
      });
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
