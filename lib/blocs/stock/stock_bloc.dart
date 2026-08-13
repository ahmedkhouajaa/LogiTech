import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../database/database_helper.dart';
import '../../models/stock_movement.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';
import 'package:business_manager_pro/services/error_handler.dart';

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
      final entId = EnterpriseService.instance.currentEnterpriseId;

      // 1. Fetch Movements
      List<StockMovement> movements = [];
      try {
        Query query = FirebaseFirestore.instance.collection('stock_movements');
        if (entId != null && entId.isNotEmpty) {
          query = query.where('enterprise_id', isEqualTo: entId);
        }
        final snap = await query.get();
        movements = snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return StockMovement.fromMap(data);
        }).where((m) => !m.isDeleted).toList();
        movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {
        movements = await DatabaseHelper.instance.getStockMovements();
      }

      // 2. Fetch Warehouses
      List<Warehouse> warehouses = [];
      try {
        Query query = FirebaseFirestore.instance.collection('warehouses');
        if (entId != null && entId.isNotEmpty) {
          query = query.where('enterprise_id', isEqualTo: entId);
        }
        final snap = await query.get();
        warehouses = snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return Warehouse.fromMap(data);
        }).where((w) => !w.isDeleted).toList();
      } catch (_) {
        warehouses = await DatabaseHelper.instance.getWarehouses();
      }
      if (warehouses.isEmpty) {
        warehouses = [
          Warehouse(id: 'default_warehouse', name: 'Entrepôt principal', isDefault: true)
        ];
      }

      // 3. Calculate Stock Value
      double totalStockValue = 0;
      try {
        Query query = FirebaseFirestore.instance.collection('articles');
        if (entId != null && entId.isNotEmpty) {
          query = query.where('enterprise_id', isEqualTo: entId);
        }
        final snap = await query.get();
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final qty = (data['stock_qty'] as num?)?.toDouble() ?? (data['stock'] as num?)?.toDouble() ?? 0.0;
          final price = (data['purchase_price'] as num?)?.toDouble() ?? (data['sale_price'] as num?)?.toDouble() ?? 0.0;
          totalStockValue += (qty * price);
        }
      } catch (_) {
        totalStockValue = await DatabaseHelper.instance.getTotalStockValue();
      }

      emit(StockLoaded(movements, warehouses, totalStockValue));
    } catch (e) {
      emit(StockError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAddMovement(AddStockMovement event, Emitter<StockState> emit) async {
    try {
      await FirestoreRepository.instance.saveDocument('stock_movements', event.movement.id, event.movement.toMap());
      add(LoadStock());
    } catch (e) {
      emit(StockError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAddWarehouse(AddWarehouse event, Emitter<StockState> emit) async {
    try {
      await FirestoreRepository.instance.saveDocument('warehouses', event.warehouse.id, event.warehouse.toMap());
      add(LoadStock());
    } catch (e) {
      emit(StockError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateWarehouse(UpdateWarehouse event, Emitter<StockState> emit) async {
    try {
      await FirestoreRepository.instance.saveDocument('warehouses', event.warehouse.id, event.warehouse.toMap());
      add(LoadStock());
    } catch (e) {
      emit(StockError(ErrorHandler.parseError(e)));
    }
  }
}
