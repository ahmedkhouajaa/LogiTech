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
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const ReturnNotesLoaded(
    this.notes, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  ReturnNotesLoaded copyWith({
    List<ReturnNote>? notes,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ReturnNotesLoaded(
      notes ?? this.notes,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [notes, totalCount, hasMore, isLoadingMore];
}

class ReturnNotesError extends ReturnNotesState {
  final String message;
  const ReturnNotesError(this.message);
  @override
  List<Object?> get props => [message];
}
