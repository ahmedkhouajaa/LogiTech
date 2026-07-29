import 'package:equatable/equatable.dart';
import '../../models/supplier_return.dart';

abstract class SupplierReturnsState extends Equatable {
  const SupplierReturnsState();

  @override
  List<Object?> get props => [];
}

class SupplierReturnsInitial extends SupplierReturnsState {}

class SupplierReturnsLoading extends SupplierReturnsState {}

class SupplierReturnsLoaded extends SupplierReturnsState {
  final List<SupplierReturn> returns;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  const SupplierReturnsLoaded(
    this.returns, {
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  SupplierReturnsLoaded copyWith({
    List<SupplierReturn>? returns,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SupplierReturnsLoaded(
      returns ?? this.returns,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [returns, totalCount, hasMore, isLoadingMore];
}

class SupplierReturnsError extends SupplierReturnsState {
  final String message;

  const SupplierReturnsError(this.message);

  @override
  List<Object?> get props => [message];
}
