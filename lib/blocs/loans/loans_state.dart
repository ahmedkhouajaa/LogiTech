import 'package:equatable/equatable.dart';
import '../../models/employee_loan.dart';

abstract class LoansState extends Equatable {
  const LoansState();

  @override
  List<Object?> get props => [];
}

class LoansInitial extends LoansState {}

class LoansLoading extends LoansState {}

class LoansLoaded extends LoansState {
  final List<EmployeeLoan> loans;
  final int totalCount;

  const LoansLoaded(this.loans, {this.totalCount = 0});

  LoansLoaded copyWith({
    List<EmployeeLoan>? loans,
    int? totalCount,
  }) {
    return LoansLoaded(
      loans ?? this.loans,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [loans, totalCount];
}

class LoansError extends LoansState {
  final String message;

  const LoansError(this.message);

  @override
  List<Object?> get props => [message];
}
