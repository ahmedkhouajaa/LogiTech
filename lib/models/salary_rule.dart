import 'dart:convert';

/// Modèle pour une Règle Salariale (Salary Rule)
/// Conforme à la configuration Odoo ERP (Images 2 & 3)
class SalaryRule {
  final String id;
  final String name;
  final String category; // 'Allocation', 'Brut', 'Net', 'Déduction', 'Cotisation'
  final String code; // e.g. 'P1'
  final int sequence; // e.g. 5
  final bool isActive;
  final bool isNonPeriodic;
  final bool appearsOnPayslip;

  // Conditions
  final String conditionBasedOn; // 'Toujours vrai', 'Plage', 'Code Python'
  final String? conditionRangeVariable;
  final double? conditionRangeMin;
  final double? conditionRangeMax;
  final String? conditionPythonCode;

  // Calcul
  final String amountType; // 'Montant fixe', 'Pourcentage (%)', 'Code Python'
  final double fixedAmount;
  final double percentage;
  final double quantity;
  final String? pythonCode;

  // Contribution de la société
  final String? contributionRegister;

  // Comptabilité
  final String? debitAccount;
  final String? creditAccount;
  final String? analyticAccount;

  // Description / Notes
  final String? description;

  const SalaryRule({
    required this.id,
    required this.name,
    this.category = 'Allocation',
    required this.code,
    this.sequence = 5,
    this.isActive = true,
    this.isNonPeriodic = true,
    this.appearsOnPayslip = true,
    this.conditionBasedOn = 'Toujours vrai',
    this.conditionRangeVariable,
    this.conditionRangeMin,
    this.conditionRangeMax,
    this.conditionPythonCode,
    this.amountType = 'Montant fixe',
    this.fixedAmount = 0.0,
    this.percentage = 0.0,
    this.quantity = 1.0,
    this.pythonCode,
    this.contributionRegister,
    this.debitAccount,
    this.creditAccount,
    this.analyticAccount,
    this.description,
  });

  /// Calcule le montant effectif de la règle
  double computeAmount({double baseWage = 0.0}) {
    if (amountType == 'Pourcentage (%)') {
      return (baseWage * (percentage / 100.0)) * quantity;
    }
    return fixedAmount * quantity;
  }

  SalaryRule copyWith({
    String? id,
    String? name,
    String? category,
    String? code,
    int? sequence,
    bool? isActive,
    bool? isNonPeriodic,
    bool? appearsOnPayslip,
    String? conditionBasedOn,
    String? conditionRangeVariable,
    double? conditionRangeMin,
    double? conditionRangeMax,
    String? conditionPythonCode,
    String? amountType,
    double? fixedAmount,
    double? percentage,
    double? quantity,
    String? pythonCode,
    String? contributionRegister,
    String? debitAccount,
    String? creditAccount,
    String? analyticAccount,
    String? description,
  }) {
    return SalaryRule(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      code: code ?? this.code,
      sequence: sequence ?? this.sequence,
      isActive: isActive ?? this.isActive,
      isNonPeriodic: isNonPeriodic ?? this.isNonPeriodic,
      appearsOnPayslip: appearsOnPayslip ?? this.appearsOnPayslip,
      conditionBasedOn: conditionBasedOn ?? this.conditionBasedOn,
      conditionRangeVariable: conditionRangeVariable ?? this.conditionRangeVariable,
      conditionRangeMin: conditionRangeMin ?? this.conditionRangeMin,
      conditionRangeMax: conditionRangeMax ?? this.conditionRangeMax,
      conditionPythonCode: conditionPythonCode ?? this.conditionPythonCode,
      amountType: amountType ?? this.amountType,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      percentage: percentage ?? this.percentage,
      quantity: quantity ?? this.quantity,
      pythonCode: pythonCode ?? this.pythonCode,
      contributionRegister: contributionRegister ?? this.contributionRegister,
      debitAccount: debitAccount ?? this.debitAccount,
      creditAccount: creditAccount ?? this.creditAccount,
      analyticAccount: analyticAccount ?? this.analyticAccount,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'code': code,
      'sequence': sequence,
      'isActive': isActive,
      'isNonPeriodic': isNonPeriodic,
      'appearsOnPayslip': appearsOnPayslip,
      'conditionBasedOn': conditionBasedOn,
      'conditionRangeVariable': conditionRangeVariable,
      'conditionRangeMin': conditionRangeMin,
      'conditionRangeMax': conditionRangeMax,
      'conditionPythonCode': conditionPythonCode,
      'amountType': amountType,
      'fixedAmount': fixedAmount,
      'percentage': percentage,
      'quantity': quantity,
      'pythonCode': pythonCode,
      'contributionRegister': contributionRegister,
      'debitAccount': debitAccount,
      'creditAccount': creditAccount,
      'analyticAccount': analyticAccount,
      'description': description,
    };
  }

