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

  const SupplierReturnsLoaded(this.returns);

  @override
  List<Object?> get props => [returns];
}

class SupplierReturnsError extends SupplierReturnsState {
  final String message;

  const SupplierReturnsError(this.message);

  @override
  List<Object?> get props => [message];
}
