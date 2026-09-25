import 'package:uuid/uuid.dart';

class CustomTaxRate {
  final String id;
  final String name;
  final String label;
  final String taxType; // 'percentage' or 'fixed'
  final double value;
  final String appliedWhen; // 'before_tva' or 'after_tva'
  final String usage; // 'all', 'sale', 'purchase'
  final int priority;
  final bool appliedToArticle;
  final DateTime createdAt;

  const CustomTaxRate({
    required this.id,
    required this.name,
    required this.label,
    this.taxType = 'percentage',
    required this.value,
    this.appliedWhen = 'before_tva',
    this.usage = 'all',
    this.priority = 0,
    this.appliedToArticle = false,
    required this.createdAt,
  });

  bool get isPercentage => taxType == 'percentage';
  bool get isFixed => taxType == 'fixed';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'taxType': taxType,
      'value': value,
      'appliedWhen': appliedWhen,
      'usage': usage,
      'priority': priority,
      'appliedToArticle': appliedToArticle,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomTaxRate.fromMap(Map<String, dynamic> map) {
    return CustomTaxRate(
      id: map['id']?.toString() ?? const Uuid().v4(),
      name: map['name']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      taxType: map['taxType']?.toString() ?? 'percentage',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      appliedWhen: map['appliedWhen']?.toString() ?? 'before_tva',
      usage: map['usage']?.toString() ?? 'all',
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      appliedToArticle: map['appliedToArticle'] == true,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  CustomTaxRate copyWith({
    String? id,
    String? name,
    String? label,
    String? taxType,
    double? value,
    String? appliedWhen,
    String? usage,
    int? priority,
    bool? appliedToArticle,
    DateTime? createdAt,
  }) {
    return CustomTaxRate(
      id: id ?? this.id,
      name: name ?? this.name,
      label: label ?? this.label,
      taxType: taxType ?? this.taxType,
      value: value ?? this.value,
      appliedWhen: appliedWhen ?? this.appliedWhen,
      usage: usage ?? this.usage,
      priority: priority ?? this.priority,
      appliedToArticle: appliedToArticle ?? this.appliedToArticle,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
