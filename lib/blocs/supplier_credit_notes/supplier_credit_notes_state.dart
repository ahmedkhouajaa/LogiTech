import 'package:equatable/equatable.dart';
import '../../models/supplier_credit_note.dart';

abstract class SupplierCreditNotesState extends Equatable {
  const SupplierCreditNotesState();

  @override
  List<Object?> get props => [];
}

class SupplierCreditNotesInitial extends SupplierCreditNotesState {}

class SupplierCreditNotesLoading extends SupplierCreditNotesState {}

class SupplierCreditNotesLoaded extends SupplierCreditNotesState {
  final List<SupplierCreditNote> creditNotes;

  const SupplierCreditNotesLoaded(this.creditNotes);

  @override
  List<Object?> get props => [creditNotes];
}

class SupplierCreditNotesError extends SupplierCreditNotesState {
  final String message;

  const SupplierCreditNotesError(this.message);

  @override
  List<Object?> get props => [message];
}
