import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  int totalUpdated = 0;
  for (final file in files) {
    if (file.path.contains('constants.dart')) continue;

    String content = file.readAsStringSync();
    String original = content;

    if (content.contains('AppColors.')) {
      final widgets = [
        'Text', 'TextStyle', 'DropdownMenuItem', 'InputDecoration',
        'Padding', 'Center', 'Column', 'Row', 'Expanded', 'Container',
        'Align', 'ClipRRect', 'BorderSide', 'BoxDecoration', 'EdgeInsets',
        'SizedBox', 'Icon', 'IconButton', 'Card', 'Divider', 'Border'
      ];
      for (final w in widgets) {
        content = content.replaceAll('const ' + w + '(', w + '(');
        content = content.replaceAll('const ' + w + '.', w + '.');
      }
    }

    if (content != original) {
      file.writeAsStringSync(content);
      print('Stripped consts in ' + file.path);
      totalUpdated++;
    }
  }
  print('Total files updated: ' + totalUpdated.toString());
}
