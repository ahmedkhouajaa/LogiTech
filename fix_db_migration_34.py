import os

db_path = 'd:/LogiTech/lib/database/database_helper.dart'
with open(db_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Bump version from 33 to 34
content = content.replace('version: 33,', 'version: 34,')

# 2. Add oldVersion < 34 logic
migration34 = """    if (oldVersion < 34) {
      try {
        await db.execute('ALTER TABLE supplier_credit_notes ADD COLUMN status TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE supplier_credit_notes ADD COLUMN reason TEXT');
      } catch (e) {}
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
      } catch (e) {}
    }
  }

  Future<void> _createProductRelatedTables(Database db) async {"""

content = content.replace('  }\n\n  Future<void> _createProductRelatedTables(Database db) async {', migration34)

with open(db_path, 'w', encoding='utf-8') as f:
    f.write(content)
