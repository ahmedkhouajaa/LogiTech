import '../../models/stock_entry.dart';

abstract class StockEntriesEvent {}

class LoadStockEntries extends StockEntriesEvent {}

class AddStockEntry extends StockEntriesEvent {
  final StockEntry entry;
  AddStockEntry(this.entry);
}

class UpdateStockEntry extends StockEntriesEvent {
  final StockEntry entry;
  UpdateStockEntry(this.entry);
}

class DeleteStockEntry extends StockEntriesEvent {
  final String entryId;
  DeleteStockEntry(this.entryId);
}

class FilterStockEntries extends StockEntriesEvent {
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  FilterStockEntries({this.supplierId, this.dateFrom, this.dateTo, this.status});
}
