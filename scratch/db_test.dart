import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  test('Check DB Path', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationDocumentsDirectory();
    print('DB Path: \${dir.path}');
  });
}
