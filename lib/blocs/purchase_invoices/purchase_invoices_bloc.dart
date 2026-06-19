import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/purchase_invoice.dart';
import '../../utils/constants.dart';

abstract class PurchaseInvoicesEvent extends Equatable {
  const PurchaseInvoicesEvent();
  @override
  List<Object?> get props => [];
}
class LoadPurchaseInvoices extends PurchaseInvoicesEvent {}
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
  const PurchaseInvoicesLoaded(
    this.purchaseInvoices,
    this.filteredPurchaseInvoices, {
    this.activeFilter,
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
  });
  @override
  List<Object?> get props => [purchaseInvoices, filteredPurchaseInvoices, activeFilter, clientFilter, dateFromFilter, dateToFilter];
}
class PurchaseInvoicesError extends PurchaseInvoicesState {
  final String message;
  const PurchaseInvoicesError(this.message);
  @override
  List<Object?> get props => [message];
}

class PurchaseInvoicesBloc extends Bloc<PurchaseInvoicesEvent, PurchaseInvoicesState> {
  PurchaseInvoicesBloc() : super(PurchaseInvoicesInitial()) {
    on<LoadPurchaseInvoices>(_onLoad);
    on<AddPurchaseInvoice>(_onAdd);
    on<UpdatePurchaseInvoice>(_onUpdate);
    on<DeletePurchaseInvoice>(_onDelete);
    on<MarkPurchaseInvoicePaid>(_onMarkPaid);
    on<FilterPurchaseInvoicesByStatus>(_onFilter);
    on<FilterPurchaseInvoices>(_onFilterCombined);
  }

  Future<void> _onLoad(LoadPurchaseInvoices event, Emitter<PurchaseInvoicesState> emit) async {
    emit(PurchaseInvoicesLoading());
    try {
      final purchaseInvoices = await DatabaseHelper.instance.getPurchaseInvoices();
      emit(PurchaseInvoicesLoaded(purchaseInvoices, purchaseInvoices));
    } catch (e) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  Future<void> _onAdd(AddPurchaseInvoice event, Emitter<PurchaseInvoicesState> emit) async {
    try {
      await DatabaseHelper.instance.insertPurchaseInvoice(event.purchaseInvoice);
      add(LoadPurchaseInvoices());
    } catch (e, s) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdatePurchaseInvoice event, Emitter<PurchaseInvoicesState> emit) async {
    try {
      await DatabaseHelper.instance.updatePurchaseInvoice(event.purchaseInvoice);
      add(LoadPurchaseInvoices());
    } catch (e) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  Future<void> _onDelete(DeletePurchaseInvoice event, Emitter<PurchaseInvoicesState> emit) async {
    try {
      await DatabaseHelper.instance.deletePurchaseInvoice(event.id);
      add(LoadPurchaseInvoices());
    } catch (e) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  Future<void> _onMarkPaid(MarkPurchaseInvoicePaid event, Emitter<PurchaseInvoicesState> emit) async {
    try {
      final purchaseInvoice = await DatabaseHelper.instance.getPurchaseInvoice(event.id);
      if (purchaseInvoice == null) return;
      final newStatus = event.amountPaid >= (purchaseInvoice.totalTTC + purchaseInvoice.stampTax)
          ? InvoiceStatus.paid
          : InvoiceStatus.partial;
      final updated = purchaseInvoice.copyWith(amountPaid: event.amountPaid, status: newStatus);
      await DatabaseHelper.instance.updatePurchaseInvoice(updated);
      add(LoadPurchaseInvoices());
    } catch (e) {
      emit(PurchaseInvoicesError(e.toString()));
    }
  }

  void _onFilter(FilterPurchaseInvoicesByStatus event, Emitter<PurchaseInvoicesState> emit) {
    if (state is PurchaseInvoicesLoaded) {
      final current = state as PurchaseInvoicesLoaded;
      final filtered = event.status == null
          ? current.purchaseInvoices
          : current.purchaseInvoices.where((i) => i.status == event.status).toList();
      emit(PurchaseInvoicesLoaded(current.purchaseInvoices, filtered, activeFilter: event.status));
    }
  }

  void _onFilterCombined(FilterPurchaseInvoices event, Emitter<PurchaseInvoicesState> emit) {
    if (state is PurchaseInvoicesLoaded) {
      final current = state as PurchaseInvoicesLoaded;
      var filtered = current.purchaseInvoices.toList();

      // Filter by client
      if (event.clientId != null && event.clientId!.isNotEmpty) {
        filtered = filtered.where((i) => i.supplierId == event.clientId).toList();
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

      emit(PurchaseInvoicesLoaded(
        current.purchaseInvoices,
        filtered,
        activeFilter: event.status,
        clientFilter: event.clientId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
      ));
    }
  }
}
