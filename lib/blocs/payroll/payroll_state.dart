import 'package:equatable/equatable.dart';
import '../../models/payslip.dart';
import '../../models/payslip_batch.dart';

abstract class PayrollState extends Equatable {
  const PayrollState();

  @override
  List<Object?> get props => [];
}

class PayrollInitial extends PayrollState {}

class PayrollLoading extends PayrollState {}

class PayrollLoaded extends PayrollState {
  final List<Payslip> payslips;
  final List<PayslipBatch> batches;

  const PayrollLoaded(this.payslips, {this.batches = const []});

  PayrollLoaded copyWith({List<Payslip>? payslips, List<PayslipBatch>? batches}) {
    return PayrollLoaded(
      payslips ?? this.payslips,
      batches: batches ?? this.batches,
    );
  }

  @override
  List<Object?> get props => [payslips, batches];
}

class PayrollError extends PayrollState {
  final String message;

  const PayrollError(this.message);

  @override
  List<Object?> get props => [message];
}
