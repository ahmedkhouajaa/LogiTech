import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import '../../models/return_note.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';
import 'return_notes_event.dart';
import 'return_notes_state.dart';
import 'package:business_manager_pro/services/error_handler.dart';

class ReturnNotesBloc extends Bloc<ReturnNotesEvent, ReturnNotesState> {
  static const int pageSize = 10;

  ReturnNotesBloc() : super(ReturnNotesInitial()) {
    on<LoadReturnNotes>(_onLoadReturnNotes);
    on<LoadFirstReturnNotes>(_onLoadFirstReturnNotes);
    on<LoadNextReturnNotes>(_onLoadNextReturnNotes);
    on<ResetReturnNotesPagination>(_onResetReturnNotesPagination);
    on<AddReturnNote>(_onAddReturnNote);
    on<UpdateReturnNote>(_onUpdateReturnNote);
    on<DeleteReturnNote>(_onDeleteReturnNote);
    on<FilterReturnNotes>(_onFilterReturnNotes);
  }

  Future<void> _onLoadReturnNotes(LoadReturnNotes event, Emitter<ReturnNotesState> emit) async {
    await _onLoadFirstReturnNotes(LoadFirstReturnNotes(), emit);
  }

  Future<void> _onLoadFirstReturnNotes(LoadFirstReturnNotes event, Emitter<ReturnNotesState> emit) async {
    emit(ReturnNotesLoading());
    try {
      FirestorePaginationService.instance.resetReturnNotesPagination();
      final notesFuture = FirestorePaginationService.instance.getFirstReturnNotes(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getReturnNotesCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([notesFuture, countFuture]);
      final notes = results[0] as List<ReturnNote>;
      final totalCount = results[1] as int;

      emit(ReturnNotesLoaded(
        notes,
        totalCount: totalCount > notes.length ? totalCount : notes.length,
        hasMore: notes.length >= pageSize,
      ));
    } catch (e) {
      emit(ReturnNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadNextReturnNotes(LoadNextReturnNotes event, Emitter<ReturnNotesState> emit) async {
    final currentState = state;
    if (currentState is! ReturnNotesLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextNotes = await FirestorePaginationService.instance.getNextReturnNotes(
        pageSize: pageSize,
        currentOffset: currentState.notes.length,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextNotes.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<ReturnNote>.from(currentState.notes)..addAll(nextNotes);
        emit(ReturnNotesLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextNotes.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetReturnNotesPagination(ResetReturnNotesPagination event, Emitter<ReturnNotesState> emit) async {
    FirestorePaginationService.instance.resetReturnNotesPagination();
    add(LoadFirstReturnNotes(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onFilterReturnNotes(FilterReturnNotes event, Emitter<ReturnNotesState> emit) async {
    add(LoadFirstReturnNotes(
      customerId: event.clientId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAddReturnNote(AddReturnNote event, Emitter<ReturnNotesState> emit) async {
    try {
      await FirestoreRepository.instance.saveReturnNote(event.note);
      add(LoadFirstReturnNotes());
    } catch (e) {
      emit(ReturnNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateReturnNote(UpdateReturnNote event, Emitter<ReturnNotesState> emit) async {
    try {
      await FirestoreRepository.instance.saveReturnNote(event.note);
      add(LoadFirstReturnNotes());
    } catch (e) {
      emit(ReturnNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteReturnNote(DeleteReturnNote event, Emitter<ReturnNotesState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('return_notes', event.id);
      add(LoadFirstReturnNotes());
    } catch (e) {
      emit(ReturnNotesError(ErrorHandler.parseError(e)));
    }
  }
}
