import 'package:flutter_bloc/flutter_bloc.dart';
import 'inventory_sheets_event.dart';
import 'inventory_sheets_state.dart';
import '../../database/database_helper.dart';

class InventorySheetsBloc extends Bloc<InventorySheetsEvent, InventorySheetsState> {
  final DatabaseHelper databaseHelper;

  InventorySheetsBloc({required this.databaseHelper}) : super(InventorySheetsInitial()) {
    on<InventorySheetsLoadRequested>(_onLoadRequested);
    on<InventorySheetAdded>(_onSheetAdded);
    on<InventorySheetUpdated>(_onSheetUpdated);
    on<InventorySheetDeleted>(_onSheetDeleted);
  }

  Future<void> _onLoadRequested(InventorySheetsLoadRequested event, Emitter<InventorySheetsState> emit) async {
    emit(InventorySheetsLoading());
    try {
      final sheets = await databaseHelper.getInventorySheets();
      emit(InventorySheetsLoaded(sheets));
    } catch (e) {
      emit(InventorySheetsError(e.toString()));
    }
  }

  Future<void> _onSheetAdded(InventorySheetAdded event, Emitter<InventorySheetsState> emit) async {
    try {
      await databaseHelper.insertInventorySheet(event.sheet);
      add(InventorySheetsLoadRequested());
    } catch (e) {
      emit(InventorySheetsError(e.toString()));
    }
  }

  Future<void> _onSheetUpdated(InventorySheetUpdated event, Emitter<InventorySheetsState> emit) async {
    try {
      await databaseHelper.updateInventorySheet(event.sheet);
      add(InventorySheetsLoadRequested());
    } catch (e) {
      emit(InventorySheetsError(e.toString()));
    }
  }

  Future<void> _onSheetDeleted(InventorySheetDeleted event, Emitter<InventorySheetsState> emit) async {
    try {
      await databaseHelper.deleteInventorySheet(event.sheetId);
      add(InventorySheetsLoadRequested());
    } catch (e) {
      emit(InventorySheetsError(e.toString()));
    }
  }
}
