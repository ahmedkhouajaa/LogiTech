import 'package:flutter/material.dart';

enum CrmActivityType {
  call,
  meeting,
  email,
  task,
}

extension CrmActivityTypeExt on CrmActivityType {
  String get label {
    switch (this) {
      case CrmActivityType.call:
        return 'Appel téléphonique';
      case CrmActivityType.meeting:
        return 'Rendez-vous / Réunion';
      case CrmActivityType.email:
        return 'Email de suivi';
      case CrmActivityType.task:
        return 'Tâche commerciale';
    }
  }

  IconData get icon {
    switch (this) {
      case CrmActivityType.call:
        return Icons.phone_in_talk_rounded;
      case CrmActivityType.meeting:
        return Icons.groups_rounded;
      case CrmActivityType.email:
        return Icons.mail_outline_rounded;
      case CrmActivityType.task:
        return Icons.task_alt_rounded;
    }
  }

  Color get color {
    switch (this) {
      case CrmActivityType.call:
        return const Color(0xFF0284C7);
      case CrmActivityType.meeting:
        return const Color(0xFF8B5CF6);
      case CrmActivityType.email:
        return const Color(0xFFF59E0B);
      case CrmActivityType.task:
        return const Color(0xFF10B981);
    }
  }
}

class CrmActivity {
  final String id;
  final String enterpriseId;
  final String? opportunityId;
  final String? opportunityTitle;
  final String? customerId;
  final String? customerName;
  final CrmActivityType type;
  final String title;
  final String? description;
  final DateTime dueDate;
  final String? assignedToUserId;
  final String? assignedToUserName;
  final bool isDone;
  final DateTime? completedAt;
  final DateTime createdAt;

  CrmActivity({
    required this.id,
    required this.enterpriseId,
    this.opportunityId,
    this.opportunityTitle,
    this.customerId,
    this.customerName,
    required this.type,
    required this.title,
    this.description,
    required this.dueDate,
    this.assignedToUserId,
    this.assignedToUserName,
    this.isDone = false,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOverdue => !isDone && dueDate.isBefore(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day;
  }

  CrmActivity copyWith({
    String? id,
    String? enterpriseId,
    String? opportunityId,
    String? opportunityTitle,
    String? customerId,
    String? customerName,
    CrmActivityType? type,
    String? title,
    String? description,
    DateTime? dueDate,
    String? assignedToUserId,
    String? assignedToUserName,
    bool? isDone,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return CrmActivity(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      opportunityId: opportunityId ?? this.opportunityId,
      opportunityTitle: opportunityTitle ?? this.opportunityTitle,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedToUserName: assignedToUserName ?? this.assignedToUserName,
      isDone: isDone ?? this.isDone,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'opportunityId': opportunityId,
      'opportunityTitle': opportunityTitle,
      'customerId': customerId,
      'customerName': customerName,
      'type': type.name,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'assignedToUserId': assignedToUserId,
      'assignedToUserName': assignedToUserName,
      'isDone': isDone,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CrmActivity.fromMap(Map<String, dynamic> map) {
    CrmActivityType activityType = CrmActivityType.task;
    if (map['type'] != null) {
      for (final t in CrmActivityType.values) {
        if (t.name == map['type']) {
          activityType = t;
          break;
        }
      }
    }

    return CrmActivity(
      id: map['id'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      opportunityId: map['opportunityId'],
      opportunityTitle: map['opportunityTitle'],
      customerId: map['customerId'],
      customerName: map['customerName'],
      type: activityType,
      title: map['title'] ?? '',
      description: map['description'],
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate'].toString()) ?? DateTime.now() : DateTime.now(),
      assignedToUserId: map['assignedToUserId'],
      assignedToUserName: map['assignedToUserName'],
      isDone: map['isDone'] == true,
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
