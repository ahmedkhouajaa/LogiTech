import '../../models/stock_entry.dart';

abstract class StockEntriesState {}

class StockEntriesInitial extends StockEntriesState {}

class StockEntriesLoading extends StockEntriesState {}

class StockEntriesLoaded extends StockEntriesState {
  final List<StockEntry> entries;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String? supplierFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final String? statusFilter;

  StockEntriesLoaded(
    this.entries, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.supplierFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.statusFilter,
  });

  StockEntriesLoaded copyWith({
    List<StockEntry>? entries,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    String? supplierFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    String? statusFilter,
  }) {
    return StockEntriesLoaded(
      entries ?? this.entries,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      supplierFilter: supplierFilter ?? this.supplierFilter,
      dateFromFilter: dateFromFilter ?? this.dateFromFilter,
      dateToFilter: dateToFilter ?? this.dateToFilter,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  List<StockEntry> get filteredEntries {
    return entries.where((entry) {
      bool matchSupplier = supplierFilter == null || entry.supplierId == supplierFilter;
      bool matchStatus = statusFilter == null || entry.status == statusFilter;
      bool matchDateFrom = dateFromFilter == null || entry.date.isAfter(dateFromFilter!.subtract(const Duration(days: 1)));
      bool matchDateTo = dateToFilter == null || entry.date.isBefore(dateToFilter!.add(const Duration(days: 1)));
      return matchSupplier && matchStatus && matchDateFrom && matchDateTo && !entry.isDeleted;
    }).toList();
  }
}

class StockEntriesError extends StockEntriesState {
  final String message;
  StockEntriesError(this.message);
}
