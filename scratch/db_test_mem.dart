import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/database/database_helper.dart';
import 'package:business_manager_pro/models/purchase_invoice.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('Insert Purchase Invoice InMemory', () async {
    sqfliteFfiInit();
    var factory = databaseFactoryFfi;
    var db = await factory.openDatabase(inMemoryDatabasePath);
    
    // Manually create tables to mimic what _createPurchasesRelatedTables or _upgradeDB does
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoices (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        order_id TEXT,
        delivery_note_id TEXT,
        project_id TEXT,
        devis_id TEXT,
        date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        amount_paid REAL DEFAULT 0,
        stamp_tax REAL DEFAULT 0,
        timbre_fiscal REAL DEFAULT 0,
        global_discount_percent REAL DEFAULT 0,
        global_discount_amount REAL DEFAULT 0,
        pricing_mode TEXT DEFAULT 'ht',
        notes TEXT,
        conditions TEXT,
        firebase_uid TEXT,
        credit_note_id TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        description TEXT,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        discount_percent REAL DEFAULT 0,
        total_ht REAL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices(id)
      )
    ''');

    await db.insert('suppliers', {'id': 'supp_1', 'name': 'Test Supplier'});

    final invoice = PurchaseInvoice(
      id: 'test_id',
      number: 'FA-123',
      supplierId: 'supp_1',
      date: DateTime.now(),
      dueDate: DateTime.now().add(Duration(days: 30)),
    );

    try {
      print('Inserting invoice...');
      await db.insert('purchase_invoices', invoice.toMap());
      print('Inserted invoice! Now items...');
      for (final item in invoice.items) {
        await db.insert('purchase_invoice_items', item.toMap());
      }
      print('Inserted items! Now fetching...');
      
      final maps = await db.rawQuery('''
        SELECT pi.*, s.name as supplier_name
        FROM purchase_invoices pi
        LEFT JOIN suppliers s ON pi.supplier_id = s.id
        WHERE pi.is_deleted = 0
        ORDER BY pi.created_at DESC
      ''');
      print('Maps: \${maps.length}');
      for (var map in maps) {
        final itemsMap = await db.query(
          'purchase_invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [map['id']],
        );
        final items = itemsMap.map((m) => PurchaseInvoiceItem.fromMap(m)).toList();
        final finalInvoice = PurchaseInvoice.fromMap(map).copyWith(items: items);
        print('Fetched invoice: \${finalInvoice.id}');
      }
      
      print('Success!');
    } catch (e, stack) {
      print('Error inserting invoice: \$e');
      print(stack);
    }
  });
}
