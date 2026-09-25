import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single tracked action performed by a user in the system.
class UserActivityLog {
  final String id;
  final String enterpriseId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String action; // 'create', 'update', 'delete', 'restore', 'login', 'empty_trash', 'export'
  final String module; // 'Ventes', 'Achats', 'Articles', 'Clients', 'Fournisseurs', 'Stock', 'Trésorerie', 'Paiements', 'Retenues (RS)', 'Projets', 'Paramètres', 'Corbeille', 'Utilisateurs'
  final String collection;
  final String documentId;
  final String documentReference;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  const UserActivityLog({
    required this.id,
    required this.enterpriseId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.action,
    required this.module,
    required this.collection,
    required this.documentId,
    required this.documentReference,
    required this.description,
    required this.timestamp,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterprise_id': enterpriseId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'user_role': userRole,
      'action': action,
      'module': module,
      'collection': collection,
      'document_id': documentId,
      'document_reference': documentReference,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }

  factory UserActivityLog.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate = DateTime.now();
    final rawTs = map['timestamp'] ?? map['created_at'];
    if (rawTs != null) {
      if (rawTs is Timestamp) {
        parsedDate = rawTs.toDate();
      } else if (rawTs is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(rawTs);
      } else if (rawTs is String) {
        parsedDate = DateTime.tryParse(rawTs) ?? DateTime.now();
      }
    }

    return UserActivityLog(
      id: docId,
      enterpriseId: map['enterprise_id'] ?? '',
      userId: map['user_id'] ?? map['userId'] ?? '',
      userName: map['user_name'] ?? map['userName'] ?? 'Utilisateur inconnu',
      userEmail: map['user_email'] ?? map['userEmail'] ?? '',
      userRole: map['user_role'] ?? map['userRole'] ?? 'collaborateur',
      action: map['action'] ?? 'update',
      module: map['module'] ?? 'Général',
      collection: map['collection'] ?? '',
      documentId: map['document_id'] ?? map['documentId'] ?? '',
      documentReference: map['document_reference'] ?? map['reference'] ?? '',
      description: map['description'] ?? '',
      timestamp: parsedDate,
      details: map['details'] is Map ? Map<String, dynamic>.from(map['details']) : null,
    );
  }
}
