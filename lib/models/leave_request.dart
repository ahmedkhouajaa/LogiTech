import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Modèle pour une Demande de Congé (Prise de congé) ou une Allocation de congé
/// Conforme à la structure Odoo ERP (Images 1, 2, 3, 4 & 5)
class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String? employeeAvatar;
  final String? description; // Ex: "Solde annuel" ou motif de prise
  final String leaveType; // "Congés payés", "Congé maladie", etc.
  final String allocationType; // "Allocation régulière", "Allocation du cumul de congés"
  final String mode; // "Par employé", "Par entreprise", "Par département", "Par catégorie d'employé"
  final DateTime startDate;
  final DateTime endDate;
  final DateTime validityStartDate; // Période de validité date début
  final DateTime? validityEndDate; // Période de validité date fin
  final bool isUnlimitedValidity; // "Sans limites"
  final double daysCount; // Durée / Montant en jours ou heures (ex. 1.0, 5.0, 20.0)
  final String unit; // "Jours", "Heures"
  final String? department; // If mode == Par département
  final String? employeeCategory; // If mode == Par catégorie
  final String status; // 'pending'/'to_approve' (À approuver), 'second_approval' (Deuxième approbation), 'approved' (Approuvé), 'draft' (Brouillon), 'rejected'/'refused' (Refusé)
  final bool isAllocation; // true = Allocation de crédit congé, false = Prise de congé
  final String? reason; // Justification / Motif
  final String? rejectionReason;
  final String? approvedBy;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.employeeAvatar,
    this.description,
    this.leaveType = 'Congés payés',
    this.allocationType = 'Allocation régulière',
    this.mode = 'Par employé',
    DateTime? startDate,
    DateTime? endDate,
    DateTime? validityStartDate,
    this.validityEndDate,
    this.isUnlimitedValidity = true,
    this.daysCount = 1.0,
    this.unit = 'Jours',
    this.department,
    this.employeeCategory,
    this.status = 'to_approve',
    this.isAllocation = false,
    this.reason,
    this.rejectionReason,
    this.approvedBy,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : startDate = startDate ?? validityStartDate ?? DateTime.now(),
        endDate = endDate ?? validityEndDate ?? DateTime.now().add(const Duration(days: 1)),
        validityStartDate = validityStartDate ?? startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isApproved => status == 'approved' || status == 'validated';
  bool get isPending => status == 'pending' || status == 'to_approve';
  bool get isSecondApproval => status == 'second_approval';
  bool get isDraft => status == 'draft';
  bool get isRejected => status == 'rejected' || status == 'refused';

  String get statusDisplay {
    if (isApproved) return 'Approuvé';
    if (isSecondApproval) return 'Deuxième approbation';
    if (isPending) return 'À approuver';
    if (isDraft) return 'Brouillon';
    return 'Refusé';
  }

  Color get statusColor {
    if (isApproved) return const Color(0xFF10B981); // Green
    if (isSecondApproval) return const Color(0xFFD97706); // Amber / Orange (Image 5)
    if (isPending) return const Color(0xFFD97706); // Amber / Orange (Image 5)
    if (isDraft) return const Color(0xFF64748B); // Slate Gray
    return const Color(0xFFEF4444); // Red
  }

  Color get statusBgColor {
    if (isApproved) return const Color(0xFF10B981);
    if (isSecondApproval) return const Color(0xFFF59E0B);
    if (isPending) return const Color(0xFFF59E0B);
    if (isDraft) return const Color(0xFFE2E8F0);
    return const Color(0xFFEF4444);
  }

  String get displayDescription {
    if (description != null && description!.trim().isNotEmpty) {
      return description!.trim();
    }
    return isAllocation ? 'Solde annuel' : 'Congé $leaveType';
  }

  String formatStartWithTime() {
    return '${DateFormat('dd/MM/yyyy').format(startDate)} 08:00:00';
  }

  String formatEndWithTime() {
    return '${DateFormat('dd/MM/yyyy').format(endDate)} 17:00:00';
  }

  String formatDuration() {
    final d = daysCount.truncateToDouble() == daysCount ? daysCount.toInt().toString() : daysCount.toStringAsFixed(1);
    return '$d ${unit.toLowerCase()}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'employee_avatar': employeeAvatar,
        'description': description,
        'leave_type': leaveType,
        'allocation_type': allocationType,
        'mode': mode,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'validity_start_date': validityStartDate.toIso8601String(),
        'validity_end_date': validityEndDate?.toIso8601String(),
        'is_unlimited_validity': isUnlimitedValidity ? 1 : 0,
        'days_count': daysCount,
        'unit': unit,
        'department': department,
        'employee_category': employeeCategory,
        'status': status,
        'is_allocation': isAllocation ? 1 : 0,
        'reason': reason,
        'rejection_reason': rejectionReason,
        'approved_by': approvedBy,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory LeaveRequest.fromMap(Map<String, dynamic> map) => LeaveRequest(
        id: map['id']?.toString() ?? '',
        employeeId: (map['employee_id'] ?? map['employeeId'])?.toString() ?? '',
        employeeName: (map['employee_name'] ?? map['employeeName'])?.toString() ?? '',
        employeeAvatar: map['employee_avatar']?.toString(),
        description: map['description']?.toString(),
        leaveType: (map['leave_type'] ?? map['leaveType'])?.toString() ?? 'Congés payés',
        allocationType: (map['allocation_type'] ?? map['allocationType'])?.toString() ?? 'Allocation régulière',
        mode: (map['mode'])?.toString() ?? 'Par employé',
        startDate: DateTime.tryParse(map['start_date']?.toString() ?? ''),
        endDate: DateTime.tryParse(map['end_date']?.toString() ?? ''),
        validityStartDate: DateTime.tryParse(map['validity_start_date']?.toString() ?? ''),
        validityEndDate: DateTime.tryParse(map['validity_end_date']?.toString() ?? ''),
        isUnlimitedValidity: map['is_unlimited_validity'] == 1 ||
            map['is_unlimited_validity'] == true ||
            map['isUnlimitedValidity'] == true ||
            map['validity_end_date'] == null,
        daysCount: (map['days_count'] ?? map['daysCount'] as num?)?.toDouble() ?? 1.0,
        unit: map['unit']?.toString() ?? 'Jours',
        department: map['department']?.toString(),
        employeeCategory: (map['employee_category'] ?? map['employeeCategory'])?.toString(),
        status: map['status']?.toString() ?? 'to_approve',
        isAllocation: map['is_allocation'] == 1 || map['is_allocation'] == true || map['isAllocation'] == true,
        reason: map['reason']?.toString(),
        rejectionReason: (map['rejection_reason'] ?? map['rejectionReason'])?.toString(),
        approvedBy: (map['approved_by'] ?? map['approvedBy'])?.toString(),
        enterpriseId: (map['enterprise_id'] ?? map['enterpriseId'])?.toString(),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == true,
      );

  LeaveRequest copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? employeeAvatar,
    String? description,
    String? leaveType,
    String? allocationType,
    String? mode,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? validityStartDate,
    DateTime? validityEndDate,
    bool? isUnlimitedValidity,
    double? daysCount,
    String? unit,
    String? department,
    String? employeeCategory,
    String? status,
    bool? isAllocation,
    String? reason,
    String? rejectionReason,
    String? approvedBy,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      LeaveRequest(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        employeeName: employeeName ?? this.employeeName,
        employeeAvatar: employeeAvatar ?? this.employeeAvatar,
        description: description ?? this.description,
        leaveType: leaveType ?? this.leaveType,
        allocationType: allocationType ?? this.allocationType,
        mode: mode ?? this.mode,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        validityStartDate: validityStartDate ?? this.validityStartDate,
        validityEndDate: validityEndDate ?? this.validityEndDate,
        isUnlimitedValidity: isUnlimitedValidity ?? this.isUnlimitedValidity,
        daysCount: daysCount ?? this.daysCount,
        unit: unit ?? this.unit,
        department: department ?? this.department,
        employeeCategory: employeeCategory ?? this.employeeCategory,
        status: status ?? this.status,
        isAllocation: isAllocation ?? this.isAllocation,
        reason: reason ?? this.reason,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        approvedBy: approvedBy ?? this.approvedBy,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  String toJson() => json.encode(toMap());

  factory LeaveRequest.fromJson(String source) => LeaveRequest.fromMap(json.decode(source));
}
