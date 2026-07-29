import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/retenue_source_vente.dart';
import '../../services/firestore_pagination_service.dart';

// Events
abstract class RetenueSourceVenteEvent extends Equatable {
  const RetenueSourceVenteEvent();

  @override
  List<Object?> get props => [];
}

class LoadFirstRetenueSourceVentes extends RetenueSourceVenteEvent {
  final String? searchQuery;
  final String statusFilter;
  final int pageSize;
  final bool isSales;

  const LoadFirstRetenueSourceVentes({
    this.searchQuery,
    this.statusFilter = 'Tous',
    this.pageSize = 10,
    this.isSales = true,
  });

  @override
  List<Object?> get props => [searchQuery, statusFilter, pageSize, isSales];
}

class LoadNextRetenueSourceVentes extends RetenueSourceVenteEvent {
  final String? searchQuery;
  final String statusFilter;
  final int pageSize;
  final bool isSales;

  const LoadNextRetenueSourceVentes({
    this.searchQuery,
    this.statusFilter = 'Tous',
    this.pageSize = 10,
    this.isSales = true,
  });

  @override
  List<Object?> get props => [searchQuery, statusFilter, pageSize, isSales];
}

class ResetRetenueSourceVentesPagination extends RetenueSourceVenteEvent {
  final String? searchQuery;
  final String statusFilter;
  final bool isSales;
  
  const ResetRetenueSourceVentesPagination({this.searchQuery, this.statusFilter = 'Tous', this.isSales = true});

  @override
  List<Object?> get props => [searchQuery, statusFilter, isSales];
}

// States
abstract class RetenueSourceVenteState extends Equatable {
  const RetenueSourceVenteState();
  
  @override
  List<Object?> get props => [];
}

class RetenueSourceVenteInitial extends RetenueSourceVenteState {}
class RetenueSourceVenteLoading extends RetenueSourceVenteState {}

class RetenueSourceVenteLoaded extends RetenueSourceVenteState {
  final List<RetenueSourceVente> retenues;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String activeStatusFilter;
  final String searchQuery;

  const RetenueSourceVenteLoaded({
    required this.retenues,
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.activeStatusFilter = 'Tous',
    this.searchQuery = '',
  });

  RetenueSourceVenteLoaded copyWith({
    List<RetenueSourceVente>? retenues,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? activeStatusFilter,
    String? searchQuery,
  }) {
    return RetenueSourceVenteLoaded(
      retenues: retenues ?? this.retenues,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      activeStatusFilter: activeStatusFilter ?? this.activeStatusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        retenues,
        totalCount,
        hasMore,
        isLoadingMore,
        activeStatusFilter,
        searchQuery,
      ];
}

class RetenueSourceVenteError extends RetenueSourceVenteState {
  final String message;
  const RetenueSourceVenteError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class RetenueSourceVenteBloc extends Bloc<RetenueSourceVenteEvent, RetenueSourceVenteState> {
  RetenueSourceVenteBloc() : super(RetenueSourceVenteInitial()) {
    on<LoadFirstRetenueSourceVentes>(_onLoadFirst);
    on<LoadNextRetenueSourceVentes>(_onLoadNext);
    on<ResetRetenueSourceVentesPagination>(_onResetPagination);
  }

  Future<void> _onLoadFirst(
    LoadFirstRetenueSourceVentes event,
    Emitter<RetenueSourceVenteState> emit,
  ) async {
    emit(RetenueSourceVenteLoading());
    try {
      final count = await FirestorePaginationService.instance.getRetenueSourceVentesCount(
        searchQuery: event.searchQuery,
        statusFilter: event.statusFilter,
        isSales: event.isSales,
      );

      final items = await FirestorePaginationService.instance.getFirstRetenueSourceVentes(
        pageSize: event.pageSize,
        searchQuery: event.searchQuery,
        statusFilter: event.statusFilter,
        isSales: event.isSales,
      );

      emit(RetenueSourceVenteLoaded(
        retenues: items,
        totalCount: count,
        hasMore: items.length == event.pageSize,
        isLoadingMore: false,
        activeStatusFilter: event.statusFilter,
        searchQuery: event.searchQuery ?? '',
      ));
    } catch (e) {
      emit(RetenueSourceVenteError("Erreur lors du chargement des retenues à la source"));
    }
  }

  Future<void> _onLoadNext(
    LoadNextRetenueSourceVentes event,
    Emitter<RetenueSourceVenteState> emit,
  ) async {
    final currentState = state;
    if (currentState is RetenueSourceVenteLoaded && currentState.hasMore && !currentState.isLoadingMore) {
      emit(currentState.copyWith(isLoadingMore: true));
      try {
        final newItems = await FirestorePaginationService.instance.getNextRetenueSourceVentes(
          pageSize: event.pageSize,
          searchQuery: event.searchQuery,
          statusFilter: event.statusFilter,
          isSales: event.isSales,
        );

        emit(currentState.copyWith(
          retenues: [...currentState.retenues, ...newItems],
          hasMore: newItems.length == event.pageSize,
          isLoadingMore: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> _onResetPagination(
    ResetRetenueSourceVentesPagination event,
    Emitter<RetenueSourceVenteState> emit,
  ) async {
    FirestorePaginationService.instance.resetRetenueSourceVentesPagination();
    add(LoadFirstRetenueSourceVentes(
      searchQuery: event.searchQuery,
      statusFilter: event.statusFilter,
      isSales: event.isSales,
    ));
  }
}
