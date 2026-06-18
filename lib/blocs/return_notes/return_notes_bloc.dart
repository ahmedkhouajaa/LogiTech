import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import 'return_notes_event.dart';
import 'return_notes_state.dart';

class ReturnNotesBloc extends Bloc<ReturnNotesEvent, ReturnNotesState> {
  ReturnNotesBloc() : super(ReturnNotesInitial()) {
    on<LoadReturnNotes>(_onLoadReturnNotes);
    on<AddReturnNote>(_onAddReturnNote);
    on<UpdateReturnNote>(_onUpdateReturnNote);
    on<DeleteReturnNote>(_onDeleteReturnNote);
    on<FilterReturnNotes>(_onFilterReturnNotes);
  }

  Future<void> _onLoadReturnNotes(LoadReturnNotes event, Emitter<ReturnNotesState> emit) async {
    emit(ReturnNotesLoading());
    try {
      final notes = await DatabaseHelper.instance.getReturnNotes(
        status: event.status,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(ReturnNotesLoaded(notes));
    } catch (e) {
      emit(ReturnNotesError('Erreur de chargement: $e'));
    }
  }

  Future<void> _onFilterReturnNotes(FilterReturnNotes event, Emitter<ReturnNotesState> emit) async {
    emit(ReturnNotesLoading());
    try {
      final allNotes = await DatabaseHelper.instance.getReturnNotes(
        status: event.status,
        startDate: event.dateFrom,
        endDate: event.dateTo,
      );
      final filteredNotes = allNotes.where((note) {
        if (event.clientId != null && event.clientId != 'all' && event.clientId!.isNotEmpty) {
          return note.customerId == event.clientId;
        }
        return true;
      }).toList();
      emit(ReturnNotesLoaded(filteredNotes));
    } catch (e) {
      emit(ReturnNotesError('Erreur de filtrage: $e'));
    }
  }

  Future<void> _onAddReturnNote(AddReturnNote event, Emitter<ReturnNotesState> emit) async {
    try {
      await DatabaseHelper.instance.insertReturnNote(event.note);
      add(const LoadReturnNotes());
    } catch (e) {
      emit(ReturnNotesError('Erreur d\'ajout: $e'));
    }
  }

  Future<void> _onUpdateReturnNote(UpdateReturnNote event, Emitter<ReturnNotesState> emit) async {
    try {
      await DatabaseHelper.instance.updateReturnNote(event.note);
      add(const LoadReturnNotes());
    } catch (e) {
      emit(ReturnNotesError('Erreur de mise a jour: $e'));
    }
  }

  Future<void> _onDeleteReturnNote(DeleteReturnNote event, Emitter<ReturnNotesState> emit) async {
    try {
      await DatabaseHelper.instance.deleteReturnNote(event.id);
      add(const LoadReturnNotes());
    } catch (e) {
      emit(ReturnNotesError('Erreur de suppression: $e'));
    }
  }
}
