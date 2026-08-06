import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../database/database_helper.dart';
import '../../models/supplier.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/enterprise_service.dart';

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
  }

  Future<void> _onLoad(LoadSuppliers event, Emitter<SuppliersState> emit) async {
    try {
      final localSuppliers = await DatabaseHelper.instance.getSuppliers();
      emit(SuppliersLoaded(localSuppliers, totalCount: localSuppliers.length, hasMore: false));
    } catch (e) {
      emit(SuppliersLoading());
    }
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    Query query = FirebaseFirestore.instance.collection('fournisseurs').where('is_deleted', isEqualTo: 0);
    if (currentEntId != null && currentEntId.isNotEmpty) {
      query = query.where('enterprise_id', isEqualTo: currentEntId);
    }
    query.get().then((snapshot) async {
          final List<Supplier> firestoreSuppliers = snapshot.docs.map((doc) => Supplier.fromMap(doc.data() as Map<String, dynamic>)).toList();
          for (var supplier in firestoreSuppliers) {
            await DatabaseHelper.instance.insertSupplier(supplier);
          }
          final suppliers = await DatabaseHelper.instance.getSuppliers();
          if (!emit.isDone) {
            emit(SuppliersLoaded(suppliers, totalCount: suppliers.length, hasMore: false));
          }
        })
        .catchError((e) {
          print("Failed to fetch/save suppliers from Firestore: $e");
        });
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
      emit(SuppliersError(e.toString()));
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
      emit(SuppliersError(e.toString()));
    }
  }

  Future<void> _onAdd(AddSupplier event, Emitter<SuppliersState> emit) async {
    final currentState = state;
    List<Supplier> currentList = [];
    if (currentState is SuppliersLoaded) {
      currentList = List<Supplier>.from(currentState.suppliers);
    }
    currentList.removeWhere((s) => s.id == event.supplier.id);
    currentList.insert(0, event.supplier);
    emit(SuppliersLoaded(currentList, totalCount: currentList.length, hasMore: false));

    DatabaseHelper.instance.insertSupplier(event.supplier).catchError((e) {
      print("Failed to save supplier to SQLite: $e");
    });
    FirebaseFirestore.instance
        .collection('fournisseurs')
        .doc(event.supplier.id)
        .set(event.supplier.toMap(), SetOptions(merge: true))
        .catchError((e) => print("Failed to add supplier to Firestore: $e"));
  }

  Future<void> _onUpdate(UpdateSupplier event, Emitter<SuppliersState> emit) async {
    final currentState = state;
    if (currentState is SuppliersLoaded) {
      final currentList = List<Supplier>.from(currentState.suppliers);
      final idx = currentList.indexWhere((s) => s.id == event.supplier.id);
      if (idx != -1) {
        currentList[idx] = event.supplier;
      } else {
        currentList.insert(0, event.supplier);
      }
      emit(SuppliersLoaded(currentList, totalCount: currentList.length, hasMore: false));
    }

    DatabaseHelper.instance.updateSupplier(event.supplier).catchError((e) {
      print("Failed to update supplier in SQLite: $e");
    });
    FirebaseFirestore.instance
        .collection('fournisseurs')
        .doc(event.supplier.id)
        .set(event.supplier.toMap(), SetOptions(merge: true))
        .catchError((e) => print("Failed to update supplier in Firestore: $e"));
  }

  Future<void> _onDelete(DeleteSupplier event, Emitter<SuppliersState> emit) async {
    final currentState = state;
    if (currentState is SuppliersLoaded) {
      final currentList = List<Supplier>.from(currentState.suppliers)..removeWhere((s) => s.id == event.id);
      emit(SuppliersLoaded(currentList, totalCount: currentList.length, hasMore: false));
    }

    DatabaseHelper.instance.deleteSupplier(event.id).catchError((e) {
      print("Failed to delete supplier in SQLite: $e");
    });
    FirebaseFirestore.instance
        .collection('fournisseurs')
        .doc(event.id)
        .update({'is_deleted': 1})
        .catchError((e) => print("Failed to delete supplier in Firestore: $e"));
  }
}
