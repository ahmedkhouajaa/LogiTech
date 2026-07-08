import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/stock_transfer.dart';
import '../../database/database_helper.dart';

import 'package:sqflite/sqflite.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class StockTransfersEvent {}

class LoadStockTransfers extends StockTransfersEvent {}

class AddStockTransfer extends StockTransfersEvent {
  final StockTransfer transfer;
  AddStockTransfer(this.transfer);
}

class UpdateStockTransfer extends StockTransfersEvent {
  final StockTransfer transfer;
  UpdateStockTransfer(this.transfer);
}

class DeleteStockTransfer extends StockTransfersEvent {
  final String transferId;
  DeleteStockTransfer(this.transferId);
}

// ─── States ──────────────────────────────────────────────────────
abstract class StockTransfersState {}

class StockTransfersInitial extends StockTransfersState {}

class StockTransfersLoading extends StockTransfersState {}

class StockTransfersLoaded extends StockTransfersState {
  final List<StockTransfer> transfers;
  StockTransfersLoaded(this.transfers);
}

class StockTransfersError extends StockTransfersState {
  final String message;
  StockTransfersError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class StockTransfersBloc extends Bloc<StockTransfersEvent, StockTransfersState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  StockTransfersBloc() : super(StockTransfersInitial()) {
    on<LoadStockTransfers>(_onLoad);
    on<AddStockTransfer>(_onAdd);
    on<UpdateStockTransfer>(_onUpdate);
    on<DeleteStockTransfer>(_onDelete);
  }

  Future<void> _onLoad(LoadStockTransfers event, Emitter<StockTransfersState> emit) async {
    emit(StockTransfersLoading());
    try {
      final transfers = await _dbHelper.getStockTransfers();
      emit(StockTransfersLoaded(transfers));
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }

  Future<void> _onAdd(AddStockTransfer event, Emitter<StockTransfersState> emit) async {
    try {
      final now = DateTime.now();
      String number = event.transfer.number;
      
      if (number.isEmpty || number.startsWith('BT-')) {
        final db = await _dbHelper.database;
        final countResult = await db.rawQuery(
          "SELECT COUNT(*) as count FROM stock_transfers WHERE strftime('%Y', date) = ?", 
          [now.year.toString()]
        );
        int count = Sqflite.firstIntValue(countResult) ?? 0;
        count += 1;
        number = 'BT-${now.year}-${count.toString().padLeft(5, '0')}';
      }

      final transferToInsert = event.transfer.copyWith(number: number);
      await _dbHelper.insertStockTransfer(transferToInsert);
      add(LoadStockTransfers());
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateStockTransfer event, Emitter<StockTransfersState> emit) async {
    try {
      await _dbHelper.updateStockTransfer(event.transfer);
      add(LoadStockTransfers());
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteStockTransfer event, Emitter<StockTransfersState> emit) async {
    try {
      await _dbHelper.deleteStockTransfer(event.transferId);
      add(LoadStockTransfers());
    } catch (e) {
      emit(StockTransfersError(e.toString()));
    }
  }
}
