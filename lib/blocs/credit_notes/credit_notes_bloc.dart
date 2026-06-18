import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/credit_note.dart';

abstract class CreditNotesEvent extends Equatable {
  const CreditNotesEvent();
  @override
  List<Object?> get props => [];
}

class LoadCreditNotes extends CreditNotesEvent {}

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
  const CreditNotesLoaded(this.creditNotes);
  @override
  List<Object?> get props => [creditNotes];
}

class CreditNotesError extends CreditNotesState {
  final String message;
  const CreditNotesError(this.message);
  @override
  List<Object?> get props => [message];
}

class CreditNotesBloc extends Bloc<CreditNotesEvent, CreditNotesState> {
  CreditNotesBloc() : super(CreditNotesInitial()) {
    on<LoadCreditNotes>(_onLoad);
    on<AddCreditNote>(_onAdd);
    on<UpdateCreditNote>(_onUpdate);
    on<DeleteCreditNote>(_onDelete);
  }

  Future<void> _onLoad(LoadCreditNotes event, Emitter<CreditNotesState> emit) async {
    emit(CreditNotesLoading());
    try {
      final creditNotes = await DatabaseHelper.instance.getCreditNotes();
      emit(CreditNotesLoaded(creditNotes));
    } catch (e) {
      emit(CreditNotesError(e.toString()));
    }
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
      await DatabaseHelper.instance.deleteCreditNote(event.id);
      add(LoadCreditNotes());
    } catch (e) {
      emit(CreditNotesError(e.toString()));
    }
  }
}
