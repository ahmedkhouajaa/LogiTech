enum WorkcenterType {
  machine,
  workshop,
  manual;

  String get label {
    switch (this) {
      case WorkcenterType.machine:
        return 'Machine';
      case WorkcenterType.workshop:
        return 'Atelier / Ligne';
      case WorkcenterType.manual:
        return 'Poste manuel';
    }
  }
}

class ProductionWorkcenter {
  final String id;
  final String name;
  final String code;
  final WorkcenterType type;
  final double hourlyCost; // TND / heure
  final double capacityHoursPerDay; // ex: 8h, 16h, 24h
  final double efficiency; // Pourcentage d'efficacité (ex: 95%)
  final bool active;
  final String? description;
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductionWorkcenter({
    required this.id,
    required this.name,
    required this.code,
    this.type = WorkcenterType.machine,
    this.hourlyCost = 0.0,
    this.capacityHoursPerDay = 8.0,
    this.efficiency = 100.0,
    this.active = true,
    this.description,
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'type': type.name,
        'hourly_cost': hourlyCost,
        'capacity_hours_per_day': capacityHoursPerDay,
        'efficiency': efficiency,
        'active': active,
        'description': description,
        'enterprise_id': enterpriseId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ProductionWorkcenter.fromMap(Map<String, dynamic> map) =>
      ProductionWorkcenter(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        code: map['code']?.toString() ?? '',
        type: WorkcenterType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => WorkcenterType.machine,
        ),
        hourlyCost: (map['hourly_cost'] as num?)?.toDouble() ?? 0.0,
        capacityHoursPerDay:
            (map['capacity_hours_per_day'] as num?)?.toDouble() ?? 8.0,
        efficiency: (map['efficiency'] as num?)?.toDouble() ?? 100.0,
        active: map['active'] == true || map['active'] == 1,
        description: map['description']?.toString(),
        enterpriseId: map['enterprise_id']?.toString(),
        createdAt: map['created_at'] != null
            ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
      );

  ProductionWorkcenter copyWith({
    String? id,
    String? name,
    String? code,
    WorkcenterType? type,
    double? hourlyCost,
    double? capacityHoursPerDay,
    double? efficiency,
    bool? active,
    String? description,
    String? enterpriseId,
  }) =>
      ProductionWorkcenter(
        id: id ?? this.id,
        name: name ?? this.name,
        code: code ?? this.code,
        type: type ?? this.type,
        hourlyCost: hourlyCost ?? this.hourlyCost,
        capacityHoursPerDay: capacityHoursPerDay ?? this.capacityHoursPerDay,
        efficiency: efficiency ?? this.efficiency,
        active: active ?? this.active,
        description: description ?? this.description,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
