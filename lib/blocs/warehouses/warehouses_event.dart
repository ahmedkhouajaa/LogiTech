import '../../models/stock_movement.dart';

abstract class WarehousesEvent {}

class LoadWarehouses extends WarehousesEvent {}

class AddWarehouse extends WarehousesEvent {
  final Warehouse warehouse;
  AddWarehouse(this.warehouse);
}

class UpdateWarehouse extends WarehousesEvent {
  final Warehouse warehouse;
  UpdateWarehouse(this.warehouse);
}

class DeleteWarehouse extends WarehousesEvent {
  final String id;
  DeleteWarehouse(this.id);
}
