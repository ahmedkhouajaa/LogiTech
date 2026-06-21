import 'package:equatable/equatable.dart';
import '../../models/supplier_credit_note.dart';

abstract class SupplierCreditNotesEvent extends Equatable {
  const SupplierCreditNotesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSupplierCreditNotes extends SupplierCreditNotesEvent {}

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
