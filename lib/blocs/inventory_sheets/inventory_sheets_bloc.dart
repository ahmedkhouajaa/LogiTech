import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/helpers.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory_sheets_event.dart';
import 'inventory_sheets_state.dart';
import '../../database/database_helper.dart';
import '../../models/inventory_sheet.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';

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
    await _onLoadFirstInventorySheets(LoadFirstInventorySheets(), emit);
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
      String number = event.sheet.number;
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextInventorySheetSequence();
        number = generateDocNumber(DocPrefix.inventorySheet, seq);
      }
      final sheetToSave = event.sheet.copyWith(number: number);
      await FirestoreRepository.instance.saveInventorySheet(sheetToSave);

      for (var item in sheetToSave.items) {
        final diff = item.actualQty - item.theoreticalQty;
        if (item.productId.isNotEmpty && diff != 0) {
          String? prodName;
          try {
            final prodRef = FirebaseFirestore.instance.collection('products').doc(item.productId);
            final doc = await prodRef.get();
            if (doc.exists && doc.data() != null) {
              prodName = doc.data()!['name']?.toString();
              final currentStock = (doc.data()!['stock_qty'] as num?)?.toDouble() ?? (doc.data()!['stock'] as num?)?.toDouble() ?? 0.0;
              await prodRef.update({
                'stock_qty': currentStock + diff,
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          } catch (_) {}

          String? whName;
          final whId = sheetToSave.warehouseId;
          try {
            if (whId.isNotEmpty) {
              final whRef = FirebaseFirestore.instance.collection('warehouses').doc(whId);
              final doc = await whRef.get();
              if (doc.exists && doc.data() != null) {
                whName = doc.data()!['name']?.toString();
              }
            }
          } catch (_) {}

          final movId = const Uuid().v4();
          final mov = StockMovement(
            id: movId,
            productId: item.productId,
            productName: prodName,
            warehouseId: whId,
            warehouseName: whName,
            type: MovementType.adjustment,
            quantity: diff.abs(),
            referenceType: 'inventory_sheet',
            referenceId: sheetToSave.number.isNotEmpty ? sheetToSave.number : sheetToSave.id,
            date: sheetToSave.date,
            notes: sheetToSave.notes ?? 'Ajustement d\'inventaire (${diff > 0 ? "+$diff" : "$diff"})',
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
          );
          await FirestoreRepository.instance.saveDocument('stock_movements', mov.id, mov.toMap());
        }
      }

      add(LoadFirstInventorySheets());
    } catch (e) {
      emit(InventorySheetsError("Erreur lors de l'ajout: $e"));
    }
  }

  Future<void> _onSheetUpdated(InventorySheetUpdated event, Emitter<InventorySheetsState> emit) async {
    try {
      await FirestoreRepository.instance.saveInventorySheet(event.sheet);
      add(LoadFirstInventorySheets());
    } catch (e) {
      emit(InventorySheetsError("Erreur lors de la mise à jour: $e"));
    }
  }

  Future<void> _onSheetDeleted(InventorySheetDeleted event, Emitter<InventorySheetsState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('inventory_sheets', event.sheetId);
      add(LoadFirstInventorySheets());
    } catch (e) {
      emit(InventorySheetsError("Erreur lors de la suppression: $e"));
    }
  }
}
