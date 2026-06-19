import 'dart:io';

void main() {
  final content = File('lib/blocs/invoices/invoices_bloc.dart').readAsStringSync();
  
  var newContent = content.replaceAll('Invoice', 'PurchaseInvoice');
  newContent = newContent.replaceAll('invoice', 'purchaseInvoice');
  newContent = newContent.replaceAll('customer', 'supplier');
  newContent = newContent.replaceAll('Customer', 'Supplier');
  
  // Also we need to fix PurchaseInvoiceStatus back to InvoiceStatus since InvoiceStatus is the global enum.
  newContent = newContent.replaceAll('PurchaseInvoiceStatus', 'InvoiceStatus');
  
  // write the entire bloc to purchase_invoices_bloc.dart 
  File('lib/blocs/purchase_invoices/purchase_invoices_bloc.dart').writeAsStringSync(newContent);
  
  // delete the obsolete event and state files to avoid duplicate definitions
  File('lib/blocs/purchase_invoices/purchase_invoices_event.dart').deleteSync();
  File('lib/blocs/purchase_invoices/purchase_invoices_state.dart').deleteSync();
  
  print('Fixed purchase_invoices_bloc.dart');
}
