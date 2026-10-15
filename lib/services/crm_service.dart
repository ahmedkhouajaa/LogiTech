import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/crm_opportunity.dart';
import '../models/crm_activity.dart';
import '../models/crm_automation.dart';
import '../models/crm_email.dart';
import '../models/customer.dart';
import 'enterprise_service.dart';

class CrmService {
  CrmService._internal();
  static final CrmService instance = CrmService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ValueNotifier for UI reactivity
  final ValueNotifier<List<CrmOpportunity>> opportunitiesNotifier = ValueNotifier([]);
  final ValueNotifier<List<CrmStage>> stagesNotifier = ValueNotifier([]);
  final ValueNotifier<List<CrmActivity>> activitiesNotifier = ValueNotifier([]);
  final ValueNotifier<List<CrmAutomationRule>> automationsNotifier = ValueNotifier([]);
  final ValueNotifier<List<CrmEmailTemplate>> templatesNotifier = ValueNotifier([]);
  final ValueNotifier<List<CrmEmailLog>> emailLogsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  StreamSubscription? _subOpportunities;
  StreamSubscription? _subStages;
  StreamSubscription? _subActivities;
  StreamSubscription? _subAutomations;
  StreamSubscription? _subTemplates;
  StreamSubscription? _subEmailLogs;

  String? _currentEnterpriseId;

  String get _activeEnterpriseId {
    if (_currentEnterpriseId != null && _currentEnterpriseId!.isNotEmpty) {
      return _currentEnterpriseId!;
    }
    final active = EnterpriseService.instance.currentEnterpriseId;
    if (active != null && active.isNotEmpty) {
      return active;
    }
    return 'default_enterprise';
  }

  void init() {
    EnterpriseService.instance.currentEnterpriseNotifier.addListener(_onEnterpriseChanged);
    _onEnterpriseChanged();
  }

  void dispose() {
    EnterpriseService.instance.currentEnterpriseNotifier.removeListener(_onEnterpriseChanged);
    _cancelSubs();
  }

  void _onEnterpriseChanged() {
    final eid = EnterpriseService.instance.currentEnterpriseId;
    if (eid != _currentEnterpriseId) {
      _currentEnterpriseId = eid;
      _cancelSubs();
      if (eid != null && eid.isNotEmpty) {
        loadData(eid);
      } else {
        opportunitiesNotifier.value = [];
        stagesNotifier.value = CrmStage.defaultStages();
        activitiesNotifier.value = [];
        automationsNotifier.value = [];
        templatesNotifier.value = [];
        emailLogsNotifier.value = [];
      }
    }
  }

  void _cancelSubs() {
    _subOpportunities?.cancel();
    _subStages?.cancel();
    _subActivities?.cancel();
    _subAutomations?.cancel();
    _subTemplates?.cancel();
    _subEmailLogs?.cancel();
  }

