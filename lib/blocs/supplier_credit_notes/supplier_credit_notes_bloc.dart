import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import '../../models/supplier_credit_note.dart';
import 'supplier_credit_notes_event.dart';
import 'supplier_credit_notes_state.dart';

class SupplierCreditNotesBloc extends Bloc<SupplierCreditNotesEvent, SupplierCreditNotesState> {
  final DatabaseHelper dbHelper;

  SupplierCreditNotesBloc(this.dbHelper) : super(SupplierCreditNotesInitial()) {
    on<LoadSupplierCreditNotes>(_onLoadSupplierCreditNotes);
    on<AddSupplierCreditNote>(_onAddSupplierCreditNote);
    on<UpdateSupplierCreditNote>(_onUpdateSupplierCreditNote);
    on<DeleteSupplierCreditNote>(_onDeleteSupplierCreditNote);
    on<FilterSupplierCreditNotes>(_onFilterSupplierCreditNotes);
  }

  Future<void> _onLoadSupplierCreditNotes(LoadSupplierCreditNotes event, Emitter<SupplierCreditNotesState> emit) async {
    emit(SupplierCreditNotesLoading());
    try {
      final creditNotes = await dbHelper.getSupplierCreditNotes();
      emit(SupplierCreditNotesLoaded(creditNotes));
    } catch (e) {
      emit(SupplierCreditNotesError(e.toString()));
    }
  }

  Future<void> _onAddSupplierCreditNote(AddSupplierCreditNote event, Emitter<SupplierCreditNotesState> emit) async {
    emit(SupplierCreditNotesLoading());
    try {
      await dbHelper.insertSupplierCreditNote(event.supplierCreditNote);
      final creditNotes = await dbHelper.getSupplierCreditNotes();
      emit(SupplierCreditNotesLoaded(creditNotes));
    } catch (e) {
      emit(SupplierCreditNotesError(e.toString()));
    }
  }

  Future<void> _onUpdateSupplierCreditNote(UpdateSupplierCreditNote event, Emitter<SupplierCreditNotesState> emit) async {
    emit(SupplierCreditNotesLoading());
    try {
      await dbHelper.updateSupplierCreditNote(event.supplierCreditNote);
      final creditNotes = await dbHelper.getSupplierCreditNotes();
      emit(SupplierCreditNotesLoaded(creditNotes));
    } catch (e) {
      emit(SupplierCreditNotesError(e.toString()));
    }
  }

  Future<void> _onDeleteSupplierCreditNote(DeleteSupplierCreditNote event, Emitter<SupplierCreditNotesState> emit) async {
    emit(SupplierCreditNotesLoading());
    try {
      await dbHelper.deleteSupplierCreditNote(event.id);
      final creditNotes = await dbHelper.getSupplierCreditNotes();
      emit(SupplierCreditNotesLoaded(creditNotes));
    } catch (e) {
      emit(SupplierCreditNotesError(e.toString()));
    }
  }

  Future<void> _onFilterSupplierCreditNotes(FilterSupplierCreditNotes event, Emitter<SupplierCreditNotesState> emit) async {
    emit(SupplierCreditNotesLoading());
    try {
      final creditNotes = await dbHelper.getSupplierCreditNotes();
      final filtered = creditNotes.where((r) {
        if (event.supplierId != null && event.supplierId != 'all' && r.supplierId != event.supplierId) return false;
        if (event.status != null && event.status != 'all' && r.status != event.status) return false;
        if (event.dateFrom != null && r.date.isBefore(event.dateFrom!)) return false;
        if (event.dateTo != null && r.date.isAfter(event.dateTo!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
      emit(SupplierCreditNotesLoaded(filtered));
    } catch (e) {
      emit(SupplierCreditNotesError(e.toString()));
    }
  }
}
