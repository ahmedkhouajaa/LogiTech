import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/purchase_invoice.dart';
import '../../utils/constants.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';

abstract class PurchaseInvoicesEvent extends Equatable {
  const PurchaseInvoicesEvent();
  @override
  List<Object?> get props => [];
}
class LoadPurchaseInvoices extends PurchaseInvoicesEvent {}

class LoadFirstPurchaseInvoices extends PurchaseInvoicesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstPurchaseInvoices({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class LoadNextPurchaseInvoices extends PurchaseInvoicesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadNextPurchaseInvoices({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class ResetPurchaseInvoicesPagination extends PurchaseInvoicesEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const ResetPurchaseInvoicesPagination({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class AddPurchaseInvoice extends PurchaseInvoicesEvent {
  final PurchaseInvoice purchaseInvoice;
  const AddPurchaseInvoice(this.purchaseInvoice);
  @override
  List<Object?> get props => [purchaseInvoice];
}
class UpdatePurchaseInvoice extends PurchaseInvoicesEvent {
  final PurchaseInvoice purchaseInvoice;
  const UpdatePurchaseInvoice(this.purchaseInvoice);
  @override
  List<Object?> get props => [purchaseInvoice];
}
class DeletePurchaseInvoice extends PurchaseInvoicesEvent {
  final String id;
  const DeletePurchaseInvoice(this.id);
  @override
  List<Object?> get props => [id];
}
class MarkPurchaseInvoicePaid extends PurchaseInvoicesEvent {
  final String id;
  final double amountPaid;
  const MarkPurchaseInvoicePaid(this.id, this.amountPaid);
  @override
  List<Object?> get props => [id, amountPaid];
}
class FilterPurchaseInvoicesByStatus extends PurchaseInvoicesEvent {
  final InvoiceStatus? status;
  const FilterPurchaseInvoicesByStatus(this.status);
  @override
  List<Object?> get props => [status];
}
class FilterPurchaseInvoices extends PurchaseInvoicesEvent {
  final String? clientId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final InvoiceStatus? status;
  const FilterPurchaseInvoices({this.clientId, this.dateFrom, this.dateTo, this.status});
  @override
  List<Object?> get props => [clientId, dateFrom, dateTo, status];
}

abstract class PurchaseInvoicesState extends Equatable {
  const PurchaseInvoicesState();
  @override
  List<Object?> get props => [];
}
class PurchaseInvoicesInitial extends PurchaseInvoicesState {}
class PurchaseInvoicesLoading extends PurchaseInvoicesState {}
class PurchaseInvoicesLoaded extends PurchaseInvoicesState {
  final List<PurchaseInvoice> purchaseInvoices;
  final List<PurchaseInvoice> filteredPurchaseInvoices;
  final InvoiceStatus? activeFilter;
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const PurchaseInvoicesLoaded(
    this.purchaseInvoices,
    this.filteredPurchaseInvoices, {
    this.activeFilter,
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  PurchaseInvoicesLoaded copyWith({
    List<PurchaseInvoice>? purchaseInvoices,
    List<PurchaseInvoice>? filteredPurchaseInvoices,
    InvoiceStatus? activeFilter,
    String? clientFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PurchaseInvoicesLoaded(
      purchaseInvoices ?? this.purchaseInvoices,
      filteredPurchaseInvoices ?? this.filteredPurchaseInvoices,
      activeFilter: activeFilter ?? this.activeFilter,
      clientFilter: clientFilter ?? this.clientFilter,
      dateFromFilter: dateFromFilter ?? this.dateFromFilter,
      dateToFilter: dateToFilter ?? this.dateToFilter,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    purchaseInvoices,
    filteredPurchaseInvoices,
    activeFilter,
    clientFilter,
    dateFromFilter,
    dateToFilter,
    totalCount,
    hasMore,
    isLoadingMore,
  ];
}
class PurchaseInvoicesError extends PurchaseInvoicesState {
  final String message;
  const PurchaseInvoicesError(this.message);
  @override
  List<Object?> get props => [message];
}

class PurchaseInvoicesBloc extends Bloc<PurchaseInvoicesEvent, PurchaseInvoicesState> {
  static const int pageSize = 10;

  PurchaseInvoicesBloc() : super(PurchaseInvoicesInitial()) {
    on<LoadPurchaseInvoices>(_onLoad);
    on<LoadFirstPurchaseInvoices>(_onLoadFirst);
    on<LoadNextPurchaseInvoices>(_onLoadNext);
    on<ResetPurchaseInvoicesPagination>(_onResetPagination);
    on<AddPurchaseInvoice>(_onAdd);
    on<UpdatePurchaseInvoice>(_onUpdate);
    on<DeletePurchaseInvoice>(_onDelete);
    on<MarkPurchaseInvoicePaid>(_onMarkPaid);
    on<FilterPurchaseInvoicesByStatus>(_onFilter);
    on<FilterPurchaseInvoices>(_onFilterCombined);
  }

  Future<void> _onLoad(LoadPurchaseInvoices event, Emitter<PurchaseInvoicesState> emit) async {
    await _onLoadFirst(const LoadFirstPurchaseInvoices(), emit);
  }

  Future<void> _onLoadFirst(LoadFirstPurchaseInvoices event, Emitter<PurchaseInvoicesState> emit) async {
    emit(PurchaseInvoicesLoading());
    try {
      FirestorePaginationService.instance.resetPurchaseInvoicesPagination();
      final invoicesFuture = FirestorePaginationService.instance.getFirstPurchaseInvoices(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getPurchaseInvoicesCount(
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([invoicesFuture, countFuture]);
      final invoices = results[0] as List<PurchaseInvoice>;
      final totalCount = results[1] as int;

      emit(PurchaseInvoicesLoaded(
        invoices,
        invoices,
        totalCount: totalCount > invoices.length ? totalCount : invoices.length,
        hasMore: invoices.length >= pageSize,
      ));
    } catch (e) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  Future<void> _onLoadNext(LoadNextPurchaseInvoices event, Emitter<PurchaseInvoicesState> emit) async {
    final currentState = state;
    if (currentState is! PurchaseInvoicesLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextInvoices = await FirestorePaginationService.instance.getNextPurchaseInvoices(
        pageSize: pageSize,
        currentOffset: currentState.purchaseInvoices.length,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextInvoices.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<PurchaseInvoice>.from(currentState.purchaseInvoices)..addAll(nextInvoices);
        emit(PurchaseInvoicesLoaded(
          updatedList,
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextInvoices.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetPagination(ResetPurchaseInvoicesPagination event, Emitter<PurchaseInvoicesState> emit) async {
    FirestorePaginationService.instance.resetPurchaseInvoicesPagination();
    add(LoadFirstPurchaseInvoices(
      searchQuery: event.searchQuery,
      supplierId: event.supplierId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAdd(AddPurchaseInvoice event, Emitter<PurchaseInvoicesState> emit) async {
    try {
      await FirestoreRepository.instance.savePurchaseInvoice(event.purchaseInvoice);
      add(const LoadFirstPurchaseInvoices());
    } catch (e, s) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdatePurchaseInvoice event, Emitter<PurchaseInvoicesState> emit) async {
    try {
      await FirestoreRepository.instance.savePurchaseInvoice(event.purchaseInvoice);
      add(const LoadFirstPurchaseInvoices());
    } catch (e) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  Future<void> _onDelete(DeletePurchaseInvoice event, Emitter<PurchaseInvoicesState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('purchase_invoices', event.id);
      add(const LoadFirstPurchaseInvoices());
    } catch (e) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  Future<void> _onMarkPaid(MarkPurchaseInvoicePaid event, Emitter<PurchaseInvoicesState> emit) async {
    try {
      add(const LoadFirstPurchaseInvoices());
    } catch (e) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  void _onFilter(FilterPurchaseInvoicesByStatus event, Emitter<PurchaseInvoicesState> emit) {
    add(LoadFirstPurchaseInvoices(status: event.status?.name));
  }

  void _onFilterCombined(FilterPurchaseInvoices event, Emitter<PurchaseInvoicesState> emit) {
    add(LoadFirstPurchaseInvoices(
      supplierId: event.clientId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status?.name,
    ));
  }
}
