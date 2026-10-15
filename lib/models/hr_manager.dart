import 'package:cloud_firestore/cloud_firestore.dart';

class HrManager {
  final String id;
  final String enterpriseId;
  final String lastName; // Nom
  final String firstName; // Prénom
  final String email;
  final String phone;
  final List<String> roles; // e.g. ['Administrateur', 'Manager']
  final bool isOwner;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HrManager({
    required this.id,
    required this.enterpriseId,
    required this.lastName,
    required this.firstName,
    required this.email,
    this.phone = '',
    this.roles = const ['Manager'],
    this.isOwner = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName {
    final name = '$lastName $firstName'.trim();
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email.split('@').first;
    return 'Gestionnaire';
  }

  HrManager copyWith({
    String? id,
    String? enterpriseId,
    String? lastName,
    String? firstName,
    String? email,
    String? phone,
    List<String>? roles,
    bool? isOwner,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HrManager(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      isOwner: isOwner ?? this.isOwner,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'lastName': lastName,
      'firstName': firstName,
      'email': email,
      'phone': phone,
      'roles': roles,
      'isOwner': isOwner,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory HrManager.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawRoles = map['roles'];
    List<String> parsedRoles = ['Manager'];
    if (rawRoles is List) {
      parsedRoles = rawRoles.map((e) => e.toString()).toList();
    } else if (rawRoles is String && rawRoles.isNotEmpty) {
      parsedRoles = [rawRoles];
    }

    return HrManager(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id'] as String? ?? ''),
      enterpriseId: map['enterpriseId'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      roles: parsedRoles,
      isOwner: map['isOwner'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
