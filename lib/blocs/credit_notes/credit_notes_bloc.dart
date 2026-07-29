import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/credit_note.dart';
import '../../services/firestore_pagination_service.dart';

abstract class CreditNotesEvent extends Equatable {
  const CreditNotesEvent();
  @override
  List<Object?> get props => [];
}

class LoadCreditNotes extends CreditNotesEvent {}

class LoadFirstCreditNotes extends CreditNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstCreditNotes({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class LoadNextCreditNotes extends CreditNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadNextCreditNotes({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class ResetCreditNotesPagination extends CreditNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const ResetCreditNotesPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class AddCreditNote extends CreditNotesEvent {
  final CreditNote creditNote;
  const AddCreditNote(this.creditNote);
  @override
  List<Object?> get props => [creditNote];
}

class UpdateCreditNote extends CreditNotesEvent {
  final CreditNote creditNote;
  const UpdateCreditNote(this.creditNote);
  @override
  List<Object?> get props => [creditNote];
}

class DeleteCreditNote extends CreditNotesEvent {
  final String id;
  const DeleteCreditNote(this.id);
  @override
  List<Object?> get props => [id];
}

abstract class CreditNotesState extends Equatable {
  const CreditNotesState();
  @override
  List<Object?> get props => [];
}

class CreditNotesInitial extends CreditNotesState {}

class CreditNotesLoading extends CreditNotesState {}

class CreditNotesLoaded extends CreditNotesState {
  final List<CreditNote> creditNotes;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const CreditNotesLoaded(
    this.creditNotes, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  CreditNotesLoaded copyWith({
    List<CreditNote>? creditNotes,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CreditNotesLoaded(
      creditNotes ?? this.creditNotes,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [creditNotes, totalCount, hasMore, isLoadingMore];
}

class CreditNotesError extends CreditNotesState {
  final String message;
  const CreditNotesError(this.message);
  @override
  List<Object?> get props => [message];
}

class CreditNotesBloc extends Bloc<CreditNotesEvent, CreditNotesState> {
  static const int pageSize = 10;

  CreditNotesBloc() : super(CreditNotesInitial()) {
    on<LoadCreditNotes>(_onLoad);
    on<LoadFirstCreditNotes>(_onLoadFirstCreditNotes);
    on<LoadNextCreditNotes>(_onLoadNextCreditNotes);
    on<ResetCreditNotesPagination>(_onResetCreditNotesPagination);
    on<AddCreditNote>(_onAdd);
    on<UpdateCreditNote>(_onUpdate);
    on<DeleteCreditNote>(_onDelete);
  }

  Future<void> _onLoad(LoadCreditNotes event, Emitter<CreditNotesState> emit) async {
    emit(CreditNotesLoading());
    try {
      final creditNotes = await DatabaseHelper.instance.getCreditNotes();
      emit(CreditNotesLoaded(creditNotes, totalCount: creditNotes.length));
    } catch (e) {
      emit(CreditNotesError(e.toString()));
    }
  }

  Future<void> _onLoadFirstCreditNotes(LoadFirstCreditNotes event, Emitter<CreditNotesState> emit) async {
    emit(CreditNotesLoading());
    try {
      FirestorePaginationService.instance.resetCreditNotesPagination();
      final notesFuture = FirestorePaginationService.instance.getFirstCreditNotes(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getCreditNotesCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([notesFuture, countFuture]);
      final creditNotes = results[0] as List<CreditNote>;
      final totalCount = results[1] as int;

      emit(CreditNotesLoaded(
        creditNotes,
        totalCount: totalCount > creditNotes.length ? totalCount : creditNotes.length,
        hasMore: creditNotes.length >= pageSize,
      ));
    } catch (e) {
      emit(CreditNotesError(e.toString()));
    }
  }

  Future<void> _onLoadNextCreditNotes(LoadNextCreditNotes event, Emitter<CreditNotesState> emit) async {
    final currentState = state;
    if (currentState is! CreditNotesLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextNotes = await FirestorePaginationService.instance.getNextCreditNotes(
        pageSize: pageSize,
        currentOffset: currentState.creditNotes.length,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextNotes.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<CreditNote>.from(currentState.creditNotes)..addAll(nextNotes);
        emit(CreditNotesLoaded(
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

  Future<void> _onResetCreditNotesPagination(ResetCreditNotesPagination event, Emitter<CreditNotesState> emit) async {
    FirestorePaginationService.instance.resetCreditNotesPagination();
    add(LoadFirstCreditNotes(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAdd(AddCreditNote event, Emitter<CreditNotesState> emit) async {
    try {
      await DatabaseHelper.instance.insertCreditNote(event.creditNote);
      add(LoadCreditNotes());
    } catch (e) {
      emit(CreditNotesError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateCreditNote event, Emitter<CreditNotesState> emit) async {
    try {
      await DatabaseHelper.instance.updateCreditNote(event.creditNote);
      add(LoadCreditNotes());
    } catch (e) {
      emit(CreditNotesError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteCreditNote event, Emitter<CreditNotesState> emit) async {
    try {
      await DatabaseHelper.instance.softDelete('credit_notes', event.id);
      add(LoadCreditNotes());
    } catch (e) {
      emit(CreditNotesError(e.toString()));
    }
  }
}
