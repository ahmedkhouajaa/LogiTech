import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/stock_withdrawal.dart';
import '../../models/stock_movement.dart';
import '../../utils/constants.dart';
import '../../database/database_helper.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/enterprise_service.dart';
import '../../services/firestore_repository.dart';

// ─── Events ──────────────────────────────────────────────────────
abstract class StockWithdrawalsEvent {}

class LoadStockWithdrawals extends StockWithdrawalsEvent {}

class LoadFirstStockWithdrawals extends StockWithdrawalsEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadFirstStockWithdrawals({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class LoadNextStockWithdrawals extends StockWithdrawalsEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  LoadNextStockWithdrawals({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

class ResetStockWithdrawalsPagination extends StockWithdrawalsEvent {
  final String? searchQuery;
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  ResetStockWithdrawalsPagination({
    this.searchQuery,
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

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
  final String? customerId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  FilterStockWithdrawals({
    this.customerId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });
}

// ─── States ──────────────────────────────────────────────────────
abstract class StockWithdrawalsState {}

class StockWithdrawalsInitial extends StockWithdrawalsState {}

class StockWithdrawalsLoading extends StockWithdrawalsState {}

class StockWithdrawalsLoaded extends StockWithdrawalsState {
  final List<StockWithdrawal> withdrawals;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  StockWithdrawalsLoaded(
    this.withdrawals, {
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  StockWithdrawalsLoaded copyWith({
    List<StockWithdrawal>? withdrawals,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return StockWithdrawalsLoaded(
      withdrawals ?? this.withdrawals,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class StockWithdrawalsError extends StockWithdrawalsState {
  final String message;
  StockWithdrawalsError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────
class StockWithdrawalsBloc extends Bloc<StockWithdrawalsEvent, StockWithdrawalsState> {
  static const int pageSize = 10;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  StockWithdrawalsBloc() : super(StockWithdrawalsInitial()) {
    on<LoadStockWithdrawals>(_onLoad);
    on<LoadFirstStockWithdrawals>(_onLoadFirstStockWithdrawals);
    on<LoadNextStockWithdrawals>(_onLoadNextStockWithdrawals);
    on<ResetStockWithdrawalsPagination>(_onResetStockWithdrawalsPagination);
    on<AddStockWithdrawal>(_onAdd);
    on<UpdateStockWithdrawal>(_onUpdate);
    on<DeleteStockWithdrawal>(_onDelete);
    on<FilterStockWithdrawals>(_onFilter);
  }

  Future<void> _onLoadFirstStockWithdrawals(LoadFirstStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    emit(StockWithdrawalsLoading());
    try {
      FirestorePaginationService.instance.resetStockWithdrawalsPagination();
      final itemsFuture = FirestorePaginationService.instance.getFirstStockWithdrawals(
        pageSize: pageSize,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );
      final countFuture = FirestorePaginationService.instance.getStockWithdrawalsCount(
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      final results = await Future.wait([itemsFuture, countFuture]);
      final items = results[0] as List<StockWithdrawal>;
      final totalCount = results[1] as int;

      emit(StockWithdrawalsLoaded(
        items,
        totalCount: totalCount > items.length ? totalCount : items.length,
        hasMore: items.length >= pageSize,
      ));
    } catch (e) {
      emit(StockWithdrawalsError("Erreur lors du chargement: $e"));
    }
  }

  Future<void> _onLoadNextStockWithdrawals(LoadNextStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    final currentState = state;
    if (currentState is! StockWithdrawalsLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextItems = await FirestorePaginationService.instance.getNextStockWithdrawals(
        pageSize: pageSize,
        currentOffset: currentState.withdrawals.length,
        searchQuery: event.searchQuery,
        customerId: event.customerId,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        status: event.status,
      );

      if (nextItems.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<StockWithdrawal>.from(currentState.withdrawals)..addAll(nextItems);
        emit(StockWithdrawalsLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextItems.length >= pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetStockWithdrawalsPagination(ResetStockWithdrawalsPagination event, Emitter<StockWithdrawalsState> emit) async {
    FirestorePaginationService.instance.resetStockWithdrawalsPagination();
    add(LoadFirstStockWithdrawals(
      searchQuery: event.searchQuery,
      customerId: event.customerId,
      dateFrom: event.dateFrom,
      dateTo: event.dateTo,
      status: event.status,
    ));
  }

  Future<void> _onLoad(LoadStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    await _onLoadFirstStockWithdrawals(LoadFirstStockWithdrawals(), emit);
  }

  Future<void> _onAdd(AddStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
    try {
      await FirestoreRepository.instance.saveStockWithdrawal(event.withdrawal);

      for (var item in event.withdrawal.items) {
        if (item.productId.isNotEmpty && item.quantity > 0) {
          String? prodName;
          try {
            final prodRef = FirebaseFirestore.instance.collection('products').doc(item.productId);
            final doc = await prodRef.get();
            if (doc.exists && doc.data() != null) {
              prodName = doc.data()!['name']?.toString();
              final currentStock = (doc.data()!['stock_qty'] as num?)?.toDouble() ?? (doc.data()!['stock'] as num?)?.toDouble() ?? 0.0;
              final newStock = currentStock - item.quantity;
              await prodRef.update({
                'stock_qty': newStock,
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          } catch (_) {}

          String? whName;
          final whId = event.withdrawal.warehouseId ?? '';
          try {
            if (whId.isNotEmpty) {
              final whRef = FirebaseFirestore.instance.collection('warehouses').doc(whId);
              final doc = await whRef.get();
              if (doc.exists && doc.data() != null) {
                whName = doc.data()!['name']?.toString();
              }
            }
          } catch (_) {}
          if (whName == null && (whId.isEmpty || whId == 'default_warehouse')) {
            whName = 'Entrepôt principal';
          }

          final movId = const Uuid().v4();
          final mov = StockMovement(
            id: movId,
            productId: item.productId,
            productName: prodName,
            warehouseId: whId.isNotEmpty ? whId : 'default_warehouse',
            warehouseName: whName,
            type: MovementType.exit,
            quantity: item.quantity,
            referenceType: 'stock_withdrawal',
            referenceId: event.withdrawal.number.isNotEmpty ? event.withdrawal.number : event.withdrawal.id,
            date: event.withdrawal.date,
            notes: event.withdrawal.notes ?? event.withdrawal.conditionsGenerales,
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
          );
          await FirestoreRepository.instance.saveDocument('stock_movements', mov.id, mov.toMap());
        }
      }

      add(LoadFirstStockWithdrawals());
    } catch (e) {
      emit(StockWithdrawalsError("Erreur lors de l'ajout: $e"));
    }
  }

  Future<void> _onUpdate(UpdateStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
    try {
      await FirestoreRepository.instance.saveStockWithdrawal(event.withdrawal);

      for (var item in event.withdrawal.items) {
        if (item.productId.isNotEmpty && item.quantity > 0) {
          String? prodName;
          try {
            final prodRef = FirebaseFirestore.instance.collection('products').doc(item.productId);
            final doc = await prodRef.get();
            if (doc.exists && doc.data() != null) {
              prodName = doc.data()!['name']?.toString();
            }
          } catch (_) {}

          String? whName;
          final whId = event.withdrawal.warehouseId ?? '';
          try {
            if (whId.isNotEmpty) {
              final whRef = FirebaseFirestore.instance.collection('warehouses').doc(whId);
              final doc = await whRef.get();
              if (doc.exists && doc.data() != null) {
                whName = doc.data()!['name']?.toString();
              }
            }
          } catch (_) {}
          if (whName == null && (whId.isEmpty || whId == 'default_warehouse')) {
            whName = 'Entrepôt principal';
          }

          final movId = const Uuid().v4();
          final mov = StockMovement(
            id: movId,
            productId: item.productId,
            productName: prodName,
            warehouseId: whId.isNotEmpty ? whId : 'default_warehouse',
            warehouseName: whName,
            type: MovementType.exit,
            quantity: item.quantity,
            referenceType: 'stock_withdrawal',
            referenceId: event.withdrawal.number.isNotEmpty ? event.withdrawal.number : event.withdrawal.id,
            date: event.withdrawal.date,
            notes: event.withdrawal.notes ?? event.withdrawal.conditionsGenerales,
            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
          );
          await FirestoreRepository.instance.saveDocument('stock_movements', mov.id, mov.toMap());
        }
      }

      add(LoadFirstStockWithdrawals());
    } catch (e) {
      emit(StockWithdrawalsError("Erreur lors de la mise à jour: $e"));
    }
  }

  Future<void> _onDelete(DeleteStockWithdrawal event, Emitter<StockWithdrawalsState> emit) async {
    try {
      await FirestoreRepository.instance.softDeleteDocument('bons_prelevement', event.withdrawalId);
    } catch (_) {
      try {
        await FirestoreRepository.instance.deleteDocument('bons_prelevement', event.withdrawalId);
      } catch (_) {}
    }
    add(LoadFirstStockWithdrawals());
  }

  Future<void> _onFilter(FilterStockWithdrawals event, Emitter<StockWithdrawalsState> emit) async {
    emit(StockWithdrawalsLoading());
    try {
      final allWithdrawals = await _dbHelper.getStockWithdrawals(
        status: event.status,
        startDate: event.dateFrom,
        endDate: event.dateTo,
      );

      final filtered = allWithdrawals.where((w) {
        if (!w.number.startsWith('BP-')) return false;
        if (event.customerId != null && event.customerId!.isNotEmpty && event.customerId != 'all') {
          return w.customerId == event.customerId;
        }
        return true;
      }).toList();

      emit(StockWithdrawalsLoaded(
        filtered,
        totalCount: filtered.length,
      ));
    } catch (e) {
      emit(StockWithdrawalsError(e.toString()));
    }
  }
}
