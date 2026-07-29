import 'package:flutter_bloc/flutter_bloc.dart';
import 'inventory_sheets_event.dart';
import 'inventory_sheets_state.dart';
import '../../database/database_helper.dart';
import '../../models/inventory_sheet.dart';
import '../../services/firestore_pagination_service.dart';

class InventorySheetsBloc extends Bloc<InventorySheetsEvent, InventorySheetsState> {
  static const int pageSize = 10;
  final DatabaseHelper databaseHelper;

  InventorySheetsBloc({required this.databaseHelper}) : super(InventorySheetsInitial()) {
    on<InventorySheetsLoadRequested>(_onLoadRequested);
    on<LoadFirstInventorySheets>(_onLoadFirstInventorySheets);
    on<LoadNextInventorySheets>(_onLoadNextInventorySheets);
    on<ResetInventorySheetsPagination>(_onResetInventorySheetsPagination);
    on<InventorySheetAdded>(_onSheetAdded);
    on<InventorySheetUpdated>(_onSheetUpdated);
    on<InventorySheetDeleted>(_onSheetDeleted);
  }

  Future<void> _onLoadRequested(InventorySheetsLoadRequested event, Emitter<InventorySheetsState> emit) async {
    emit(InventorySheetsLoading());
    try {
      final sheets = await databaseHelper.getInventorySheets();
      emit(InventorySheetsLoaded(sheets, totalCount: sheets.length));
    } catch (e) {
      emit(InventorySheetsError(e.toString()));
    }
  }

  Future<void> _onLoadFirstInventorySheets(LoadFirstInventorySheets event, Emitter<InventorySheetsState> emit) async {
    emit(InventorySheetsLoading());
    try {
      FirestorePaginationService.instance.resetInventorySheetsPagination();
      final sheetsFuture = FirestorePaginationService.instance.getFirstInventorySheets(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        warehouseId: event.warehouseId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getInventorySheetsCount(
        searchQuery: event.searchQuery,
        warehouseId: event.warehouseId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([sheetsFuture, countFuture]);
      final sheets = results[0] as List<InventorySheet>;
      final totalCount = results[1] as int;

      emit(InventorySheetsLoaded(
        sheets,
        totalCount: totalCount > sheets.length ? totalCount : sheets.length,
        hasMore: sheets.length >= pageSize,
      ));
    } catch (e) {
      emit(InventorySheetsError(e.toString()));
    }
  }

  Future<void> _onLoadNextInventorySheets(LoadNextInventorySheets event, Emitter<InventorySheetsState> emit) async {
    final currentState = state;
    if (currentState is! InventorySheetsLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextSheets = await FirestorePaginationService.instance.getNextInventorySheets(
        pageSize: pageSize,
        currentOffset: currentState.sheets.length,
        searchQuery: event.searchQuery,
        warehouseId: event.warehouseId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextSheets.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<InventorySheet>.from(currentState.sheets)..addAll(nextSheets);
        emit(InventorySheetsLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextSheets.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetInventorySheetsPagination(ResetInventorySheetsPagination event, Emitter<InventorySheetsState> emit) async {
    FirestorePaginationService.instance.resetInventorySheetsPagination();
    add(LoadFirstInventorySheets(
      searchQuery: event.searchQuery,
      warehouseId: event.warehouseId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
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
