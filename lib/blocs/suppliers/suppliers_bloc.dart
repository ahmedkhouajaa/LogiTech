import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/supplier.dart';
import '../../services/firestore_pagination_service.dart';

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
    emit(SuppliersLoading());
    try {
      final suppliers = await DatabaseHelper.instance.getSuppliers();
      emit(SuppliersLoaded(suppliers, totalCount: suppliers.length, hasMore: false));
    } catch (e) {
      emit(SuppliersError(e.toString()));
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
    try {
      await DatabaseHelper.instance.insertSupplier(event.supplier);
      add(const ResetSuppliersPagination());
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateSupplier event, Emitter<SuppliersState> emit) async {
    try {
      await DatabaseHelper.instance.updateSupplier(event.supplier);
      add(const ResetSuppliersPagination());
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteSupplier event, Emitter<SuppliersState> emit) async {
    try {
      await DatabaseHelper.instance.deleteSupplier(event.id);
      add(const ResetSuppliersPagination());
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }
}
