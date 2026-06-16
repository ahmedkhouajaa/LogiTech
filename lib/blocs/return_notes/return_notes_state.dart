import 'package:equatable/equatable.dart';
import '../../models/return_note.dart';

abstract class ReturnNotesState extends Equatable {
  const ReturnNotesState();
  @override
  List<Object?> get props => [];
}

class ReturnNotesInitial extends ReturnNotesState {}

class ReturnNotesLoading extends ReturnNotesState {}

class ReturnNotesLoaded extends ReturnNotesState {
  final List<ReturnNote> notes;
  const ReturnNotesLoaded(this.notes);
  @override
  List<Object?> get props => [notes];
}

class ReturnNotesError extends ReturnNotesState {
  final String message;
  const ReturnNotesError(this.message);
  @override
  List<Object?> get props => [message];
}
