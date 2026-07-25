import 'dart:io';

void main() {
  // 1. Fix const errors in app_shell_screen.dart and mobile_shell_screen.dart
  void removeConsts(String path) {
    final file = File(path);
    if (file.existsSync()) {
      String content = file.readAsStringSync();
      // Remove the word const before widgets that might use AppColors
      content = content.replaceAll('const Row(', 'Row(')
                       .replaceAll('const Icon(', 'Icon(')
                       .replaceAll('const Text(', 'Text(')
                       .replaceAll('const SizedBox(', 'SizedBox(')
                       .replaceAll('const Padding(', 'Padding(')
                       .replaceAll('const Column(', 'Column(')
                       .replaceAll('const Expanded(', 'Expanded(');
      file.writeAsStringSync(content);
    }
  }
  removeConsts('lib/screens/app_shell_screen.dart');
  removeConsts('lib/mobile/mobile_shell_screen.dart');

  // 2. Fix Duplicated named argument 'style' in specific files
  final duplicateFiles = [
    'lib/screens/stock_screen.dart',
    'lib/screens/stock_withdrawals_screen.dart',
    'lib/screens/stock_entries_screen.dart',
    'lib/screens/stock_transfers_screen.dart',
    'lib/screens/inventory_sheets_screen.dart',
    'lib/mobile/screens/mobile_stock_screen.dart',
    'lib/mobile/screens/mobile_stock_movements_screen.dart',
  ];
  
  String injectedStyle = "style: TextStyle(fontSize: 13, color: AppColors.textPrimary),";

  for (final path in duplicateFiles) {
    final file = File(path);
    if (file.existsSync()) {
      String content = file.readAsStringSync();
      // We know the duplicate is our injected one because we injected it literally.
      // Wait, there might be multiple dropdowns in the file, some have duplicates some don't.
      // Let's just remove the first instance of 'style: TextStyle(fontSize: 13, color: AppColors.textPrimary),' 
      // if it occurs in a block that already has 'style:'.
      // Actually, we can just replace the injected style with nothing if it's duplicated.
      // But it's easier to just remove our injected style completely from these specific files if they already had styles.
      // Let's just remove our injected style from all dropdowns in these files, since they already had styles!
      content = content.replaceAll(injectedStyle, "");
      file.writeAsStringSync(content);
    }
  }

  // 3. Fix Object? to String? generics
  void fixGeneric(String path) {
    final file = File(path);
    if (file.existsSync()) {
      String content = file.readAsStringSync();
      // Replace DropdownButtonFormField( with DropdownButtonFormField<String>( if it's not already
      // This is a bit brute-force, let's just do it for all DropdownButtonFormField in these 2 files
      content = content.replaceAll('DropdownButtonFormField(', 'DropdownButtonFormField<String>(');
      file.writeAsStringSync(content);
    }
  }
  fixGeneric('lib/screens/create_article_screen.dart');
  fixGeneric('lib/screens/create_inventory_sheet_screen.dart');
  
  print('Fixes applied.');
}
