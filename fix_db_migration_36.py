import os

db_path = 'd:/LogiTech/lib/database/database_helper.dart'
with open(db_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Bump version from 35 to 36
content = content.replace('version: 35,', 'version: 36,')

# 2. Add oldVersion < 36 logic
migration36 = """    if (oldVersion < 36) {
      try {
        await db.execute('ALTER TABLE purchase_invoice_items ADD COLUMN discount_percent REAL DEFAULT 0');
      } catch (e) {}
    }
  }

  Future<void> _createProductRelatedTables(Database db) async {"""

content = content.replace('  }\n\n  Future<void> _createProductRelatedTables(Database db) async {', migration36)

with open(db_path, 'w', encoding='utf-8') as f:
    f.write(content)
