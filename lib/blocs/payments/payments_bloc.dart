import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/payment_model.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/firestore_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────
abstract class PaymentsEvent extends Equatable {
  const PaymentsEvent();
  @override
  List<Object?> get props => [];
}

class LoadPayments extends PaymentsEvent {}

class LoadFirstPayments extends PaymentsEvent {
  final String? searchQuery;
  final String? statusFilter;
  const LoadFirstPayments({this.searchQuery, this.statusFilter});
  @override
  List<Object?> get props => [searchQuery, statusFilter];
}

class LoadNextPayments extends PaymentsEvent {
  final String? searchQuery;
  final String? statusFilter;
  const LoadNextPayments({this.searchQuery, this.statusFilter});
  @override
  List<Object?> get props => [searchQuery, statusFilter];
}

class ResetPaymentsPagination extends PaymentsEvent {
  final String? searchQuery;
  final String? statusFilter;
  const ResetPaymentsPagination({this.searchQuery, this.statusFilter});
  @override
  List<Object?> get props => [searchQuery, statusFilter];
}

class AddPayment extends PaymentsEvent {
  final Payment payment;
  const AddPayment(this.payment);
  @override
  List<Object?> get props => [payment];
}

class UpdatePayment extends PaymentsEvent {
  final Payment payment;
  const UpdatePayment(this.payment);
  @override
  List<Object?> get props => [payment];
}

class DeletePayment extends PaymentsEvent {
  final String id;
  const DeletePayment(this.id);
  @override
  List<Object?> get props => [id];
}

class AddPaymentAccount extends PaymentsEvent {
  final PaymentAccount account;
  const AddPaymentAccount(this.account);
  @override
  List<Object?> get props => [account];
}

// ─── States ─────────────────────────────────────────────────────────────────
abstract class PaymentsState extends Equatable {
  const PaymentsState();
  @override
  List<Object?> get props => [];
}

class PaymentsInitial extends PaymentsState {}

class PaymentsLoading extends PaymentsState {}

class PaymentsLoaded extends PaymentsState {
  final List<Payment> payments;
  final List<PaymentAccount> accounts;
  final int? _totalCount;
  final bool? _hasMore;
  final bool? _isLoadingMore;
  final String activeStatusFilter;

  int get totalCount => _totalCount ?? payments.length;
  bool get hasMore => _hasMore ?? false;
  bool get isLoadingMore => _isLoadingMore ?? false;

  const PaymentsLoaded(
    this.payments,
    this.accounts, {
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    this.activeStatusFilter = 'Tous',
  })  : _totalCount = totalCount,
        _hasMore = hasMore,
        _isLoadingMore = isLoadingMore;

  PaymentsLoaded copyWith({
    List<Payment>? payments,
    List<PaymentAccount>? accounts,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? activeStatusFilter,
  }) {
    return PaymentsLoaded(
      payments ?? this.payments,
      accounts ?? this.accounts,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      activeStatusFilter: activeStatusFilter ?? this.activeStatusFilter,
    );
  }

  @override
  List<Object?> get props => [payments, accounts, _totalCount, _hasMore, _isLoadingMore, activeStatusFilter];
}

class PaymentsError extends PaymentsState {
  final String message;
  const PaymentsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────
class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  PaymentsBloc() : super(PaymentsInitial()) {
    on<LoadPayments>(_onLoad);
    on<LoadFirstPayments>(_onLoadFirst);
    on<LoadNextPayments>(_onLoadNext);
    on<ResetPaymentsPagination>(_onReset);
    on<AddPayment>(_onAdd);
    on<UpdatePayment>(_onUpdate);
    on<DeletePayment>(_onDelete);
    on<AddPaymentAccount>(_onAddAccount);
  }

  String? _mapStatusFilter(String? statusFilter) {
    if (statusFilter == null || statusFilter == 'Tous') return null;
    if (statusFilter == 'En attente') return 'pending';
    if (statusFilter == 'Confirmé') return 'confirmed';
    if (statusFilter == 'Rejeté') return 'cancelled';
    return null;
  }

