import 'dart:io';

void main() {
  final file = File('lib/screens/credit_notes_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll('Invoice', 'CreditNote');
  content = content.replaceAll('invoice', 'creditNote');
  content = content.replaceAll('Invoices', 'CreditNotes');
  content = content.replaceAll('invoices', 'creditNotes');
  content = content.replaceAll('INVOICE', 'CREDIT_NOTE');
  content = content.replaceAll('Factures', 'Avoirs');
  content = content.replaceAll('Facture', 'Avoir');
  content = content.replaceAll('factures', 'avoirs');
  content = content.replaceAll('facture', 'avoir');
  
  file.writeAsStringSync(content);
}
