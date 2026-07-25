import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    String originalContent = content;

    // We want to replace Colors.white with AppColors.surface for Cards, Containers, BoxDecorations, Materials.
    // Because of nested parentheses, regex [^)]* might stop too early if there's a nested function call before the color.
    // For example: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white) -> the nested parentheses in circular(10) will break [^)]*
    
    // A better approach: 
    // Split file by lines. If a line has `color: Colors.white` or `color: Colors.white,`,
    // AND it does not contain `TextStyle` or `Icon` or `CircularProgressIndicator` or `Text`,
    // AND the previous line doesn't have `TextStyle` or `Icon`, we just blindly replace it!
    
    List<String> lines = content.split('\n');
    bool changed = false;
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.contains('Colors.white')) {
        // Skip if it is an Icon, TextStyle, Text, or CircularProgressIndicator (usually text/icons should stay white on colored buttons)
        if (line.contains('TextStyle') || 
            line.contains('Icon(') || 
            line.contains('IconThemeData') ||
            line.contains('CircularProgressIndicator') || 
            line.contains('Text(') ||
            line.contains('foregroundColor:') ||
            line.contains('Colors.white.with')) {
          continue;
        }
        
        // Also check if it's just `color: Colors.white,` alone on a line, let's check previous line just in case
        if (i > 0 && (lines[i-1].contains('TextStyle') || lines[i-1].contains('Icon'))) {
          continue;
        }

        // We replace it!
        // We replace both `color: Colors.white` and `backgroundColor: Colors.white`
        lines[i] = line.replaceAll('Colors.white', 'AppColors.surface');
        changed = true;
      }
    }

    if (changed) {
      file.writeAsStringSync(lines.join('\n'));
      print('Fixed ${file.path}');
    }
  }
}
