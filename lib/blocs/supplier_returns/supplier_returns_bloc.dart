import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import '../../models/supplier_return.dart';
import 'supplier_returns_event.dart';
import 'supplier_returns_state.dart';

class SupplierReturnsBloc extends Bloc<SupplierReturnsEvent, SupplierReturnsState> {
  final DatabaseHelper dbHelper;

  SupplierReturnsBloc(this.dbHelper) : super(SupplierReturnsInitial()) {
    on<LoadSupplierReturns>(_onLoadSupplierReturns);
    on<AddSupplierReturn>(_onAddSupplierReturn);
    on<UpdateSupplierReturn>(_onUpdateSupplierReturn);
    on<DeleteSupplierReturn>(_onDeleteSupplierReturn);
    on<FilterSupplierReturns>(_onFilterSupplierReturns);
  }

  Future<void> _onLoadSupplierReturns(LoadSupplierReturns event, Emitter<SupplierReturnsState> emit) async {
    emit(SupplierReturnsLoading());
    try {
      final returns = await dbHelper.getSupplierReturns();
      emit(SupplierReturnsLoaded(returns));
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onAddSupplierReturn(AddSupplierReturn event, Emitter<SupplierReturnsState> emit) async {
    emit(SupplierReturnsLoading());
    try {
      await dbHelper.insertSupplierReturn(event.supplierReturn);
      final returns = await dbHelper.getSupplierReturns();
      emit(SupplierReturnsLoaded(returns));
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onUpdateSupplierReturn(UpdateSupplierReturn event, Emitter<SupplierReturnsState> emit) async {
    emit(SupplierReturnsLoading());
    try {
      await dbHelper.updateSupplierReturn(event.supplierReturn);
      final returns = await dbHelper.getSupplierReturns();
      emit(SupplierReturnsLoaded(returns));
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onDeleteSupplierReturn(DeleteSupplierReturn event, Emitter<SupplierReturnsState> emit) async {
    emit(SupplierReturnsLoading());
    try {
      await dbHelper.deleteSupplierReturn(event.id);
      final returns = await dbHelper.getSupplierReturns();
      emit(SupplierReturnsLoaded(returns));
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }

  Future<void> _onFilterSupplierReturns(FilterSupplierReturns event, Emitter<SupplierReturnsState> emit) async {
    emit(SupplierReturnsLoading());
    try {
      final returns = await dbHelper.getSupplierReturns();
      final filtered = returns.where((r) {
        if (event.FournisseurId != null && event.FournisseurId != 'all' && r.supplierId != event.FournisseurId) return false;
        if (event.status != null && event.status != 'all' && r.status != event.status) return false;
        if (event.dateFrom != null && r.date.isBefore(event.dateFrom!)) return false;
        if (event.dateTo != null && r.date.isAfter(event.dateTo!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
      emit(SupplierReturnsLoaded(filtered));
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }
}
