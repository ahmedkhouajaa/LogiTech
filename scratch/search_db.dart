import 'dart:io';

void main() {
  var lines = File('lib/database/database_helper.dart').readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].toLowerCase().contains('purchase_invoice')) {
      print('${i+1}: ${lines[i]}');
    }
  }
}
