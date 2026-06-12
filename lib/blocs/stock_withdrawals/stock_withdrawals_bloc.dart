import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/stock_withdrawal.dart';
import '../../database/database_helper.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class StockWithdrawalsEvent {}

class LoadStockWithdrawals extends StockWithdrawalsEvent {}

class AddStockWithdrawal extends StockWithdrawalsEvent {
  final StockWithdrawal withdrawal;
  AddStockWithdrawal(this.withdrawal);
}

class UpdateStockWithdrawal extends StockWithdrawalsEvent {
  final StockWithdrawal withdrawal;
  UpdateStockWithdrawal(this.withdrawal);
}

class DeleteStockWithdrawal extends StockWithdrawalsEvent {
  final String withdrawalId;
  DeleteStockWithdrawal(this.withdrawalId);
}

class FilterStockWithdrawals extends StockWithdrawalsEvent {
  final String? clientId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;
  FilterStockWithdrawals({this.clientId, this.dateFrom, this.dateTo, this.status});
}

// ─── States ──────────────────────────────────────────────────────
abstract class StockWithdrawalsState {}

class StockWithdrawalsInitial extends StockWithdrawalsState {}

class StockWithdrawalsLoading extends StockWithdrawalsState {}

class StockWithdrawalsLoaded extends StockWithdrawalsState {
  final List<StockWithdrawal> withdrawals;
  final String? clientFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  StockWithdrawalsLoaded(
    this.withdrawals, {
    this.clientFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });
}

class StockWithdrawalsError extends StockWithdrawalsState {
  final String message;
  StockWithdrawalsError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class StockWithdrawalsBloc extends Bloc<StockWithdrawalsEvent, StockWithdrawalsState> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  StockWithdrawalsBloc() : super(StockWithdrawalsInitial()) {
    on<LoadStockWithdrawals>(_onLoad);
    on<AddStockWithdrawal>(_onAdd);
    on<UpdateStockWithdrawal>(_onUpdate);
    on<DeleteStockWithdrawal>(_onDelete);
    on<FilterStockWithdrawals>(_onFilter);
  }

  Future<void> _onLoad(LoadStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    emit(StockWithdrawalsLoading());
    try {
      final withdrawals = await _db.getStockWithdrawals();
      emit(StockWithdrawalsLoaded(withdrawals));
    } catch (e) {
      emit(StockWithdrawalsError(e.toString()));
    }
  }

  Future<void> _onAdd(AddStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
    try {
      await _db.insertStockWithdrawal(event.withdrawal);
      add(LoadStockWithdrawals());
    } catch (e) {
      emit(StockWithdrawalsError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
    try {
      await _db.updateStockWithdrawal(event.withdrawal);
      add(LoadStockWithdrawals());
    } catch (e) {
      emit(StockWithdrawalsError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
    try {
      await _db.softDeleteStockWithdrawal(event.withdrawalId);
      add(LoadStockWithdrawals());
    } catch (e) {
      emit(StockWithdrawalsError(e.toString()));
    }
  }

  Future<void> _onFilter(FilterStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    emit(StockWithdrawalsLoading());
    try {
      final allWithdrawals = await _db.getStockWithdrawals(
        status: event.status,
        startDate: event.dateFrom,
        endDate: event.dateTo,
      );

      final filtered = allWithdrawals.where((w) {
        if (event.clientId != null && event.clientId!.isNotEmpty && event.clientId != 'all') {
          return w.customerId == event.clientId;
        }
        return true;
      }).toList();

      emit(StockWithdrawalsLoaded(
        filtered,
        clientFilter: event.clientId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
        statusFilter: event.status,
      ));
    } catch (e) {
      emit(StockWithdrawalsError(e.toString()));
    }
  }
}
