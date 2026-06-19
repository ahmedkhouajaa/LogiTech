import 'dart:io';

void main() {
  final content = File('lib/models/invoice.dart').readAsStringSync();
  
  var newContent = content.replaceAll('Invoice', 'PurchaseInvoice');
  newContent = newContent.replaceAll('invoice_id', 'purchase_invoice_id');
  newContent = newContent.replaceAll('invoice', 'purchaseInvoice');
  newContent = newContent.replaceAll('customer', 'supplier');
  newContent = newContent.replaceAll('Customer', 'Supplier');
  
  File('lib/models/purchase_invoice.dart').writeAsStringSync(newContent);
  print('Fixed purchase_invoice.dart');
}
