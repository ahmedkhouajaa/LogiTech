import 'package:intl/intl.dart';

/// Modèle pour les Jours Fériés Odoo ERP (Screenshots 1 & 2)
/// Utilisé dans le module Congés (Time Off) et répercuté sur le Pointage (Screenshots 3 & 4)
/// et le Bulletin de Paie sous 'Global Leaves' (Screenshot 5).
class PublicHoliday {
  final String id;
  final String name; // e.g. "Public Time Off", "revolution", "Jour de l'An", "fete d'année"
  final DateTime dateFrom; // Date de début
  final DateTime dateTo; // Date de fin
  final String workingHoursSchedule; // e.g. "Standard 40 hours/week"
  final String company; // e.g. "My Company (San Francisco)"
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  PublicHoliday({
    required this.id,
    required this.name,
    required this.dateFrom,
    required this.dateTo,
    this.workingHoursSchedule = 'Standard 40 hours/week',
    this.company = 'My Company (San Francisco)',
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get formattedDateFrom => DateFormat('dd/MM/yyyy HH:mm:ss').format(dateFrom);
  String get formattedDateTo => DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTo);
  int get year => dateFrom.year;

  /// Vérifie si une date donnée correspond à ce jour férié
  bool isDateMatching(DateTime date) {
    if (isDeleted) return false;
    final checkDate = DateTime(date.year, date.month, date.day);
    final startDate = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final endDate = DateTime(dateTo.year, dateTo.month, dateTo.day);

    return !checkDate.isBefore(startDate) && !checkDate.isAfter(endDate);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date_from': dateFrom.toIso8601String(),
      'date_to': dateTo.toIso8601String(),
      'working_hours_schedule': workingHoursSchedule,
      'company': company,
      'enterprise_id': enterpriseId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory PublicHoliday.fromMap(Map<String, dynamic> map) {
    return PublicHoliday(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      dateFrom: map['date_from'] != null
          ? DateTime.tryParse(map['date_from'] as String) ?? DateTime.now()
          : DateTime.now(),
      dateTo: map['date_to'] != null
          ? DateTime.tryParse(map['date_to'] as String) ?? DateTime.now()
          : DateTime.now(),
      workingHoursSchedule: (map['working_hours_schedule'] as String?) ?? 'Standard 40 hours/week',
      company: (map['company'] as String?) ?? 'My Company (San Francisco)',
      enterpriseId: map['enterprise_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
    );
  }

  PublicHoliday copyWith({
    String? id,
    String? name,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? workingHoursSchedule,
    String? company,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return PublicHoliday(
      id: id ?? this.id,
      name: name ?? this.name,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      workingHoursSchedule: workingHoursSchedule ?? this.workingHoursSchedule,
      company: company ?? this.company,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
