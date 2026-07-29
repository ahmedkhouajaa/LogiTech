import 'package:equatable/equatable.dart';
import '../../models/inventory_sheet.dart';

abstract class InventorySheetsState extends Equatable {
  const InventorySheetsState();

  @override
  List<Object?> get props => [];
}

class InventorySheetsInitial extends InventorySheetsState {}

class InventorySheetsLoading extends InventorySheetsState {}

class InventorySheetsLoaded extends InventorySheetsState {
  final List<InventorySheet> sheets;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const InventorySheetsLoaded(
    this.sheets, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  InventorySheetsLoaded copyWith({
    List<InventorySheet>? sheets,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return InventorySheetsLoaded(
      sheets ?? this.sheets,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [sheets, totalCount, hasMore, isLoadingMore];
}

class InventorySheetsError extends InventorySheetsState {
  final String message;
  const InventorySheetsError(this.message);

  @override
  List<Object?> get props => [message];
}
