import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../database/database_helper.dart';
import '../../models/stock_movement.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';
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
    
    Query query = FirebaseFirestore.instance.collection('warehouses').where('is_deleted', isEqualTo: 0);
    if (currentEntId != null && currentEntId.isNotEmpty) {
      query = query.where('enterprise_id', isEqualTo: currentEntId);
    }

    bool shownFromCache = false;
    try {
      final cacheSnap = await query.get(const GetOptions(source: Source.cache));
      if (cacheSnap.docs.isNotEmpty && !emit.isDone) {
        final accounts = cacheSnap.docs.map((d) => Warehouse.fromMap(d.data() as Map<String, dynamic>)).toList();
        emit(WarehousesLoaded(accounts));
        shownFromCache = true;
      }
    } catch (_) {}

    try {
      final serverSnap = await query.get(const GetOptions(source: Source.server));
      List<Warehouse> accounts = serverSnap.docs.map((d) => Warehouse.fromMap(d.data() as Map<String, dynamic>)).toList();
      
      if (!accounts.any((w) => w.isDefault)) {
        final defaultWarehouse = Warehouse(
          id: const Uuid().v4(),
          name: 'Entrepôt par défaut',
          reference: 'WH-001',
          isDefault: true,
          isActive: true,
          enterpriseId: currentEntId ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        accounts.add(defaultWarehouse);

        FirestoreRepository.instance
            .saveDocument('warehouses', defaultWarehouse.id, defaultWarehouse.toMap())
            .catchError((e) => print('Firestore warehouse auto-create sync error: $e'));
      }

      accounts.sort((a, b) => (a.reference ?? '').compareTo(b.reference ?? ''));

      if (!emit.isDone) {
        emit(WarehousesLoaded(accounts));
      }
    } catch (e) {
      if (!shownFromCache && !emit.isDone) {
        emit(WarehousesLoaded(const []));
      }
    }
  }

  Future<void> _onAddWarehouse(AddWarehouse event, Emitter<WarehousesState> emit) async {
    final currentState = state;
    List<Warehouse> currentList = [];
    if (currentState is WarehousesLoaded) {
      currentList = List<Warehouse>.from(currentState.warehouses);
    }
    
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    
    String? finalReference = event.warehouse.reference;
    if (finalReference == null || finalReference.trim().isEmpty || finalReference.toUpperCase().startsWith('WH')) {
      try {
        finalReference = await DatabaseHelper.instance.generateNextWarehouseSequenceAtomic(currentEntId);
      } catch (e) {
        // Fallback silently if offline or failed
      }
    }

    final warehouse = (event.warehouse.enterpriseId == null || event.warehouse.enterpriseId!.isEmpty || finalReference != event.warehouse.reference)
        ? event.warehouse.copyWith(
            enterpriseId: currentEntId ?? '',
            reference: finalReference,
          )
        : event.warehouse;

    currentList.removeWhere((w) => w.id == warehouse.id);
    currentList.insert(0, warehouse);
    currentList.sort((a, b) => (a.reference ?? '').compareTo(b.reference ?? ''));
    emit(WarehousesLoaded(currentList));

    try {
      if (warehouse.isDefault) {
        await _unsetOtherDefaults(exceptId: warehouse.id);
      }
      await FirestoreRepository.instance.saveDocument('warehouses', warehouse.id, warehouse.toMap());
    } catch (e) {
      print("Failed to save warehouse to Firestore: $e");
    }
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
      currentList.sort((a, b) => (a.reference ?? '').compareTo(b.reference ?? ''));
      emit(WarehousesLoaded(currentList));
    }

    try {
      if (event.warehouse.isDefault) {
        await _unsetOtherDefaults(exceptId: event.warehouse.id);
      }
      await FirestoreRepository.instance.saveDocument('warehouses', event.warehouse.id, event.warehouse.toMap());
    } catch (e) {
      print("Failed to update warehouse in Firestore: $e");
    }
  }

  Future<void> _onDeleteWarehouse(DeleteWarehouse event, Emitter<WarehousesState> emit) async {
    final currentState = state;
    if (currentState is WarehousesLoaded) {
      final currentList = List<Warehouse>.from(currentState.warehouses)
        ..removeWhere((w) => w.id == event.id);
      emit(WarehousesLoaded(currentList));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('warehouses', event.id);
    } catch (e) {
      print("Failed to delete warehouse in Firestore: $e");
    }
  }

  Future<void> _unsetOtherDefaults({String? exceptId}) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    Query query = FirebaseFirestore.instance.collection('warehouses')
      .where('isDefault', isEqualTo: true)
      .where('is_deleted', isEqualTo: 0);
      
    if (currentEntId != null && currentEntId.isNotEmpty) {
      query = query.where('enterprise_id', isEqualTo: currentEntId);
    }
    
    try {
      final snap = await query.get();
      for (var doc in snap.docs) {
        if (doc.id != exceptId) {
          await doc.reference.update({'isDefault': false});
        }
      }
    } catch (e) {
      print("Failed to unset other defaults in Firestore: $e");
    }
  }
}
