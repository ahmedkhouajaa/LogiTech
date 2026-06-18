import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExpenseCategoryService {
  static const String _fileName = 'expense_categories.json';

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<Map<String, String>> loadCategories() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(contents);
        return data.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      print('Error loading expense categories: $e');
    }
    // Default categories if file doesn't exist
    return {
      'salaries': '💰 Salaires',
      'taxes': '👨‍✈️ Impôts',
      'rent': '🏢 Loyer',
      'other': 'Autre',
    };
  }

  static Future<void> saveCategories(Map<String, String> categories) async {
    try {
      final file = await _file;
      await file.writeAsString(jsonEncode(categories));
    } catch (e) {
      print('Error saving expense categories: $e');
    }
  }
}
