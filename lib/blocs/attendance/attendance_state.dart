import 'package:equatable/equatable.dart';
import '../../models/attendance.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class AttendanceLoaded extends AttendanceState {
  final List<Attendance> attendances;
  final DateTime? filterDate;
  final String searchQuery;
  final String? filterEmployeeId;

  const AttendanceLoaded({
    required this.attendances,
    this.filterDate,
    this.searchQuery = '',
    this.filterEmployeeId,
  });

  AttendanceLoaded copyWith({
    List<Attendance>? attendances,
    DateTime? filterDate,
    String? searchQuery,
    String? filterEmployeeId,
  }) {
    return AttendanceLoaded(
      attendances: attendances ?? this.attendances,
      filterDate: filterDate ?? this.filterDate,
      searchQuery: searchQuery ?? this.searchQuery,
      filterEmployeeId: filterEmployeeId ?? this.filterEmployeeId,
    );
  }

  @override
  List<Object?> get props => [attendances, filterDate, searchQuery, filterEmployeeId];
}

class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError(this.message);

  @override
  List<Object?> get props => [message];
}
