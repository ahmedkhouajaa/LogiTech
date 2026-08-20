import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseCategoryService {
  static const String _prefKey = 'logitech_expense_categories_v1';

  static Future<Map<String, String>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contents = prefs.getString(_prefKey);
      if (contents != null && contents.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(contents);
        return data.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading expense categories: $e');
    }
    // Default categories if key doesn't exist
    return {
      'salaries': '💰 Salaires',
      'taxes': '👨‍✈️ Impôts',
      'rent': '🏢 Loyer',
      'other': 'Autre',
    };
  }

  static Future<void> saveCategories(Map<String, String> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(categories));
    } catch (e) {
      // ignore: avoid_print
      print('Error saving expense categories: $e');
    }
  }
}
