const fs = require('fs');

// Fix bloc
let blocPath = 'd:/LogiTech/lib/blocs/supplier_returns/supplier_returns_bloc.dart';
let blocContent = fs.readFileSync(blocPath, 'utf8');

// I replaced `}\n  Future<void> _onFilterSupplierReturns` with `  Future<void> _onFilterSupplierReturns` previously which caused missing `}`.
// Let's just rewrite the bloc class correctly from scratch or just replace the end
blocContent = `import 'package:flutter_bloc/flutter_bloc.dart';
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
`;
fs.writeFileSync(blocPath, blocContent, 'utf8');

// Fix create screen
let createPath = 'd:/LogiTech/lib/screens/create_supplier_return_screen.dart';
let createContent = fs.readFileSync(createPath, 'utf8');

// remove duplicate reason
createContent = createContent.replace(/reason: _notesController\.text,\n\s*reason: _notesController\.text,/g, 'reason: _notesController.text,');

// add createdAt, isDeleted, updatedAt
createContent = createContent.replace(/items: _items,/g, 'items: _items,\n      isDeleted: false,\n      createdAt: DateTime.now(),\n      updatedAt: DateTime.now(),');

fs.writeFileSync(createPath, createContent, 'utf8');
