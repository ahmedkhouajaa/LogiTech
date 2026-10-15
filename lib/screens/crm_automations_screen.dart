import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/crm_automation.dart';
import '../services/crm_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class CrmAutomationsScreen extends StatefulWidget {
  const CrmAutomationsScreen({super.key});

  @override
  State<CrmAutomationsScreen> createState() => _CrmAutomationsScreenState();
}

class _CrmAutomationsScreenState extends State<CrmAutomationsScreen> {
  final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: CrmService.instance.automationsNotifier,
      builder: (context, _) {
        final rules = CrmService.instance.automationsNotifier.value;
        final activeCount = rules.where((r) => r.isActive).length;
        final totalExecs = rules.fold(0, (acc, r) => acc + r.executionCount);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(context, isDark, rules.length, activeCount, totalExecs),
                const SizedBox(height: 20),

                // Rules List
                Expanded(
                  child: rules.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          itemCount: rules.length,
                          itemBuilder: (context, index) {
                            final rule = rules[index];
                            return _buildRuleCard(rule, isDark);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, int total, int active, int execs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF8B5CF6), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Automatisations Commerciales'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$active active(s) sur $total règles • $execs exécutions automatisées au total',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _openCreateRuleDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Text('Nouvelle Règle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text('Aucune automatisation configurée', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Gagnez du temps en créant des rappels et actions automatiques.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openCreateRuleDialog(context),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('Créer une Règle', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(CrmAutomationRule rule, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Active toggle
              Switch(
                value: rule.isActive,
                activeThumbColor: const Color(0xFF2563EB),
                onChanged: (val) {
                  CrmService.instance.toggleAutomation(rule.id, val);
                },
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rule.description,
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Run counter badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rule.executionCount} exécutions',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 8),

              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                onPressed: () => _confirmDeleteRule(context, rule),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Flow pills: Trigger -> Action
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text('Déclencheur : ${rule.trigger.label}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_outline, size: 14, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text('Action : ${rule.action.label}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                  ],
                ),
              ),
              if (rule.lastExecutedAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Dernière exécution : ${dateFmt.format(rule.lastExecutedAt!)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _openCreateRuleDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final activityTitleCtrl = TextEditingController(text: 'Relance commerciale automatique');
    CrmAutomationTrigger trigger = CrmAutomationTrigger.opportunityCreated;
    CrmAutomationAction action = CrmAutomationAction.createActivity;
    int dueInDays = 2;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text('Créer une Règle d\'Automatisation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nom de la règle *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        decoration: _inputDeco('Ex : Relance automatique des propositions', isDark),
                      ),
                      const SizedBox(height: 12),

                      const Text('Description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descCtrl,
                        decoration: _inputDeco('Expliquez brièvement le but de cette automatisation', isDark),
                      ),
                      const SizedBox(height: 16),

                      const Text('1. Quand cet événement survient (Déclencheur) :', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<CrmAutomationTrigger>(
                        initialValue: trigger,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        decoration: _dropdownDeco(null, isDark),
                        items: CrmAutomationTrigger.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (v) => setDState(() => trigger = v ?? CrmAutomationTrigger.opportunityCreated),
                      ),
                      const SizedBox(height: 16),

                      const Text('2. Alors exécuter cette action :', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<CrmAutomationAction>(
                        initialValue: action,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        decoration: _dropdownDeco(null, isDark),
                        items: CrmAutomationAction.values.map((a) => DropdownMenuItem(value: a, child: Text(a.label, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (v) => setDState(() => action = v ?? CrmAutomationAction.createActivity),
                      ),
                      const SizedBox(height: 12),

                      if (action == CrmAutomationAction.createActivity) ...[
                        const Text('Titre de l\'activité à créer', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: activityTitleCtrl,
                          decoration: _inputDeco('Ex : Appel de suivi', isDark),
                        ),
                        const SizedBox(height: 12),
                        const Text('Échéance (en jours après l\'événement)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          initialValue: dueInDays,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          decoration: _dropdownDeco(null, isDark),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 jour', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 2, child: Text('2 jours', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 3, child: Text('3 jours', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 5, child: Text('5 jours', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 7, child: Text('7 jours (1 semaine)', style: TextStyle(fontSize: 12.5))),
                          ],
                          onChanged: (d) => setDState(() => dueInDays = d ?? 2),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: isSaving ? null : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    setDState(() => isSaving = true);
                    final isOnline = ConnectivityService.instance.isOnline;

                    final rule = CrmAutomationRule(
                      id: const Uuid().v4(),
                      enterpriseId: '',
                      name: name,
                      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Règle automatique',
                      trigger: trigger,
                      action: action,
                      actionParams: {
                        'activityTitle': activityTitleCtrl.text.trim(),
                        'activityType': 'call',
                        'dueInDays': dueInDays,
                        'tag': 'Automatisé',
                      },
                    );

                    try {
                      await CrmService.instance.saveAutomation(rule);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(isOnline ? Icons.check_circle_rounded : Icons.cloud_off_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isOnline
                                        ? 'Règle "$name" créée avec succès !'
                                        : 'Règle "$name" enregistrée (hors ligne - en attente de synchronisation)',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: isOnline ? const Color(0xFF10B981) : AppColors.warning,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setDState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Créer la règle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteRule(BuildContext context, CrmAutomationRule rule) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'supprimer cette règle d\'automatisation',
      onConfirmed: () {
        CrmService.instance.deleteAutomation(rule.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Règle "${rule.name}" supprimée.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  InputDecoration _inputDeco(String? hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12.5,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }

  InputDecoration _dropdownDeco(String? hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12.5,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
