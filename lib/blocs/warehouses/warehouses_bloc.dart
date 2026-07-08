import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import 'warehouses_event.dart';
import 'warehouses_state.dart';

class WarehousesBloc extends Bloc<WarehousesEvent, WarehousesState> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  WarehousesBloc() : super(WarehousesInitial()) {
    on<LoadWarehouses>(_onLoadWarehouses);
    on<AddWarehouse>(_onAddWarehouse);
    on<UpdateWarehouse>(_onUpdateWarehouse);
    on<DeleteWarehouse>(_onDeleteWarehouse);
  }

  Future<void> _onLoadWarehouses(LoadWarehouses event, Emitter<WarehousesState> emit) async {
    emit(WarehousesLoading());
    try {
      final warehouses = await dbHelper.getWarehouses();
      emit(WarehousesLoaded(warehouses));
    } catch (e) {
      emit(WarehousesError(e.toString()));
    }
  }

  Future<void> _onAddWarehouse(AddWarehouse event, Emitter<WarehousesState> emit) async {
    try {
      if (event.warehouse.isDefault) {
        // If the new one is default, we should unset others
        await _unsetOtherDefaults();
      }
      await dbHelper.insertWarehouse(event.warehouse);
      add(LoadWarehouses());
    } catch (e) {
      emit(WarehousesError(e.toString()));
    }
  }

  Future<void> _onUpdateWarehouse(UpdateWarehouse event, Emitter<WarehousesState> emit) async {
    try {
      if (event.warehouse.isDefault) {
        await _unsetOtherDefaults(exceptId: event.warehouse.id);
      }
      await dbHelper.updateWarehouse(event.warehouse);
      add(LoadWarehouses());
    } catch (e) {
      emit(WarehousesError(e.toString()));
    }
  }

  Future<void> _onDeleteWarehouse(DeleteWarehouse event, Emitter<WarehousesState> emit) async {
    try {
      await dbHelper.deleteWarehouse(event.id);
      add(LoadWarehouses());
    } catch (e) {
      emit(WarehousesError(e.toString()));
    }
  }

  Future<void> _unsetOtherDefaults({String? exceptId}) async {
    final warehouses = await dbHelper.getWarehouses();
    for (var w in warehouses) {
      if (w.isDefault && w.id != exceptId) {
        await dbHelper.updateWarehouse(w.copyWith(isDefault: false));
      }
    }
  }
}
