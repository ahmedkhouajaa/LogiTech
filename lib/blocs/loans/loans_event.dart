import 'package:equatable/equatable.dart';
import '../../models/employee_loan.dart';

abstract class LoansEvent extends Equatable {
  const LoansEvent();

  @override
  List<Object?> get props => [];
}

class LoadLoans extends LoansEvent {
  final String? employeeId;
  final String? status;
  final String? searchQuery;

  const LoadLoans({
    this.employeeId,
    this.status,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [employeeId, status, searchQuery];
}

class AddLoan extends LoansEvent {
  final EmployeeLoan loan;

  const AddLoan(this.loan);

  @override
  List<Object?> get props => [loan];
}

class UpdateLoan extends LoansEvent {
  final EmployeeLoan loan;

  const UpdateLoan(this.loan);

  @override
  List<Object?> get props => [loan];
}

class DeleteLoan extends LoansEvent {
  final String id;

  const DeleteLoan(this.id);

  @override
  List<Object?> get props => [id];
}

class PayLoanRepayment extends LoansEvent {
  final String loanId;
  final String repaymentId;
  final String? payslipId;
  final String? payslipReference;

  const PayLoanRepayment({
    required this.loanId,
    required this.repaymentId,
    this.payslipId,
    this.payslipReference,
  });

  @override
  List<Object?> get props => [loanId, repaymentId, payslipId, payslipReference];
}

class UnlinkLoanRepayment extends LoansEvent {
  final String loanId;
  final String repaymentId;

  const UnlinkLoanRepayment({
    required this.loanId,
    required this.repaymentId,
  });

  @override
  List<Object?> get props => [loanId, repaymentId];
}
