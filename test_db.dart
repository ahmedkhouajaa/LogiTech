import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'lib/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  try {
    print('Starting database init...');
    await DatabaseHelper.instance.database;
    print('Database init successful.');
  } catch (e, stack) {
    print('Error initializing database: $e');
    print(stack);
  }
}
