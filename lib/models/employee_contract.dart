class EmployeeContract {
  final String id;
  final String reference; // e.g., CTR/2026/001
  final String employeeId;
  final String employeeName;
  final DateTime hiringDate;
  final DateTime startDate;
  final DateTime? endDate;
  final String workingHoursType; // Mensuel, Hebdomadaire
  final String workingHoursStandard; // Standard 40 h, Standard 48 h
  final double overtimeHourlyRate; // Taux Horaire des Heures Supplémentaires
  final double dailyRate; // Taux par Jour
  final String salaryStructureType; // Employee, Cadre, Ouvrier
  final String department;
  final String jobTitle;
  final String contractType; // CDI, CDD, SIVP, Stage, Freelance
  final String paymentMethod; // Virement, Chèque, Espèces
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankAccountHolder;
  final String? analyticAccount; // ACCOUNTING
  final String? salaryJournal; // ACCOUNTING
  final double wage; // Salaire brut / mois
  final double wageMonths; // e.g. 12, 13, 13.50
  final String wageStructure; // Contrat de travail à durée indéterminée
  final String? wageScaleCategory; // Catégorie d'Échelle Salariale
  final String? salaryScale; // Échelle Salariale
  final String? hierarchicalLevel; // Niveau Hiérarchique
  final DateTime? affectationDate; // Date d'Affectation
  final int trialPeriodMonths; // Période d'essai en mois
  final String? notes; // Détails du contrat
  final String status; // active, draft, expired, terminated
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  EmployeeContract({
    required this.id,
    required this.reference,
    required this.employeeId,
    required this.employeeName,
    DateTime? hiringDate,
    DateTime? startDate,
    this.endDate,
    this.workingHoursType = 'Mensuel',
    this.workingHoursStandard = 'Standard 40 h',
    this.overtimeHourlyRate = 0.0,
    this.dailyRate = 0.0,
    this.salaryStructureType = 'Employee',
    this.department = 'Administration',
    this.jobTitle = 'Poste',
    this.contractType = 'CDI',
    this.paymentMethod = 'Virement',
    this.bankAccountNumber,
    this.bankName,
    this.bankAccountHolder,
    this.analyticAccount,
    this.salaryJournal,
    this.wage = 0.0,
    this.wageMonths = 12.0,
    this.wageStructure = 'Contrat de travail à durée indéterminée',
    this.wageScaleCategory,
    this.salaryScale = '0',
    this.hierarchicalLevel = '0',
    this.affectationDate,
    this.trialPeriodMonths = 3,
    this.notes,
    this.status = 'active',
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : hiringDate = hiringDate ?? DateTime.now(),
        startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'reference': reference,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'hiring_date': hiringDate.toIso8601String(),
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'working_hours_type': workingHoursType,
        'working_hours_standard': workingHoursStandard,
        'overtime_hourly_rate': overtimeHourlyRate,
        'daily_rate': dailyRate,
        'salary_structure_type': salaryStructureType,
        'department': department,
        'job_title': jobTitle,
        'contract_type': contractType,
        'payment_method': paymentMethod,
        'bank_account_number': bankAccountNumber,
        'bank_name': bankName,
        'bank_account_holder': bankAccountHolder,
        'analytic_account': analyticAccount,
        'salary_journal': salaryJournal,
        'wage': wage,
        'wage_months': wageMonths,
        'wage_structure': wageStructure,
        'wage_scale_category': wageScaleCategory,
        'salary_scale': salaryScale,
        'hierarchical_level': hierarchicalLevel,
        'affectation_date': affectationDate?.toIso8601String(),
        'trial_period_months': trialPeriodMonths,
        'notes': notes,
        'status': status,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory EmployeeContract.fromMap(Map<String, dynamic> map) => EmployeeContract(
        id: map['id']?.toString() ?? '',
        reference: map['reference']?.toString() ?? 'CTR/2026/001',
        employeeId: (map['employee_id'] ?? map['employeeId'])?.toString() ?? '',
        employeeName: (map['employee_name'] ?? map['employeeName'])?.toString() ?? '',
        hiringDate: DateTime.tryParse(map['hiring_date']?.toString() ?? '') ?? DateTime.now(),
        startDate: DateTime.tryParse(map['start_date']?.toString() ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(map['end_date']?.toString() ?? ''),
        workingHoursType: map['working_hours_type']?.toString() ?? 'Mensuel',
        workingHoursStandard: map['working_hours_standard']?.toString() ?? 'Standard 40 h',
        overtimeHourlyRate: (map['overtime_hourly_rate'] as num?)?.toDouble() ?? 0.0,
        dailyRate: (map['daily_rate'] as num?)?.toDouble() ?? 0.0,
        salaryStructureType: map['salary_structure_type']?.toString() ?? 'Employee',
        department: map['department']?.toString() ?? 'Administration',
        jobTitle: (map['job_title'] ?? map['jobTitle'])?.toString() ?? 'Poste',
        contractType: (map['contract_type'] ?? map['contractType'])?.toString() ?? 'CDI',
        paymentMethod: (map['payment_method'] ?? map['paymentMethod'])?.toString() ?? 'Virement',
        bankAccountNumber: map['bank_account_number']?.toString(),
        bankName: map['bank_name']?.toString(),
        bankAccountHolder: map['bank_account_holder']?.toString(),
        analyticAccount: map['analytic_account']?.toString(),
        salaryJournal: map['salary_journal']?.toString(),
        wage: (map['wage'] as num?)?.toDouble() ?? (map['base_salary'] as num?)?.toDouble() ?? 0.0,
        wageMonths: (map['wage_months'] as num?)?.toDouble() ?? 12.0,
        wageStructure: map['wage_structure']?.toString() ?? 'Contrat de travail à durée indéterminée',
        wageScaleCategory: map['wage_scale_category']?.toString(),
        salaryScale: map['salary_scale']?.toString() ?? '0',
        hierarchicalLevel: map['hierarchical_level']?.toString() ?? '0',
        affectationDate: DateTime.tryParse(map['affectation_date']?.toString() ?? ''),
        trialPeriodMonths: (map['trial_period_months'] as num?)?.toInt() ?? 3,
        notes: map['notes']?.toString(),
        status: map['status']?.toString() ?? 'active',
        enterpriseId: (map['enterprise_id'] ?? map['enterpriseId'])?.toString(),
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
        isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true || map['isDeleted'] == true,
      );

  EmployeeContract copyWith({
    String? id,
    String? reference,
    String? employeeId,
    String? employeeName,
    DateTime? hiringDate,
    DateTime? startDate,
    DateTime? endDate,
    String? workingHoursType,
    String? workingHoursStandard,
    double? overtimeHourlyRate,
    double? dailyRate,
    String? salaryStructureType,
    String? department,
    String? jobTitle,
    String? contractType,
    String? paymentMethod,
    String? bankAccountNumber,
    String? bankName,
    String? bankAccountHolder,
    String? analyticAccount,
    String? salaryJournal,
    double? wage,
    double? wageMonths,
    String? wageStructure,
    String? wageScaleCategory,
    String? salaryScale,
    String? hierarchicalLevel,
    DateTime? affectationDate,
    int? trialPeriodMonths,
    String? notes,
    String? status,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) =>
      EmployeeContract(
        id: id ?? this.id,
        reference: reference ?? this.reference,
        employeeId: employeeId ?? this.employeeId,
        employeeName: employeeName ?? this.employeeName,
        hiringDate: hiringDate ?? this.hiringDate,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        workingHoursType: workingHoursType ?? this.workingHoursType,
        workingHoursStandard: workingHoursStandard ?? this.workingHoursStandard,
        overtimeHourlyRate: overtimeHourlyRate ?? this.overtimeHourlyRate,
        dailyRate: dailyRate ?? this.dailyRate,
        salaryStructureType: salaryStructureType ?? this.salaryStructureType,
        department: department ?? this.department,
        jobTitle: jobTitle ?? this.jobTitle,
        contractType: contractType ?? this.contractType,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
        bankName: bankName ?? this.bankName,
        bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
        analyticAccount: analyticAccount ?? this.analyticAccount,
        salaryJournal: salaryJournal ?? this.salaryJournal,
        wage: wage ?? this.wage,
        wageMonths: wageMonths ?? this.wageMonths,
        wageStructure: wageStructure ?? this.wageStructure,
        wageScaleCategory: wageScaleCategory ?? this.wageScaleCategory,
        salaryScale: salaryScale ?? this.salaryScale,
        hierarchicalLevel: hierarchicalLevel ?? this.hierarchicalLevel,
        affectationDate: affectationDate ?? this.affectationDate,
        trialPeriodMonths: trialPeriodMonths ?? this.trialPeriodMonths,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
