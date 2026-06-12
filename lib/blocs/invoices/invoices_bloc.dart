import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/invoice.dart';
import '../../utils/constants.dart';

abstract class InvoicesEvent extends Equatable {
  const InvoicesEvent();
  @override
  List<Object?> get props => [];
}
class LoadInvoices extends InvoicesEvent {}
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
  final InvoiceStatus? activeFilter;
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  const InvoicesLoaded(
    this.invoices,
    this.filteredInvoices, {
    this.activeFilter,
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
  });
  @override
  List<Object?> get props => [invoices, filteredInvoices, activeFilter, clientFilter, dateFromFilter, dateToFilter];
}
class InvoicesError extends InvoicesState {
  final String message;
  const InvoicesError(this.message);
  @override
  List<Object?> get props => [message];
}

class InvoicesBloc extends Bloc<InvoicesEvent, InvoicesState> {
  InvoicesBloc() : super(InvoicesInitial()) {
    on<LoadInvoices>(_onLoad);
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
      emit(InvoicesLoaded(invoices, invoices));
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  Future<void> _onAdd(AddInvoice event, Emitter<InvoicesState> emit) async {
    try {
      await DatabaseHelper.instance.insertInvoice(event.invoice);
      add(LoadInvoices());
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateInvoice event, Emitter<InvoicesState> emit) async {
    try {
      await DatabaseHelper.instance.updateInvoice(event.invoice);
      add(LoadInvoices());
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteInvoice event, Emitter<InvoicesState> emit) async {
    try {
      await DatabaseHelper.instance.deleteInvoice(event.id);
      add(LoadInvoices());
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  Future<void> _onMarkPaid(MarkInvoicePaid event, Emitter<InvoicesState> emit) async {
    try {
      final invoice = await DatabaseHelper.instance.getInvoice(event.id);
      if (invoice == null) return;
      final newStatus = event.amountPaid >= (invoice.totalTTC + invoice.stampTax)
          ? InvoiceStatus.paid
          : InvoiceStatus.partial;
      final updated = invoice.copyWith(amountPaid: event.amountPaid, status: newStatus);
      await DatabaseHelper.instance.updateInvoice(updated);
      add(LoadInvoices());
    } catch (e) {
      emit(InvoicesError(e.toString()));
    }
  }

  void _onFilter(FilterInvoicesByStatus event, Emitter<InvoicesState> emit) {
    if (state is InvoicesLoaded) {
      final current = state as InvoicesLoaded;
      final filtered = event.status == null
          ? current.invoices
          : current.invoices.where((i) => i.status == event.status).toList();
      emit(InvoicesLoaded(current.invoices, filtered, activeFilter: event.status));
    }
  }

  void _onFilterCombined(FilterInvoices event, Emitter<InvoicesState> emit) {
    if (state is InvoicesLoaded) {
      final current = state as InvoicesLoaded;
      var filtered = current.invoices.toList();

      // Filter by client
      if (event.clientId != null && event.clientId!.isNotEmpty) {
        filtered = filtered.where((i) => i.customerId == event.clientId).toList();
      }

      // Filter by date range
      if (event.dateFrom != null) {
        filtered = filtered.where((i) =>
          i.date.isAfter(event.dateFrom!.subtract(const Duration(days: 1)))
        ).toList();
      }
      if (event.dateTo != null) {
        filtered = filtered.where((i) =>
          i.date.isBefore(event.dateTo!.add(const Duration(days: 1)))
        ).toList();
      }

      // Filter by status
      if (event.status != null) {
        filtered = filtered.where((i) => i.status == event.status).toList();
      }

      emit(InvoicesLoaded(
        current.invoices,
        filtered,
        activeFilter: event.status,
        clientFilter: event.clientId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
      ));
    }
  }
}
