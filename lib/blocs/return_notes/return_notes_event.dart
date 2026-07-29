import 'package:equatable/equatable.dart';
import '../../models/return_note.dart';

abstract class ReturnNotesEvent extends Equatable {
  const ReturnNotesEvent();
  @override
  List<Object?> get props => [];
}

class LoadReturnNotes extends ReturnNotesEvent {
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  const LoadReturnNotes({this.status, this.startDate, this.endDate});
  @override
  List<Object?> get props => [status, startDate, endDate];
}

class LoadFirstReturnNotes extends ReturnNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstReturnNotes({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class LoadNextReturnNotes extends ReturnNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadNextReturnNotes({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class ResetReturnNotesPagination extends ReturnNotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const ResetReturnNotesPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class FilterReturnNotes extends ReturnNotesEvent {
  final String? clientId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const FilterReturnNotes({this.clientId, this.dateFrom, this.dateTo, this.status});
  @override
  List<Object?> get props => [clientId, dateFrom, dateTo, status];
}

class AddReturnNote extends ReturnNotesEvent {
  final ReturnNote note;
  const AddReturnNote(this.note);
  @override
  List<Object?> get props => [note];
}

class UpdateReturnNote extends ReturnNotesEvent {
  final ReturnNote note;
  const UpdateReturnNote(this.note);
  @override
  List<Object?> get props => [note];
}

class DeleteReturnNote extends ReturnNotesEvent {
  final String id;
  const DeleteReturnNote(this.id);
  @override
  List<Object?> get props => [id];
}
