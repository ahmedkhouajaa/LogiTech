import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/stock_movement.dart';

abstract class StockEvent extends Equatable { const StockEvent(); @override List<Object?> get props => []; }
class LoadStock extends StockEvent {}
class AddStockMovement extends StockEvent { final StockMovement movement; const AddStockMovement(this.movement); @override List<Object?> get props => [movement]; }
class AddWarehouse extends StockEvent { final Warehouse warehouse; const AddWarehouse(this.warehouse); @override List<Object?> get props => [warehouse]; }
class UpdateWarehouse extends StockEvent { final Warehouse warehouse; const UpdateWarehouse(this.warehouse); @override List<Object?> get props => [warehouse]; }

abstract class StockState extends Equatable { const StockState(); @override List<Object?> get props => []; }
class StockInitial extends StockState {}
class StockLoading extends StockState {}
class StockLoaded extends StockState {
  final List<StockMovement> movements;
  final List<Warehouse> warehouses;
  final double totalStockValue;
  const StockLoaded(this.movements, this.warehouses, this.totalStockValue);
  @override List<Object?> get props => [movements, warehouses, totalStockValue];
}
class StockError extends StockState { final String message; const StockError(this.message); @override List<Object?> get props => [message]; }

class StockBloc extends Bloc<StockEvent, StockState> {
  StockBloc() : super(StockInitial()) {
    on<LoadStock>(_onLoad);
    on<AddStockMovement>(_onAddMovement);
    on<AddWarehouse>(_onAddWarehouse);
    on<UpdateWarehouse>(_onUpdateWarehouse);
  }

  Future<void> _onLoad(LoadStock event, Emitter<StockState> emit) async {
    emit(StockLoading());
    try {
      final movements = await DatabaseHelper.instance.getStockMovements();
      final warehouses = await DatabaseHelper.instance.getWarehouses();
      final value = await DatabaseHelper.instance.getTotalStockValue();
      emit(StockLoaded(movements, warehouses, value));
    } catch (e) { emit(StockError(e.toString())); }
  }

  Future<void> _onAddMovement(AddStockMovement event, Emitter<StockState> emit) async {
    try { await DatabaseHelper.instance.insertStockMovement(event.movement); add(LoadStock()); } catch (e) { emit(StockError(e.toString())); }
  }

  Future<void> _onAddWarehouse(AddWarehouse event, Emitter<StockState> emit) async {
    try { await DatabaseHelper.instance.insertWarehouse(event.warehouse); add(LoadStock()); } catch (e) { emit(StockError(e.toString())); }
  }

  Future<void> _onUpdateWarehouse(UpdateWarehouse event, Emitter<StockState> emit) async {
    try { await DatabaseHelper.instance.updateWarehouse(event.warehouse); add(LoadStock()); } catch (e) { emit(StockError(e.toString())); }
  }
}
