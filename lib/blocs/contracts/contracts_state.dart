import 'package:equatable/equatable.dart';
import '../../models/employee_contract.dart';

abstract class ContractsState extends Equatable {
  const ContractsState();

  @override
  List<Object?> get props => [];
}

class ContractsInitial extends ContractsState {}

class ContractsLoading extends ContractsState {}

class ContractsLoaded extends ContractsState {
  final List<EmployeeContract> contracts;
  final int totalCount;

  const ContractsLoaded(this.contracts, {this.totalCount = 0});

  ContractsLoaded copyWith({
    List<EmployeeContract>? contracts,
    int? totalCount,
  }) {
    return ContractsLoaded(
      contracts ?? this.contracts,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [contracts, totalCount];
}

class ContractsError extends ContractsState {
  final String message;

  const ContractsError(this.message);

  @override
  List<Object?> get props => [message];
}
