import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/receiving_voucher.dart';
import '../../database/database_helper.dart';

// ─── Events ────────────────────────────────────────────────────────
abstract class ReceivingVouchersEvent {}

class LoadReceivingVouchers extends ReceivingVouchersEvent {}

class AddReceivingVoucher extends ReceivingVouchersEvent {
  final ReceivingVoucher voucher;
  AddReceivingVoucher(this.voucher);
}

// ─── States ────────────────────────────────────────────────────────
abstract class ReceivingVouchersState {}

class ReceivingVouchersInitial extends ReceivingVouchersState {}

class ReceivingVouchersLoading extends ReceivingVouchersState {}

class ReceivingVouchersLoaded extends ReceivingVouchersState {
  final List<ReceivingVoucher> vouchers;
  ReceivingVouchersLoaded(this.vouchers);
}

class ReceivingVouchersError extends ReceivingVouchersState {
  final String message;
  ReceivingVouchersError(this.message);
}

class ReceivingVoucherAdded extends ReceivingVouchersState {}

// ─── BLoC ──────────────────────────────────────────────────────────
class ReceivingVouchersBloc extends Bloc<ReceivingVouchersEvent, ReceivingVouchersState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  ReceivingVouchersBloc() : super(ReceivingVouchersInitial()) {
    on<LoadReceivingVouchers>(_onLoadReceivingVouchers);
    on<AddReceivingVoucher>(_onAddReceivingVoucher);
  }

  Future<void> _onLoadReceivingVouchers(LoadReceivingVouchers event, Emitter<ReceivingVouchersState> emit) async {
    emit(ReceivingVouchersLoading());
    try {
      final vouchers = await _dbHelper.getReceivingVouchers();
      emit(ReceivingVouchersLoaded(vouchers));
    } catch (e) {
      emit(ReceivingVouchersError(e.toString()));
    }
  }

  Future<void> _onAddReceivingVoucher(AddReceivingVoucher event, Emitter<ReceivingVouchersState> emit) async {
    emit(ReceivingVouchersLoading());
    try {
      final voucherMap = event.voucher.toMap();
      final itemsMap = event.voucher.items.map((i) => i.toMap()).toList();
      await _dbHelper.insertReceivingVoucher(voucherMap, itemsMap);
      add(LoadReceivingVouchers());
      emit(ReceivingVoucherAdded());
    } catch (e) {
      emit(ReceivingVouchersError(e.toString()));
    }
  }
}
