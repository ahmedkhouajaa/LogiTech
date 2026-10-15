import 'package:equatable/equatable.dart';
import '../../models/employee_contract.dart';

abstract class ContractsEvent extends Equatable {
  const ContractsEvent();

  @override
  List<Object?> get props => [];
}

class LoadContracts extends ContractsEvent {
  final String? searchQuery;
  final String? employeeId;
  final String? status;

  const LoadContracts({this.searchQuery, this.employeeId, this.status});

  @override
  List<Object?> get props => [searchQuery, employeeId, status];
}

class AddContract extends ContractsEvent {
  final EmployeeContract contract;

  const AddContract(this.contract);

  @override
  List<Object?> get props => [contract];
}

class UpdateContract extends ContractsEvent {
  final EmployeeContract contract;

  const UpdateContract(this.contract);

  @override
  List<Object?> get props => [contract];
}

class DeleteContract extends ContractsEvent {
  final String id;

  const DeleteContract(this.id);

  @override
  List<Object?> get props => [id];
}
