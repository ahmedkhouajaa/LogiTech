import 'package:equatable/equatable.dart';
import '../../models/inventory_sheet.dart';

abstract class InventorySheetsState extends Equatable {
  const InventorySheetsState();

  @override
  List<Object?> get props => [];
}

class InventorySheetsInitial extends InventorySheetsState {}

class InventorySheetsLoading extends InventorySheetsState {}

class InventorySheetsLoaded extends InventorySheetsState {
  final List<InventorySheet> sheets;
  const InventorySheetsLoaded(this.sheets);

  @override
  List<Object?> get props => [sheets];
}

class InventorySheetsError extends InventorySheetsState {
  final String message;
  const InventorySheetsError(this.message);

  @override
  List<Object?> get props => [message];
}
