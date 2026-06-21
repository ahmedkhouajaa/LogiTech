const fs = require('fs');

let dbPath = 'd:/LogiTech/lib/database/database_helper.dart';
let dbContent = fs.readFileSync(dbPath, 'utf8');

// 1. Add creation logic to DB
const createTableQuery = `      await db.execute('''
        CREATE TABLE supplier_credit_notes(
          id TEXT PRIMARY KEY,
          number TEXT,
          supplier_id TEXT,
          date TEXT,
          status TEXT,
          reason TEXT,
          total_ht REAL,
          total_tva REAL,
          total_ttc REAL,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
        )
      ''');

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
      ''');`;

dbContent = dbContent.replace(
  /if \(oldVersion < 32\) \{[\s\S]*?\}/,
  `if (oldVersion < 32) {
${createTableQuery}
    }`
);

if (!dbContent.includes('oldVersion < 32')) {
  dbContent = dbContent.replace(
    /if \(oldVersion < 31\) \{[\s\S]*?\}/,
    `$&
    if (oldVersion < 32) {
${createTableQuery}
    }`
  );
}

// Ensure version is 32
dbContent = dbContent.replace(/static const int _version = 31;/, 'static const int _version = 32;');

// 2. Add methods
const methods = `  // ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
  // Supplier Credit Notes (Avoirs Fournisseur)
  // ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈

  Future<int> getNextSupplierCreditNoteSequence() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM supplier_credit_notes WHERE date LIKE ?",
        ['\${DateTime.now().year}-%']);
    return (Sqflite.firstIntValue(result) ?? 0) + 1;
  }

  Future<List<SupplierCreditNote>> getSupplierCreditNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'supplier_credit_notes',
      where: 'is_deleted = 0',
      orderBy: 'date DESC',
    );
    
    List<SupplierCreditNote> notes = [];
    for (var map in maps) {
      final items = await _getSupplierCreditNoteItems(map['id']);
      notes.add(SupplierCreditNote.fromMap(map, items));
    }
    return notes;
  }

  Future<List<SupplierCreditNoteItem>> _getSupplierCreditNoteItems(String noteId) async {
    final db = await database;
    final maps = await db.query(
      'supplier_credit_note_items',
      where: 'supplier_credit_note_id = ?',
      whereArgs: [noteId],
    );
    return maps.map((e) => SupplierCreditNoteItem.fromMap(e)).toList();
  }

  Future<void> insertSupplierCreditNote(SupplierCreditNote note) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('supplier_credit_notes', note.toMap());
      for (var item in note.items) {
        await txn.insert('supplier_credit_note_items', item.toMap());
      }
    });
  }

  Future<void> updateSupplierCreditNote(SupplierCreditNote note) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'supplier_credit_notes',
        {...note.toMap(), 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [note.id],
      );
      
      await txn.delete(
        'supplier_credit_note_items',
        where: 'supplier_credit_note_id = ?',
        whereArgs: [note.id],
      );
      
      for (var item in note.items) {
        await txn.insert('supplier_credit_note_items', item.toMap());
      }
    });
  }

  Future<void> deleteSupplierCreditNote(String id) async {
    final db = await database;
    await db.update(
      'supplier_credit_notes',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
`;

if (!dbContent.includes('getSupplierCreditNotes')) {
  dbContent = dbContent.replace(/}\s*$/, methods + '\n}\n');
}

if (!dbContent.includes("import '../models/supplier_credit_note.dart';")) {
    dbContent = dbContent.replace("import '../models/supplier_return.dart';", "import '../models/supplier_return.dart';\nimport '../models/supplier_credit_note.dart';");
}

fs.writeFileSync(dbPath, dbContent, 'utf8');
