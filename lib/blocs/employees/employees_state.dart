import 'package:equatable/equatable.dart';
import '../../models/employee.dart';

abstract class EmployeesState extends Equatable {
  const EmployeesState();

  @override
  List<Object?> get props => [];
}

class EmployeesInitial extends EmployeesState {}

class EmployeesLoading extends EmployeesState {}

class EmployeesLoaded extends EmployeesState {
  final List<Employee> employees;
  final int totalCount;

  const EmployeesLoaded(this.employees, {this.totalCount = 0});

  EmployeesLoaded copyWith({
    List<Employee>? employees,
    int? totalCount,
  }) {
    return EmployeesLoaded(
      employees ?? this.employees,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [employees, totalCount];
}

class EmployeesError extends EmployeesState {
  final String message;

  const EmployeesError(this.message);

  @override
  List<Object?> get props => [message];
}
