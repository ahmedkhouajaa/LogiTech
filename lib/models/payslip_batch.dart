class PayslipBatch {
  final String id;
  final String name; // e.g. "12-2024"
  final int periodMonth;
  final int periodYear;
  final DateTime startDate;
  final DateTime endDate;
  final String salaryJournal; // default "Opérations diverses"
  final bool isCreditNote;
  final String status; // 'draft' (Brouillon) or 'closed' (Fermer)
  final List<String> payslipIds;
  final String? notes;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  PayslipBatch({
    required this.id,
    required this.name,
    required this.periodMonth,
    required this.periodYear,
    DateTime? startDate,
    DateTime? endDate,
    this.salaryJournal = 'Opérations diverses',
    this.isCreditNote = false,
    this.status = 'draft',
    this.payslipIds = const [],
    this.notes,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : startDate = startDate ?? DateTime(periodYear, periodMonth, 1),
        endDate = endDate ?? DateTime(periodYear, periodMonth + 1, 0),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'period_month': periodMonth,
      'period_year': periodYear,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'salary_journal': salaryJournal,
      'is_credit_note': isCreditNote ? 1 : 0,
      'status': status,
      'payslip_ids': payslipIds,
      'notes': notes,
      'enterprise_id': enterpriseId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory PayslipBatch.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    final pMonth = (map['period_month'] as num?)?.toInt() ?? now.month;
    final pYear = (map['period_year'] as num?)?.toInt() ?? now.year;

    DateTime? sDate;
    if (map['start_date'] != null) {
      try {
        sDate = DateTime.parse(map['start_date'].toString());
      } catch (_) {}
    }

    DateTime? eDate;
    if (map['end_date'] != null) {
      try {
        eDate = DateTime.parse(map['end_date'].toString());
      } catch (_) {}
    }

    List<String> pIds = [];
    if (map['payslip_ids'] is List) {
      pIds = (map['payslip_ids'] as List).map((e) => e.toString()).toList();
    }

    return PayslipBatch(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '$pMonth-$pYear',
      periodMonth: pMonth,
      periodYear: pYear,
      startDate: sDate,
      endDate: eDate,
      salaryJournal: map['salary_journal']?.toString() ?? 'Opérations diverses',
      isCreditNote: map['is_credit_note'] == 1 || map['is_credit_note'] == true,
      status: map['status']?.toString() ?? 'draft',
      payslipIds: pIds,
      notes: map['notes']?.toString(),
      enterpriseId: map['enterprise_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? now : now,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? now : now,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
    );
  }

  PayslipBatch copyWith({
    String? id,
    String? name,
    int? periodMonth,
    int? periodYear,
    DateTime? startDate,
    DateTime? endDate,
    String? salaryJournal,
    bool? isCreditNote,
    String? status,
    List<String>? payslipIds,
    String? notes,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return PayslipBatch(
      id: id ?? this.id,
      name: name ?? this.name,
      periodMonth: periodMonth ?? this.periodMonth,
      periodYear: periodYear ?? this.periodYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      salaryJournal: salaryJournal ?? this.salaryJournal,
      isCreditNote: isCreditNote ?? this.isCreditNote,
      status: status ?? this.status,
      payslipIds: payslipIds ?? this.payslipIds,
      notes: notes ?? this.notes,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  static const List<String> monthsFr = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];

  String get periodName {
    if (periodMonth >= 1 && periodMonth <= 12) {
      return '${monthsFr[periodMonth - 1]}-$periodYear';
    }
    return '$periodMonth-$periodYear';
  }
}
