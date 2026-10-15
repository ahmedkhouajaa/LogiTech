import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../models/attendance.dart';
import '../../services/firestore_repository.dart';
import '../../services/enterprise_service.dart';
import '../../services/error_handler.dart';
import '../../services/attendance_tolerance_service.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  AttendanceBloc() : super(AttendanceInitial()) {
    on<LoadAttendances>(_onLoadAttendances);
    on<AddAttendance>(_onAddAttendance);
    on<UpdateAttendance>(_onUpdateAttendance);
    on<DeleteAttendance>(_onDeleteAttendance);
    on<QuickCheckIn>(_onQuickCheckIn);
    on<QuickCheckOut>(_onQuickCheckOut);
    on<AddChatterMessage>(_onAddChatterMessage);
  }

  Future<void> _onLoadAttendances(LoadAttendances event, Emitter<AttendanceState> emit) async {
    final currentList = state is AttendanceLoaded ? (state as AttendanceLoaded).attendances : <Attendance>[];
    if (currentList.isEmpty) {
      emit(AttendanceLoading());
    }

    try {
      final currentEntId = EnterpriseService.instance.currentEnterpriseId;
      Query query = FirebaseFirestore.instance.collection('attendances');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      }

      final snapshot = await query.get();
      final attendances = <Attendance>[];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        final isDeleted = data['is_deleted'] == 1 || data['is_deleted'] == true;
        if (isDeleted) continue;

        try {
          final att = Attendance.fromMap(data);
          attendances.add(att);
        } catch (_) {}
      }

      // Tri par date d'arrivée décroissante (les plus récentes d'abord)
      attendances.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      emit(AttendanceLoaded(attendances: attendances));
    } catch (e) {
      emit(AttendanceError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onAddAttendance(AddAttendance event, Emitter<AttendanceState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;
    final item = event.attendance.copyWith(
      enterpriseId: (event.attendance.enterpriseId != null && event.attendance.enterpriseId!.isNotEmpty)
          ? event.attendance.enterpriseId
          : currentEntId,
      chatterMessages: event.attendance.chatterMessages.isNotEmpty
          ? event.attendance.chatterMessages
          : [
              {
                'authorName': 'Administrator',
                'date': DateTime.now().toIso8601String(),
                'message': 'Création d\'un nouvel enregistrement de présence...',
              }
            ],
    );

    try {
      await FirestoreRepository.instance.saveDocument('attendances', item.id, item.toMap());

      if (state is AttendanceLoaded) {
        final current = List<Attendance>.from((state as AttendanceLoaded).attendances);
        current.removeWhere((a) => a.id == item.id);
        current.insert(0, item);
        current.sort((a, b) => b.checkIn.compareTo(a.checkIn));
        emit((state as AttendanceLoaded).copyWith(attendances: current));
      } else {
        emit(AttendanceLoaded(attendances: [item]));
      }
    } catch (e) {
      emit(AttendanceError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onUpdateAttendance(UpdateAttendance event, Emitter<AttendanceState> emit) async {
    final item = event.attendance.copyWith(updatedAt: DateTime.now());

    try {
      await FirestoreRepository.instance.saveDocument('attendances', item.id, item.toMap());

      if (state is AttendanceLoaded) {
        final current = List<Attendance>.from((state as AttendanceLoaded).attendances);
        final index = current.indexWhere((a) => a.id == item.id);
        if (index != -1) {
          current[index] = item;
        } else {
          current.insert(0, item);
        }
        current.sort((a, b) => b.checkIn.compareTo(a.checkIn));
        emit((state as AttendanceLoaded).copyWith(attendances: current));
      }
    } catch (e) {
      emit(AttendanceError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onDeleteAttendance(DeleteAttendance event, Emitter<AttendanceState> emit) async {
    try {
      await FirestoreRepository.instance.saveDocument('attendances', event.id, {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (state is AttendanceLoaded) {
        final current = List<Attendance>.from((state as AttendanceLoaded).attendances);
        current.removeWhere((a) => a.id == event.id);
        emit((state as AttendanceLoaded).copyWith(attendances: current));
      }
    } catch (e) {
      emit(AttendanceError(ErrorHandler.parseError(e)));
    }
  }

  Future<void> _onQuickCheckIn(QuickCheckIn event, Emitter<AttendanceState> emit) async {
    final now = event.time ?? DateTime.now();
    final newId = const Uuid().v4();
    final theoStart = AttendanceToleranceService.instance.computeTheoreticalStart(now);
    final theoEnd = AttendanceToleranceService.instance.computeTheoreticalEnd(null, fallbackDate: now);
    final theoHours = AttendanceToleranceService.instance.computeTheoreticalHours(theoStart, theoEnd);

    final att = Attendance(
      id: newId,
      employeeId: event.employeeId,
      employeeName: event.employeeName,
      employeeAvatar: event.employeeAvatar,
      checkIn: now,
      theoreticalStart: theoStart,
      theoreticalEnd: theoEnd,
      theoreticalHours: theoHours,
      mode: 'Manuel',
      exitMode: 'Manuel',
      chatterMessages: [
        {
          'authorName': 'Administrator',
          'date': now.toIso8601String(),
          'message': 'Pointage d\'arrivée enregistré (${event.employeeName})',
        }
      ],
    );
    add(AddAttendance(att));
  }

  Future<void> _onQuickCheckOut(QuickCheckOut event, Emitter<AttendanceState> emit) async {
    if (state is! AttendanceLoaded) return;
    final current = (state as AttendanceLoaded).attendances;
    final index = current.indexWhere((a) => a.id == event.attendanceId);
    if (index == -1) return;

    final existing = current[index];
    final outTime = event.time ?? DateTime.now();
    final theoStart = existing.theoreticalStart ?? AttendanceToleranceService.instance.computeTheoreticalStart(existing.checkIn);
    final theoEnd = AttendanceToleranceService.instance.computeTheoreticalEnd(outTime, fallbackDate: existing.checkIn);
    final workedH = AttendanceToleranceService.instance.computeWorkedHours(existing.checkIn, outTime);
    final theoH = AttendanceToleranceService.instance.computeTheoreticalHours(theoStart, theoEnd);
    final overtimeH = workedH > theoH ? (workedH - theoH) : 0.0;

    final updated = existing.copyWith(
      checkOut: outTime,
      theoreticalStart: theoStart,
      theoreticalEnd: theoEnd,
      workedHours: workedH,
      theoreticalHours: theoH,
      overtimeHours: overtimeH,
      updatedAt: DateTime.now(),
      chatterMessages: [
        ...existing.chatterMessages,
        {
          'authorName': 'Administrator',
          'date': outTime.toIso8601String(),
          'message': 'Pointage de départ enregistré (${existing.employeeName})',
        }
      ],
    );

    add(UpdateAttendance(updated));
  }

  Future<void> _onAddChatterMessage(AddChatterMessage event, Emitter<AttendanceState> emit) async {
    if (state is! AttendanceLoaded) return;
    final current = (state as AttendanceLoaded).attendances;
    final index = current.indexWhere((a) => a.id == event.attendanceId);
    if (index == -1) return;

    final existing = current[index];
    final newMessages = List<Map<String, dynamic>>.from(existing.chatterMessages);
    newMessages.add({
      'authorName': event.authorName,
      'date': DateTime.now().toIso8601String(),
      'message': event.message,
    });

    final updated = existing.copyWith(
      chatterMessages: newMessages,
      updatedAt: DateTime.now(),
    );

    add(UpdateAttendance(updated));
  }
}
