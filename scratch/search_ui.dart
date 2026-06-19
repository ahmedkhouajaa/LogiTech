import 'dart:io';

void main() {
  var lines = File('lib/screens/supplier_orders_screen.dart').readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].toLowerCase().contains('popupmenu')) {
      print('${i+1}: ${lines[i]}');
    }
  }
}
