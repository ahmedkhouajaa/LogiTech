import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/invoice.dart';
import '../../utils/constants.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';
import 'package:business_manager_pro/services/error_handler.dart';

abstract class InvoicesEvent extends Equatable {
  const InvoicesEvent();
  @override
  List<Object?> get props => [];
}

class LoadInvoices extends InvoicesEvent {}

class LoadFirstInvoices extends InvoicesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstInvoices({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class LoadNextInvoices extends InvoicesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadNextInvoices({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class ResetInvoicesPagination extends InvoicesEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const ResetInvoicesPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, customerId, dateFrom, dateTo, status];
}

class AddInvoice extends InvoicesEvent {
  final Invoice invoice;
  const AddInvoice(this.invoice);
  @override
  List<Object?> get props => [invoice];
}
class UpdateInvoice extends InvoicesEvent {
  final Invoice invoice;
  const UpdateInvoice(this.invoice);
  @override
  List<Object?> get props => [invoice];
}
class DeleteInvoice extends InvoicesEvent {
  final String id;
  const DeleteInvoice(this.id);
  @override
  List<Object?> get props => [id];
}
class MarkInvoicePaid extends InvoicesEvent {
  final String id;
  final double amountPaid;
  const MarkInvoicePaid(this.id, this.amountPaid);
  @override
  List<Object?> get props => [id, amountPaid];
}
class FilterInvoicesByStatus extends InvoicesEvent {
  final InvoiceStatus? status;
  const FilterInvoicesByStatus(this.status);
  @override
  List<Object?> get props => [status];
}
class FilterInvoices extends InvoicesEvent {
  final String? clientId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final InvoiceStatus? status;
  const FilterInvoices({this.clientId, this.dateFrom, this.dateTo, this.status});
  @override
  List<Object?> get props => [clientId, dateFrom, dateTo, status];
}

abstract class InvoicesState extends Equatable {
  const InvoicesState();
  @override
  List<Object?> get props => [];
}
class InvoicesInitial extends InvoicesState {}
class InvoicesLoading extends InvoicesState {}
class InvoicesLoaded extends InvoicesState {
  final List<Invoice> invoices;
  final List<Invoice> filteredInvoices;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final InvoiceStatus? activeFilter;
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;

  const InvoicesLoaded(
    this.invoices,
    this.filteredInvoices, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.activeFilter,
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
  });

  InvoicesLoaded copyWith({
    List<Invoice>? invoices,
    List<Invoice>? filteredInvoices,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    InvoiceStatus? activeFilter,
    String? clientFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
  }) {
    return InvoicesLoaded(
      invoices ?? this.invoices,
      filteredInvoices ?? this.filteredInvoices,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      activeFilter: activeFilter ?? this.activeFilter,
      clientFilter: clientFilter ?? this.clientFilter,
      dateFromFilter: dateFromFilter ?? this.dateFromFilter,
      dateToFilter: dateToFilter ?? this.dateToFilter,
    );
  }

  @override
  List<Object?> get props => [
        invoices,
        filteredInvoices,
        totalCount,
        hasMore,
        isLoadingMore,
        activeFilter,
        clientFilter,
        dateFromFilter,
        dateToFilter
      ];
}

class InvoicesError extends InvoicesState {
  final String message;
  const InvoicesError(this.message);
  @override
  List<Object?> get props => [message];
}

class InvoicesBloc extends Bloc<InvoicesEvent, InvoicesState> {
  static const int pageSize = 10;

  InvoicesBloc() : super(InvoicesInitial()) {
    on<LoadInvoices>(_onLoad);
    on<LoadFirstInvoices>(_onLoadFirstInvoices);
    on<LoadNextInvoices>(_onLoadNextInvoices);
    on<ResetInvoicesPagination>(_onResetInvoicesPagination);
    on<AddInvoice>(_onAdd);
    on<UpdateInvoice>(_onUpdate);
    on<DeleteInvoice>(_onDelete);
    on<MarkInvoicePaid>(_onMarkPaid);
    on<FilterInvoicesByStatus>(_onFilter);
    on<FilterInvoices>(_onFilterCombined);
  }

  Future<void> _onLoad(LoadInvoices event, Emitter<InvoicesState> emit) async {
    emit(InvoicesLoading());
    try {
      final invoices = await DatabaseHelper.instance.getInvoices();
      emit(InvoicesLoaded(invoices, invoices, totalCount: invoices.length));
    } catch (e) {
      emit(InvoicesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadFirstInvoices(LoadFirstInvoices event, Emitter<InvoicesState> emit) async {
    emit(InvoicesLoading());
    try {
      FirestorePaginationService.instance.resetInvoicesPagination();
      final invoicesFuture = FirestorePaginationService.instance.getFirstInvoices(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getInvoicesCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([invoicesFuture, countFuture]);
      final invoices = results[0] as List<Invoice>;
      final totalCount = results[1] as int;

      emit(InvoicesLoaded(
        invoices,
        invoices,
        totalCount: totalCount > invoices.length ? totalCount : invoices.length,
        hasMore: invoices.length >= pageSize,
      ));
    } catch (e) {
      emit(InvoicesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onLoadNextInvoices(LoadNextInvoices event, Emitter<InvoicesState> emit) async {
    final currentState = state;
    if (currentState is! InvoicesLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextInvoices = await FirestorePaginationService.instance.getNextInvoices(
        pageSize: pageSize,
        currentOffset: currentState.invoices.length,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextInvoices.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<Invoice>.from(currentState.invoices)..addAll(nextInvoices);
        emit(InvoicesLoaded(
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

  Future<void> _onResetInvoicesPagination(ResetInvoicesPagination event, Emitter<InvoicesState> emit) async {
    FirestorePaginationService.instance.resetInvoicesPagination();
    add(LoadFirstInvoices(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAdd(AddInvoice event, Emitter<InvoicesState> emit) async {
    try {
      await FirestoreRepository.instance.saveInvoice(event.invoice);
      add(const LoadFirstInvoices());
    } catch (e) {
      emit(InvoicesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdate(UpdateInvoice event, Emitter<InvoicesState> emit) async {
    try {
      await FirestoreRepository.instance.saveInvoice(event.invoice);
      add(const LoadFirstInvoices());
    } catch (e) {
      emit(InvoicesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDelete(DeleteInvoice event, Emitter<InvoicesState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('invoices', event.id);
      add(const LoadFirstInvoices());
    } catch (e) {
      emit(InvoicesError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onMarkPaid(MarkInvoicePaid event, Emitter<InvoicesState> emit) async {
    try {
      final invoice = await DatabaseHelper.instance.getInvoice(event.id);
      if (invoice != null) {
        final newStatus = event.amountPaid >= invoice.totalTTC ? InvoiceStatus.paid : InvoiceStatus.partial;
        final updatedInvoice = invoice.copyWith(amountPaid: event.amountPaid, status: newStatus);
        await DatabaseHelper.instance.updateInvoice(updatedInvoice);
        add(LoadInvoices());
      }
    } catch (e) {
      emit(InvoicesError(ErrorHandler.parseError(e)));
    }
  }

  void _onFilter(FilterInvoicesByStatus event, Emitter<InvoicesState> emit) {
    if (state is InvoicesLoaded) {
      final current = state as InvoicesLoaded;
      final filtered = event.status == null
          ? current.invoices
          : current.invoices.where((i) => i.status == event.status).toList();
      emit(current.copyWith(filteredInvoices: filtered, activeFilter: event.status));
    }
  }

  void _onFilterCombined(FilterInvoices event, Emitter<InvoicesState> emit) {
    if (state is InvoicesLoaded) {
      final current = state as InvoicesLoaded;
      final filtered = current.invoices.where((invoice) {
        if (event.clientId != null && invoice.customerId != event.clientId) return false;
        if (event.status != null && invoice.status != event.status) return false;
        if (event.dateFrom != null && invoice.date.isBefore(event.dateFrom!)) return false;
        if (event.dateTo != null && invoice.date.isAfter(event.dateTo!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
      emit(current.copyWith(
        filteredInvoices: filtered,
        activeFilter: event.status,
        clientFilter: event.clientId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
      ));
    }
  }
}