  Future<void> _onLoad(LoadPayments event, Emitter<PaymentsState> emit) async {
    await _onLoadFirst(const LoadFirstPayments(), emit);
  }

  Future<void> _onLoadFirst(LoadFirstPayments event, Emitter<PaymentsState> emit) async {
    emit(PaymentsLoading());
    try {
      FirestorePaginationService.instance.resetPaymentsPagination();
      final paymentsFuture = FirestorePaginationService.instance.getFirstPayments(
        pageSize: 100,
        searchQuery: event.searchQuery,
        status: _mapStatusFilter(event.statusFilter),
      );
      final countFuture = FirestorePaginationService.instance.getPaymentsCount(
        searchQuery: event.searchQuery,
        status: _mapStatusFilter(event.statusFilter),
      );
      final accountsFuture = DatabaseHelper.instance.getPaymentAccounts();

      final results = await Future.wait([paymentsFuture, countFuture, accountsFuture]);
      final payments = results[0] as List<Payment>;
      final totalCount = results[1] as int;
      final accounts = results[2] as List<PaymentAccount>;

      emit(PaymentsLoaded(
        payments,
        accounts,
        totalCount: totalCount > payments.length ? totalCount : payments.length,
        hasMore: payments.length >= 100,
        activeStatusFilter: event.statusFilter ?? 'Tous',
      ));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onLoadNext(LoadNextPayments event, Emitter<PaymentsState> emit) async {
    final currentState = state;
    if (currentState is! PaymentsLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPayments = await FirestorePaginationService.instance.getNextPayments(
        pageSize: 100,
        currentOffset: currentState.payments.length,
        searchQuery: event.searchQuery,
        status: _mapStatusFilter(event.statusFilter),
      );

      emit(currentState.copyWith(
        payments: [...currentState.payments, ...nextPayments],
        hasMore: nextPayments.length >= 100,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onReset(ResetPaymentsPagination event, Emitter<PaymentsState> emit) async {
    try {
      FirestorePaginationService.instance.resetPaymentsPagination();
      final paymentsFuture = FirestorePaginationService.instance.getFirstPayments(
        pageSize: 100,
        searchQuery: event.searchQuery,
        status: _mapStatusFilter(event.statusFilter),
      );
      final countFuture = FirestorePaginationService.instance.getPaymentsCount(
        searchQuery: event.searchQuery,
        status: _mapStatusFilter(event.statusFilter),
      );
      final accountsFuture = DatabaseHelper.instance.getPaymentAccounts();

      final results = await Future.wait([paymentsFuture, countFuture, accountsFuture]);
      final payments = results[0] as List<Payment>;
      final totalCount = results[1] as int;
      final accounts = results[2] as List<PaymentAccount>;

      emit(PaymentsLoaded(
        payments,
        accounts,
        totalCount: totalCount > payments.length ? totalCount : payments.length,
        hasMore: payments.length >= 100,
        activeStatusFilter: event.statusFilter ?? 'Tous',
      ));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onAdd(AddPayment event, Emitter<PaymentsState> emit) async {
    try {
      await FirestoreRepository.instance.savePayment(event.payment);
      add(LoadFirstPayments(statusFilter: state is PaymentsLoaded ? (state as PaymentsLoaded).activeStatusFilter : 'Tous'));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdatePayment event, Emitter<PaymentsState> emit) async {
    try {
      await FirestoreRepository.instance.savePayment(event.payment);
      add(LoadFirstPayments(statusFilter: state is PaymentsLoaded ? (state as PaymentsLoaded).activeStatusFilter : 'Tous'));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onDelete(DeletePayment event, Emitter<PaymentsState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('paiements', event.id);
      add(LoadFirstPayments(statusFilter: state is PaymentsLoaded ? (state as PaymentsLoaded).activeStatusFilter : 'Tous'));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onAddAccount(AddPaymentAccount event, Emitter<PaymentsState> emit) async {
    try {
      await DatabaseHelper.instance.insertPaymentAccount(event.account);
      add(ResetPaymentsPagination(statusFilter: state is PaymentsLoaded ? (state as PaymentsLoaded).activeStatusFilter : 'Tous'));
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }
}
