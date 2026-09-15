import 'package:flutter/material.dart';

/// Represents the definition of a user-configured or system custom status for a document type.
class CustomStatusDefinition {
  final String id;
  final String enterpriseId;
  final String documentType; // e.g. 'quote', 'invoice', 'customer_order', etc.
  final String name; // e.g. "En cours de contrôle", "Prêt pour livraison"
  final String key; // unique identifier / slug e.g. "en_cours_de_controle"
  final int colorValue; // ARGB 32-bit int value e.g. 0xFF3B82F6
  final int order;
  final bool isDefault; // true if built-in system status (cannot be deleted)
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomStatusDefinition({
    required this.id,
    required this.enterpriseId,
    required this.documentType,
    required this.name,
    String? key,
    required this.colorValue,
    this.order = 0,
    this.isDefault = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : key = key ?? _generateKey(name),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get color => Color(colorValue);

  static String _generateKey(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[àâä]'), 'a');
    s = s.replaceAll(RegExp(r'[îï]'), 'i');
    s = s.replaceAll(RegExp(r'[ôö]'), 'o');
    s = s.replaceAll(RegExp(r'[ùûü]'), 'u');
    s = s.replaceAll(RegExp(r'[ç]'), 'c');
    s = s.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    if (s.endsWith('_')) s = s.substring(0, s.length - 1);
    if (s.isEmpty) s = 'statut_${DateTime.now().millisecondsSinceEpoch}';
    return s;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'enterprise_id': enterpriseId,
        'enterpriseId': enterpriseId,
        'document_type': documentType,
        'documentType': documentType,
        'name': name,
        'key': key,
        'color_value': colorValue,
        'colorValue': colorValue,
        'order': order,
        'is_default': isDefault,
        'isDefault': isDefault,
        'created_at': createdAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CustomStatusDefinition.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) {
        try {
          return DateTime.parse(val);
        } catch (_) {}
      }
      return DateTime.now();
    }

    final rawColor = map['color_value'] ?? map['colorValue'] ?? 0xFF3B82F6;
    final intColor = (rawColor is num) ? rawColor.toInt() : 0xFF3B82F6;

    return CustomStatusDefinition(
      id: id ?? map['id']?.toString() ?? '',
      enterpriseId: map['enterprise_id']?.toString() ?? map['enterpriseId']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? map['documentType']?.toString() ?? 'quote',
      name: map['name']?.toString() ?? '',
      key: map['key']?.toString(),
      colorValue: intColor,
      order: (map['order'] as num?)?.toInt() ?? 0,
      isDefault: map['is_default'] == true || map['isDefault'] == true,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  CustomStatusDefinition copyWith({
    String? id,
    String? enterpriseId,
    String? documentType,
    String? name,
    String? key,
    int? colorValue,
    int? order,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CustomStatusDefinition(
        id: id ?? this.id,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        documentType: documentType ?? this.documentType,
        name: name ?? this.name,
        key: key ?? this.key,
        colorValue: colorValue ?? this.colorValue,
        order: order ?? this.order,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}
