import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  
  // Try default path in Documents
  String path = p.join(Platform.environment['USERPROFILE']!, 'Documents', 'business_manager_pro.db');
  print('Checking database at: $path');
  
  if (!File(path).existsSync()) {
    print('DB not found in Documents, trying fallback...');
    // Maybe it's in another folder? getApplicationDocumentsDirectory() usually maps to Documents on Windows.
  }
  
  try {
    var db = await databaseFactory.openDatabase(path);
    
    var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    var hasPurchaseInvoices = tables.any((t) => t['name'] == 'purchase_invoices');
    print('Has purchase_invoices table: $hasPurchaseInvoices');
    
    if (hasPurchaseInvoices) {
      var invoices = await db.query('purchase_invoices');
      print('Number of purchase invoices: ${invoices.length}');
      if (invoices.isNotEmpty) {
        print('First invoice: ${invoices.first}');
      }
    }
    
    await db.close();
  } catch (e) {
    print('Error: $e');
  }
}
