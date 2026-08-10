import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/stock_entry.dart';
import '../../services/firestore_pagination_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';
import 'stock_entries_event.dart';
import 'stock_entries_state.dart';

class StockEntriesBloc extends Bloc<StockEntriesEvent, StockEntriesState> {
  static const int pageSize = 10;
  final _uuid = const Uuid();

  StockEntriesBloc() : super(StockEntriesInitial()) {
    on<LoadStockEntries>(_onLoadStockEntries);
    on<LoadFirstStockEntries>(_onLoadFirstStockEntries);
    on<LoadNextStockEntries>(_onLoadNextStockEntries);
    on<ResetStockEntriesPagination>(_onResetStockEntriesPagination);
    on<AddStockEntry>(_onAddStockEntry);
    on<UpdateStockEntry>(_onUpdateStockEntry);
    on<DeleteStockEntry>(_onDeleteStockEntry);
    on<FilterStockEntries>(_onFilterStockEntries);
  }

  Future<void> _onLoadFirstStockEntries(LoadFirstStockEntries event, Emitter<StockEntriesState> emit) async {
    emit(StockEntriesLoading());
    try {
      FirestorePaginationService.instance.resetStockEntriesPagination();
      final entriesFuture = FirestorePaginationService.instance.getFirstStockEntries(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getStockEntriesCount(
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([entriesFuture, countFuture]);
      final entries = results[0] as List<StockEntry>;
      final totalCount = results[1] as int;

      emit(StockEntriesLoaded(
        entries,
        totalCount: totalCount > entries.length ? totalCount : entries.length,
        hasMore: entries.length >= pageSize,
      ));
    } catch (e) {
      emit(StockEntriesError("Erreur lors du chargement des bons d'entree: $e"));
    }
  }

  Future<void> _onLoadNextStockEntries(LoadNextStockEntries event, Emitter<StockEntriesState> emit) async {
    final currentState = state;
    if (currentState is! StockEntriesLoaded || !currentState.hasMore || currentState.isLoadingMore) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextItems = await FirestorePaginationService.instance.getNextStockEntries(
        pageSize: pageSize,
        currentOffset: currentState.entries.length,
        searchQuery: event.searchQuery,
        supplierId: event.supplierId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextItems.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<StockEntry>.from(currentState.entries)..addAll(nextItems);
        emit(StockEntriesLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextItems.length >= pageSize,
          isLoadingMore: false,
          supplierFilter: event.supplierId,
          dateFromFilter: event.dateFrom,
          dateToFilter: event.dateTo,
          statusFilter: event.status,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetStockEntriesPagination(ResetStockEntriesPagination event, Emitter<StockEntriesState> emit) async {
    FirestorePaginationService.instance.resetStockEntriesPagination();
    add(LoadFirstStockEntries(
      searchQuery: event.searchQuery,
      supplierId: event.supplierId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onLoadStockEntries(LoadStockEntries event, Emitter<StockEntriesState> emit) async {
    await _onLoadFirstStockEntries(const LoadFirstStockEntries(), emit);
  }

  Future<void> _onAddStockEntry(AddStockEntry event, Emitter<StockEntriesState> emit) async {
    try {
      await FirestoreRepository.instance.saveStockEntry(event.entry);

      for (var item in event.entry.items) {
        if (item.productId.isNotEmpty && item.quantity > 0) {
          String? prodName;
          try {
            final prodRef = FirebaseFirestore.instance.collection('products').doc(item.productId);
            final doc = await prodRef.get();
            if (doc.exists && doc.data() != null) {
              prodName = doc.data()!['name']?.toString();
              final currentStock = (doc.data()!['stock_qty'] as num?)?.toDouble() ?? (doc.data()!['stock'] as num?)?.toDouble() ?? 0.0;
              await prodRef.update({
                'stock_qty': currentStock + item.quantity,
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          } catch (_) {}

          String? whName;
          try {
            final whRef = FirebaseFirestore.instance.collection('warehouses').doc(event.entry.warehouseId);
            final doc = await whRef.get();
            if (doc.exists && doc.data() != null) {
              whName = doc.data()!['name']?.toString();
            }
          } catch (_) {}
          if (whName == null && (event.entry.warehouseId.isEmpty || event.entry.warehouseId == 'default_warehouse')) {
            whName = 'Entrepôt principal';
          }

          final movId = const Uuid().v4();
          final mov = StockMovement(
            id: movId,
            productId: item.productId,
            productName: prodName,
            warehouseId: event.entry.warehouseId,
            warehouseName: whName,
            type: MovementType.entry,
            quantity: item.quantity,
            referenceType: 'stock_entry',
            referenceId: event.entry.number.isNotEmpty ? event.entry.number : event.entry.id,
            date: event.entry.date,
            notes: event.entry.reason,
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
          );
          await FirestoreRepository.instance.saveDocument('stock_movements', mov.id, mov.toMap());
        }
      }

      add(const LoadFirstStockEntries());
    } catch (e) {
      emit(StockEntriesError("Erreur lors de l'ajout: $e"));
    }
  }

  Future<void> _onUpdateStockEntry(UpdateStockEntry event, Emitter<StockEntriesState> emit) async {
    try {
      await FirestoreRepository.instance.saveStockEntry(event.entry);

      for (var item in event.entry.items) {
        if (item.productId.isNotEmpty && item.quantity > 0) {
          final movId = const Uuid().v4();
          final mov = StockMovement(
            id: movId,
            productId: item.productId,
            warehouseId: event.entry.warehouseId,
            type: MovementType.entry,
            quantity: item.quantity,
            referenceType: 'stock_entry',
            referenceId: event.entry.number.isNotEmpty ? event.entry.number : event.entry.id,
            date: event.entry.date,
            notes: event.entry.reason,
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
          );
          await FirestoreRepository.instance.saveDocument('stock_movements', mov.id, mov.toMap());
        }
      }

      add(const LoadFirstStockEntries());
    } catch (e) {
      emit(StockEntriesError('Erreur lors de la mise a jour: $e'));
    }
  }

  Future<void> _onDeleteStockEntry(DeleteStockEntry event, Emitter<StockEntriesState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('stock_entries', event.entryId);
      add(const LoadFirstStockEntries());
    } catch (e) {
      emit(StockEntriesError('Erreur lors de la suppression: $e'));
    }
  }

  void _onFilterStockEntries(FilterStockEntries event, Emitter<StockEntriesState> emit) {
    if (state is StockEntriesLoaded) {
      final currentState = state as StockEntriesLoaded;
      emit(StockEntriesLoaded(
        currentState.entries,
        supplierFilter: event.supplierId,
        dateFromFilter: event.dateFrom,
        dateToFilter: event.dateTo,
        statusFilter: event.status,
      ));
    }
  }
}
