import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/delivery_note.dart';
import '../../database/database_helper.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class DeliveryNotesEvent {}

class LoadDeliveryNotes extends DeliveryNotesEvent {}

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
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  DeliveryNotesLoaded(
    this.notes, {
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });
}

class DeliveryNotesError extends DeliveryNotesState {
  final String message;
  DeliveryNotesError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class DeliveryNotesBloc extends Bloc<DeliveryNotesEvent, DeliveryNotesState> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  DeliveryNotesBloc() : super(DeliveryNotesInitial()) {
    on<LoadDeliveryNotes>(_onLoad);
    on<AddDeliveryNote>(_onAdd);
    on<UpdateDeliveryNote>(_onUpdate);
    on<DeleteDeliveryNote>(_onDelete);
    on<FilterDeliveryNotes>(_onFilter);
  }

  Future<void> _onLoad(LoadDeliveryNotes event, Emitter<DeliveryNotesState> emit) async {
    emit(DeliveryNotesLoading());
    try {
      final notes = await _db.getDeliveryNotes();
      emit(DeliveryNotesLoaded(notes));
    } catch (e) {
      emit(DeliveryNotesError(e.toString()));
    }
  }

  Future<void> _onAdd(AddDeliveryNote event, Emitter<DeliveryNotesState> emit) async {
    try {
      await _db.insertDeliveryNote(event.note);
      add(LoadDeliveryNotes());
    } catch (e) {
      emit(DeliveryNotesError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateDeliveryNote event, Emitter<DeliveryNotesState> emit) async {
    try {
      await _db.updateDeliveryNote(event.note);
      add(LoadDeliveryNotes());
    } catch (e) {
      emit(DeliveryNotesError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteDeliveryNote event, Emitter<DeliveryNotesState> emit) async {
    try {
      await _db.softDeleteDeliveryNote(event.noteId);
      add(LoadDeliveryNotes());
    } catch (e) {
      emit(DeliveryNotesError(e.toString()));
    }
  }

  Future<void> _onFilter(FilterDeliveryNotes event, Emitter<DeliveryNotesState> emit) async {
    emit(DeliveryNotesLoading());
    try {
      final allNotes = await _db.getDeliveryNotes(
        status: event.status,
        startDate: event.dateFrom,
        endDate: event.dateTo,
      );

      final filtered = allNotes.where((n) {
        if (event.clientId != null && event.clientId!.isNotEmpty && event.clientId != 'all') {
          return n.customerId == event.clientId;
        }
        return true;
      }).toList();

      emit(DeliveryNotesLoaded(
        filtered,
        clientFilter: event.clientId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
        statusFilter: event.status,
      ));
    } catch (e) {
      emit(DeliveryNotesError(e.toString()));
    }
  }
}
