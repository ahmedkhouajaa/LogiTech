import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_repository.dart';
import '../../database/database_helper.dart';
import '../../models/supplier.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/enterprise_service.dart';
import '../../services/permission_service.dart';
import '../../models/user_management_model.dart';
import 'package:business_manager_pro/services/error_handler.dart';

abstract class SuppliersEvent extends Equatable {
  const SuppliersEvent();
  @override
  List<Object?> get props => [];
}

class LoadSuppliers extends SuppliersEvent {}

class LoadFirstSuppliers extends SuppliersEvent {
  final String? searchQuery;
  const LoadFirstSuppliers({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class LoadNextSuppliers extends SuppliersEvent {
  final String? searchQuery;
  const LoadNextSuppliers({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class ResetSuppliersPagination extends SuppliersEvent {
  final String? searchQuery;
  const ResetSuppliersPagination({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class AddSupplier extends SuppliersEvent {
  final Supplier supplier;
  const AddSupplier(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class UpdateSupplier extends SuppliersEvent {
  final Supplier supplier;
  const UpdateSupplier(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class DeleteSupplier extends SuppliersEvent {
  final String id;
  const DeleteSupplier(this.id);
  @override
  List<Object?> get props => [id];
}

class BulkDeleteSuppliers extends SuppliersEvent {
  final List<String> ids;
  const BulkDeleteSuppliers(this.ids);
  @override
  List<Object?> get props => [ids];
}

abstract class SuppliersState extends Equatable {
  const SuppliersState();
  @override
  List<Object?> get props => [];
}

class SuppliersInitial extends SuppliersState {}
class SuppliersLoading extends SuppliersState {}

class SuppliersLoaded extends SuppliersState {
  final List<Supplier> suppliers;
  final int? _totalCount;
  final bool? _hasMore;
  final bool? _isLoadingMore;

  int get totalCount => _totalCount ?? 0;
  bool get hasMore => _hasMore ?? true;
  bool get isLoadingMore => _isLoadingMore ?? false;

  const SuppliersLoaded(
    this.suppliers, {
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  })  : _totalCount = totalCount,
        _hasMore = hasMore,
        _isLoadingMore = isLoadingMore;

  SuppliersLoaded copyWith({
    List<Supplier>? suppliers,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SuppliersLoaded(
      suppliers ?? this.suppliers,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [suppliers, _totalCount, _hasMore, _isLoadingMore];
}

class SuppliersError extends SuppliersState {
  final String message;
  const SuppliersError(this.message);
  @override
  List<Object?> get props => [message];
}

class SuppliersBloc extends Bloc<SuppliersEvent, SuppliersState> {
  SuppliersBloc() : super(SuppliersInitial()) {
    on<LoadSuppliers>(_onLoad);
    on<LoadFirstSuppliers>(_onLoadFirstSuppliers);
    on<LoadNextSuppliers>(_onLoadNextSuppliers);
    on<ResetSuppliersPagination>(_onResetSuppliersPagination);
    on<AddSupplier>(_onAdd);
    on<UpdateSupplier>(_onUpdate);
    on<DeleteSupplier>(_onDelete);
    on<BulkDeleteSuppliers>(_onBulkDelete);
  }

  Future<void> _onLoad(LoadSuppliers event, Emitter<SuppliersState> emit) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;

    emit(SuppliersLoading());

    Query buildQuery() {
      Query query = FirebaseFirestore.instance.collection('fournisseurs');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      } else if (uid != null && uid.isNotEmpty) {
        query = query.where('userId', isEqualTo: uid);
      }
      return query;
    }

    List<Supplier> parseSnapshot(QuerySnapshot snapshot) {
      final results = <Supplier>[];
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        final isDel = data['is_deleted'] == 1 || data['is_deleted'] == true || data['is_deleted'] == '1' || data['isDeleted'] == 1 || data['isDeleted'] == true;
        if (isDel) {
          doc.reference.delete().catchError((_) {});
          continue;
        }
        data['created_at'] = data['created_at'] ?? DateTime.now().toIso8601String();
        data['updated_at'] = data['updated_at'] ?? DateTime.now().toIso8601String();
        if (!data.containsKey('code') && data.containsKey('supplierCode')) {
          data['code'] = data['supplierCode'];
        }
        if (!data.containsKey('supplier_type') && data.containsKey('type')) {
          data['supplier_type'] = data['type'];
        }
        try {
          results.add(Supplier.fromMap(data));
        } catch (e) {
          print("Error parsing supplier ${doc.id}: $e");
        }
      }
      return results;
    }

    List<Supplier> deduplicateDefaults(List<Supplier> list) {
      final unique = <Supplier>[];
      bool seenDefault = false;
      for (final s in list) {
        final isDef = s.isDefault || s.name.trim().toLowerCase() == 'fournisseur passager';
        if (isDef) {
          if (!seenDefault) {
            unique.add(s);
            seenDefault = true;
          }
        } else {
          unique.add(s);
        }
      }
      return unique;
    }

    try {
      // Phase 1: Try cache for instant display
      bool shownFromCache = false;
      try {
        final cacheSnapshot = await buildQuery().get(const GetOptions(source: Source.cache));
        if (cacheSnapshot.docs.isNotEmpty && !emit.isDone) {
          final cachedSuppliers = deduplicateDefaults(parseSnapshot(cacheSnapshot));
          emit(SuppliersLoaded(cachedSuppliers, totalCount: cachedSuppliers.length, hasMore: false));
          shownFromCache = true;
        }
      } catch (_) {
        // Cache unavailable, will fetch from server below
      }

      // Phase 2: Always fetch from server for cross-device sync
      try {
        final serverSnapshot = await buildQuery().get(const GetOptions(source: Source.server));
        List<Supplier> suppliers = deduplicateDefaults(parseSnapshot(serverSnapshot));

        if (!emit.isDone) {
          emit(SuppliersLoaded(suppliers, totalCount: suppliers.length, hasMore: false));
        }
      } catch (e) {
        // Server fetch failed; if we already showed cache data, that's fine
        if (!shownFromCache && !emit.isDone) {
          emit(SuppliersLoaded([], totalCount: 0, hasMore: false));
        }
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(SuppliersLoaded([], totalCount: 0, hasMore: false));
      }
    }
  }

  Future<void> _onLoadFirstSuppliers(LoadFirstSuppliers event, Emitter<SuppliersState> emit) async {
    emit(SuppliersLoading());
    try {
      FirestorePaginationService.instance.resetSuppliersPagination();
      final suppliersFuture = FirestorePaginationService.instance.getFirstSuppliers(
        pageSize: 10,
        searchQuery: event.searchQuery,
      );
      final countFuture = FirestorePaginationService.instance.getSuppliersCount(
        searchQuery: event.searchQuery,
      );

      final results = await Future.wait([suppliersFuture, countFuture]);
      final suppliers = results[0] as List<Supplier>;
      final totalCount = results[1] as int;

      emit(SuppliersLoaded(
        suppliers,
        totalCount: totalCount > suppliers.length ? totalCount : suppliers.length,
        hasMore: suppliers.length >= 10,
      ));
    } catch (e) {
      emit(SuppliersError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadNextSuppliers(LoadNextSuppliers event, Emitter<SuppliersState> emit) async {
    final currentState = state;
    if (currentState is! SuppliersLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextSuppliers = await FirestorePaginationService.instance.getNextSuppliers(
        pageSize: 10,
        currentOffset: currentState.suppliers.length,
        searchQuery: event.searchQuery,
      );

      emit(currentState.copyWith(
        suppliers: [...currentState.suppliers, ...nextSuppliers],
        hasMore: nextSuppliers.length >= 10,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetSuppliersPagination(ResetSuppliersPagination event, Emitter<SuppliersState> emit) async {
    try {
      FirestorePaginationService.instance.resetSuppliersPagination();
      final suppliersFuture = FirestorePaginationService.instance.getFirstSuppliers(
        pageSize: 10,
        searchQuery: event.searchQuery,
      );
      final countFuture = FirestorePaginationService.instance.getSuppliersCount(
        searchQuery: event.searchQuery,
      );

      final results = await Future.wait([suppliersFuture, countFuture]);
      final suppliers = results[0] as List<Supplier>;
      final totalCount = results[1] as int;

      emit(SuppliersLoaded(
        suppliers,
        totalCount: totalCount > suppliers.length ? totalCount : suppliers.length,
        hasMore: suppliers.length >= 10,
      ));
    } catch (e) {
      emit(SuppliersError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAdd(AddSupplier event, Emitter<SuppliersState> emit) async {
    if (!PermissionService.instance.canCreate(UserPermissionResources.suppliers)) {
      emit(const SuppliersError('Permission refusée : Vous n\'avez pas le droit d\'ajouter un fournisseur.'));
      return;
    }
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    
    String finalCode = event.supplier.code;
    
    // If the code looks like an auto-generated sequence, fetch the next atomic sequence right before saving
    if (finalCode.toUpperCase().startsWith('FR') || finalCode.toUpperCase().startsWith('FOU')) {
      try {
        finalCode = await DatabaseHelper.instance.generateNextSupplierSequenceAtomic(currentEntId);
      } catch (e) {
        // Fallback to the code provided if offline
      }
    }

    // Ensure the supplier has the current enterpriseId and correct code
    final supplier = (event.supplier.enterpriseId == null || event.supplier.enterpriseId!.isEmpty || finalCode != event.supplier.code)
        ? Supplier(
            id: event.supplier.id,
            code: finalCode,
            name: event.supplier.name,
            email: event.supplier.email,
            phone: event.supplier.phone,
            address: event.supplier.address,
            city: event.supplier.city,
            taxId: event.supplier.taxId,
            rc: event.supplier.rc,
            balance: event.supplier.balance,
            notes: event.supplier.notes,
            firebaseUid: event.supplier.firebaseUid,
            enterpriseId: currentEntId,
            isDeleted: event.supplier.isDeleted,
            isDefault: false,
            createdAt: event.supplier.createdAt,
            updatedAt: event.supplier.updatedAt,
            supplierType: event.supplier.supplierType,
            companyName: event.supplier.companyName,
            responsibleName: event.supplier.responsibleName,
            cinNumber: event.supplier.cinNumber,
            postalCode: event.supplier.postalCode,
            country: event.supplier.country,
            deliveryStreet: event.supplier.deliveryStreet,
            deliveryCity: event.supplier.deliveryCity,
            deliveryPostalCode: event.supplier.deliveryPostalCode,
            deliveryCountry: event.supplier.deliveryCountry,
            deliverySameAsBilling: event.supplier.deliverySameAsBilling,
            bankAccount: event.supplier.bankAccount,
            birthDate: event.supplier.birthDate,
            referenceCode: event.supplier.referenceCode,
          )
        : event.supplier;

    final currentState = state;
    List<Supplier> currentList = [];
    int newCount = 1;
    if (currentState is SuppliersLoaded) {
      currentList = List<Supplier>.from(currentState.suppliers);
      newCount = (currentState.totalCount > 0) ? currentState.totalCount + 1 : currentList.length + 1;
    }
    currentList.removeWhere((s) => s.id == supplier.id);
    currentList.add(supplier);
    
    // Maintain list sorted by code ascending
    currentList.sort((a, b) => a.code.compareTo(b.code));
    
    if (currentState is SuppliersLoaded) {
      emit(currentState.copyWith(
        suppliers: currentList,
        totalCount: newCount,
      ));
    } else {
      emit(SuppliersLoaded(currentList, totalCount: newCount, hasMore: false));
    }

    try {
      await FirestoreRepository.instance.saveSupplier(supplier);
    } catch (e) {
      print("Failed to save supplier to Firestore: $e");
    }
  }

  Future<void> _onUpdate(UpdateSupplier event, Emitter<SuppliersState> emit) async {
    if (event.supplier.isDefault || event.supplier.name.trim().toLowerCase() == 'fournisseur passager') {
      emit(const SuppliersError('Cet élément est un élément par défaut et ne peut pas être modifié.'));
      return;
    }
    if (!PermissionService.instance.canUpdate(UserPermissionResources.suppliers)) {
      emit(const SuppliersError('Permission refusée : Vous n\'avez pas le droit de modifier un fournisseur.'));
      return;
    }
    final currentState = state;
    if (currentState is SuppliersLoaded) {
      final currentList = List<Supplier>.from(currentState.suppliers);
      currentList.removeWhere((s) => s.id == event.supplier.id);
      currentList.add(event.supplier);
      
      // Maintain list sorted by code ascending
      currentList.sort((a, b) => a.code.compareTo(b.code));
      
      emit(currentState.copyWith(suppliers: currentList));
    }

    try {
      await FirestoreRepository.instance.saveSupplier(event.supplier);
    } catch (e) {
      print("Failed to update supplier in Firestore: $e");
    }
  }

  Future<void> _onDelete(DeleteSupplier event, Emitter<SuppliersState> emit) async {
    final trimmedId = event.id.trim();
    if (trimmedId.isEmpty) return;

    final currentState = state;
    if (currentState is SuppliersLoaded) {
      final target = currentState.suppliers.where((s) => s.id == trimmedId).firstOrNull;
      if (target != null && (target.isDefault || target.name.trim().toLowerCase() == 'fournisseur passager')) {
        emit(const SuppliersError('Cet élément est un élément par défaut et ne peut pas être supprimé.'));
        return;
      }
    }
    if (!PermissionService.instance.canDelete(UserPermissionResources.suppliers)) {
      emit(const SuppliersError('Permission refusée : Vous n\'avez pas le droit de supprimer un fournisseur.'));
      return;
    }

    // 1. Optimistically remove from state immediately
    if (currentState is SuppliersLoaded) {
      final updatedList = currentState.suppliers.where((s) => s.id != trimmedId).toList();
      final newCount = (currentState.totalCount > 0 ? currentState.totalCount - 1 : updatedList.length);
      emit(currentState.copyWith(
        suppliers: updatedList,
        totalCount: newCount,
      ));
    }

    try {
      await FirestoreRepository.instance.deleteDocument('fournisseurs', trimmedId);
      await DatabaseHelper.instance.deleteSupplier(trimmedId);
    } catch (e) {
      print("Failed to delete supplier in Firestore: $e");
    }
  }

  Future<void> _onBulkDelete(BulkDeleteSuppliers event, Emitter<SuppliersState> emit) async {
    if (!PermissionService.instance.canDelete(UserPermissionResources.suppliers)) {
      emit(const SuppliersError('Permission refusée : Vous n\'avez pas le droit de supprimer des fournisseurs.'));
      return;
    }

    final validIds = event.ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) return;

    final currentState = state;
    final protectedIds = <String>{};
    if (currentState is SuppliersLoaded) {
      for (final s in currentState.suppliers) {
        if (validIds.contains(s.id) && (s.isDefault || s.name.trim().toLowerCase() == 'fournisseur passager')) {
          protectedIds.add(s.id);
        }
      }
    }

    final idsToDelete = validIds.where((id) => !protectedIds.contains(id)).toList();
    if (idsToDelete.isEmpty) return;
    final idsSet = idsToDelete.toSet();

    // 1. Optimistically remove from state immediately
    if (currentState is SuppliersLoaded) {
      final updatedList = currentState.suppliers.where((s) => !idsSet.contains(s.id)).toList();
      final newCount = (currentState.totalCount >= idsToDelete.length
          ? currentState.totalCount - idsToDelete.length
          : updatedList.length);
      emit(currentState.copyWith(
        suppliers: updatedList,
        totalCount: newCount,
      ));
    }

    // 2. Batch delete in chunks of 400
    try {
      const chunkSize = 400;
      for (var i = 0; i < idsToDelete.length; i += chunkSize) {
        final end = (i + chunkSize < idsToDelete.length) ? i + chunkSize : idsToDelete.length;
        final chunk = idsToDelete.sublist(i, end);
        final batch = FirebaseFirestore.instance.batch();
        for (final id in chunk) {
          batch.delete(FirebaseFirestore.instance.collection('fournisseurs').doc(id));
        }
        await batch.commit();
      }

      for (final id in idsToDelete) {
        await DatabaseHelper.instance.deleteSupplier(id);
      }
    } catch (e) {
      print("Error in bulk deleting suppliers: $e");
    }
  }
}
