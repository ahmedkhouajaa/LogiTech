/// Trigger events supported by CRM Automations
enum CrmAutomationTrigger {
  leadCreated,
  opportunityCreated,
  stageChanged,
  dealWon,
  dealLost,
  inactivityThreshold,
}

extension CrmAutomationTriggerExt on CrmAutomationTrigger {
  String get label {
    switch (this) {
      case CrmAutomationTrigger.leadCreated:
        return 'Nouveau prospect (Lead) créé';
      case CrmAutomationTrigger.opportunityCreated:
        return 'Nouvelle opportunité créée';
      case CrmAutomationTrigger.stageChanged:
        return "Changement d'étape du pipeline";
      case CrmAutomationTrigger.dealWon:
        return 'Affaire marquée Gagnée';
      case CrmAutomationTrigger.dealLost:
        return 'Affaire marquée Perdue';
      case CrmAutomationTrigger.inactivityThreshold:
        return 'Inactivité sans contact (X jours)';
    }
  }
}

/// Action types triggered by automations
enum CrmAutomationAction {
  createActivity,
  sendTemplateEmail,
  changeStage,
  addTag,
}

extension CrmAutomationActionExt on CrmAutomationAction {
  String get label {
    switch (this) {
      case CrmAutomationAction.createActivity:
        return 'Créer une activité / tâche automatique';
      case CrmAutomationAction.sendTemplateEmail:
        return 'Préparer / Envoyer un email type';
      case CrmAutomationAction.changeStage:
        return "Déplacer vers une autre étape";
      case CrmAutomationAction.addTag:
        return 'Ajouter une étiquette (tag)';
    }
  }
}

class CrmAutomationRule {
  final String id;
  final String enterpriseId;
  final String name;
  final String description;
  final bool isActive;
  final CrmAutomationTrigger trigger;
  final Map<String, dynamic> triggerParams; // e.g. {'targetStageId': 'proposal'} or {'days': 7}
  final CrmAutomationAction action;
  final Map<String, dynamic> actionParams; // e.g. {'activityTitle': 'Relance devis', 'dueInDays': 3}
  final int executionCount;
  final DateTime? lastExecutedAt;
  final DateTime createdAt;

  CrmAutomationRule({
    required this.id,
    required this.enterpriseId,
    required this.name,
    required this.description,
    this.isActive = true,
    required this.trigger,
    this.triggerParams = const {},
    required this.action,
    this.actionParams = const {},
    this.executionCount = 0,
    this.lastExecutedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  CrmAutomationRule copyWith({
    String? id,
    String? enterpriseId,
    String? name,
    String? description,
    bool? isActive,
    CrmAutomationTrigger? trigger,
    Map<String, dynamic>? triggerParams,
    CrmAutomationAction? action,
    Map<String, dynamic>? actionParams,
    int? executionCount,
    DateTime? lastExecutedAt,
    DateTime? createdAt,
  }) {
    return CrmAutomationRule(
      id: id ?? this.id,
      enterpriseId: enterpriseId ?? this.enterpriseId,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      trigger: trigger ?? this.trigger,
      triggerParams: triggerParams ?? this.triggerParams,
      action: action ?? this.action,
      actionParams: actionParams ?? this.actionParams,
      executionCount: executionCount ?? this.executionCount,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enterpriseId': enterpriseId,
      'name': name,
      'description': description,
      'isActive': isActive,
      'trigger': trigger.name,
      'triggerParams': triggerParams,
      'action': action.name,
      'actionParams': actionParams,
      'executionCount': executionCount,
      'lastExecutedAt': lastExecutedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CrmAutomationRule.fromMap(Map<String, dynamic> map) {
    CrmAutomationTrigger tr = CrmAutomationTrigger.opportunityCreated;
    if (map['trigger'] != null) {
      for (final t in CrmAutomationTrigger.values) {
        if (t.name == map['trigger']) {
          tr = t;
          break;
        }
      }
    }

    CrmAutomationAction act = CrmAutomationAction.createActivity;
    if (map['action'] != null) {
      for (final a in CrmAutomationAction.values) {
        if (a.name == map['action']) {
          act = a;
          break;
        }
      }
    }

    return CrmAutomationRule(
      id: map['id'] ?? '',
      enterpriseId: map['enterpriseId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isActive: map['isActive'] != false,
      trigger: tr,
      triggerParams: map['triggerParams'] is Map ? Map<String, dynamic>.from(map['triggerParams']) : {},
      action: act,
      actionParams: map['actionParams'] is Map ? Map<String, dynamic>.from(map['actionParams']) : {},
      executionCount: map['executionCount'] is int ? map['executionCount'] : 0,
      lastExecutedAt: map['lastExecutedAt'] != null ? DateTime.tryParse(map['lastExecutedAt'].toString()) : null,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  /// Default predefined smart rules
  static List<CrmAutomationRule> defaultRules(String enterpriseId) {
    return [
      CrmAutomationRule(
        id: 'rule_1',
        enterpriseId: enterpriseId,
        name: 'Relance après proposition commerciale',
        description: 'Quand une proposition est envoyée, planifie un appel de suivi 3 jours après.',
        isActive: true,
        trigger: CrmAutomationTrigger.stageChanged,
        triggerParams: {'targetStageId': 'proposal'},
        action: CrmAutomationAction.createActivity,
        actionParams: {
          'activityType': 'call',
          'activityTitle': 'Appel de suivi : proposition commerciale',
          'dueInDays': 3,
        },
      ),
      CrmAutomationRule(
        id: 'rule_2',
        enterpriseId: enterpriseId,
        name: 'Qualification rapide de nouvelle piste',
        description: 'Dès qu\'un nouveau prospect est ajouté, crée une tâche de qualification sous 24h.',
        isActive: true,
        trigger: CrmAutomationTrigger.leadCreated,
        triggerParams: {},
        action: CrmAutomationAction.createActivity,
        actionParams: {
          'activityType': 'task',
          'activityTitle': 'Contacter et qualifier le nouveau prospect',
          'dueInDays': 1,
        },
      ),
      CrmAutomationRule(
        id: 'rule_3',
        enterpriseId: enterpriseId,
        name: 'Étiquetage automatique des affaires gagnées',
        description: 'Dès qu\'une affaire est gagnée, lui assigne le tag "Signé".',
        isActive: true,
        trigger: CrmAutomationTrigger.dealWon,
        triggerParams: {},
        action: CrmAutomationAction.addTag,
        actionParams: {'tag': 'Signé'},
      ),
    ];
  }
}
