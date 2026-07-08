import '../../models/stock_movement.dart';

abstract class WarehousesState {}

class WarehousesInitial extends WarehousesState {}

class WarehousesLoading extends WarehousesState {}

class WarehousesLoaded extends WarehousesState {
  final List<Warehouse> warehouses;
  WarehousesLoaded(this.warehouses);
}

class WarehousesError extends WarehousesState {
  final String message;
  WarehousesError(this.message);
}