  Future<void> loadData(String enterpriseId) async {
    isLoadingNotifier.value = true;
    _currentEnterpriseId = enterpriseId;

    try {
      // 1. STAGES
      final stagesRef = _firestore.collection('enterprises').doc(enterpriseId).collection('crm_stages');
      _subStages = stagesRef.orderBy('order').snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          // Initialize default stages
          _seedDefaultStages(enterpriseId);
        } else {
          stagesNotifier.value = snap.docs.map((d) => CrmStage.fromMap(d.data())).toList();
        }
      }, onError: (e) {
        debugPrint('[CrmService] Error loading stages: $e');
        stagesNotifier.value = CrmStage.defaultStages();
      });

      // 2. OPPORTUNITIES
      final oppsRef = _firestore.collection('enterprises').doc(enterpriseId).collection('crm_opportunities');
      _subOpportunities = oppsRef.orderBy('updatedAt', descending: true).snapshots().listen((snap) {
        final list = snap.docs.map((d) => CrmOpportunity.fromMap(d.data())).toList();
        opportunitiesNotifier.value = list;
      }, onError: (e) {
        debugPrint('[CrmService] Error loading opportunities: $e');
      });

      // 3. ACTIVITIES
      final actRef = _firestore.collection('enterprises').doc(enterpriseId).collection('crm_activities');
      _subActivities = actRef.orderBy('dueDate').snapshots().listen((snap) {
        final list = snap.docs.map((d) => CrmActivity.fromMap(d.data())).toList();
        activitiesNotifier.value = list;
      }, onError: (e) {
        debugPrint('[CrmService] Error loading activities: $e');
      });

      // 4. AUTOMATIONS
      final autoRef = _firestore.collection('enterprises').doc(enterpriseId).collection('crm_automations');
      _subAutomations = autoRef.snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          _seedDefaultAutomations(enterpriseId);
        } else {
          automationsNotifier.value = snap.docs.map((d) => CrmAutomationRule.fromMap(d.data())).toList();
        }
      }, onError: (e) {
        debugPrint('[CrmService] Error loading automations: $e');
      });

      // 5. EMAIL TEMPLATES
      final tplRef = _firestore.collection('enterprises').doc(enterpriseId).collection('crm_email_templates');
      _subTemplates = tplRef.snapshots().listen((snap) {
        if (snap.docs.isEmpty) {
          _seedDefaultTemplates(enterpriseId);
        } else {
          templatesNotifier.value = snap.docs.map((d) => CrmEmailTemplate.fromMap(d.data())).toList();
        }
      }, onError: (e) {
        debugPrint('[CrmService] Error loading email templates: $e');
      });

      // 6. EMAIL LOGS
      final emailsRef = _firestore.collection('enterprises').doc(enterpriseId).collection('crm_emails');
      _subEmailLogs = emailsRef.orderBy('sentAt', descending: true).snapshots().listen((snap) {
        final list = snap.docs.map((d) => CrmEmailLog.fromMap(d.data())).toList();
        emailLogsNotifier.value = list;
      }, onError: (e) {
        debugPrint('[CrmService] Error loading email logs: $e');
      });
    } catch (e) {
      debugPrint('[CrmService] loadData exception: $e');
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<void> _seedDefaultStages(String eid) async {
    final defaults = CrmStage.defaultStages();
    stagesNotifier.value = defaults;
    final batch = _firestore.batch();
    final col = _firestore.collection('enterprises').doc(eid).collection('crm_stages');
    for (final s in defaults) {
      batch.set(col.doc(s.id), s.toMap());
    }
    await batch.commit().catchError((e) {
      debugPrint('[CrmService] Error seeding default stages: $e');
    });
  }

  Future<void> _seedDefaultAutomations(String eid) async {
    final defaults = CrmAutomationRule.defaultRules(eid);
    automationsNotifier.value = defaults;
    final batch = _firestore.batch();
    final col = _firestore.collection('enterprises').doc(eid).collection('crm_automations');
    for (final r in defaults) {
      batch.set(col.doc(r.id), r.toMap());
    }
    await batch.commit().catchError((e) {
      debugPrint('[CrmService] Error seeding automations: $e');
    });
  }

  Future<void> _seedDefaultTemplates(String eid) async {
    final defaults = CrmEmailTemplate.defaultTemplates(eid);
    templatesNotifier.value = defaults;
    final batch = _firestore.batch();
    final col = _firestore.collection('enterprises').doc(eid).collection('crm_email_templates');
    for (final t in defaults) {
      batch.set(col.doc(t.id), t.toMap());
    }
    await batch.commit().catchError((e) {
      debugPrint('[CrmService] Error seeding email templates: $e');
    });
  }

  // ---------------------------------------------------------------------------
  // OPPORTUNITIES CRUD & ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> saveOpportunity(CrmOpportunity opp) async {
    final eid = opp.enterpriseId.isNotEmpty ? opp.enterpriseId : _activeEnterpriseId;
    final docRef = _firestore.collection('enterprises').doc(eid).collection('crm_opportunities').doc(opp.id);
    await docRef.set(opp.toMap(), SetOptions(merge: true));

    // Update in-memory if stream is lagging
    final current = List<CrmOpportunity>.from(opportunitiesNotifier.value);
    final idx = current.indexWhere((o) => o.id == opp.id);
    if (idx >= 0) {
      current[idx] = opp;
    } else {
      current.insert(0, opp);
      // Trigger new opportunity automation
      _triggerAutomations(CrmAutomationTrigger.opportunityCreated, opp);
    }
    opportunitiesNotifier.value = current;
  }

  Future<void> deleteOpportunity(String oppId) async {
    final eid = _activeEnterpriseId;
    await _firestore.collection('enterprises').doc(eid).collection('crm_opportunities').doc(oppId).delete();
    final current = List<CrmOpportunity>.from(opportunitiesNotifier.value);
    current.removeWhere((o) => o.id == oppId);
    opportunitiesNotifier.value = current;
  }

  Future<void> updateOpportunityStage(String oppId, String newStageId, String newStageName, {String? lostReason}) async {
    final opp = opportunitiesNotifier.value.firstWhere(
      (o) => o.id == oppId,
      orElse: () => CrmOpportunity(
        id: oppId,
        enterpriseId: _activeEnterpriseId,
        title: '',
        customerId: '',
        customerName: '',
        stageId: newStageId,
        stageName: newStageName,
      ),
    );

    int proba = opp.probability;
    final matchingStage = stagesNotifier.value.where((s) => s.id == newStageId).firstOrNull;
    if (matchingStage != null) {
      proba = matchingStage.defaultProbability;
    }

    final isWon = newStageId == 'won';
    final isLost = newStageId == 'lost';

    final updated = opp.copyWith(
      stageId: newStageId,
      stageName: newStageName,
      probability: proba,
      lostReason: isLost ? (lostReason ?? 'Sans suite') : null,
      wonAt: isWon ? DateTime.now() : null,
      lostAt: isLost ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );

    await saveOpportunity(updated);

    // Trigger stage changed automation
    _triggerAutomations(CrmAutomationTrigger.stageChanged, updated, extraParams: {'stageId': newStageId});
    if (isWon) {
      _triggerAutomations(CrmAutomationTrigger.dealWon, updated);
    } else if (isLost) {
      _triggerAutomations(CrmAutomationTrigger.dealLost, updated);
    }
  }

  /// Create an Opportunity from a Lead Customer
  Future<CrmOpportunity> createOpportunityFromLead(Customer lead, {String? dealTitle, double amount = 0.0}) async {
    final oppId = _uuid.v4();
    final eid = _activeEnterpriseId;
    final title = dealTitle ?? 'Projet ${lead.name}';

    final opp = CrmOpportunity(
      id: oppId,
      enterpriseId: eid,
      title: title,
      customerId: lead.id,
      customerName: lead.name,
      customerPhone: lead.phone,
      customerEmail: lead.email,
      isLead: true,
      stageId: 'new',
      stageName: 'Piste / Nouveau',
      expectedRevenue: amount,
      probability: 10,
      source: 'Prospection directe',
    );

    await saveOpportunity(opp);
    return opp;
  }

  /// Link Quote to Opportunity
  Future<void> linkQuoteToOpportunity(String oppId, String quoteId) async {
    final opp = opportunitiesNotifier.value.firstWhere((o) => o.id == oppId);
    if (!opp.quoteIds.contains(quoteId)) {
      final updatedQuotes = List<String>.from(opp.quoteIds)..add(quoteId);
      final updated = opp.copyWith(quoteIds: updatedQuotes);
      await saveOpportunity(updated);
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIVITIES CRUD
  // ---------------------------------------------------------------------------
  Future<void> saveActivity(CrmActivity activity) async {
    final eid = activity.enterpriseId.isNotEmpty ? activity.enterpriseId : _activeEnterpriseId;
    final docRef = _firestore.collection('enterprises').doc(eid).collection('crm_activities').doc(activity.id);
    await docRef.set(activity.toMap(), SetOptions(merge: true));

    final current = List<CrmActivity>.from(activitiesNotifier.value);
    final idx = current.indexWhere((a) => a.id == activity.id);
    if (idx >= 0) {
      current[idx] = activity;
    } else {
      current.add(activity);
    }
    activitiesNotifier.value = current;
  }

  Future<void> toggleActivityDone(String activityId, bool isDone) async {
    final act = activitiesNotifier.value.firstWhere((a) => a.id == activityId);
    final updated = act.copyWith(
      isDone: isDone,
      completedAt: isDone ? DateTime.now() : null,
    );
    await saveActivity(updated);
  }

  Future<void> deleteActivity(String activityId) async {
    final eid = _activeEnterpriseId;
    await _firestore.collection('enterprises').doc(eid).collection('crm_activities').doc(activityId).delete();
    final current = List<CrmActivity>.from(activitiesNotifier.value);
    current.removeWhere((a) => a.id == activityId);
    activitiesNotifier.value = current;
  }

  // ---------------------------------------------------------------------------
  // AUTOMATIONS ENGINE
  // ---------------------------------------------------------------------------
  Future<void> toggleAutomation(String ruleId, bool isActive) async {
    final rule = automationsNotifier.value.firstWhere((r) => r.id == ruleId);
    final updated = rule.copyWith(isActive: isActive);
    final eid = _activeEnterpriseId;
    await _firestore.collection('enterprises').doc(eid).collection('crm_automations').doc(ruleId).set(
      updated.toMap(),
      SetOptions(merge: true),
    );
    final current = List<CrmAutomationRule>.from(automationsNotifier.value);
    final idx = current.indexWhere((r) => r.id == ruleId);
    if (idx >= 0) {
      current[idx] = updated;
      automationsNotifier.value = current;
    }
  }

  Future<void> saveAutomation(CrmAutomationRule rule) async {
    final eid = rule.enterpriseId.isNotEmpty ? rule.enterpriseId : _activeEnterpriseId;
    await _firestore.collection('enterprises').doc(eid).collection('crm_automations').doc(rule.id).set(
      rule.toMap(),
      SetOptions(merge: true),
    );
    final current = List<CrmAutomationRule>.from(automationsNotifier.value);
    final idx = current.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      current[idx] = rule;
    } else {
      current.add(rule);
    }
    automationsNotifier.value = current;
  }

  Future<void> deleteAutomation(String ruleId) async {
    final eid = _activeEnterpriseId;
    await _firestore.collection('enterprises').doc(eid).collection('crm_automations').doc(ruleId).delete();
    final current = List<CrmAutomationRule>.from(automationsNotifier.value);
    current.removeWhere((r) => r.id == ruleId);
    automationsNotifier.value = current;
  }

  void _triggerAutomations(CrmAutomationTrigger trigger, CrmOpportunity opp, {Map<String, dynamic>? extraParams}) {
    for (final rule in automationsNotifier.value) {
      if (!rule.isActive || rule.trigger != trigger) continue;

      // Check condition (e.g., target stage)
      if (trigger == CrmAutomationTrigger.stageChanged) {
        final target = rule.triggerParams['targetStageId'];
        if (target != null && target != extraParams?['stageId']) continue;
      }

      // Execute action
      _executeAction(rule, opp);
    }
  }

  Future<void> _executeAction(CrmAutomationRule rule, CrmOpportunity opp) async {
    try {
      if (rule.action == CrmAutomationAction.createActivity) {
        final days = (rule.actionParams['dueInDays'] is int) ? rule.actionParams['dueInDays'] as int : 2;
        final dueDate = DateTime.now().add(Duration(days: days));
        final title = rule.actionParams['activityTitle']?.toString() ?? 'Activité de suivi automatique';

        CrmActivityType type = CrmActivityType.task;
        final typeStr = rule.actionParams['activityType']?.toString();
        if (typeStr == 'call') type = CrmActivityType.call;
        if (typeStr == 'meeting') type = CrmActivityType.meeting;
        if (typeStr == 'email') type = CrmActivityType.email;

        final act = CrmActivity(
          id: _uuid.v4(),
          enterpriseId: opp.enterpriseId,
          opportunityId: opp.id,
          opportunityTitle: opp.title,
          customerId: opp.customerId,
          customerName: opp.customerName,
          type: type,
          title: title,
          dueDate: dueDate,
          description: 'Créée automatiquement via la règle : "${rule.name}"',
        );
        await saveActivity(act);
      } else if (rule.action == CrmAutomationAction.addTag) {
        final tag = rule.actionParams['tag']?.toString();
        if (tag != null && !opp.tags.contains(tag)) {
          final updatedTags = List<String>.from(opp.tags)..add(tag);
          await saveOpportunity(opp.copyWith(tags: updatedTags));
        }
      }

      // Increment execution count
      final updatedRule = rule.copyWith(
        executionCount: rule.executionCount + 1,
        lastExecutedAt: DateTime.now(),
      );
      saveAutomation(updatedRule);
    } catch (e) {
      debugPrint('[CrmService] Error executing automation action: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // EMAIL TEMPLATES & LOGS
  // ---------------------------------------------------------------------------
  Future<void> saveEmailTemplate(CrmEmailTemplate tpl) async {
    final eid = tpl.enterpriseId.isNotEmpty ? tpl.enterpriseId : _activeEnterpriseId;
    await _firestore.collection('enterprises').doc(eid).collection('crm_email_templates').doc(tpl.id).set(
      tpl.toMap(),
      SetOptions(merge: true),
    );
    final current = List<CrmEmailTemplate>.from(templatesNotifier.value);
    final idx = current.indexWhere((t) => t.id == tpl.id);
    if (idx >= 0) {
      current[idx] = tpl;
    } else {
      current.add(tpl);
    }
    templatesNotifier.value = current;
  }

  Future<void> deleteEmailTemplate(String tplId) async {
    final eid = _activeEnterpriseId;
    await _firestore.collection('enterprises').doc(eid).collection('crm_email_templates').doc(tplId).delete();
    final current = List<CrmEmailTemplate>.from(templatesNotifier.value);
    current.removeWhere((t) => t.id == tplId);
    templatesNotifier.value = current;
  }

  Future<void> logSentEmail(CrmEmailLog log) async {
    final eid = log.enterpriseId.isNotEmpty ? log.enterpriseId : _activeEnterpriseId;
    await _firestore.collection('enterprises').doc(eid).collection('crm_emails').doc(log.id).set(log.toMap());

    final current = List<CrmEmailLog>.from(emailLogsNotifier.value);
    current.insert(0, log);
    emailLogsNotifier.value = current;

    // Log an activity as well for transparency
    final act = CrmActivity(
      id: _uuid.v4(),
      enterpriseId: eid,
      opportunityId: log.opportunityId,
      opportunityTitle: log.opportunityTitle,
      customerId: log.customerId,
      customerName: log.customerName,
      type: CrmActivityType.email,
      title: 'Email envoyé : ${log.subject}',
      description: log.body,
      dueDate: DateTime.now(),
      isDone: true,
      completedAt: DateTime.now(),
    );
    await saveActivity(act);
  }

  // ---------------------------------------------------------------------------
  // KPI & STATS HELPERS
  // ---------------------------------------------------------------------------
  double getTotalPipelineRevenue() {
    return opportunitiesNotifier.value
        .where((o) => !o.isLost)
        .fold(0.0, (acc, o) => acc + o.expectedRevenue);
  }

  double getWeightedPipelineRevenue() {
    return opportunitiesNotifier.value
        .where((o) => !o.isClosed)
        .fold(0.0, (acc, o) => acc + o.weightedRevenue);
  }

  double getWonRevenue() {
    return opportunitiesNotifier.value
        .where((o) => o.isWon)
        .fold(0.0, (acc, o) => acc + o.expectedRevenue);
  }

  double getWinRate() {
    final closed = opportunitiesNotifier.value.where((o) => o.isClosed).toList();
    if (closed.isEmpty) return 0.0;
    final won = closed.where((o) => o.isWon).length;
    return (won / closed.length) * 100.0;
  }

  int getPendingActivitiesCount() {
    return activitiesNotifier.value.where((a) => !a.isDone).length;
  }

  int getOverdueActivitiesCount() {
    return activitiesNotifier.value.where((a) => a.isOverdue).length;
  }
}
