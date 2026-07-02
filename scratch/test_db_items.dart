import 'package:flutter/material.dart';
import 'package:business_manager_pro/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dbHelper = DatabaseHelper.instance;
  
  // Check orders
  final orders = await dbHelper.getCustomerOrders();
  print('--- Customer Orders ---');
  for (var o in orders) {
    final full = await dbHelper.getCustomerOrder(o.id);
    print('${o.number}: Total HT: ${o.totalHTAfterDiscount}, Items count: ${full?.items.length}');
  }
  
  // Check delivery notes
  final dns = await dbHelper.getDeliveryNotes();
  print('--- Delivery Notes ---');
  for (var d in dns) {
    final full = await dbHelper.getDeliveryNote(d.id);
    print('${d.number}: Total HT: ${d.totalHTAfterDiscount}, Items count: ${full?.items.length}');
  }
}
