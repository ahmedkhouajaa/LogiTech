import 'dart:convert';
import 'package:intl/intl.dart';

/// Modèle pour un Enregistrement de Présence / Pointage Manuel
/// Conforme à la structure Odoo ERP Présences (Screenshots 1, 2, 3)
/// avec prise en charge des intervalles de tolérance d'entrée et de sortie.
class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final String? employeeAvatar;
  final DateTime checkIn; // Arrivée
  final DateTime? checkOut; // Départ (nullable si toujours en cours)
  final double workedHours; // Heures travaillées (déduction pause déjeuner standard)
  final double overtimeHours; // Heures supplémentaires
  final bool hasOvertimeApproval; // Autorisation Heures Supplémentaires
  final String? overtimeRateId; // ID du Taux d'Heures Supplémentaires (e.g. rate_1_5)
  final String? overtimeRateName; // Nom du Taux d'Heures Supplémentaires (e.g. "x 1.5", "2", "X2")
  final double? overtimeRateMultiplier; // Multiplicateur (e.g. 1.5, 2.0)
  final DateTime? theoreticalStart; // Début théorique (calculé avec tolérance d'entrée)
  final DateTime? theoreticalEnd; // Fin théorique (calculé avec tolérance de sortie)
  final double theoreticalHours; // Heures théoriques dues
  final String mode; // Mode d'arrivée: "Manuel", "Badge", "Kiosque", "Mobile"
  final String exitMode; // Mode de départ: "Manuel", "Badge", "Kiosque", "Mobile"
  final String? notes;
  final List<Map<String, dynamic>> chatterMessages; // Historique Odoo Chatter
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.employeeAvatar,
    required this.checkIn,
    this.checkOut,
    double? workedHours,
    double? overtimeHours,
    this.hasOvertimeApproval = false,
    this.overtimeRateId,
    this.overtimeRateName,
    this.overtimeRateMultiplier,
    this.theoreticalStart,
    this.theoreticalEnd,
    this.theoreticalHours = 8.0,
    this.mode = 'Manuel',
    this.exitMode = 'Manuel',
    this.notes,
    List<Map<String, dynamic>>? chatterMessages,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : workedHours = workedHours ?? _calculateWorkedHours(checkIn, checkOut),
        overtimeHours = overtimeHours ?? _calculateOvertime(workedHours ?? _calculateWorkedHours(checkIn, checkOut), theoreticalHours),
        chatterMessages = chatterMessages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Calcule les heures effectives travaillées avec déduction de la pause de 60 min
  /// si la journée fait au moins 6 heures (360 min)
  /// - Ex Capture 1: 08:00 à 17:00 -> 9h - 1h = 8h00 travaillées = 08:00
  /// - Ex Capture 3: 08:12 à 17:00 -> 8h48 - 1h = 7h48 travaillées = 07:48
  static double _calculateWorkedHours(DateTime inTime, DateTime? outTime, {int breakMinutes = 60}) {
    if (outTime == null) return 0.0;
    final diffSec = outTime.difference(inTime).inSeconds;
    if (diffSec <= 0) return 0.0;
    final totalMin = diffSec / 60.0;
    double netMin = totalMin;
    if (totalMin >= 360 && breakMinutes > 0) {
      netMin = totalMin - breakMinutes;
    }
    if (netMin < 0) netMin = 0;
    return netMin / 60.0;
  }

  static double _calculateOvertime(double worked, double theoretical) {
    if (worked <= theoretical) return 0.0;
    return worked - theoretical;
  }

  /// Formate une durée en décimal (ex: 7.8 pour 07:48, 8.0 pour 08:00) en chaîne Odoo HH:mm
  static String formatDuration(double hours) {
    if (hours.isNaN || hours <= 0) return '00:00';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Formate une durée en décimal en chaîne Odoo HH:mm:ss
  static String formatDurationWithSeconds(double hours) {
    if (hours.isNaN || hours <= 0) return '00:00:00';
    final totalSeconds = (hours * 3600).round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Parse une chaîne "HH:mm" ou "HH:mm:ss" en nombre décimal d'heures
  static double parseDuration(String str) {
    final parts = str.trim().split(':');
    if (parts.length >= 2) {
      final h = double.tryParse(parts[0]) ?? 0;
      final m = double.tryParse(parts[1]) ?? 0;
      final s = parts.length > 2 ? (double.tryParse(parts[2]) ?? 0) : 0;
      return h + (m / 60.0) + (s / 3600.0);
    }
    return double.tryParse(str) ?? 0.0;
  }

  String get formattedCheckIn => DateFormat('dd/MM/yyyy HH:mm:ss').format(checkIn);
  String get formattedCheckOut => checkOut != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(checkOut!) : '';
  String get formattedCheckInTime => DateFormat('HH:mm').format(checkIn);
  String get formattedCheckOutTime => checkOut != null ? DateFormat('HH:mm').format(checkOut!) : '17:00';
  String get formattedWorkedHours => formatDuration(workedHours);
  String get formattedOvertimeHours => formatDuration(overtimeHours);
  String get formattedTheoreticalHours => formatDuration(theoreticalHours);

  double get weightedOvertimeHours => overtimeHours * (overtimeRateMultiplier ?? 1.0);

  /// Titre exact Odoo ERP (Screenshots 1 & 3):
  /// e.g. "08:00 : (08:00-17:00)" ou "07:48 : (08:12-17:00)"
  String get odooHeaderTitle {
    final outStr = checkOut != null ? DateFormat('HH:mm').format(checkOut!) : '17:00';
    return '$formattedWorkedHours : ($formattedCheckInTime-$outStr)';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_avatar': employeeAvatar,
      'check_in': checkIn.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'worked_hours': workedHours,
      'overtime_hours': overtimeHours,
      'has_overtime_approval': hasOvertimeApproval ? 1 : 0,
      'overtime_rate_id': overtimeRateId,
      'overtime_rate_name': overtimeRateName,
      'overtime_rate_multiplier': overtimeRateMultiplier,
      'theoretical_start': theoreticalStart?.toIso8601String(),
      'theoretical_end': theoreticalEnd?.toIso8601String(),
      'theoretical_hours': theoreticalHours,
      'mode': mode,
      'exit_mode': exitMode,
      'notes': notes,
      'chatter_messages': jsonEncode(chatterMessages),
      'enterprise_id': enterpriseId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    List<Map<String, dynamic>> parsedChatter = [];
    if (map['chatter_messages'] != null) {
      try {
        if (map['chatter_messages'] is String) {
          final decoded = jsonDecode(map['chatter_messages'] as String);
          if (decoded is List) {
            parsedChatter = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } else if (map['chatter_messages'] is List) {
          parsedChatter = (map['chatter_messages'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {}
    }

    return Attendance(
      id: map['id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      employeeName: map['employee_name']?.toString() ?? '',
      employeeAvatar: map['employee_avatar']?.toString(),
      checkIn: map['check_in'] != null ? DateTime.tryParse(map['check_in'].toString()) ?? now : now,
      checkOut: map['check_out'] != null ? DateTime.tryParse(map['check_out'].toString()) : null,
      workedHours: (map['worked_hours'] as num?)?.toDouble(),
      overtimeHours: (map['overtime_hours'] as num?)?.toDouble(),
      hasOvertimeApproval: map['has_overtime_approval'] == 1 || map['has_overtime_approval'] == true,
      overtimeRateId: map['overtime_rate_id']?.toString(),
      overtimeRateName: map['overtime_rate_name']?.toString(),
      overtimeRateMultiplier: (map['overtime_rate_multiplier'] as num?)?.toDouble(),
      theoreticalStart: map['theoretical_start'] != null ? DateTime.tryParse(map['theoretical_start'].toString()) : null,
      theoreticalEnd: map['theoretical_end'] != null ? DateTime.tryParse(map['theoretical_end'].toString()) : null,
      theoreticalHours: (map['theoretical_hours'] as num?)?.toDouble() ?? 8.0,
      mode: map['mode']?.toString() ?? 'Manuel',
      exitMode: map['exit_mode']?.toString() ?? 'Manuel',
      notes: map['notes']?.toString(),
      chatterMessages: parsedChatter,
      enterpriseId: map['enterprise_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? now : now,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? now : now,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
    );
  }

  Attendance copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? employeeAvatar,
    DateTime? checkIn,
    DateTime? checkOut,
    double? workedHours,
    double? overtimeHours,
    bool? hasOvertimeApproval,
    String? overtimeRateId,
    String? overtimeRateName,
    double? overtimeRateMultiplier,
    DateTime? theoreticalStart,
    DateTime? theoreticalEnd,
    double? theoreticalHours,
    String? mode,
    String? exitMode,
    String? notes,
    List<Map<String, dynamic>>? chatterMessages,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Attendance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeAvatar: employeeAvatar ?? this.employeeAvatar,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      workedHours: workedHours ?? this.workedHours,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      hasOvertimeApproval: hasOvertimeApproval ?? this.hasOvertimeApproval,
      overtimeRateId: overtimeRateId ?? this.overtimeRateId,
      overtimeRateName: overtimeRateName ?? this.overtimeRateName,
      overtimeRateMultiplier: overtimeRateMultiplier ?? this.overtimeRateMultiplier,
      theoreticalStart: theoreticalStart ?? this.theoreticalStart,
      theoreticalEnd: theoreticalEnd ?? this.theoreticalEnd,
      theoreticalHours: theoreticalHours ?? this.theoreticalHours,
      mode: mode ?? this.mode,
      exitMode: exitMode ?? this.exitMode,
      notes: notes ?? this.notes,
      chatterMessages: chatterMessages ?? this.chatterMessages,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
