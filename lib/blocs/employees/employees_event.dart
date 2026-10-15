import 'package:equatable/equatable.dart';
import '../../models/employee.dart';

abstract class EmployeesEvent extends Equatable {
  const EmployeesEvent();

  @override
  List<Object?> get props => [];
}

class LoadEmployees extends EmployeesEvent {
  final String? searchQuery;
  final String? department;
  final bool? onlyActive;

  const LoadEmployees({this.searchQuery, this.department, this.onlyActive});

  @override
  List<Object?> get props => [searchQuery, department, onlyActive];
}

class AddEmployee extends EmployeesEvent {
  final Employee employee;

  const AddEmployee(this.employee);

  @override
  List<Object?> get props => [employee];
}

class UpdateEmployee extends EmployeesEvent {
  final Employee employee;

  const UpdateEmployee(this.employee);

  @override
  List<Object?> get props => [employee];
}

class DeleteEmployee extends EmployeesEvent {
  final String id;

  const DeleteEmployee(this.id);

  @override
  List<Object?> get props => [id];
}
