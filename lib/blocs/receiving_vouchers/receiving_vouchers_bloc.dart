import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/receiving_voucher.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';

// ─── Events ────────────────────────────────────────────────────────
abstract class ReceivingVouchersEvent {}

class LoadReceivingVouchers extends ReceivingVouchersEvent {}

class LoadFirstReceivingVouchers extends ReceivingVouchersEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadFirstReceivingVouchers({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextReceivingVouchers extends ReceivingVouchersEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextReceivingVouchers({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetReceivingVouchersPagination extends ReceivingVouchersEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetReceivingVouchersPagination({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class AddReceivingVoucher extends ReceivingVouchersEvent {
  final ReceivingVoucher voucher;
  AddReceivingVoucher(this.voucher);
}

class UpdateReceivingVoucher extends ReceivingVouchersEvent {
  final ReceivingVoucher voucher;
  UpdateReceivingVoucher(this.voucher);
}

class DeleteReceivingVoucher extends ReceivingVouchersEvent {
  final String id;
  DeleteReceivingVoucher(this.id);
}

// ─── States ────────────────────────────────────────────────────────
abstract class ReceivingVouchersState {}

class ReceivingVouchersInitial extends ReceivingVouchersState {}

class ReceivingVouchersLoading extends ReceivingVouchersState {}

class ReceivingVouchersLoaded extends ReceivingVouchersState {
  final List<ReceivingVoucher> vouchers;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  ReceivingVouchersLoaded(
    this.vouchers, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  ReceivingVouchersLoaded copyWith({
    List<ReceivingVoucher>? vouchers,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ReceivingVouchersLoaded(
      vouchers ?? this.vouchers,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class ReceivingVouchersError extends ReceivingVouchersState {
  final String message;
  ReceivingVouchersError(this.message);
}

class ReceivingVoucherAdded extends ReceivingVouchersState {}

// ─── BLoC ──────────────────────────────────────────────────────────
class ReceivingVouchersBloc extends Bloc<ReceivingVouchersEvent, ReceivingVouchersState> {
  static const int pageSize = 10;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  ReceivingVouchersBloc() : super(ReceivingVouchersInitial()) {
    on<LoadReceivingVouchers>(_onLoadReceivingVouchers);
    on<LoadFirstReceivingVouchers>(_onLoadFirstReceivingVouchers);
    on<LoadNextReceivingVouchers>(_onLoadNextReceivingVouchers);
    on<ResetReceivingVouchersPagination>(_onResetReceivingVouchersPagination);
    on<AddReceivingVoucher>(_onAddReceivingVoucher);
    on<UpdateReceivingVoucher>(_onUpdateReceivingVoucher);
    on<DeleteReceivingVoucher>(_onDeleteReceivingVoucher);
  }

  Future<void> _onLoadReceivingVouchers(LoadReceivingVouchers event, Emitter<ReceivingVouchersState> emit) async {
    await _onLoadFirstReceivingVouchers(LoadFirstReceivingVouchers(), emit);
  }

  Future<void> _onLoadFirstReceivingVouchers(LoadFirstReceivingVouchers event, Emitter<ReceivingVouchersState> emit) async {
    emit(ReceivingVouchersLoading());
    try {
      FirestorePaginationService.instance.resetReceivingVouchersPagination();
      final vouchersFuture = FirestorePaginationService.instance.getFirstReceivingVouchers(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getReceivingVouchersCount(
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([vouchersFuture, countFuture]);
      final vouchers = results[0] as List<ReceivingVoucher>;
      final totalCount = results[1] as int;

      emit(ReceivingVouchersLoaded(
        vouchers,
        totalCount: totalCount > vouchers.length ? totalCount : vouchers.length,
        hasMore: vouchers.length >= pageSize,
      ));
    } catch (e) {
      emit(ReceivingVouchersError(e.toString()));
    }
  }

  Future<void> _onLoadNextReceivingVouchers(LoadNextReceivingVouchers event, Emitter<ReceivingVouchersState> emit) async {
    final currentState = state;
    if (currentState is! ReceivingVouchersLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextVouchers = await FirestorePaginationService.instance.getNextReceivingVouchers(
        pageSize: pageSize,
        currentOffset: currentState.vouchers.length,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextVouchers.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<ReceivingVoucher>.from(currentState.vouchers)..addAll(nextVouchers);
        emit(ReceivingVouchersLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextVouchers.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetReceivingVouchersPagination(ResetReceivingVouchersPagination event, Emitter<ReceivingVouchersState> emit) async {
    FirestorePaginationService.instance.resetReceivingVouchersPagination();
    add(LoadFirstReceivingVouchers(
      searchQuery: event.searchQuery,
      supplierId: event.supplierId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onAddReceivingVoucher(AddReceivingVoucher event, Emitter<ReceivingVouchersState> emit) async {
    try {
      await FirestoreRepository.instance.saveReceivingVoucher(event.voucher);
      add(LoadFirstReceivingVouchers());
    } catch (e) {
      emit(ReceivingVouchersError(e.toString()));
    }
  }

  Future<void> _onUpdateReceivingVoucher(UpdateReceivingVoucher event, Emitter<ReceivingVouchersState> emit) async {
    try {
      await FirestoreRepository.instance.saveReceivingVoucher(event.voucher);
      add(LoadFirstReceivingVouchers());
    } catch (e) {
      emit(ReceivingVouchersError(e.toString()));
    }
  }

  Future<void> _onDeleteReceivingVoucher(DeleteReceivingVoucher event, Emitter<ReceivingVouchersState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('receiving_vouchers', event.id);
      add(LoadFirstReceivingVouchers());
    } catch (e) {
      emit(ReceivingVouchersError(e.toString()));
    }
  }
}
