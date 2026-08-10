import '../../models/stock_entry.dart';

abstract class StockEntriesEvent {
  const StockEntriesEvent();
}

class LoadStockEntries extends StockEntriesEvent {
  const LoadStockEntries();
}

class LoadFirstStockEntries extends StockEntriesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstStockEntries({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextStockEntries extends StockEntriesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextStockEntries({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetStockEntriesPagination extends StockEntriesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetStockEntriesPagination({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

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
