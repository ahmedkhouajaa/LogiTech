import 'package:equatable/equatable.dart';
import '../../models/inventory_sheet.dart';

abstract class InventorySheetsEvent extends Equatable {
  const InventorySheetsEvent();

  @override
  List<Object?> get props => [];
}

class InventorySheetsLoadRequested extends InventorySheetsEvent {}

class LoadFirstInventorySheets extends InventorySheetsEvent {
  final String? searchQuery;
  final String? warehouseId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstInventorySheets({
    this.searchQuery,
    this.warehouseId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, warehouseId, dateFrom, dateTo, status];
}

class LoadNextInventorySheets extends InventorySheetsEvent {
  final String? searchQuery;
  final String? warehouseId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadNextInventorySheets({
    this.searchQuery,
    this.warehouseId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, warehouseId, dateFrom, dateTo, status];
}

class ResetInventorySheetsPagination extends InventorySheetsEvent {
  final String? searchQuery;
  final String? warehouseId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const ResetInventorySheetsPagination({
    this.searchQuery,
    this.warehouseId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, warehouseId, dateFrom, dateTo, status];
}

class InventorySheetAdded extends InventorySheetsEvent {
  final InventorySheet sheet;
  const InventorySheetAdded(this.sheet);
  @override
  List<Object?> get props => [sheet];
}

class InventorySheetUpdated extends InventorySheetsEvent {
  final InventorySheet sheet;
  const InventorySheetUpdated(this.sheet);
  @override
  List<Object?> get props => [sheet];
}

class InventorySheetDeleted extends InventorySheetsEvent {
  final String sheetId;
  const InventorySheetDeleted(this.sheetId);
  @override
  List<Object?> get props => [sheetId];
}
