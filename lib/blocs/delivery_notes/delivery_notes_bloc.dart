import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/delivery_note.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';
import 'package:business_manager_pro/services/error_handler.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class DeliveryNotesEvent { const DeliveryNotesEvent(); }

class LoadDeliveryNotes extends DeliveryNotesEvent {}

class LoadFirstDeliveryNotes extends DeliveryNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstDeliveryNotes({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextDeliveryNotes extends DeliveryNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextDeliveryNotes({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetDeliveryNotesPagination extends DeliveryNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetDeliveryNotesPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class AddDeliveryNote extends DeliveryNotesEvent {
  final DeliveryNote note;
  AddDeliveryNote(this.note);
}

class UpdateDeliveryNote extends DeliveryNotesEvent {
  final DeliveryNote note;
  UpdateDeliveryNote(this.note);
}

class DeleteDeliveryNote extends DeliveryNotesEvent {
  final String noteId;
  DeleteDeliveryNote(this.noteId);
}

class FilterDeliveryNotes extends DeliveryNotesEvent {
  final String? clientId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;
  FilterDeliveryNotes({this.clientId, this.dateFrom, this.dateTo, this.status});
}

// ─── States ──────────────────────────────────────────────────────
abstract class DeliveryNotesState {}

class DeliveryNotesInitial extends DeliveryNotesState {}

class DeliveryNotesLoading extends DeliveryNotesState {}

class DeliveryNotesLoaded extends DeliveryNotesState {
  final List<DeliveryNote> notes;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  DeliveryNotesLoaded(
    this.notes, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });

  DeliveryNotesLoaded copyWith({
    List<DeliveryNote>? notes,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? clientFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    String? statusFilter,
  }) {
    return DeliveryNotesLoaded(
      notes ?? this.notes,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      clientFilter: clientFilter ?? this.clientFilter,
      dateFromFilter: dateFromFilter ?? this.dateFromFilter,
      dateToFilter: dateToFilter ?? this.dateToFilter,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class DeliveryNotesError extends DeliveryNotesState {
  final String message;
  DeliveryNotesError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class DeliveryNotesBloc extends Bloc<DeliveryNotesEvent, DeliveryNotesState> {
  static const int pageSize = 10;
  final DatabaseHelper _db = DatabaseHelper.instance;

  DeliveryNotesBloc() : super(DeliveryNotesInitial()) {
    on<LoadDeliveryNotes>(_onLoad);
    on<LoadFirstDeliveryNotes>(_onLoadFirstDeliveryNotes);
    on<LoadNextDeliveryNotes>(_onLoadNextDeliveryNotes);
    on<ResetDeliveryNotesPagination>(_onResetDeliveryNotesPagination);
    on<AddDeliveryNote>(_onAdd);
    on<UpdateDeliveryNote>(_onUpdate);
    on<DeleteDeliveryNote>(_onDelete);
    on<FilterDeliveryNotes>(_onFilter);
  }

  Future<void> _onLoad(LoadDeliveryNotes event, Emitter<DeliveryNotesState> emit) async {
    emit(DeliveryNotesLoading());
    try {
      final notes = await _db.getDeliveryNotes();
      emit(DeliveryNotesLoaded(notes, totalCount: notes.length));
    } catch (e) {
      emit(DeliveryNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadFirstDeliveryNotes(LoadFirstDeliveryNotes event, Emitter<DeliveryNotesState> emit) async {
    emit(DeliveryNotesLoading());
    try {
      FirestorePaginationService.instance.resetDeliveryNotesPagination();
      final notesFuture = FirestorePaginationService.instance.getFirstDeliveryNotes(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getDeliveryNotesCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([notesFuture, countFuture]);
      final notes = results[0] as List<DeliveryNote>;
      final totalCount = results[1] as int;

      emit(DeliveryNotesLoaded(
        notes,
        totalCount: totalCount > notes.length ? totalCount : notes.length,
        hasMore: notes.length >= pageSize,
      ));
    } catch (e) {
      emit(DeliveryNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadNextDeliveryNotes(LoadNextDeliveryNotes event, Emitter<DeliveryNotesState> emit) async {
    final currentState = state;
    if (currentState is! DeliveryNotesLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextNotes = await FirestorePaginationService.instance.getNextDeliveryNotes(
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
        final updatedList = List<DeliveryNote>.from(currentState.notes)..addAll(nextNotes);
        emit(DeliveryNotesLoaded(
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

  Future<void> _onResetDeliveryNotesPagination(ResetDeliveryNotesPagination event, Emitter<DeliveryNotesState> emit) async {
    FirestorePaginationService.instance.resetDeliveryNotesPagination();
    add(LoadFirstDeliveryNotes(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAdd(AddDeliveryNote event, Emitter<DeliveryNotesState> emit) async {
    try {
      await FirestoreRepository.instance.saveDeliveryNote(event.note);
      add(const LoadFirstDeliveryNotes());
    } catch (e) {
      emit(DeliveryNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdate(UpdateDeliveryNote event, Emitter<DeliveryNotesState> emit) async {
    try {
      await FirestoreRepository.instance.saveDeliveryNote(event.note);
      add(const LoadFirstDeliveryNotes());
    } catch (e) {
      emit(DeliveryNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDelete(DeleteDeliveryNote event, Emitter<DeliveryNotesState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('delivery_notes', event.noteId);
      add(const LoadFirstDeliveryNotes());
    } catch (e) {
      emit(DeliveryNotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onFilter(FilterDeliveryNotes event, Emitter<DeliveryNotesState> emit) async {
    try {
      final allNotes = await _db.getDeliveryNotes(
        status: event.status,
        startDate: event.dateFrom,
        endDate: event.dateTo,
      );

      var filtered = allNotes;
      if (event.clientId != null && event.clientId!.isNotEmpty) {
        filtered = filtered.where((n) => n.customerId == event.clientId).toList();
      }

      emit(DeliveryNotesLoaded(
        filtered,
        clientFilter: event.clientId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
        statusFilter: event.status,
      ));
    } catch (e) {
      emit(DeliveryNotesError(ErrorHandler.parseError(e)));
    }
  }
}
