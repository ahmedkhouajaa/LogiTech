import 'dart:io';

void main() {
  final file = File('lib/screens/create_delivery_note_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll('CreateDeliveryNoteScreen', 'CreateStockWithdrawalScreen');
  content = content.replaceAll('_CreateDeliveryNoteScreenState', '_CreateStockWithdrawalScreenState');
  
  content = content.replaceAll('DeliveryNotesBloc', 'StockWithdrawalsBloc');
  content = content.replaceAll('AddDeliveryNote', 'AddStockWithdrawal');
  content = content.replaceAll('UpdateDeliveryNote', 'UpdateStockWithdrawal');
  
  content = content.replaceAll('DeliveryNoteItem', 'StockWithdrawalItem');
  content = content.replaceAll('DeliveryNoteStatus', 'StockWithdrawalStatus');
  content = content.replaceAll('DeliveryNote', 'StockWithdrawal');
  
  content = content.replaceAll('delivery_note.dart', 'stock_withdrawal.dart');
  content = content.replaceAll('delivery_notes_bloc.dart', 'stock_withdrawals_bloc.dart');
  
  content = content.replaceAll('Bon de Livraison', 'Bon de Sortie');
  content = content.replaceAll('Bons de Livraison', 'Bons de Sortie');
  content = content.replaceAll('bon de livraison', 'bon de sortie');
  content = content.replaceAll('bons de livraison', 'bons de sortie');
  
  content = content.replaceAll('delivery_note_id', 'withdrawal_id'); // Just in case
  content = content.replaceAll('BL-', 'BS-'); // Change prefix

  File('lib/screens/create_stock_withdrawal_screen.dart').writeAsStringSync(content);
  print('done create screen');
}
