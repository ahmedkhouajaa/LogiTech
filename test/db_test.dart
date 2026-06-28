import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() {
  test('Check DB', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Find db
    String dbPath = 'logitech_erp.db';
    if (Platform.isWindows) {
      // It might be in the project root or somewhere else.
      // Usually sqflite_common_ffi puts it in the current directory.
    }
    print("Connecting to $dbPath...");
    try {
      final db = await databaseFactory.openDatabase(dbPath);
      final quotes = await db.rawQuery('SELECT id, number FROM quotes');
      print('Quotes: ${quotes.length}');
      for (var q in quotes) {
        final items = await db.rawQuery('SELECT count(*) as count FROM quote_items WHERE quote_id = ?', [q['id']]);
        print('Quote ${q['number']} has ${items.first['count']} items');
      }
      db.close();
    } catch(e) {
      print("Error: $e");
    }
  });
}
