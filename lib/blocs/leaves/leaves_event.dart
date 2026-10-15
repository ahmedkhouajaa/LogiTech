import 'package:equatable/equatable.dart';
import '../../models/leave_request.dart';

abstract class LeavesEvent extends Equatable {
  const LeavesEvent();

  @override
  List<Object?> get props => [];
}

class LoadLeaves extends LeavesEvent {
  final String? employeeId;
  final String? status;

  const LoadLeaves({this.employeeId, this.status});

  @override
  List<Object?> get props => [employeeId, status];
}

class AddLeaveRequest extends LeavesEvent {
  final LeaveRequest leaveRequest;

  const AddLeaveRequest(this.leaveRequest);

  @override
  List<Object?> get props => [leaveRequest];
}

class UpdateLeaveRequest extends LeavesEvent {
  final LeaveRequest leaveRequest;

  const UpdateLeaveRequest(this.leaveRequest);

  @override
  List<Object?> get props => [leaveRequest];
}


class UpdateLeaveStatus extends LeavesEvent {
  final String id;
  final String newStatus; // approved, rejected
  final String? rejectionReason;
  final String? approvedBy;

  const UpdateLeaveStatus({
    required this.id,
    required this.newStatus,
    this.rejectionReason,
    this.approvedBy,
  });

  @override
  List<Object?> get props => [id, newStatus, rejectionReason, approvedBy];
}

class DeleteLeaveRequest extends LeavesEvent {
  final String id;

  const DeleteLeaveRequest(this.id);

  @override
  List<Object?> get props => [id];
}
