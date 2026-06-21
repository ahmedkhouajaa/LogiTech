import os

db_path = 'd:/LogiTech/lib/database/database_helper.dart'
with open(db_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace CREATE TABLE in migration v32 with ALTER TABLE
old_migration = """        CREATE TABLE supplier_credit_notes(
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
        )"""

new_migration = """        ALTER TABLE supplier_credit_notes ADD COLUMN status TEXT;
      ''');
      await db.execute('''
        ALTER TABLE supplier_credit_notes ADD COLUMN reason TEXT;"""

content = content.replace(old_migration, new_migration)

# Replace CREATE TABLE in _createDB to include status and reason
old_create = """      CREATE TABLE supplier_credit_notes (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        purchase_invoice_id TEXT,
        supplier_id TEXT NOT NULL,
        date TEXT NOT NULL,
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )"""

new_create = """      CREATE TABLE supplier_credit_notes (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        purchase_invoice_id TEXT,
        supplier_id TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT,
        reason TEXT,
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )"""

content = content.replace(old_create, new_create)

# Since the previous migration failed, the db version might still be 31 or 32
# but we need to ensure the ALTER TABLE runs if the columns don't exist.
# However, if it runs again and the columns DO exist, it will throw an error.
# A safer migration:
safe_migration = """      try {
        await db.execute('ALTER TABLE supplier_credit_notes ADD COLUMN status TEXT');
      } catch (e) {
        // Ignore if already exists
      }
      try {
        await db.execute('ALTER TABLE supplier_credit_notes ADD COLUMN reason TEXT');
      } catch (e) {
        // Ignore if already exists
      }
      
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
      } catch (e) {
        // Ignore if already exists
      }"""

# We'll just replace the whole if (oldVersion < 32) block content
content = content.replace("""    if (oldVersion < 32) {
      await db.execute('''
        ALTER TABLE supplier_credit_notes ADD COLUMN status TEXT;
      ''');
      await db.execute('''
        ALTER TABLE supplier_credit_notes ADD COLUMN reason TEXT;
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
      ''');
    }""", f"""    if (oldVersion < 32) {{
{safe_migration}
    }}""")

with open(db_path, 'w', encoding='utf-8') as f:
    f.write(content)
