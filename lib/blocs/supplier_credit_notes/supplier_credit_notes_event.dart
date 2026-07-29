import 'package:equatable/equatable.dart';
import '../../models/supplier_credit_note.dart';

abstract class SupplierCreditNotesEvent extends Equatable {
  const SupplierCreditNotesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSupplierCreditNotes extends SupplierCreditNotesEvent {}

class LoadFirstSupplierCreditNotes extends SupplierCreditNotesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstSupplierCreditNotes({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class LoadNextSupplierCreditNotes extends SupplierCreditNotesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadNextSupplierCreditNotes({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class ResetSupplierCreditNotesPagination extends SupplierCreditNotesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const ResetSupplierCreditNotesPagination({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class AddSupplierCreditNote extends SupplierCreditNotesEvent {
  final SupplierCreditNote supplierCreditNote;

  const AddSupplierCreditNote(this.supplierCreditNote);

  @override
  List<Object?> get props => [supplierCreditNote];
}

class UpdateSupplierCreditNote extends SupplierCreditNotesEvent {
  final SupplierCreditNote supplierCreditNote;

  const UpdateSupplierCreditNote(this.supplierCreditNote);

  @override
  List<Object?> get props => [supplierCreditNote];
}

class DeleteSupplierCreditNote extends SupplierCreditNotesEvent {
  final String id;

  const DeleteSupplierCreditNote(this.id);

  @override
  List<Object?> get props => [id];
}

class FilterSupplierCreditNotes extends SupplierCreditNotesEvent {
  final String? supplierId;
  final String? status;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const FilterSupplierCreditNotes({
    this.supplierId,
    this.status,
    this.dateFrom,
    this.dateTo,
  });

  @override
  List<Object?> get props => [supplierId, status, dateFrom, dateTo];
}
