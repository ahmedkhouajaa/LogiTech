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
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const SupplierCreditNotesLoaded(
    this.creditNotes, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  SupplierCreditNotesLoaded copyWith({
    List<SupplierCreditNote>? creditNotes,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SupplierCreditNotesLoaded(
      creditNotes ?? this.creditNotes,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [creditNotes, totalCount, hasMore, isLoadingMore];
}

class SupplierCreditNotesError extends SupplierCreditNotesState {
  final String message;

  const SupplierCreditNotesError(this.message);

  @override
  List<Object?> get props => [message];
}
