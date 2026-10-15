import 'package:equatable/equatable.dart';
import '../../models/attendance.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

class LoadAttendances extends AttendanceEvent {
  const LoadAttendances();
}

class AddAttendance extends AttendanceEvent {
  final Attendance attendance;

  const AddAttendance(this.attendance);

  @override
  List<Object?> get props => [attendance];
}

class UpdateAttendance extends AttendanceEvent {
  final Attendance attendance;

  const UpdateAttendance(this.attendance);

  @override
  List<Object?> get props => [attendance];
}

class DeleteAttendance extends AttendanceEvent {
  final String id;

  const DeleteAttendance(this.id);

  @override
  List<Object?> get props => [id];
}

class QuickCheckIn extends AttendanceEvent {
  final String employeeId;
  final String employeeName;
  final String? employeeAvatar;
  final DateTime? time;

  const QuickCheckIn({
    required this.employeeId,
    required this.employeeName,
    this.employeeAvatar,
    this.time,
  });

  @override
  List<Object?> get props => [employeeId, employeeName, employeeAvatar, time];
}

class QuickCheckOut extends AttendanceEvent {
  final String attendanceId;
  final DateTime? time;

  const QuickCheckOut({
    required this.attendanceId,
    this.time,
  });

  @override
  List<Object?> get props => [attendanceId, time];
}

class AddChatterMessage extends AttendanceEvent {
  final String attendanceId;
  final String authorName;
  final String message;

  const AddChatterMessage({
    required this.attendanceId,
    required this.authorName,
    required this.message,
  });

  @override
  List<Object?> get props => [attendanceId, authorName, message];
}
