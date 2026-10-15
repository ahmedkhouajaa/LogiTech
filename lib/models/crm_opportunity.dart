import 'package:flutter/material.dart';

/// Stage definition in the CRM Pipeline
class CrmStage {
  final String id;
  final String name;
  final int order;
  final Color color;
  final Color bgColor;
  final int defaultProbability;
  final bool isWon;
  final bool isLost;

  const CrmStage({
    required this.id,
    required this.name,
    required this.order,
    required this.color,
    required this.bgColor,
    this.defaultProbability = 50,
    this.isWon = false,
    this.isLost = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'color': color.toARGB32(),
      'bgColor': bgColor.toARGB32(),
      'defaultProbability': defaultProbability,
      'isWon': isWon,
      'isLost': isLost,
    };
  }

  factory CrmStage.fromMap(Map<String, dynamic> map) {
    return CrmStage(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      order: map['order'] is int ? map['order'] : 0,
      color: map['color'] != null ? Color(map['color']) : const Color(0xFF2563EB),
      bgColor: map['bgColor'] != null ? Color(map['bgColor']) : const Color(0xFFEFF6FF),
      defaultProbability: map['defaultProbability'] is int ? map['defaultProbability'] : 50,
      isWon: map['isWon'] == true,
      isLost: map['isLost'] == true,
    );
  }

  static List<CrmStage> defaultStages() {
    return const [
      CrmStage(
        id: 'new',
        name: 'Piste / Nouveau',
        order: 0,
        color: Color(0xFFF59E0B),
        bgColor: Color(0xFFFEF3C7),
        defaultProbability: 10,
      ),
      CrmStage(
        id: 'qualified',
        name: 'Qualifié',
        order: 1,
        color: Color(0xFF3B82F6),
        bgColor: Color(0xFFEFF6FF),
        defaultProbability: 30,
      ),
      CrmStage(
        id: 'proposal',
        name: 'Proposition envoyée',
        order: 2,
        color: Color(0xFF6366F1),
        bgColor: Color(0xFFEEF2FF),
        defaultProbability: 60,
      ),
      CrmStage(
        id: 'negotiation',
        name: 'En négociation',
        order: 3,
        color: Color(0xFF8B5CF6),
        bgColor: Color(0xFFF5F3FF),
        defaultProbability: 80,
      ),
      CrmStage(
        id: 'won',
        name: 'Gagné (Signé)',
        order: 4,
        color: Color(0xFF10B981),
        bgColor: Color(0xFFD1FAE5),
        defaultProbability: 100,
        isWon: true,
      ),
      CrmStage(
        id: 'lost',
        name: 'Perdu / Sans suite',
        order: 5,
        color: Color(0xFFEF4444),
        bgColor: Color(0xFFFEE2E2),
        defaultProbability: 0,
        isLost: true,
      ),
    ];
  }
}

/// A commercial Opportunity (Affaire / Deal)
class CrmOpportunity {
  final String id;
  final String enterpriseId;
  final String title;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final bool isLead;
  final String stageId;
  final String stageName;
  final double expectedRevenue;
  final int probability; // 0 to 100 %
  final DateTime? expectedCloseDate;
  final String? ownerUserId;
  final String? ownerUserName;
  final int priority; // 0 = Basse, 1 = Normale, 2 = Haute, 3 = Urgente
  final List<String> tags;
  final String source; // e.g. Site Web, Salon, Recommandation, Prospection...
  final List<String> quoteIds;
  final String? lostReason;
  final String? notes;
  final DateTime? wonAt;
  final DateTime? lostAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CrmOpportunity({
    required this.id,
    required this.enterpriseId,
    required this.title,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.isLead = false,
    required this.stageId,
    required this.stageName,
    this.expectedRevenue = 0.0,
    this.probability = 50,
    this.expectedCloseDate,
    this.ownerUserId,
    this.ownerUserName,
    this.priority = 1,
    this.tags = const [],
    this.source = 'Prospection directe',
    this.quoteIds = const [],
    this.lostReason,
    this.notes,
    this.wonAt,
    this.lostAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Weighted expected revenue: expectedRevenue * (probability / 100)
  double get weightedRevenue => expectedRevenue * (probability / 100.0);

  bool get isWon => stageId == 'won' || wonAt != null;
  bool get isLost => stageId == 'lost' || lostAt != null;
  bool get isClosed => isWon || isLost;

  CrmOpportunity copyWith({
    String? id,
    String? enterpriseId,
    String? title,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    bool? isLead,
    String? stageId,
    String? stageName,
    double? expectedRevenue,
    int? probability,
    DateTime? expectedCloseDate,
    String? ownerUserId,
    String? ownerUserName,
    int? priority,
    List<String>? tags,
    String? source,
    List<String>? quoteIds,
    String? lostReason,
    String? notes,
    DateTime? wonAt,
    DateTime? lostAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CrmOpportunity(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      title: title ?? this.title,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      isLead: isLead ?? this.isLead,
      stageId: stageId ?? this.stageId,
      stageName: stageName ?? this.stageName,
      expectedRevenue: expectedRevenue ?? this.expectedRevenue,
      probability: probability ?? this.probability,
      expectedCloseDate: expectedCloseDate ?? this.expectedCloseDate,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerUserName: ownerUserName ?? this.ownerUserName,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      quoteIds: quoteIds ?? this.quoteIds,
      lostReason: lostReason ?? this.lostReason,
      notes: notes ?? this.notes,
      wonAt: wonAt ?? this.wonAt,
      lostAt: lostAt ?? this.lostAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'title': title,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'isLead': isLead,
      'stageId': stageId,
      'stageName': stageName,
      'expectedRevenue': expectedRevenue,
      'probability': probability,
      'expectedCloseDate': expectedCloseDate?.toIso8601String(),
      'ownerUserId': ownerUserId,
      'ownerUserName': ownerUserName,
      'priority': priority,
      'tags': tags,
      'source': source,
      'quoteIds': quoteIds,
      'lostReason': lostReason,
      'notes': notes,
      'wonAt': wonAt?.toIso8601String(),
      'lostAt': lostAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CrmOpportunity.fromMap(Map<String, dynamic> map) {
    return CrmOpportunity(
      id: map['id'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      title: map['title'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'],
      customerEmail: map['customerEmail'],
      isLead: map['isLead'] == true,
      stageId: map['stageId'] ?? 'new',
      stageName: map['stageName'] ?? 'Piste / Nouveau',
      expectedRevenue: (map['expectedRevenue'] is num) ? (map['expectedRevenue'] as num).toDouble() : 0.0,
      probability: map['probability'] is int ? map['probability'] : 50,
      expectedCloseDate: map['expectedCloseDate'] != null ? DateTime.tryParse(map['expectedCloseDate'].toString()) : null,
      ownerUserId: map['ownerUserId'],
      ownerUserName: map['ownerUserName'],
      priority: map['priority'] is int ? map['priority'] : 1,
      tags: map['tags'] is List ? List<String>.from(map['tags'].map((e) => e.toString())) : [],
      source: map['source'] ?? 'Prospection directe',
      quoteIds: map['quoteIds'] is List ? List<String>.from(map['quoteIds'].map((e) => e.toString())) : [],
      lostReason: map['lostReason'],
      notes: map['notes'],
      wonAt: map['wonAt'] != null ? DateTime.tryParse(map['wonAt'].toString()) : null,
      lostAt: map['lostAt'] != null ? DateTime.tryParse(map['lostAt'].toString()) : null,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
