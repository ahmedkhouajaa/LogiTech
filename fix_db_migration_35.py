import os

db_path = 'd:/LogiTech/lib/database/database_helper.dart'
with open(db_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Bump version from 34 to 35
content = content.replace('version: 34,', 'version: 35,')

# 2. Add oldVersion < 35 logic
migration35 = """    if (oldVersion < 35) {
      try {
        await db.execute('ALTER TABLE purchase_invoice_items ADD COLUMN description TEXT');
      } catch (e) {}
    }
  }

  Future<void> _createProductRelatedTables(Database db) async {"""

content = content.replace('  }\n\n  Future<void> _createProductRelatedTables(Database db) async {', migration35)

with open(db_path, 'w', encoding='utf-8') as f:
    f.write(content)
