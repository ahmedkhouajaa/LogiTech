import 'package:flutter/material.dart';

/// Represents the definition of a user-configured custom field for a document type.
class CustomFieldDefinition {
  final String id;
  final String enterpriseId;
  final String documentType; // e.g. 'quote', 'invoice', 'customer_order', etc.
  final String name; // e.g. "diagnostic technicien", "prix estimé"
  final String key; // unique identifier / slug e.g. "diagnostic_technicien"
  final String type; // 'text', 'number', 'date', 'textarea'
  final bool isRequired;
  final String? placeholder;
  final String? defaultValue;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomFieldDefinition({
    required this.id,
    required this.enterpriseId,
    required this.documentType,
    required this.name,
    String? key,
    this.type = 'text',
    this.isRequired = false,
    this.placeholder,
    this.defaultValue,
    this.order = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : key = key ?? _generateKey(name),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
    if (s.isEmpty) s = 'champ_${DateTime.now().millisecondsSinceEpoch}';
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
        'type': type,
        'is_required': isRequired,
        'isRequired': isRequired,
        'placeholder': placeholder,
        'default_value': defaultValue,
        'defaultValue': defaultValue,
        'order': order,
        'created_at': createdAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CustomFieldDefinition.fromMap(Map<String, dynamic> map, {String? id}) {
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

    return CustomFieldDefinition(
      id: id ?? map['id']?.toString() ?? '',
      enterpriseId: map['enterprise_id']?.toString() ?? map['enterpriseId']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? map['documentType']?.toString() ?? 'quote',
      name: map['name']?.toString() ?? '',
      key: map['key']?.toString(),
      type: map['type']?.toString() ?? 'text',
      isRequired: map['is_required'] == true || map['isRequired'] == true,
      placeholder: map['placeholder']?.toString(),
      defaultValue: map['default_value']?.toString() ?? map['defaultValue']?.toString(),
      order: (map['order'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  CustomFieldDefinition copyWith({
    String? id,
    String? enterpriseId,
    String? documentType,
    String? name,
    String? key,
    String? type,
    bool? isRequired,
    String? placeholder,
    String? defaultValue,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CustomFieldDefinition(
        id: id ?? this.id,
        enterpriseId: enterpriseId ?? this.enterpriseId,
        documentType: documentType ?? this.documentType,
        name: name ?? this.name,
        key: key ?? this.key,
        type: type ?? this.type,
        isRequired: isRequired ?? this.isRequired,
        placeholder: placeholder ?? this.placeholder,
        defaultValue: defaultValue ?? this.defaultValue,
        order: order ?? this.order,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  IconData get icon {
    switch (type) {
      case 'number':
        return Icons.pin_rounded;
      case 'date':
        return Icons.calendar_today_rounded;
      case 'textarea':
        return Icons.notes_rounded;
      case 'text':
      default:
        return Icons.text_fields_rounded;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'number':
        return 'Nombre';
      case 'date':
        return 'Date';
      case 'textarea':
        return 'Texte long';
      case 'text':
      default:
        return 'Texte';
    }
  }
}
