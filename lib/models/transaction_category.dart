import 'package:uuid/uuid.dart';

class TransactionCategory {
  final String id;
  final String name;
  final String type; // 'income' or 'expense'
  final bool isDefault;
  final DateTime createdAt;

  TransactionCategory({
    String? id,
    required this.name,
    required this.type,
    this.isDefault = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  TransactionCategory copyWith({
    String? id,
    String? name,
    String? type,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return TransactionCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TransactionCategory.fromMap(Map<String, dynamic> map) {
    return TransactionCategory(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      isDefault: map['is_default'] == 1,
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at']) : DateTime.now(),
    );
  }
}
