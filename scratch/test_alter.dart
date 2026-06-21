import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  // Get home directory for Documents (since it's a typical Windows setup)
  var home = Platform.environment['USERPROFILE'];
  var dbPath = '$home\\Documents\\business_manager_pro.db';
  print('Opening db at ' + dbPath);
  try {
    var db = await databaseFactory.openDatabase(dbPath);
    
    // Check if table exists
    var res = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='supplier_credit_notes'");
    print('Table exists: ' + res.toString());

    // Try alter table
    try {
      await db.execute('ALTER TABLE supplier_credit_notes ADD COLUMN status TEXT');
      print('Added status column');
    } catch (e) {
      print('Error adding status: ' + e.toString());
    }

    try {
      await db.execute('ALTER TABLE supplier_credit_notes ADD COLUMN reason TEXT');
      print('Added reason column');
    } catch (e) {
      print('Error adding reason: ' + e.toString());
    }
    
    // Create items table just in case
    try {
        await db.execute('''
          CREATE TABLE supplier_credit_note_items(
            id TEXT PRIMARY KEY,
            supplier_credit_note_id TEXT,
            product_id TEXT,
            designation TEXT,
            quantity REAL,
            unit_price REAL,
            tva_rate REAL,
            total_ht REAL,
            total_ttc REAL,
            FOREIGN KEY (supplier_credit_note_id) REFERENCES supplier_credit_notes(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id)
          )
        ''');
        print('Created items table');
    } catch(e) {
        print('Error creating items table: ' + e.toString());
    }

    await db.close();
  } catch (e) {
    print('DB Error: ' + e.toString());
  }
}
