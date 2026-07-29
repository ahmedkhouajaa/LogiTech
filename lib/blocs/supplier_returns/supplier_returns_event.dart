import 'package:equatable/equatable.dart';
import '../../models/supplier_return.dart';

abstract class SupplierReturnsEvent extends Equatable {
  const SupplierReturnsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSupplierReturns extends SupplierReturnsEvent {}

class LoadFirstSupplierReturns extends SupplierReturnsEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadFirstSupplierReturns({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class LoadNextSupplierReturns extends SupplierReturnsEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const LoadNextSupplierReturns({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class ResetSupplierReturnsPagination extends SupplierReturnsEvent {
  final String? searchQuery;
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const ResetSupplierReturnsPagination({
    this.searchQuery,
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [searchQuery, supplierId, dateFrom, dateTo, status];
}

class AddSupplierReturn extends SupplierReturnsEvent {
  final SupplierReturn supplierReturn;

  const AddSupplierReturn(this.supplierReturn);

  @override
  List<Object?> get props => [supplierReturn];
}

class UpdateSupplierReturn extends SupplierReturnsEvent {
  final SupplierReturn supplierReturn;

  const UpdateSupplierReturn(this.supplierReturn);

  @override
  List<Object?> get props => [supplierReturn];
}

class DeleteSupplierReturn extends SupplierReturnsEvent {
  final String id;

  const DeleteSupplierReturn(this.id);

  @override
  List<Object?> get props => [id];
}

class FilterSupplierReturns extends SupplierReturnsEvent {
  final String? supplierId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const FilterSupplierReturns({
    this.supplierId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [supplierId, dateFrom, dateTo, status];
}
