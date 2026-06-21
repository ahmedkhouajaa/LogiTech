import os

db_path = 'd:/LogiTech/lib/database/database_helper.dart'
with open(db_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Bump version from 32 to 33
content = content.replace('version: 32,', 'version: 33,')

# 2. Add oldVersion < 33 logic
migration33 = """    if (oldVersion < 33) {
      try {
        await db.execute('ALTER TABLE supplier_credit_notes ADD COLUMN status TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE supplier_credit_notes ADD COLUMN reason TEXT');
      } catch (e) {}
    }
  }

  Future<void> _createProductRelatedTables(Database db) async {"""

content = content.replace('  }\n\n  Future<void> _createProductRelatedTables(Database db) async {', migration33)

with open(db_path, 'w', encoding='utf-8') as f:
    f.write(content)
