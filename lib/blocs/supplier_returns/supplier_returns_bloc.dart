import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import '../../models/supplier_return.dart';
import '../../services/firestore_pagination_service.dart';
import 'supplier_returns_event.dart';
import 'supplier_returns_state.dart';

class SupplierReturnsBloc extends Bloc<SupplierReturnsEvent, SupplierReturnsState> {
  static const int pageSize = 10;
  final DatabaseHelper dbHelper;

  SupplierReturnsBloc(this.dbHelper) : super(SupplierReturnsInitial()) {
    on<LoadSupplierReturns>(_onLoadSupplierReturns);
    on<LoadFirstSupplierReturns>(_onLoadFirstSupplierReturns);
    on<LoadNextSupplierReturns>(_onLoadNextSupplierReturns);
    on<ResetSupplierReturnsPagination>(_onResetSupplierReturnsPagination);
    on<AddSupplierReturn>(_onAddSupplierReturn);
    on<UpdateSupplierReturn>(_onUpdateSupplierReturn);
    on<DeleteSupplierReturn>(_onDeleteSupplierReturn);
    on<FilterSupplierReturns>(_onFilterSupplierReturns);
  }

  Future<void> _onLoadSupplierReturns(LoadSupplierReturns event, Emitter<SupplierReturnsState> emit) async {
    emit(SupplierReturnsLoading());
    try {
      final returns = await dbHelper.getSupplierReturns();
      emit(SupplierReturnsLoaded(returns, totalCount: returns.length));
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onLoadFirstSupplierReturns(LoadFirstSupplierReturns event, Emitter<SupplierReturnsState> emit) async {
    emit(SupplierReturnsLoading());
    try {
      FirestorePaginationService.instance.resetSupplierReturnsPagination();
      final returnsFuture = FirestorePaginationService.instance.getFirstSupplierReturns(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getSupplierReturnsCount(
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([returnsFuture, countFuture]);
      final returns = results[0] as List<SupplierReturn>;
      final totalCount = results[1] as int;

      emit(SupplierReturnsLoaded(
        returns,
        totalCount: totalCount > returns.length ? totalCount : returns.length,
        hasMore: returns.length >= pageSize,
      ));
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onLoadNextSupplierReturns(LoadNextSupplierReturns event, Emitter<SupplierReturnsState> emit) async {
    final currentState = state;
    if (currentState is! SupplierReturnsLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextReturns = await FirestorePaginationService.instance.getNextSupplierReturns(
        pageSize: pageSize,
        currentOffset: currentState.returns.length,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextReturns.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<SupplierReturn>.from(currentState.returns)..addAll(nextReturns);
        emit(SupplierReturnsLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextReturns.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetSupplierReturnsPagination(ResetSupplierReturnsPagination event, Emitter<SupplierReturnsState> emit) async {
    FirestorePaginationService.instance.resetSupplierReturnsPagination();
    add(LoadFirstSupplierReturns(
      searchQuery: event.searchQuery,
      supplierId: event.supplierId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAddSupplierReturn(AddSupplierReturn event, Emitter<SupplierReturnsState> emit) async {
    try {
      await dbHelper.insertSupplierReturn(event.supplierReturn);
      add(LoadSupplierReturns());
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onUpdateSupplierReturn(UpdateSupplierReturn event, Emitter<SupplierReturnsState> emit) async {
    try {
      await dbHelper.updateSupplierReturn(event.supplierReturn);
      add(LoadSupplierReturns());
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onDeleteSupplierReturn(DeleteSupplierReturn event, Emitter<SupplierReturnsState> emit) async {
    try {
      await dbHelper.deleteSupplierReturn(event.id);
      add(LoadSupplierReturns());
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onFilterSupplierReturns(FilterSupplierReturns event, Emitter<SupplierReturnsState> emit) async {
    add(LoadFirstSupplierReturns(
      supplierId: event.supplierId,
      status: event.status,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
    ));
  }
}
