class ProductFamily {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;

  ProductFamily({
    required this.id,
    required this.name,
    this.parentId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'parent_id': parentId,
    // Database has mixed INTEGER/TEXT for created_at, storing as ISO8601 for safety
    'created_at': createdAt.toIso8601String(),
  };

  factory ProductFamily.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    if (map['created_at'] != null) {
      if (map['created_at'] is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int);
      } else if (map['created_at'] is String) {
        parsedDate = DateTime.tryParse(map['created_at'] as String) ?? DateTime.now();
      }
    }
    
    return ProductFamily(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      createdAt: parsedDate,
    );
  }
}
