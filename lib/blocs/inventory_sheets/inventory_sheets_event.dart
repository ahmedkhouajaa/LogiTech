import 'package:equatable/equatable.dart';
import '../../models/inventory_sheet.dart';

abstract class InventorySheetsEvent extends Equatable {
  const InventorySheetsEvent();

  @override
  List<Object?> get props => [];
}

class InventorySheetsLoadRequested extends InventorySheetsEvent {}

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
