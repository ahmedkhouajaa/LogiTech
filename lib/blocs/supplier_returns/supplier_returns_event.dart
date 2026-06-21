import 'package:equatable/equatable.dart';
import '../../models/supplier_return.dart';

abstract class SupplierReturnsEvent extends Equatable {
  const SupplierReturnsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSupplierReturns extends SupplierReturnsEvent {}

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
  final String? FournisseurId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const FilterSupplierReturns({
    this.FournisseurId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [FournisseurId, dateFrom, dateTo, status];
}
