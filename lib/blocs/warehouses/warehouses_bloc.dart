import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../database/database_helper.dart';
import '../../models/stock_movement.dart';
import '../../services/enterprise_service.dart';
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
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    print('📦 [DEBUG WarehousesBloc] Loading warehouses for currentEnterpriseId: $currentEntId');
    
    try {
      var localWarehouses = await dbHelper.getWarehouses();
      print('📦 [DEBUG WarehousesBloc] Loaded ${localWarehouses.length} warehouses from local SQLite');
      
      // If enterprise has 0 warehouses locally, create 'Entrepôt par défaut' automatically right now
      if (localWarehouses.isEmpty) {
        final defaultWarehouse = Warehouse(
          id: const Uuid().v4(),
          name: 'Entrepôt par défaut',
          reference: 'WH-001',
          isDefault: true,
          isActive: true,
          enterpriseId: currentEntId ?? EnterpriseService.instance.currentEnterpriseId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await dbHelper.insertWarehouse(defaultWarehouse);
        localWarehouses = await dbHelper.getWarehouses();
        if (localWarehouses.isEmpty) {
          localWarehouses = [defaultWarehouse];
        }
        
        FirebaseFirestore.instance
            .collection('warehouses')
            .doc(defaultWarehouse.id)
            .set(defaultWarehouse.toMap(), SetOptions(merge: true))
            .catchError((e) => print('Firestore warehouse auto-create sync error: $e'));
      }
      
      emit(WarehousesLoaded(localWarehouses));
    } catch (e) {
      print('📦 [DEBUG WarehousesBloc] SQLite fetch error: $e');
      emit(WarehousesError(e.toString()));
      return;
    }

    // Background Firestore Sync (Non-blocking with 5s timeout)
    try {
      Query query = FirebaseFirestore.instance
          .collection('warehouses')
          .where('is_deleted', isEqualTo: 0);

      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 5));
      print('📦 [DEBUG WarehousesBloc] Firestore returned ${snapshot.docs.length} warehouse documents');
      final firestoreWarehouses = snapshot.docs
          .map((doc) => Warehouse.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      for (var warehouse in firestoreWarehouses) {
        await dbHelper.insertWarehouse(warehouse);
      }

      final updatedWarehouses = await dbHelper.getWarehouses();
      if (!emit.isDone && updatedWarehouses.isNotEmpty) {
        emit(WarehousesLoaded(updatedWarehouses));
      }
    } catch (e) {
      print('📦 [DEBUG WarehousesBloc] Firestore background sync note: $e');
    }
  }

  Future<void> _onAddWarehouse(AddWarehouse event, Emitter<WarehousesState> emit) async {
    print('📦 [DEBUG WarehousesBloc] AddWarehouse event triggered: ${event.warehouse.name} (id: ${event.warehouse.id}, enterpriseId: ${event.warehouse.enterpriseId})');
    final currentState = state;
    List<Warehouse> currentList = [];
    if (currentState is WarehousesLoaded) {
      currentList = List<Warehouse>.from(currentState.warehouses);
    }
    currentList.removeWhere((w) => w.id == event.warehouse.id);
    currentList.insert(0, event.warehouse);
    emit(WarehousesLoaded(currentList));
    print('📦 [DEBUG WarehousesBloc] Emitted optimistic WarehousesLoaded with ${currentList.length} items');

    try {
      if (event.warehouse.isDefault) {
        await _unsetOtherDefaults(exceptId: event.warehouse.id);
      }
      await dbHelper.insertWarehouse(event.warehouse);
      print('📦 [DEBUG WarehousesBloc] Successfully inserted warehouse to local SQLite');
    } catch (e) {
      print("📦 [DEBUG WarehousesBloc] Failed to save warehouse to SQLite: $e");
    }

    FirebaseFirestore.instance
        .collection('warehouses')
        .doc(event.warehouse.id)
        .set(event.warehouse.toMap(), SetOptions(merge: true))
        .then((_) => print('📦 [DEBUG WarehousesBloc] Successfully synced warehouse to Firestore'))
        .catchError((e) => print("📦 [DEBUG WarehousesBloc] Failed to add warehouse to Firestore: $e"));
  }

  Future<void> _onUpdateWarehouse(UpdateWarehouse event, Emitter<WarehousesState> emit) async {
    final currentState = state;
    if (currentState is WarehousesLoaded) {
      final currentList = List<Warehouse>.from(currentState.warehouses);
      final idx = currentList.indexWhere((w) => w.id == event.warehouse.id);
      if (idx != -1) {
        currentList[idx] = event.warehouse;
      } else {
        currentList.insert(0, event.warehouse);
      }
      emit(WarehousesLoaded(currentList));
    }

    try {
      if (event.warehouse.isDefault) {
        await _unsetOtherDefaults(exceptId: event.warehouse.id);
      }
      await dbHelper.updateWarehouse(event.warehouse);
    } catch (e) {
      print("Failed to update warehouse in SQLite: $e");
    }

    FirebaseFirestore.instance
        .collection('warehouses')
        .doc(event.warehouse.id)
        .set(event.warehouse.toMap(), SetOptions(merge: true))
        .catchError((e) => print("Failed to update warehouse in Firestore: $e"));
  }

  Future<void> _onDeleteWarehouse(DeleteWarehouse event, Emitter<WarehousesState> emit) async {
    final currentState = state;
    if (currentState is WarehousesLoaded) {
      final currentList = List<Warehouse>.from(currentState.warehouses)
        ..removeWhere((w) => w.id == event.id);
      emit(WarehousesLoaded(currentList));
    }

    try {
      await dbHelper.deleteWarehouse(event.id);
    } catch (e) {
      print("Failed to delete warehouse in SQLite: $e");
    }

    FirebaseFirestore.instance
        .collection('warehouses')
        .doc(event.id)
        .update({'is_deleted': 1})
        .catchError((e) => print("Failed to delete warehouse in Firestore: $e"));
  }

  Future<void> _unsetOtherDefaults({String? exceptId}) async {
    final warehouses = await dbHelper.getWarehouses();
    for (var w in warehouses) {
      if (w.isDefault && w.id != exceptId) {
        final updated = w.copyWith(isDefault: false);
        await dbHelper.updateWarehouse(updated);
        FirebaseFirestore.instance
            .collection('warehouses')
            .doc(w.id)
            .set(updated.toMap(), SetOptions(merge: true))
            .catchError((e) => print("Failed to unset default warehouse in Firestore: $e"));
      }
    }
  }
}
