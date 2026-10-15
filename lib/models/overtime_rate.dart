/// Modèle pour les Taux d'Heures Supplémentaires Odoo ERP (Screenshots 1, 2, 3, 4, 5)
/// Exemple: Nom: "x 1.5", Taux: 1.50, Société: "My Company"
class OvertimeRate {
  final String id;
  final String name; // e.g. "x 1.5", "X2"
  final double rate; // e.g. 1.5, 2.0
  final String company; // e.g. "My Company"
  final String? enterpriseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  OvertimeRate({
    required this.id,
    required this.name,
    required this.rate,
    this.company = 'My Company',
    this.enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Formate le taux avec virgule comme dans Odoo (Screenshots 2 & 5: "1,50" ou "2,00")
  String get formattedRate => rate.toStringAsFixed(2).replaceAll('.', ',');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rate': rate,
      'company': company,
      'enterprise_id': enterpriseId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory OvertimeRate.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return OvertimeRate(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      rate: (map['rate'] as num?)?.toDouble() ?? 1.0,
      company: map['company']?.toString() ?? 'My Company',
      enterpriseId: map['enterprise_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? now : now,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? now : now,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
    );
  }

  OvertimeRate copyWith({
    String? id,
    String? name,
    double? rate,
    String? company,
    String? enterpriseId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return OvertimeRate(
      id: id ?? this.id,
      name: name ?? this.name,
      rate: rate ?? this.rate,
      company: company ?? this.company,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OvertimeRate && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'OvertimeRate(id: $id, name: $name, rate: $rate)';
}
