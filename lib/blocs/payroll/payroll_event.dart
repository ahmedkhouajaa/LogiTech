import 'package:equatable/equatable.dart';
import '../../models/payslip.dart';
import '../../models/payslip_batch.dart';
import '../../models/employee.dart';

abstract class PayrollEvent extends Equatable {
  const PayrollEvent();

  @override
  List<Object?> get props => [];
}

class LoadPayslips extends PayrollEvent {
  final int? month;
  final int? year;

  const LoadPayslips({this.month, this.year});

  @override
  List<Object?> get props => [month, year];
}

class GenerateMonthlyPayslips extends PayrollEvent {
  final int month;
  final int year;
  final List<Employee> activeEmployees;

  const GenerateMonthlyPayslips({
    required this.month,
    required this.year,
    required this.activeEmployees,
  });

  @override
  List<Object?> get props => [month, year, activeEmployees];
}

class AddPayslip extends PayrollEvent {
  final Payslip payslip;

  const AddPayslip(this.payslip);

  @override
  List<Object?> get props => [payslip];
}

class UpdatePayslipStatus extends PayrollEvent {
  final String id;
  final String newStatus; // draft, validated, paid
  final DateTime? paymentDate;

  const UpdatePayslipStatus({
    required this.id,
    required this.newStatus,
    this.paymentDate,
  });

  @override
  List<Object?> get props => [id, newStatus, paymentDate];
}

class DeletePayslip extends PayrollEvent {
  final String id;

  const DeletePayslip(this.id);

  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// BATCH EVENTS (Lots de bulletins de paie)
// ---------------------------------------------------------------------------

class AddPayslipBatch extends PayrollEvent {
  final PayslipBatch batch;

  const AddPayslipBatch(this.batch);

  @override
  List<Object?> get props => [batch];
}

class UpdatePayslipBatch extends PayrollEvent {
  final PayslipBatch batch;

  const UpdatePayslipBatch(this.batch);

  @override
  List<Object?> get props => [batch];
}

class DeletePayslipBatch extends PayrollEvent {
  final String batchId;

  const DeletePayslipBatch(this.batchId);

  @override
  List<Object?> get props => [batchId];
}

class GenerateBatchPayslips extends PayrollEvent {
  final PayslipBatch batch;
  final List<Employee> selectedEmployees;

  const GenerateBatchPayslips({
    required this.batch,
    required this.selectedEmployees,
  });

  @override
  List<Object?> get props => [batch, selectedEmployees];
}
