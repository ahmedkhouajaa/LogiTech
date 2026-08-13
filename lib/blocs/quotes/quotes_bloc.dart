import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/quote.dart';
import '../../models/quote_status_history.dart';
import '../../utils/constants.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';
import 'package:business_manager_pro/services/error_handler.dart';

abstract class QuotesEvent extends Equatable { const QuotesEvent(); @override List<Object?> get props => []; }
class LoadQuotes extends QuotesEvent {}

class LoadFirstDevis extends QuotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstDevis({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class LoadNextDevis extends QuotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadNextDevis({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class ResetDevisPagination extends QuotesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const ResetDevisPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class AddQuote extends QuotesEvent { final Quote quote; const AddQuote(this.quote); @override List<Object?> get props => [quote]; }
class UpdateQuote extends QuotesEvent { final Quote quote; const UpdateQuote(this.quote); @override List<Object?> get props => [quote]; }
class UpdateQuoteStatus extends QuotesEvent {
  final String id;
  final DocumentStatus oldStatus;
  final DocumentStatus newStatus;
  final String? changedBy;
  final String? notes;
  const UpdateQuoteStatus(
    this.id,
    this.oldStatus,
    this.newStatus, [
    this.changedBy,
    this.notes,
  ]);
  @override List<Object?> get props => [id, oldStatus, newStatus, changedBy, notes];
}
class DeleteQuote extends QuotesEvent { final String id; const DeleteQuote(this.id); @override List<Object?> get props => [id]; }

// ── States ─────────────────────────────────────────────────────────
abstract class QuotesState extends Equatable { const QuotesState(); @override List<Object?> get props => []; }
class QuotesInitial extends QuotesState {}
class QuotesLoading extends QuotesState {}
class QuotesLoaded extends QuotesState {
  final List<Quote> quotes;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const QuotesLoaded(
    this.quotes, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  QuotesLoaded copyWith({
    List<Quote>? quotes,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return QuotesLoaded(
      quotes ?? this.quotes,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [quotes, totalCount, hasMore, isLoadingMore];
}

class QuotesError extends QuotesState { final String message; const QuotesError(this.message); @override List<Object?> get props => [message]; }

// ── BLoC ───────────────────────────────────────────────────────────
class QuotesBloc extends Bloc<QuotesEvent, QuotesState> {
  static const int pageSize = 20;

  QuotesBloc() : super(QuotesInitial()) {
    on<LoadQuotes>(_onLoad);
    on<LoadFirstDevis>(_onLoadFirstDevis);
    on<LoadNextDevis>(_onLoadNextDevis);
    on<ResetDevisPagination>(_onResetDevisPagination);
    on<AddQuote>(_onAdd);
    on<UpdateQuote>(_onUpdate);
    on<UpdateQuoteStatus>(_onUpdateStatus);
    on<DeleteQuote>(_onDelete);
  }

  Future<void> _onLoad(LoadQuotes event, Emitter<QuotesState> emit) async {
    add(const LoadFirstDevis());
  }

  Future<void> _onLoadFirstDevis(LoadFirstDevis event, Emitter<QuotesState> emit) async {
    emit(QuotesLoading());
    try {
      FirestorePaginationService.instance.resetDevisPagination();
      final quotesFuture = FirestorePaginationService.instance.getFirstDevis(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getDevisCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([quotesFuture, countFuture]);
      final quotes = results[0] as List<Quote>;
      final totalCount = results[1] as int;

      emit(QuotesLoaded(
        quotes,
        totalCount: totalCount > quotes.length ? totalCount : quotes.length,
        hasMore: quotes.length >= pageSize,
      ));
    } catch (e) {
      emit(QuotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadNextDevis(LoadNextDevis event, Emitter<QuotesState> emit) async {
    final currentState = state;
    if (currentState is! QuotesLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextQuotes = await FirestorePaginationService.instance.getNextDevis(
        pageSize: pageSize,
        currentOffset: currentState.quotes.length,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextQuotes.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<Quote>.from(currentState.quotes)..addAll(nextQuotes);
        emit(QuotesLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextQuotes.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetDevisPagination(ResetDevisPagination event, Emitter<QuotesState> emit) async {
    FirestorePaginationService.instance.resetDevisPagination();
    add(LoadFirstDevis(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAdd(AddQuote event, Emitter<QuotesState> emit) async {
    try {
      await FirestoreRepository.instance.saveQuote(event.quote);
      add(const LoadFirstDevis());
    } catch (e) {
      emit(QuotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdate(UpdateQuote event, Emitter<QuotesState> emit) async {
    try {
      await FirestoreRepository.instance.saveQuote(event.quote);
      add(const LoadFirstDevis());
    } catch (e) {
      emit(QuotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateStatus(UpdateQuoteStatus event, Emitter<QuotesState> emit) async {
    try {
      await FirestoreRepository.instance.updateDocument('quotes', event.id, {'status': event.newStatus.name});
      final history = QuoteStatusHistory(
        id: DatabaseHelper.instance.newId,
        quoteId: event.id,
        oldStatus: event.oldStatus.name,
        newStatus: event.newStatus.name,
        changedBy: event.changedBy ?? 'System',
        notes: event.notes,
        changedAt: DateTime.now(),
      );
      await FirestoreRepository.instance.saveDocument('quote_status_history', history.id, history.toMap());
      add(const LoadFirstDevis());
    } catch (e) {
      emit(QuotesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDelete(DeleteQuote event, Emitter<QuotesState> emit) async {
    final currentState = state;
    if (currentState is QuotesLoaded) {
      final updatedList = currentState.quotes.where((q) => q.id != event.id).toList();
      emit(currentState.copyWith(
        quotes: updatedList,
        totalCount: currentState.totalCount > 0 ? currentState.totalCount - 1 : 0,
      ));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('quotes', event.id);
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (currentState is QuotesLoaded) {
        add(const LoadFirstDevis());
      } else {
        add(const LoadFirstDevis());
      }
    } catch (e) {
      emit(QuotesError(ErrorHandler.parseError(e)));
    }
  }
}