  factory SalaryRule.fromMap(Map<String, dynamic> map) {
    return SalaryRule(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'Allocation',
      code: map['code'] ?? '',
      sequence: (map['sequence'] as num?)?.toInt() ?? 5,
      isActive: map['isActive'] ?? true,
      isNonPeriodic: map['isNonPeriodic'] ?? true,
      appearsOnPayslip: map['appearsOnPayslip'] ?? true,
      conditionBasedOn: map['conditionBasedOn'] ?? 'Toujours vrai',
      conditionRangeVariable: map['conditionRangeVariable'],
      conditionRangeMin: (map['conditionRangeMin'] as num?)?.toDouble(),
      conditionRangeMax: (map['conditionRangeMax'] as num?)?.toDouble(),
      conditionPythonCode: map['conditionPythonCode'],
      amountType: map['amountType'] ?? 'Montant fixe',
      fixedAmount: (map['fixedAmount'] as num?)?.toDouble() ?? 0.0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      pythonCode: map['pythonCode'],
      contributionRegister: map['contributionRegister'],
      debitAccount: map['debitAccount'],
      creditAccount: map['creditAccount'],
      analyticAccount: map['analyticAccount'],
      description: map['description'],
    );
  }

  String toJson() => json.encode(toMap());

  factory SalaryRule.fromJson(String source) => SalaryRule.fromMap(json.decode(source));

  /// Règles par défaut intégrées
  static List<SalaryRule> get defaultRules => [
        const SalaryRule(
          id: 'rule_prime',
          name: 'prime',
          category: 'Allocation',
          code: 'P1',
          sequence: 5,
          isActive: true,
          isNonPeriodic: true,
          appearsOnPayslip: true,
          conditionBasedOn: 'Toujours vrai',
          amountType: 'Montant fixe',
          fixedAmount: 150.0,
          quantity: 1.0,
          contributionRegister: 'Cotisations patronales',
        ),
        const SalaryRule(
          id: 'rule_indemnite_transport',
          name: 'Indemnité de transport',
          category: 'Allocation',
          code: 'TRANS',
          sequence: 10,
          isActive: true,
          isNonPeriodic: false,
          appearsOnPayslip: true,
          conditionBasedOn: 'Toujours vrai',
          amountType: 'Montant fixe',
          fixedAmount: 50.0,
          quantity: 1.0,
          contributionRegister: 'Non imposable',
        ),
        const SalaryRule(
          id: 'rule_prime_rendement',
          name: 'Prime de rendement',
          category: 'Allocation',
          code: 'REND',
          sequence: 15,
          isActive: true,
          isNonPeriodic: true,
          appearsOnPayslip: true,
          conditionBasedOn: 'Toujours vrai',
          amountType: 'Montant fixe',
          fixedAmount: 100.0,
          quantity: 1.0,
        ),
        const SalaryRule(
          id: 'rule_prime_panier',
          name: 'Prime de panier',
          category: 'Allocation',
          code: 'PANIER',
          sequence: 20,
          isActive: true,
          isNonPeriodic: false,
          appearsOnPayslip: true,
          conditionBasedOn: 'Toujours vrai',
          amountType: 'Montant fixe',
          fixedAmount: 45.0,
          quantity: 1.0,
        ),
        const SalaryRule(
          id: 'rule_prime_presence',
          name: 'Prime d\'assiduité et présence',
          category: 'Allocation',
          code: 'PRES',
          sequence: 25,
          isActive: true,
          isNonPeriodic: true,
          appearsOnPayslip: true,
          conditionBasedOn: 'Toujours vrai',
          amountType: 'Montant fixe',
          fixedAmount: 70.0,
          quantity: 1.0,
        ),
      ];
}
