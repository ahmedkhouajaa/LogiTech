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

    // The literal broken string for dateFrom
    String brokenDateFrom = "\${match.group(1)}_dateFrom != null ? AppColors.textPrimary : AppColors.textSecondary\${match.group(2)}";
    String fixedDateFrom = "_dateFrom != null ? formatDateLong(_dateFrom!) : 'Selectionner une date',\n                            style: TextStyle(fontSize: 13, color: _dateFrom != null ? AppColors.textPrimary : AppColors.textSecondary),";

    if (newContent.contains(brokenDateFrom)) {
      newContent = newContent.replaceAll(brokenDateFrom, fixedDateFrom);
      changed = true;
    }

    // The literal broken string for dateTo
    String brokenDateTo = "\${match.group(1)}_dateTo != null ? AppColors.textPrimary : AppColors.textSecondary\${match.group(2)}";
    String fixedDateTo = "_dateTo != null ? formatDateLong(_dateTo!) : 'Selectionner une date',\n                            style: TextStyle(fontSize: 13, color: _dateTo != null ? AppColors.textPrimary : AppColors.textSecondary),";

    if (newContent.contains(brokenDateTo)) {
      newContent = newContent.replaceAll(brokenDateTo, fixedDateTo);
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
