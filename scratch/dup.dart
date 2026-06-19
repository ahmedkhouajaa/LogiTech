import 'dart:io';

void main() {
  final invoiceStr = File('lib/screens/create_invoice_screen.dart').readAsStringSync();
  var newStr = invoiceStr
    .replaceAll('Invoice', 'PurchaseInvoice')
    .replaceAll('invoice', 'purchaseInvoice')
    .replaceAll('INVOICE', 'PURCHASE_INVOICE')
    .replaceAll('Customer', 'Supplier')
    .replaceAll('customer', 'supplier')
    .replaceAll('CUSTOMER', 'SUPPLIER')
    .replaceAll('PurchaseInvoiceStatus', 'InvoiceStatus');
  File('lib/screens/create_purchase_invoice_screen.dart').writeAsStringSync(newStr);
  
  final listStr = File('lib/screens/invoices_screen.dart').readAsStringSync();
  var newListStr = listStr
    .replaceAll('Invoice', 'PurchaseInvoice')
    .replaceAll('invoice', 'purchaseInvoice')
    .replaceAll('INVOICE', 'PURCHASE_INVOICE')
    .replaceAll('Customer', 'Supplier')
    .replaceAll('customer', 'supplier')
    .replaceAll('CUSTOMER', 'SUPPLIER')
    .replaceAll('PurchaseInvoiceStatus', 'InvoiceStatus');
  File('lib/screens/purchase_invoices_screen.dart').writeAsStringSync(newListStr);
}
