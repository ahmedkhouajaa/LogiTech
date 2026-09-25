class TrashItem {
  final String id;
  final String originalId;
  final String collection;
  final String category; // 'Ventes', 'Achats', 'Clients', 'Fournisseurs', 'Stock', 'Trésorerie', 'Projets'
  final String title;
  final String subtitle;
  final DateTime deletedAt;
  final String? enterpriseId;
  final String? userId;
  final Map<String, dynamic> snapshot;

  const TrashItem({
    required this.id,
    required this.originalId,
    required this.collection,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.deletedAt,
    this.enterpriseId,
    this.userId,
    this.snapshot = const {},
  });

  factory TrashItem.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      final s = val.toString();
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    return TrashItem(
      id: docId,
      originalId: map['original_id']?.toString() ?? map['originalId']?.toString() ?? docId,
      collection: map['collection']?.toString() ?? 'unknown',
      category: map['category']?.toString() ?? 'Autre',
      title: map['title']?.toString() ?? 'Sans titre',
      subtitle: map['subtitle']?.toString() ?? '',
      deletedAt: parseDate(map['deleted_at'] ?? map['deletedAt']),
      enterpriseId: map['enterprise_id']?.toString() ?? map['enterpriseId']?.toString(),
      userId: map['userId']?.toString() ?? map['user_id']?.toString(),
      snapshot: map['snapshot'] is Map ? Map<String, dynamic>.from(map['snapshot']) : const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_id': originalId,
      'collection': collection,
      'category': category,
      'title': title,
      'subtitle': subtitle,
      'deleted_at': deletedAt.toIso8601String(),
      'enterprise_id': enterpriseId,
      'userId': userId,
      'snapshot': snapshot,
    };
  }

  TrashItem copyWith({
    String? id,
    String? originalId,
    String? collection,
    String? category,
    String? title,
    String? subtitle,
    DateTime? deletedAt,
    String? enterpriseId,
    String? userId,
    Map<String, dynamic>? snapshot,
  }) {
    return TrashItem(
      id: id ?? this.id,
      originalId: originalId ?? this.originalId,
      collection: collection ?? this.collection,
      category: category ?? this.category,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      deletedAt: deletedAt ?? this.deletedAt,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      userId: userId ?? this.userId,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}
