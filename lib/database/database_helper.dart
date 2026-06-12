import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/quote.dart';
import '../models/delivery_note.dart';
import '../models/stock_movement.dart';
import '../models/transaction_model.dart';
import '../models/check_traite.dart';
import '../models/project.dart';
import '../models/payment_model.dart';
import '../models/customer_order.dart';
import '../models/stock_withdrawal.dart';
import '../models/supplier_order.dart';
import '../utils/constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final _uuid = const Uuid();

  DatabaseHelper._init();

  String get newId => _uuid.v4();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'business_manager_pro.db');
    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final columns = [
        "ALTER TABLE customers ADD COLUMN customer_type TEXT DEFAULT 'entreprise'",
        "ALTER TABLE customers ADD COLUMN company_name TEXT",
        "ALTER TABLE customers ADD COLUMN responsible_name TEXT",
        "ALTER TABLE customers ADD COLUMN cin_number TEXT",
        "ALTER TABLE customers ADD COLUMN birth_date TEXT",
        "ALTER TABLE customers ADD COLUMN reference_code TEXT",
        "ALTER TABLE customers ADD COLUMN street_address TEXT",
        "ALTER TABLE customers ADD COLUMN postal_code TEXT",
        "ALTER TABLE customers ADD COLUMN country TEXT DEFAULT 'Tunisia'",
        "ALTER TABLE customers ADD COLUMN delivery_street TEXT",
        "ALTER TABLE customers ADD COLUMN delivery_city TEXT",
        "ALTER TABLE customers ADD COLUMN delivery_postal_code TEXT",
        "ALTER TABLE customers ADD COLUMN delivery_country TEXT DEFAULT 'Tunisia'",
        "ALTER TABLE customers ADD COLUMN delivery_same_as_billing INTEGER DEFAULT 1",
        "ALTER TABLE customers ADD COLUMN bank_account TEXT",
        "ALTER TABLE customers ADD COLUMN tva_suspension INTEGER DEFAULT 0",
        "ALTER TABLE customers ADD COLUMN price_list TEXT DEFAULT 'default'",
        "ALTER TABLE customers ADD COLUMN private_note TEXT",
      ];
      for (final sql in columns) {
        try {
          await db.execute(sql);
        } catch (e) {
          // Ignore if the column already exists
        }
      }
    }
    if (oldVersion < 3) {
      await _createPaymentTables(db);
    }
    if (oldVersion < 4) {
      final invoiceColumns = [
        "ALTER TABLE invoices ADD COLUMN project_id TEXT",
        "ALTER TABLE invoices ADD COLUMN conditions TEXT",
        "ALTER TABLE invoices ADD COLUMN pricing_mode TEXT DEFAULT 'ht'",
        "ALTER TABLE invoices ADD COLUMN global_discount_percent REAL DEFAULT 0",
        "ALTER TABLE invoices ADD COLUMN global_discount_amount REAL DEFAULT 0",
        "ALTER TABLE invoices ADD COLUMN timbre_fiscal REAL DEFAULT 0",
      ];
      for (final sql in invoiceColumns) {
        try {
          await db.execute(sql);
        } catch (e) {
          // Ignore if the column already exists
        }
      }
    }
    if (oldVersion < 5) {
      final orderColumns = [
        "ALTER TABLE customer_orders ADD COLUMN project_id TEXT",
        "ALTER TABLE customer_orders ADD COLUMN conditions TEXT",
        "ALTER TABLE customer_orders ADD COLUMN pricing_mode TEXT DEFAULT 'ht'",
        "ALTER TABLE customer_orders ADD COLUMN global_discount_percent REAL DEFAULT 0",
        "ALTER TABLE customer_orders ADD COLUMN global_discount_amount REAL DEFAULT 0",
        "ALTER TABLE customer_orders ADD COLUMN timbre_fiscal REAL DEFAULT 1.000",
      ];
      final orderItemColumns = [
        "ALTER TABLE customer_order_items ADD COLUMN discount_percent REAL DEFAULT 0",
        "ALTER TABLE customer_order_items ADD COLUMN show_description INTEGER DEFAULT 0",
        "ALTER TABLE customer_order_items ADD COLUMN show_discount INTEGER DEFAULT 0",
      ];
      for (final sql in [...orderColumns, ...orderItemColumns]) {
        try {
          await db.execute(sql);
        } catch (e) {
          // Ignore if the column already exists
        }
      }
    }
    if (oldVersion < 6) {
      final dnColumns = [
        "ALTER TABLE delivery_notes ADD COLUMN project_id TEXT",
        "ALTER TABLE delivery_notes ADD COLUMN pricing_mode TEXT DEFAULT 'ht'",
        "ALTER TABLE delivery_notes ADD COLUMN global_discount_percent REAL DEFAULT 0",
        "ALTER TABLE delivery_notes ADD COLUMN global_discount_amount REAL DEFAULT 0",
        "ALTER TABLE delivery_notes ADD COLUMN timbre_fiscal REAL DEFAULT 0",
        "ALTER TABLE delivery_notes ADD COLUMN vehicle_registration TEXT",
        "ALTER TABLE delivery_notes ADD COLUMN driver_name TEXT",
        "ALTER TABLE delivery_notes ADD COLUMN conditions TEXT",
        "ALTER TABLE delivery_notes ADD COLUMN total_ht REAL DEFAULT 0",
        "ALTER TABLE delivery_notes ADD COLUMN total_tva REAL DEFAULT 0",
        "ALTER TABLE delivery_notes ADD COLUMN total_ttc REAL DEFAULT 0",
      ];
      final dniColumns = [
        "ALTER TABLE delivery_note_items ADD COLUMN description TEXT",
        "ALTER TABLE delivery_note_items ADD COLUMN tva_rate REAL DEFAULT 19",
        "ALTER TABLE delivery_note_items ADD COLUMN discount_percent REAL DEFAULT 0",
        "ALTER TABLE delivery_note_items ADD COLUMN total_ht REAL DEFAULT 0",
        "ALTER TABLE delivery_note_items ADD COLUMN show_description INTEGER DEFAULT 0",
        "ALTER TABLE delivery_note_items ADD COLUMN show_discount INTEGER DEFAULT 0",
      ];
      for (final sql in [...dnColumns, ...dniColumns]) {
        try {
          await db.execute(sql);
        } catch (e) {
          // Ignore if already exists
        }
      }
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bons_sortie (
          id TEXT PRIMARY KEY,
          number TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          project_id TEXT,
          date TEXT NOT NULL,
          status TEXT DEFAULT 'draft',
          pricing_mode TEXT DEFAULT 'ht',
          global_discount_percent REAL DEFAULT 0,
          global_discount_amount REAL DEFAULT 0,
          timbre_fiscal REAL DEFAULT 0,
          vehicle_registration TEXT,
          driver_name TEXT,
          warehouse_id TEXT,
          notes TEXT,
          conditions TEXT,
          total_ht REAL DEFAULT 0,
          total_tva REAL DEFAULT 0,
          total_ttc REAL DEFAULT 0,
          firebase_uid TEXT,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS bons_sortie_items (
          id TEXT PRIMARY KEY,
          withdrawal_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          description TEXT,
          quantity REAL DEFAULT 1,
          unit_price REAL DEFAULT 0,
          tva_rate REAL DEFAULT 19,
          discount_percent REAL DEFAULT 0,
          total_ht REAL DEFAULT 0,
          show_description INTEGER DEFAULT 0,
          show_discount INTEGER DEFAULT 0,
          FOREIGN KEY (withdrawal_id) REFERENCES bons_sortie(id)
        )
      ''');
    }

    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bons_sortie (
          id TEXT PRIMARY KEY,
          number TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          project_id TEXT,
          date TEXT NOT NULL,
          status TEXT DEFAULT 'draft',
          pricing_mode TEXT DEFAULT 'ht',
          global_discount_percent REAL DEFAULT 0,
          global_discount_amount REAL DEFAULT 0,
          timbre_fiscal REAL DEFAULT 0,
          vehicle_registration TEXT,
          driver_name TEXT,
          warehouse_id TEXT,
          notes TEXT,
          conditions TEXT,
          total_ht REAL DEFAULT 0,
          total_tva REAL DEFAULT 0,
          total_ttc REAL DEFAULT 0,
          firebase_uid TEXT,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS bons_sortie_items (
          id TEXT PRIMARY KEY,
          withdrawal_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          description TEXT,
          quantity REAL DEFAULT 1,
          unit_price REAL DEFAULT 0,
          tva_rate REAL DEFAULT 19,
          discount_percent REAL DEFAULT 0,
          total_ht REAL DEFAULT 0,
          show_description INTEGER DEFAULT 0,
          show_discount INTEGER DEFAULT 0,
          FOREIGN KEY (withdrawal_id) REFERENCES bons_sortie(id)
        )
      ''');
    }

    if (oldVersion < 9) {
      final soColumns = [
        "ALTER TABLE supplier_orders ADD COLUMN project_id TEXT",
        "ALTER TABLE supplier_orders ADD COLUMN pricing_mode TEXT DEFAULT 'ht'",
        "ALTER TABLE supplier_orders ADD COLUMN global_discount_percent REAL DEFAULT 0",
        "ALTER TABLE supplier_orders ADD COLUMN global_discount_amount REAL DEFAULT 0",
        "ALTER TABLE supplier_orders ADD COLUMN timbre_fiscal REAL DEFAULT 1.000",
        "ALTER TABLE supplier_orders ADD COLUMN conditions TEXT",
      ];
      final soiColumns = [
        "ALTER TABLE supplier_order_items ADD COLUMN description TEXT",
        "ALTER TABLE supplier_order_items ADD COLUMN discount_percent REAL DEFAULT 0",
        "ALTER TABLE supplier_order_items ADD COLUMN show_description INTEGER DEFAULT 0",
        "ALTER TABLE supplier_order_items ADD COLUMN show_discount INTEGER DEFAULT 0",
      ];
      for (final sql in [...soColumns, ...soiColumns]) {
        try {
          await db.execute(sql);
        } catch (e) {
          // Ignore if the column already exists
        }
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // ─── Company Settings ─────────────────────────────────────────
    await db.execute('''
      CREATE TABLE company_settings (
        id TEXT PRIMARY KEY DEFAULT '1',
        name TEXT NOT NULL DEFAULT 'Mon Entreprise',
        logo_path TEXT,
        address TEXT,
        city TEXT,
        phone TEXT,
        email TEXT,
        website TEXT,
        tax_id TEXT,
        rc_number TEXT,
        nis TEXT,
        nif TEXT,
        ai TEXT,
        currency TEXT DEFAULT 'DZD',
        default_tva_rate REAL DEFAULT 19,
        invoice_prefix TEXT DEFAULT 'FAC',
        next_invoice_number INTEGER DEFAULT 1,
        bank_name TEXT,
        bank_account TEXT,
        rib TEXT,
        updated_at TEXT
      )
    ''');

    // Insert default settings
    await db.insert('company_settings', {
      'id': '1',
      'name': 'Mon Entreprise',
      'currency': 'DZD',
      'default_tva_rate': 19,
      'invoice_prefix': 'FAC',
      'next_invoice_number': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // ─── Customers ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        city TEXT,
        tax_id TEXT,
        rc TEXT,
        balance REAL DEFAULT 0,
        credit_limit REAL DEFAULT 0,
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        customer_type TEXT DEFAULT 'entreprise',
        company_name TEXT,
        responsible_name TEXT,
        cin_number TEXT,
        birth_date TEXT,
        reference_code TEXT,
        street_address TEXT,
        postal_code TEXT,
        country TEXT DEFAULT 'Tunisia',
        delivery_street TEXT,
        delivery_city TEXT,
        delivery_postal_code TEXT,
        delivery_country TEXT DEFAULT 'Tunisia',
        delivery_same_as_billing INTEGER DEFAULT 1,
        bank_account TEXT,
        tva_suspension INTEGER DEFAULT 0,
        price_list TEXT DEFAULT 'default',
        private_note TEXT
      )
    ''');

    // ─── Suppliers ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        city TEXT,
        tax_id TEXT,
        rc TEXT,
        balance REAL DEFAULT 0,
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Products ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        unit TEXT DEFAULT 'Unité',
        purchase_price REAL DEFAULT 0,
        selling_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        stock_qty REAL DEFAULT 0,
        min_stock_qty REAL DEFAULT 0,
        barcode TEXT,
        is_active INTEGER DEFAULT 1,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Warehouses ───────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE warehouses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        is_default INTEGER DEFAULT 0,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Insert default warehouse
    await db.insert('warehouses', {
      'id': const Uuid().v4(),
      'name': 'Entrepôt Principal',
      'is_default': 1,
      'is_deleted': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // ─── Quotes ───────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE quotes (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        date TEXT NOT NULL,
        validity_date TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE quote_items (
        id TEXT PRIMARY KEY,
        quote_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        description TEXT,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        discount_percent REAL DEFAULT 0,
        total_ht REAL DEFAULT 0,
        FOREIGN KEY (quote_id) REFERENCES quotes(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // ─── Customer Orders ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE customer_orders (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        project_id TEXT,
        quote_id TEXT,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        delivery_date TEXT,
        pricing_mode TEXT DEFAULT 'ht',
        global_discount_percent REAL DEFAULT 0,
        global_discount_amount REAL DEFAULT 0,
        timbre_fiscal REAL DEFAULT 1.000,
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        notes TEXT,
        conditions TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        description TEXT,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        discount_percent REAL DEFAULT 0,
        total_ht REAL DEFAULT 0,
        show_description INTEGER DEFAULT 0,
        show_discount INTEGER DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES customer_orders(id)
      )
    ''');

    // ─── Delivery Notes ───────────────────────────────────────────
    await db.execute('''
      CREATE TABLE delivery_notes (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        order_id TEXT,
        project_id TEXT,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        pricing_mode TEXT DEFAULT 'ht',
        global_discount_percent REAL DEFAULT 0,
        global_discount_amount REAL DEFAULT 0,
        timbre_fiscal REAL DEFAULT 0,
        vehicle_registration TEXT,
        driver_name TEXT,
        warehouse_id TEXT,
        notes TEXT,
        conditions TEXT,
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE delivery_note_items (
        id TEXT PRIMARY KEY,
        delivery_note_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        description TEXT,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        discount_percent REAL DEFAULT 0,
        total_ht REAL DEFAULT 0,
        show_description INTEGER DEFAULT 0,
        show_discount INTEGER DEFAULT 0,
        FOREIGN KEY (delivery_note_id) REFERENCES delivery_notes(id)
      )
    ''');

    // ─── Exit Vouchers (Bons de Sortie) ───────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bons_sortie (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        project_id TEXT,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        pricing_mode TEXT DEFAULT 'ht',
        global_discount_percent REAL DEFAULT 0,
        global_discount_amount REAL DEFAULT 0,
        timbre_fiscal REAL DEFAULT 0,
        vehicle_registration TEXT,
        driver_name TEXT,
        warehouse_id TEXT,
        notes TEXT,
        conditions TEXT,
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bons_sortie_items (
        id TEXT PRIMARY KEY,
        withdrawal_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        description TEXT,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        discount_percent REAL DEFAULT 0,
        total_ht REAL DEFAULT 0,
        show_description INTEGER DEFAULT 0,
        show_discount INTEGER DEFAULT 0,
        FOREIGN KEY (withdrawal_id) REFERENCES bons_sortie(id)
      )
    ''');

    // ─── Invoices ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        order_id TEXT,
        delivery_note_id TEXT,
        project_id TEXT,
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
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        description TEXT,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        discount_percent REAL DEFAULT 0,
        total_ht REAL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id)
      )
    ''');

    // ─── Credit Notes ─────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE credit_notes (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        invoice_id TEXT,
        customer_id TEXT NOT NULL,
        date TEXT NOT NULL,
        reason TEXT,
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE credit_note_items (
        id TEXT PRIMARY KEY,
        credit_note_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        total_ht REAL DEFAULT 0,
        FOREIGN KEY (credit_note_id) REFERENCES credit_notes(id)
      )
    ''');

    // ─── Exit Vouchers ────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE exit_vouchers (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        customer_id TEXT,
        date TEXT NOT NULL,
        warehouse_id TEXT,
        status TEXT DEFAULT 'draft',
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exit_voucher_items (
        id TEXT PRIMARY KEY,
        voucher_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        FOREIGN KEY (voucher_id) REFERENCES exit_vouchers(id)
      )
    ''');

    // ─── Return Vouchers ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE return_vouchers (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        invoice_id TEXT,
        date TEXT NOT NULL,
        reason TEXT,
        status TEXT DEFAULT 'draft',
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE return_voucher_items (
        id TEXT PRIMARY KEY,
        voucher_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        reason TEXT,
        FOREIGN KEY (voucher_id) REFERENCES return_vouchers(id)
      )
    ''');

    // ─── Supplier Orders ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE supplier_orders (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        expected_date TEXT,
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        notes TEXT,
        project_id TEXT,
        pricing_mode TEXT DEFAULT 'ht',
        global_discount_percent REAL DEFAULT 0,
        global_discount_amount REAL DEFAULT 0,
        timbre_fiscal REAL DEFAULT 1.000,
        conditions TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE supplier_order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        description TEXT,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        discount_percent REAL DEFAULT 0,
        show_description INTEGER DEFAULT 0,
        show_discount INTEGER DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES supplier_orders(id)
      )
    ''');

    // ─── Receiving Vouchers ───────────────────────────────────────
    await db.execute('''
      CREATE TABLE receiving_vouchers (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        order_id TEXT,
        date TEXT NOT NULL,
        warehouse_id TEXT,
        status TEXT DEFAULT 'draft',
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE receiving_voucher_items (
        id TEXT PRIMARY KEY,
        voucher_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity_expected REAL DEFAULT 0,
        quantity_received REAL DEFAULT 0,
        FOREIGN KEY (voucher_id) REFERENCES receiving_vouchers(id)
      )
    ''');

    // ─── Purchase Invoices ────────────────────────────────────────
    await db.execute('''
      CREATE TABLE purchase_invoices (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        order_id TEXT,
        date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        total_ht REAL DEFAULT 0,
        total_tva REAL DEFAULT 0,
        total_ttc REAL DEFAULT 0,
        amount_paid REAL DEFAULT 0,
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        tva_rate REAL DEFAULT 19,
        total_ht REAL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices(id)
      )
    ''');

    // ─── Supplier Credit Notes ────────────────────────────────────
    await db.execute('''
      CREATE TABLE supplier_credit_notes (
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
      )
    ''');

    // ─── Supplier Returns ─────────────────────────────────────────
    await db.execute('''
      CREATE TABLE supplier_returns (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        purchase_invoice_id TEXT,
        date TEXT NOT NULL,
        reason TEXT,
        status TEXT DEFAULT 'draft',
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Accounts ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'cash',
        bank_name TEXT,
        account_number TEXT,
        balance REAL DEFAULT 0,
        is_default INTEGER DEFAULT 0,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Insert default cash account
    await db.insert('accounts', {
      'id': const Uuid().v4(),
      'name': 'Caisse Principale',
      'type': 'cash',
      'balance': 0,
      'is_default': 1,
      'is_deleted': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // ─── Transactions ─────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        reference TEXT,
        description TEXT,
        related_invoice_id TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');

    // ─── Checks & Traites ─────────────────────────────────────────
    await db.execute('''
      CREATE TABLE checks_traites (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        number TEXT NOT NULL,
        amount REAL NOT NULL,
        date_issued TEXT NOT NULL,
        maturity_date TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        party_name TEXT NOT NULL,
        account_id TEXT,
        bank_name TEXT,
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Withholding Tax ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE withholding_tax (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        invoice_id TEXT,
        rate REAL NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        declaration_date TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Stock Movements ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_type TEXT,
        reference_id TEXT,
        date TEXT NOT NULL,
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
      )
    ''');

    // ─── Stock Entries ────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE stock_entries (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        date TEXT NOT NULL,
        supplier_id TEXT,
        reason TEXT,
        status TEXT DEFAULT 'draft',
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_entry_items (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        unit_price REAL DEFAULT 0,
        FOREIGN KEY (entry_id) REFERENCES stock_entries(id)
      )
    ''');

    // ─── Stock Withdrawals ────────────────────────────────────────
    await db.execute('''
      CREATE TABLE stock_withdrawals (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        date TEXT NOT NULL,
        reason TEXT,
        requested_by TEXT,
        status TEXT DEFAULT 'draft',
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_withdrawal_items (
        id TEXT PRIMARY KEY,
        withdrawal_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        FOREIGN KEY (withdrawal_id) REFERENCES stock_withdrawals(id)
      )
    ''');

    // ─── Stock Transfers ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE stock_transfers (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        from_warehouse_id TEXT NOT NULL,
        to_warehouse_id TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_transfer_items (
        id TEXT PRIMARY KEY,
        transfer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        FOREIGN KEY (transfer_id) REFERENCES stock_transfers(id)
      )
    ''');

    // ─── Inventory Sheets ─────────────────────────────────────────
    await db.execute('''
      CREATE TABLE inventory_sheets (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT DEFAULT 'in_progress',
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_sheet_items (
        id TEXT PRIMARY KEY,
        sheet_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        theoretical_qty REAL DEFAULT 0,
        physical_qty REAL DEFAULT 0,
        difference REAL DEFAULT 0,
        FOREIGN KEY (sheet_id) REFERENCES inventory_sheets(id)
      )
    ''');

    // ─── Projects ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        customer_id TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT,
        budget REAL DEFAULT 0,
        spent REAL DEFAULT 0,
        status TEXT DEFAULT 'planning',
        progress REAL DEFAULT 0,
        notes TEXT,
        firebase_uid TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE project_invoices (
        project_id TEXT NOT NULL,
        invoice_id TEXT NOT NULL,
        PRIMARY KEY (project_id, invoice_id)
      )
    ''');

    // ─── Sync Queue ───────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        status TEXT DEFAULT 'pending',
        error_message TEXT
      )
    ''');

    // ─── Activity Log ─────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE activity_log (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        description TEXT NOT NULL,
        entity_type TEXT,
        entity_id TEXT,
        user_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // ─── Product Warehouse Stock ──────────────────────────────────
    await db.execute('''
      CREATE TABLE product_warehouse_stock (
        product_id TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        quantity REAL DEFAULT 0,
        PRIMARY KEY (product_id, warehouse_id)
      )
    ''');

    await _createPaymentTables(db);
  }

  Future<void> _createPaymentTables(Database db) async {
    // ─── Payment Accounts ─────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        bank_name TEXT,
        account_number TEXT,
        iban TEXT,
        balance REAL DEFAULT 0,
        is_default INTEGER DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Insert default cash account for payments
    final existing = await db.query('payment_accounts', where: "name = ?", whereArgs: ['Caisse Principale']);
    if (existing.isEmpty) {
      await db.insert('payment_accounts', {
        'id': newId,
        'name': 'Caisse Principale',
        'type': 'cash',
        'balance': 0,
        'is_default': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // ─── Payments ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        payment_number TEXT UNIQUE NOT NULL,
        direction TEXT NOT NULL,
        contact_id TEXT NOT NULL,
        contact_type TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        account_id TEXT,
        reference TEXT,
        payment_date INTEGER NOT NULL,
        notes TEXT,
        status TEXT DEFAULT 'paid',
        related_invoice_id TEXT,
        related_quote_id TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (account_id) REFERENCES payment_accounts(id)
      )
    ''');

    // ─── Payment Allocations ──────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_allocations (
        id TEXT PRIMARY KEY,
        payment_id TEXT NOT NULL,
        invoice_id TEXT NOT NULL,
        allocated_amount REAL NOT NULL,
        created_at INTEGER,
        FOREIGN KEY (payment_id) REFERENCES payments(id)
      )
    ''');
  }

  // ═══════════════════════════════════════════════════════════════════
  // CRUD Operations
  // ═══════════════════════════════════════════════════════════════════

  // ─── Generic Operations ─────────────────────────────────────────
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    await _addToSyncQueue(table, data['id'] as String, 'INSERT', data);
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await _addToSyncQueue(table, id, 'UPDATE', data);
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> softDelete(String table, String id) async {
    final db = await database;
    final data = {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()};
    await _addToSyncQueue(table, id, 'DELETE', data);
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAll(String table, {String? orderBy}) async {
    final db = await database;
    return await db.query(table, where: 'is_deleted = 0', orderBy: orderBy ?? 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final db = await database;
    final results = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  // ─── Sync Queue ─────────────────────────────────────────────────
  Future<void> _addToSyncQueue(String table, String recordId, String operation, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('sync_queue', {
      'table_name': table,
      'record_id': recordId,
      'operation': operation,
      'data_json': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query('sync_queue', where: 'status IN (?, ?)', whereArgs: ['pending', 'error'], orderBy: 'created_at ASC');
  }

  Future<void> markSynced(int id) async {
    final db = await database;
    await db.update('sync_queue', {
      'status': 'synced',
      'synced_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSyncError(int id, String error) async {
    final db = await database;
    await db.update('sync_queue', {
      'status': 'error',
      'error_message': error,
    }, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Customers ──────────────────────────────────────────────────
  Future<List<Customer>> getCustomers() async {
    final maps = await getAll('customers', orderBy: 'name ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomer(String id) async {
    final map = await getById('customers', id);
    return map != null ? Customer.fromMap(map) : null;
  }

  Future<void> insertCustomer(Customer customer) async {
    await insert('customers', customer.toMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    await update('customers', customer.toMap(), customer.id);
  }

  Future<void> deleteCustomer(String id) async {
    await softDelete('customers', id);
  }

  Future<int> getCustomerCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM customers WHERE is_deleted = 0');
    return result.first['count'] as int;
  }

  // ─── Suppliers ──────────────────────────────────────────────────
  Future<List<Supplier>> getSuppliers() async {
    final maps = await getAll('suppliers', orderBy: 'name ASC');
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<void> insertSupplier(Supplier supplier) async {
    await insert('suppliers', supplier.toMap());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await update('suppliers', supplier.toMap(), supplier.id);
  }

  Future<void> deleteSupplier(String id) async {
    await softDelete('suppliers', id);
  }

  // ─── Products ───────────────────────────────────────────────────
  Future<List<Product>> getProducts() async {
    final maps = await getAll('products', orderBy: 'name ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProduct(String id) async {
    final map = await getById('products', id);
    return map != null ? Product.fromMap(map) : null;
  }

  Future<void> insertProduct(Product product) async {
    await insert('products', product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await update('products', product.toMap(), product.id);
  }

  Future<void> deleteProduct(String id) async {
    await softDelete('products', id);
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT * FROM products WHERE is_deleted = 0 AND is_active = 1 AND stock_qty <= min_stock_qty AND min_stock_qty > 0 ORDER BY stock_qty ASC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<double> getTotalStockValue() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(stock_qty * purchase_price), 0) as total FROM products WHERE is_deleted = 0',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  // ─── Invoices ───────────────────────────────────────────────────
  Future<List<Invoice>> getInvoices() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT i.*, c.name as customer_name, p.name as project_name
      FROM invoices i 
      LEFT JOIN customers c ON i.customer_id = c.id 
      LEFT JOIN projects p ON i.project_id = p.id
      WHERE i.is_deleted = 0 
      ORDER BY i.created_at DESC
    ''');
    return maps.map((m) => Invoice.fromMap(m)).toList();
  }

  Future<Invoice?> getInvoice(String id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT i.*, c.name as customer_name, p.name as project_name
      FROM invoices i 
      LEFT JOIN customers c ON i.customer_id = c.id 
      LEFT JOIN projects p ON i.project_id = p.id
      WHERE i.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    final invoice = Invoice.fromMap(maps.first);
    final items = await getInvoiceItems(id);
    return invoice.copyWith(items: items);
  }

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT ii.*, p.name as product_name 
      FROM invoice_items ii 
      LEFT JOIN products p ON ii.product_id = p.id 
      WHERE ii.invoice_id = ?
    ''', [invoiceId]);
    return maps.map((m) => InvoiceItem.fromMap(m)).toList();
  }

  Future<void> insertInvoice(Invoice invoice) async {
    await insert('invoices', invoice.toMap());
    for (final item in invoice.items) {
      final db = await database;
      await db.insert('invoice_items', item.toMap());
    }
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await update('invoices', invoice.toMap(), invoice.id);
  }

  Future<void> deleteInvoice(String id) async {
    await softDelete('invoices', id);
  }

  Future<int> getNextInvoiceNumber() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) + 1 as next FROM invoices');
    return result.first['next'] as int;
  }

  // ─── Dashboard Aggregates ──────────────────────────────────────
  Future<double> getTotalInvoiced() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(total_ttc), 0) as total FROM invoices WHERE is_deleted = 0 AND status != 'cancelled'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTotalPaid() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount_paid), 0) as total FROM invoices WHERE is_deleted = 0 AND status != 'cancelled'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTotalDeliveryNotes() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as total FROM delivery_notes WHERE is_deleted = 0",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTotalTvaCollected() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(total_tva), 0) as total FROM invoices WHERE is_deleted = 0 AND status != 'cancelled'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTotalTvaDeductible() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(total_tva), 0) as total FROM purchase_invoices WHERE is_deleted = 0 AND status != 'cancelled'",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, double>> getInvoiceStatusBreakdown() async {
    final db = await database;
    final total = await getTotalInvoiced();
    if (total == 0) return {'paid': 0, 'partial': 0, 'unpaid': 0};

    final paidResult = await db.rawQuery(
      "SELECT COALESCE(SUM(total_ttc), 0) as total FROM invoices WHERE is_deleted = 0 AND status = 'paid'",
    );
    final partialResult = await db.rawQuery(
      "SELECT COALESCE(SUM(total_ttc), 0) as total FROM invoices WHERE is_deleted = 0 AND status = 'partial'",
    );

    final paid = (paidResult.first['total'] as num?)?.toDouble() ?? 0;
    final partial = (partialResult.first['total'] as num?)?.toDouble() ?? 0;
    final unpaid = total - paid - partial;

    return {
      'paid': total > 0 ? (paid / total * 100) : 0,
      'partial': total > 0 ? (partial / total * 100) : 0,
      'unpaid': total > 0 ? (unpaid / total * 100) : 0,
    };
  }

  Future<List<Invoice>> getRecentInvoices({int limit = 5}) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT i.*, c.name as customer_name 
      FROM invoices i 
      LEFT JOIN customers c ON i.customer_id = c.id 
      WHERE i.is_deleted = 0 
      ORDER BY i.created_at DESC 
      LIMIT ?
    ''', [limit]);
    return maps.map((m) => Invoice.fromMap(m)).toList();
  }

  // ─── Quotes ─────────────────────────────────────────────────────
  Future<List<Quote>> getQuotes() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT q.*, c.name as customer_name 
      FROM quotes q 
      LEFT JOIN customers c ON q.customer_id = c.id 
      WHERE q.is_deleted = 0 
      ORDER BY q.created_at DESC
    ''');
    return maps.map((m) => Quote.fromMap(m)).toList();
  }

  Future<void> insertQuote(Quote quote) async {
    await insert('quotes', quote.toMap());
    final db = await database;
    for (final item in quote.items) {
      await db.insert('quote_items', item.toMap());
    }
  }

  // ─── Delivery Notes ─────────────────────────────────────────────
  Future<List<DeliveryNote>> getDeliveryNotes({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String query = '''
      SELECT dn.*,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_company,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_name,
             p.name AS project_name
      FROM delivery_notes dn
      JOIN customers c ON dn.customer_id = c.id
      LEFT JOIN projects p ON dn.project_id = p.id
      WHERE dn.is_deleted = 0
    ''';
    final args = <dynamic>[];

    if (status != null && status.isNotEmpty && status != 'Tous') {
      query += ' AND dn.status = ?';
      args.add(status);
    }
    if (startDate != null) {
      query += ' AND date(dn.date) >= date(?)';
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      query += ' AND date(dn.date) <= date(?)';
      args.add(endDate.toIso8601String());
    }

    query += ' ORDER BY dn.date DESC, dn.created_at DESC';
    final result = await db.rawQuery(query, args);
    return result.map((m) => DeliveryNote.fromMap(m)).toList();
  }

  Future<DeliveryNote?> getDeliveryNote(String id) async {
    final db = await database;
    final dnResult = await db.rawQuery('''
      SELECT dn.*,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_company,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_name,
             p.name AS project_name
      FROM delivery_notes dn
      JOIN customers c ON dn.customer_id = c.id
      LEFT JOIN projects p ON dn.project_id = p.id
      WHERE dn.id = ? AND dn.is_deleted = 0
    ''', [id]);
    if (dnResult.isEmpty) return null;
    final itemsResult = await db.query(
      'delivery_note_items',
      where: 'delivery_note_id = ?',
      whereArgs: [id],
    );
    final items = itemsResult.map((m) => DeliveryNoteItem.fromMap(m)).toList();
    return DeliveryNote.fromMap(dnResult.first, items);
  }

  Future<void> insertDeliveryNote(DeliveryNote note) async {
    final db = await database;
    final data = note.toMap();
    await db.transaction((txn) async {
      await txn.insert('delivery_notes', data);
      for (var item in note.items) {
        await txn.insert('delivery_note_items', item.toMap());
      }
    });
    await _addToSyncQueue('delivery_notes', note.id, 'INSERT', data);
  }

  Future<void> updateDeliveryNote(DeliveryNote note) async {
    final db = await database;
    final data = note.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('delivery_notes', data,
          where: 'id = ?', whereArgs: [note.id]);
      await txn.delete('delivery_note_items',
          where: 'delivery_note_id = ?', whereArgs: [note.id]);
      for (var item in note.items) {
        await txn.insert('delivery_note_items', item.toMap());
      }
    });
    await _addToSyncQueue('delivery_notes', note.id, 'UPDATE', data);
  }

  Future<void> softDeleteDeliveryNote(String id) async {
    final db = await database;
    final data = {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()};
    await db.update('delivery_notes', data, where: 'id = ?', whereArgs: [id]);
    await _addToSyncQueue('delivery_notes', id, 'DELETE', data);
  }

  Future<int> getNextDeliveryNoteSequence() async {
    final db = await database;
    final year = DateTime.now().year;
    final result = await db.rawQuery(
      'SELECT COUNT(*) + 1 AS next FROM delivery_notes WHERE number LIKE ?',
      ['BL-$year-%'],
    );
    return result.first['next'] as int? ?? 1;
  }

  // ─── Stock Withdrawals ──────────────────────────────────────────
  Future<List<StockWithdrawal>> getStockWithdrawals({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String query = '''
      SELECT sw.*,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_company,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_name,
             p.name AS project_name
      FROM bons_sortie sw
      JOIN customers c ON sw.customer_id = c.id
      LEFT JOIN projects p ON sw.project_id = p.id
      WHERE sw.is_deleted = 0
    ''';
    final args = <dynamic>[];

    if (status != null && status.isNotEmpty && status != 'Tous') {
      query += ' AND sw.status = ?';
      args.add(status);
    }
    if (startDate != null) {
      query += ' AND date(sw.date) >= date(?)';
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      query += ' AND date(sw.date) <= date(?)';
      args.add(endDate.toIso8601String());
    }

    query += ' ORDER BY sw.date DESC, sw.created_at DESC';
    final result = await db.rawQuery(query, args);
    return result.map((m) => StockWithdrawal.fromMap(m)).toList();
  }

  Future<StockWithdrawal?> getStockWithdrawal(String id) async {
    final db = await database;
    final swResult = await db.rawQuery('''
      SELECT sw.*,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_company,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_name,
             p.name AS project_name
      FROM bons_sortie sw
      JOIN customers c ON sw.customer_id = c.id
      LEFT JOIN projects p ON sw.project_id = p.id
      WHERE sw.id = ? AND sw.is_deleted = 0
    ''', [id]);
    if (swResult.isEmpty) return null;
    final itemsResult = await db.query(
      'bons_sortie_items',
      where: 'withdrawal_id = ?',
      whereArgs: [id],
    );
    final items = itemsResult.map((m) => StockWithdrawalItem.fromMap(m)).toList();
    return StockWithdrawal.fromMap(swResult.first, items);
  }

  Future<void> insertStockWithdrawal(StockWithdrawal sw) async {
    final db = await database;
    final data = sw.toMap();
    await db.transaction((txn) async {
      await txn.insert('bons_sortie', data);
      for (var item in sw.items) {
        await txn.insert('bons_sortie_items', item.toMap());
      }
    });
    await _addToSyncQueue('bons_sortie', sw.id, 'INSERT', data);
  }

  Future<void> updateStockWithdrawal(StockWithdrawal sw) async {
    final db = await database;
    final data = sw.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('bons_sortie', data,
          where: 'id = ?', whereArgs: [sw.id]);
      await txn.delete('bons_sortie_items',
          where: 'withdrawal_id = ?', whereArgs: [sw.id]);
      for (var item in sw.items) {
        await txn.insert('bons_sortie_items', item.toMap());
      }
    });
    await _addToSyncQueue('bons_sortie', sw.id, 'UPDATE', data);
  }

  Future<void> softDeleteStockWithdrawal(String id) async {
    final db = await database;
    final data = {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()};
    await db.update('bons_sortie', data, where: 'id = ?', whereArgs: [id]);
    await _addToSyncQueue('bons_sortie', id, 'DELETE', data);
  }

  Future<int> getNextStockWithdrawalSequence() async {
    final db = await database;
    final year = DateTime.now().year;
    final result = await db.rawQuery(
      'SELECT COUNT(*) + 1 AS next FROM bons_sortie WHERE number LIKE ?',
      ['BS-$year-%'],
    );
    return result.first['next'] as int? ?? 1;
  }

  // ─── Checks & Traites ──────────────────────────────────────────
  Future<List<CheckTraite>> getChecksTraites() async {
    final maps = await getAll('checks_traites', orderBy: 'maturity_date ASC');
    return maps.map((m) => CheckTraite.fromMap(m)).toList();
  }

  Future<List<CheckTraite>> getUpcomingChecksTraites({int days = 30}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final future = DateTime.now().add(Duration(days: days)).toIso8601String();
    final maps = await db.rawQuery('''
      SELECT * FROM checks_traites 
      WHERE is_deleted = 0 AND status = 'pending' 
      AND maturity_date BETWEEN ? AND ?
      ORDER BY maturity_date ASC
    ''', [now, future]);
    return maps.map((m) => CheckTraite.fromMap(m)).toList();
  }

  Future<void> insertCheckTraite(CheckTraite ct) async {
    await insert('checks_traites', ct.toMap());
  }

  // ─── Transactions ──────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactions() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT t.*, a.name as account_name 
      FROM transactions t 
      LEFT JOIN accounts a ON t.account_id = a.id 
      WHERE t.is_deleted = 0 
      ORDER BY t.date DESC
    ''');
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<void> insertTransaction(TransactionModel txn) async {
    await insert('transactions', txn.toMap());
    // Update account balance
    final db = await database;
    final sign = txn.type == TransactionType.income ? 1 : -1;
    await db.rawUpdate(
      'UPDATE accounts SET balance = balance + ? WHERE id = ?',
      [txn.amount * sign, txn.accountId],
    );
  }

  // ─── Accounts ───────────────────────────────────────────────────
  Future<List<Account>> getAccounts() async {
    final maps = await getAll('accounts', orderBy: 'name ASC');
    return maps.map((m) => Account.fromMap(m)).toList();
  }

  Future<void> insertAccount(Account account) async {
    await insert('accounts', account.toMap());
  }

  // ─── Stock Movements ───────────────────────────────────────────
  Future<List<StockMovement>> getStockMovements() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT sm.*, p.name as product_name, w.name as warehouse_name
      FROM stock_movements sm
      LEFT JOIN products p ON sm.product_id = p.id
      LEFT JOIN warehouses w ON sm.warehouse_id = w.id
      WHERE sm.is_deleted = 0
      ORDER BY sm.date DESC
    ''');
    return maps.map((m) => StockMovement.fromMap(m)).toList();
  }

  Future<void> insertStockMovement(StockMovement movement) async {
    final db = await database;
    await db.insert('stock_movements', movement.toMap());
    // Update product stock
    final sign = (movement.type == MovementType.entry || movement.type == MovementType.adjustment) ? 1 : -1;
    await db.rawUpdate(
      'UPDATE products SET stock_qty = stock_qty + ?, updated_at = ? WHERE id = ?',
      [movement.quantity * sign, DateTime.now().toIso8601String(), movement.productId],
    );
  }

  // ─── Warehouses ─────────────────────────────────────────────────
  Future<List<Warehouse>> getWarehouses() async {
    final maps = await getAll('warehouses', orderBy: 'name ASC');
    return maps.map((m) => Warehouse.fromMap(m)).toList();
  }

  Future<void> insertWarehouse(Warehouse warehouse) async {
    await insert('warehouses', warehouse.toMap());
  }

  Future<void> updateWarehouse(Warehouse warehouse) async {
    await update('warehouses', warehouse.toMap(), warehouse.id);
  }

  // ─── Projects ───────────────────────────────────────────────────
  Future<List<Project>> getProjects() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.*, c.name as customer_name
      FROM projects p
      LEFT JOIN customers c ON p.customer_id = c.id
      WHERE p.is_deleted = 0
      ORDER BY p.created_at DESC
    ''');
    return maps.map((m) => Project.fromMap(m)).toList();
  }

  Future<void> insertProject(Project project) async {
    await insert('projects', project.toMap());
  }

  Future<void> updateProject(Project project) async {
    await update('projects', project.toMap(), project.id);
  }

  // ─── Purchase Invoices ──────────────────────────────────────────
  Future<List<PurchaseInvoice>> getPurchaseInvoices() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT pi.*, s.name as supplier_name
      FROM purchase_invoices pi
      LEFT JOIN suppliers s ON pi.supplier_id = s.id
      WHERE pi.is_deleted = 0
      ORDER BY pi.created_at DESC
    ''');
    return maps.map((m) => PurchaseInvoice.fromMap(m)).toList();
  }

  Future<void> insertPurchaseInvoice(PurchaseInvoice invoice) async {
    await insert('purchase_invoices', invoice.toMap());
    final db = await database;
    for (final item in invoice.items) {
      await db.insert('purchase_invoice_items', item.toMap());
    }
  }

  // ─── Activity Log ──────────────────────────────────────────────
  Future<void> logActivity(String action, String description, {String? entityType, String? entityId}) async {
    final db = await database;
    await db.insert('activity_log', {
      'id': newId,
      'action': action,
      'description': description,
      'entity_type': entityType,
      'entity_id': entityId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ActivityLog>> getRecentActivity({int limit = 10}) async {
    final db = await database;
    final maps = await db.query('activity_log', orderBy: 'created_at DESC', limit: limit);
    return maps.map((m) => ActivityLog.fromMap(m)).toList();
  }

  // ─── Company Settings ──────────────────────────────────────────
  Future<CompanySettings> getCompanySettings() async {
    final db = await database;
    final maps = await db.query('company_settings');
    if (maps.isEmpty) return CompanySettings();
    return CompanySettings.fromMap(maps.first);
  }

  Future<void> updateCompanySettings(CompanySettings settings) async {
    final db = await database;
    await db.update('company_settings', settings.toMap(), where: 'id = ?', whereArgs: [settings.id]);
  }

  // ─── Search ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> search(String table, String query) async {
    final db = await database;
    return await db.query(table,
      where: "is_deleted = 0 AND (name LIKE ? OR code LIKE ?)",
      whereArgs: ['%$query%', '%$query%'],
    );
  }

  // ─── Backup & Restore ──────────────────────────────────────────
  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'business_manager_pro.db');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }

  // ─── Payment Accounts ──────────────────────────────────────────
  Future<List<PaymentAccount>> getPaymentAccounts() async {
    final db = await database;
    final maps = await db.query(
      'payment_accounts',
      orderBy: 'name ASC',
    );
    return maps.map((m) => PaymentAccount.fromMap(m)).toList();
  }

  Future<void> insertPaymentAccount(PaymentAccount account) async {
    final db = await database;
    await db.insert('payment_accounts', account.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePaymentAccount(PaymentAccount account) async {
    final db = await database;
    await db.update('payment_accounts', account.toMap(),
        where: 'id = ?', whereArgs: [account.id]);
  }

  // ─── Payments ──────────────────────────────────────────────────
  Future<List<Payment>> getPayments() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT p.*,
        COALESCE(
          (SELECT name FROM customers WHERE id = p.contact_id AND is_deleted = 0 LIMIT 1),
          (SELECT name FROM suppliers WHERE id = p.contact_id AND is_deleted = 0 LIMIT 1)
        ) as contact_name,
        pa.name as account_name
      FROM payments p
      LEFT JOIN payment_accounts pa ON p.account_id = pa.id
      WHERE p.is_deleted = 0
      ORDER BY p.created_at DESC
    ''');
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<void> insertPayment(Payment payment) async {
    final db = await database;
    await db.insert('payments', payment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _addToSyncQueue('payments', payment.id, 'INSERT', payment.toMap());
  }

  Future<void> updatePayment(Payment payment) async {
    final db = await database;
    final data = payment.toMap()
      ..['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update('payments', data,
        where: 'id = ?', whereArgs: [payment.id]);
    await _addToSyncQueue('payments', payment.id, 'UPDATE', data);
  }

  Future<void> softDeletePayment(String id) async {
    final db = await database;
    await db.update(
      'payments',
      {'is_deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _addToSyncQueue('payments', id, 'DELETE', {'is_deleted': 1});
  }

  Future<int> getNextPaymentSequence(String direction) async {
    final db = await database;
    final prefix = direction == 'encaissement' ? 'PAI' : 'DEB';
    final year = DateTime.now().year;
    final result = await db.rawQuery(
      'SELECT COUNT(*) + 1 as next FROM payments WHERE payment_number LIKE ?',
      ['$prefix-$year%'],
    );
    return result.first['next'] as int? ?? 1;
  }

  // ─── Customer Orders ─────────────────────────────────────────
  Future<List<CustomerOrder>> getCustomerOrders({String? status, DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = '''
      SELECT o.*,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_company,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_name,
             p.name AS project_name
      FROM customer_orders o
      JOIN customers c ON o.customer_id = c.id
      LEFT JOIN projects p ON o.project_id = p.id
      WHERE o.is_deleted = 0
    ''';
    final args = <dynamic>[];

    if (status != null && status != 'all' && status != 'Tous') {
      query += ' AND o.status = ?';
      args.add(status);
    }
    if (startDate != null) {
      query += ' AND date(o.date) >= date(?)';
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      query += ' AND date(o.date) <= date(?)';
      args.add(endDate.toIso8601String());
    }

    query += ' ORDER BY o.date DESC, o.created_at DESC';

    final result = await db.rawQuery(query, args);
    return result.map((map) => CustomerOrder.fromMap(map)).toList();
  }

  Future<CustomerOrder?> getCustomerOrder(String id) async {
    final db = await database;
    final orderResult = await db.rawQuery('''
      SELECT o.*,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_company,
             COALESCE(c.company_name, c.name, c.responsible_name) AS customer_name,
             p.name AS project_name
      FROM customer_orders o
      JOIN customers c ON o.customer_id = c.id
      LEFT JOIN projects p ON o.project_id = p.id
      WHERE o.id = ? AND o.is_deleted = 0
    ''', [id]);

    if (orderResult.isEmpty) return null;

    final itemsResult = await db.query(
      'customer_order_items',
      where: 'order_id = ?',
      whereArgs: [id],
    );

    final items = itemsResult.map((map) => CustomerOrderItem.fromMap(map)).toList();
    return CustomerOrder.fromMap(orderResult.first, items);
  }

  Future<void> insertCustomerOrder(CustomerOrder order) async {
    final db = await database;
    final data = order.toMap();
    await db.transaction((txn) async {
      await txn.insert('customer_orders', data);
      for (var item in order.items) {
        await txn.insert('customer_order_items', item.toMap());
      }
    });
    await _addToSyncQueue('customer_orders', order.id, 'INSERT', data);
  }

  Future<void> updateCustomerOrder(CustomerOrder order) async {
    final db = await database;
    final data = order.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'customer_orders',
        data,
        where: 'id = ?',
        whereArgs: [order.id],
      );

      // Replace items
      await txn.delete(
        'customer_order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );
      for (var item in order.items) {
        await txn.insert('customer_order_items', item.toMap());
      }
    });
    await _addToSyncQueue('customer_orders', order.id, 'UPDATE', data);
  }

  Future<void> softDeleteCustomerOrder(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'customer_orders',
        {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await _addToSyncQueue('customer_orders', id, 'DELETE', {'is_deleted': 1});
  }

  Future<int> getNextCustomerOrderSequence() async {
    final db = await database;
    final year = DateTime.now().year;
    final result = await db.rawQuery(
      'SELECT COUNT(*) + 1 as next FROM customer_orders WHERE number LIKE ?',
      ['CC-$year-%'],
    );
    return result.first['next'] as int? ?? 1;
  }

  // ─── Supplier Orders ──────────────────────────────────────────────

  Future<List<SupplierOrder>> getSupplierOrders({String? status, DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    
    String where = 'so.is_deleted = 0';
    List<dynamic> whereArgs = [];

    if (status != null && status != 'Tous') {
      where += ' AND so.status = ?';
      whereArgs.add(status);
    }
    if (startDate != null) {
      where += ' AND date(so.date) >= date(?)';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where += ' AND date(so.date) <= date(?)';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery('''
      SELECT so.*, 
             s.name AS supplier_name,
             p.name AS project_name
      FROM supplier_orders so
      JOIN suppliers s ON so.supplier_id = s.id
      LEFT JOIN projects p ON so.project_id = p.id
      WHERE $where
      ORDER BY so.date DESC, so.created_at DESC
    ''', whereArgs);

    final List<SupplierOrder> orders = [];
    for (var row in result) {
      final itemsResult = await db.query(
        'supplier_order_items',
        where: 'order_id = ?',
        whereArgs: [row['id']],
      );
      final items = itemsResult.map((i) => SupplierOrderItem.fromMap(i)).toList();
      orders.add(SupplierOrder.fromMap(row, items));
    }
    return orders;
  }

  Future<SupplierOrder?> getSupplierOrderById(String id) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT so.*, 
             s.name AS supplier_name,
             p.name AS project_name
      FROM supplier_orders so
      JOIN suppliers s ON so.supplier_id = s.id
      LEFT JOIN projects p ON so.project_id = p.id
      WHERE so.id = ? AND so.is_deleted = 0
    ''', [id]);
    
    if (result.isEmpty) return null;
    
    final itemsResult = await db.query(
      'supplier_order_items',
      where: 'order_id = ?',
      whereArgs: [id],
    );
    final items = itemsResult.map((i) => SupplierOrderItem.fromMap(i)).toList();
    
    return SupplierOrder.fromMap(result.first, items);
  }

  Future<void> insertSupplierOrder(SupplierOrder order) async {
    final db = await database;
    final data = order.toMap();
    await db.transaction((txn) async {
      await txn.insert('supplier_orders', data);
      for (var item in order.items) {
        await txn.insert('supplier_order_items', item.toMap());
      }
    });
    await _addToSyncQueue('supplier_orders', order.id, 'INSERT', data);
  }

  Future<void> updateSupplierOrder(SupplierOrder order) async {
    final db = await database;
    final data = order.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    
    await db.transaction((txn) async {
      await txn.update(
        'supplier_orders',
        data,
        where: 'id = ?',
        whereArgs: [order.id],
      );
      
      await txn.delete(
        'supplier_order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );
      
      for (var item in order.items) {
        await txn.insert('supplier_order_items', item.toMap());
      }
    });
    await _addToSyncQueue('supplier_orders', order.id, 'UPDATE', data);
  }

  Future<void> softDeleteSupplierOrder(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'supplier_orders',
        {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await _addToSyncQueue('supplier_orders', id, 'DELETE', {'is_deleted': 1});
  }

  Future<int> getNextSupplierOrderSequence() async {
    final db = await database;
    final year = DateTime.now().year;
    final result = await db.rawQuery(
      'SELECT COUNT(*) + 1 as next FROM supplier_orders WHERE number LIKE ?',
      ['CF-$year-%'],
    );
    return result.first['next'] as int? ?? 1;
  }
}
