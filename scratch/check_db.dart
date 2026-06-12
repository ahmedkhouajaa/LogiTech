import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  final docsPath = await getApplicationDocumentsDirectory();
  final dbPath = p.join(docsPath.path, 'business_manager_pro.db');
  
  var db = await databaseFactory.openDatabase(dbPath);
  
  var result = await db.rawQuery("PRAGMA table_info(stock_withdrawals)");
  print('Columns in stock_withdrawals:');
  for (var row in result) {
    print(row['name']);
  }
  
  await db.close();
}
