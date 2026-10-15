import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/crm_email.dart';
import '../services/crm_service.dart';
import '../services/enterprise_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class CrmEmailsScreen extends StatefulWidget {
  const CrmEmailsScreen({super.key});

  @override
  State<CrmEmailsScreen> createState() => _CrmEmailsScreenState();
}

class _CrmEmailsScreenState extends State<CrmEmailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        CrmService.instance.templatesNotifier,
        CrmService.instance.emailLogsNotifier,
      ]),
      builder: (context, _) {
        final templates = CrmService.instance.templatesNotifier.value;
        final logs = CrmService.instance.emailLogsNotifier.value;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                _buildHeader(context, isDark),
                const SizedBox(height: 16),

                // Tabs: Modèles vs Historique
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF2563EB),
                    labelColor: const Color(0xFF2563EB),
                    unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                        text: 'Modèles Types (${templates.length})',
                      ),
                      Tab(
                        icon: const Icon(Icons.history_rounded, size: 18),
                        text: 'Historique des Échanges (${logs.length})',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Templates
                      _buildTemplatesTab(isDark, templates),
                      // Tab 2: Logs
                      _buildLogsTab(isDark, logs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
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
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF0284C7), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Intégration Email CRM'),
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
              'Gérez vos modèles d\'emails avec variables automatiques et suivez les échanges avec vos prospects',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openCreateTemplateDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Nouveau Modèle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openComposeEmailDialog(context),
              icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
              label: const Text('Rédiger un Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplatesTab(bool isDark, List<CrmEmailTemplate> templates) {
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('Aucun modèle d\'email configuré'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _openCreateTemplateDialog(context), child: const Text('Créer un modèle')),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        mainAxisExtent: 210,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: templates.length,
      itemBuilder: (context, idx) {
        final tpl = templates[idx];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tpl.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Utiliser ce modèle',
                        icon: const Icon(Icons.forward_to_inbox_rounded, size: 18, color: Color(0xFF2563EB)),
                        onPressed: () => _openComposeEmailDialog(context, initialTemplate: tpl),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                        onPressed: () => CrmService.instance.deleteEmailTemplate(tpl.id),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Objet : ${tpl.subject}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  tpl.body,
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: tpl.availableVariables.map((v) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(v, style: const TextStyle(fontSize: 9.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogsTab(bool isDark, List<CrmEmailLog> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('Aucun email envoyé pour le moment.'),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        itemCount: logs.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        itemBuilder: (context, idx) {
          final log = logs[idx];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEFF6FF),
              child: Icon(Icons.mail_outline_rounded, color: Color(0xFF2563EB), size: 18),
            ),
            title: Row(
              children: [
                Text(log.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(width: 8),
                Text('<${log.toEmail}>', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                Text(log.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
              ],
            ),
            trailing: Text(dateFmt.format(log.sentAt), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMPOSE EMAIL DIALOG
  // ---------------------------------------------------------------------------
  void _openComposeEmailDialog(BuildContext context, {CrmEmailTemplate? initialTemplate}) {
    final toCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController(text: initialTemplate?.subject ?? '');
    final bodyCtrl = TextEditingController(text: initialTemplate?.body ?? '');

    String? selectedOppId;
    CrmEmailTemplate? selectedTemplate = initialTemplate;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            bool isSaving = false;
            final opps = CrmService.instance.opportunitiesNotifier.value;
            final templates = CrmService.instance.templatesNotifier.value;
            final enterpriseName = EnterpriseService.instance.currentEnterprise?.name ?? 'LogiTech';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text('Rédiger un Email Commercial', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Template selector
                      const Text('Choisir un modèle type (optionnel)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<CrmEmailTemplate?>(
                        initialValue: selectedTemplate,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        decoration: _dropdownDeco('Sélectionner un modèle type...', isDark),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Aucun modèle (texte libre)', style: TextStyle(fontSize: 12.5))),
                          ...templates.map((t) => DropdownMenuItem(value: t, child: Text(t.name, style: const TextStyle(fontSize: 12.5)))),
                        ],
                        onChanged: (tpl) {
                          setDState(() {
                            selectedTemplate = tpl;
                            if (tpl != null) {
                              final opp = opps.where((o) => o.id == selectedOppId).firstOrNull;
                              subjectCtrl.text = tpl.formatSubject(
                                clientName: nameCtrl.text.isNotEmpty ? nameCtrl.text : 'Client',
                                opportunityTitle: opp?.title ?? 'Projet',
                                enterpriseName: enterpriseName,
                              );
                              bodyCtrl.text = tpl.formatBody(
                                clientName: nameCtrl.text.isNotEmpty ? nameCtrl.text : 'Client',
                                opportunityTitle: opp?.title ?? 'Projet',
                                expectedAmount: opp != null ? '${opp.expectedRevenue.toStringAsFixed(2)} TND' : '0.00 TND',
                                ownerName: opp?.ownerUserName ?? 'Votre commercial',
                                enterpriseName: enterpriseName,
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Associated Opportunity
                      const Text('Affaire / Opportunité liée', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedOppId,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        decoration: _dropdownDeco('Associer à une opportunité (optionnel)', isDark),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Aucune affaire liée', style: TextStyle(fontSize: 12.5))),
                          ...opps.map((o) => DropdownMenuItem(value: o.id, child: Text('${o.title} (${o.customerName})', style: const TextStyle(fontSize: 12.5)))),
                        ],
                        onChanged: (oid) {
                          setDState(() {
                            selectedOppId = oid;
                            final opp = opps.where((o) => o.id == oid).firstOrNull;
                            if (opp != null) {
                              nameCtrl.text = opp.customerName;
                              if (opp.customerEmail != null && opp.customerEmail!.isNotEmpty) {
                                toCtrl.text = opp.customerEmail!;
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Destinataire
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Nom du destinataire *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(controller: nameCtrl, decoration: _inputDeco('Ex : Ahmed Khouaja', isDark)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Adresse Email *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextField(controller: toCtrl, decoration: _inputDeco('client@societe.com', isDark)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Objet
                      const Text('Objet du message *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(controller: subjectCtrl, decoration: _inputDeco('Objet clair et professionnel', isDark)),
                      const SizedBox(height: 12),

                      // Corps
                      const Text('Corps du message *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: bodyCtrl,
                        maxLines: 6,
                        decoration: _inputDeco('Bonjour...', isDark),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  icon: isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  label: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Envoyer & Archiver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: isSaving ? null : () async {
                    final to = toCtrl.text.trim();
                    final name = nameCtrl.text.trim();
                    final subject = subjectCtrl.text.trim();
                    final body = bodyCtrl.text.trim();

                    if (to.isEmpty || subject.isEmpty || body.isEmpty) {
                      return;
                    }

                    setDState(() => isSaving = true);
                    final isOnline = ConnectivityService.instance.isOnline;

                    // Save log
                    final log = CrmEmailLog(
                      id: const Uuid().v4(),
                      enterpriseId: '',
                      opportunityId: selectedOppId,
                      customerName: name.isNotEmpty ? name : 'Contact',
                      toEmail: to,
                      subject: subject,
                      body: body,
                      templateId: selectedTemplate?.id,
                    );

                    try {
                      await CrmService.instance.logSentEmail(log);

                      // Open mailto link so user's desktop email client handles dispatch
                      final mailUri = Uri(
                        scheme: 'mailto',
                        path: to,
                        queryParameters: {
                          'subject': subject,
                          'body': body,
                        },
                      );
                      await launchUrl(mailUri).catchError((_) => false);

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
                                        ? 'Email archivé dans le CRM pour $to !'
                                        : 'Email archivé localement (hors ligne - en attente de synchronisation)',
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
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CREATE TEMPLATE DIALOG
  // ---------------------------------------------------------------------------
  void _openCreateTemplateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dCtx, setDState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Nouveau Modèle d\'Email Type', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nom du modèle *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(controller: nameCtrl, enabled: !isSaving, decoration: _inputDeco('Ex : Relance suite devis', isDark)),
                    const SizedBox(height: 12),
                    const Text('Objet *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(controller: subjectCtrl, enabled: !isSaving, decoration: _inputDeco('Votre projet {titre} - {entreprise}', isDark)),
                    const SizedBox(height: 12),
                    const Text('Variables disponibles :', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ['{client}', '{titre}', '{montant}', '{commercial}', '{entreprise}'].map((token) {
                        return ActionChip(
                          label: Text(token, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: isSaving
                              ? null
                              : () {
                                  bodyCtrl.text = '${bodyCtrl.text} $token';
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Corps du message *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 6,
                      enabled: !isSaving,
                      decoration: _inputDeco('Bonjour {client},\n...', isDark),
                    ),
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
                  final subj = subjectCtrl.text.trim();
                  final body = bodyCtrl.text.trim();
                  if (name.isEmpty || subj.isEmpty || body.isEmpty) return;

                  setDState(() => isSaving = true);
                  final isOnline = ConnectivityService.instance.isOnline;

                  final tpl = CrmEmailTemplate(
                    id: const Uuid().v4(),
                    enterpriseId: '',
                    name: name,
                    subject: subj,
                    body: body,
                  );

                  try {
                    await CrmService.instance.saveEmailTemplate(tpl);
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
                                      ? 'Modèle "$name" enregistré avec succès !'
                                      : 'Modèle "$name" enregistré (hors ligne - en attente de synchronisation)',
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
                    : const Text('Enregistrer le modèle', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDeco(String? hint, [bool isDark = false]) {
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
