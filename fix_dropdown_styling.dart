import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  int count = 0;

  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    // Use regex to find DropdownButtonFormField instantiations
    // We match DropdownButtonFormField<Type>( or DropdownButtonFormField(
    final RegExp dropdownRegex = RegExp(r'DropdownButtonFormField(?:<[^>]+>)?\s*\(');
    
    String newContent = content.replaceAllMapped(dropdownRegex, (match) {
      // Check if this block already has dropdownColor (we'll just check the next 500 characters to be safe)
      int startIndex = match.end;
      int endIndex = startIndex + 500;
      if (endIndex > content.length) endIndex = content.length;
      
      String lookahead = content.substring(startIndex, endIndex);
      
      String injection = '';
      if (!lookahead.contains('dropdownColor:')) {
        injection += '\ndropdownColor: AppColors.surfaceAlt,';
      }
      if (!lookahead.contains('borderRadius:')) {
        injection += '\nborderRadius: BorderRadius.circular(AppRadius.md),';
      }
      if (!lookahead.contains('style:') && !lookahead.contains('style :')) {
        injection += '\nstyle: TextStyle(fontSize: 13, color: AppColors.textPrimary),';
      }
      
      if (injection.isNotEmpty) {
        changed = true;
        return "\${match.group(0)}\$injection";
      }
      return match.group(0)!;
    });

    if (changed) {
      file.writeAsStringSync(newContent);
      print('Fixed \${file.path}');
      count++;
    }
  }
  
  print('Total files fixed: \$count');
}
