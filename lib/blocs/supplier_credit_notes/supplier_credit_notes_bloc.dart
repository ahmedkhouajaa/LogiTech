import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import '../../models/supplier_credit_note.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';
import 'supplier_credit_notes_event.dart';
import 'supplier_credit_notes_state.dart';
import 'package:business_manager_pro/services/error_handler.dart';

class SupplierCreditNotesBloc extends Bloc<SupplierCreditNotesEvent, SupplierCreditNotesState> {
  static const int pageSize = 10;

  SupplierCreditNotesBloc() : super(SupplierCreditNotesInitial()) {
    on<LoadSupplierCreditNotes>(_onLoadSupplierCreditNotes);
    on<LoadFirstSupplierCreditNotes>(_onLoadFirstSupplierCreditNotes);
    on<LoadNextSupplierCreditNotes>(_onLoadNextSupplierCreditNotes);
    on<ResetSupplierCreditNotesPagination>(_onResetSupplierCreditNotesPagination);
    on<AddSupplierCreditNote>(_onAddSupplierCreditNote);
    on<UpdateSupplierCreditNote>(_onUpdateSupplierCreditNote);
    on<DeleteSupplierCreditNote>(_onDeleteSupplierCreditNote);
    on<FilterSupplierCreditNotes>(_onFilterSupplierCreditNotes);
  }

  Future<void> _onLoadSupplierCreditNotes(LoadSupplierCreditNotes event, Emitter<SupplierCreditNotesState> emit) async {
    await _onLoadFirstSupplierCreditNotes(const LoadFirstSupplierCreditNotes(), emit);
  }

  Future<void> _onLoadFirstSupplierCreditNotes(LoadFirstSupplierCreditNotes event, Emitter<SupplierCreditNotesState> emit) async {
    emit(SupplierCreditNotesLoading());
    try {
      FirestorePaginationService.instance.resetSupplierCreditNotesPagination();
      final notesFuture = FirestorePaginationService.instance.getFirstSupplierCreditNotes(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getSupplierCreditNotesCount(
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([notesFuture, countFuture]);
      final creditNotes = results[0] as List<SupplierCreditNote>;
      final totalCount = results[1] as int;

      emit(SupplierCreditNotesLoaded(
        creditNotes,
        totalCount: totalCount > creditNotes.length ? totalCount : creditNotes.length,
        hasMore: creditNotes.length >= pageSize,
      ));
    } catch (e) {
      emit(SupplierCreditNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadNextSupplierCreditNotes(LoadNextSupplierCreditNotes event, Emitter<SupplierCreditNotesState> emit) async {
    final currentState = state;
    if (currentState is! SupplierCreditNotesLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextNotes = await FirestorePaginationService.instance.getNextSupplierCreditNotes(
        pageSize: pageSize,
        currentOffset: currentState.creditNotes.length,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextNotes.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<SupplierCreditNote>.from(currentState.creditNotes)..addAll(nextNotes);
        emit(SupplierCreditNotesLoaded(
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

  Future<void> _onResetSupplierCreditNotesPagination(ResetSupplierCreditNotesPagination event, Emitter<SupplierCreditNotesState> emit) async {
    FirestorePaginationService.instance.resetSupplierCreditNotesPagination();
    add(LoadFirstSupplierCreditNotes(
      searchQuery: event.searchQuery,
      supplierId: event.supplierId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAddSupplierCreditNote(AddSupplierCreditNote event, Emitter<SupplierCreditNotesState> emit) async {
    try {
      await FirestoreRepository.instance.saveSupplierCreditNote(event.supplierCreditNote);
      add(const LoadFirstSupplierCreditNotes());
    } catch (e) {
      emit(SupplierCreditNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateSupplierCreditNote(UpdateSupplierCreditNote event, Emitter<SupplierCreditNotesState> emit) async {
    try {
      await FirestoreRepository.instance.saveSupplierCreditNote(event.supplierCreditNote);
      add(const LoadFirstSupplierCreditNotes());
    } catch (e) {
      emit(SupplierCreditNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteSupplierCreditNote(DeleteSupplierCreditNote event, Emitter<SupplierCreditNotesState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('supplier_credit_notes', event.id);
      add(const LoadFirstSupplierCreditNotes());
    } catch (e) {
      emit(SupplierCreditNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onFilterSupplierCreditNotes(FilterSupplierCreditNotes event, Emitter<SupplierCreditNotesState> emit) async {
    add(LoadFirstSupplierCreditNotes(
      supplierId: event.supplierId,
      status: event.status,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
    ));
  }
}
