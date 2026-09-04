import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigurationScreen extends StatefulWidget {
  final int initialTabIndex;

  const ConfigurationScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  late int _selectedTab;

  final List<Map<String, dynamic>> _slaTargets = [
    {
      'id': 'urgent',
      'title': 'Priorité Urgente',
      'responseTarget': '1 Heure',
      'resolutionTarget': '4 Heures',
      'color': const Color(0xFFEF4444),
      'description': 'Tickets critiques bloquant totalement les opérations du client.',
    },
    {
      'id': 'high',
      'title': 'Priorité Haute',
      'responseTarget': '4 Heures',
      'resolutionTarget': '24 Heures',
      'color': const Color(0xFFF97316),
      'description': 'Dysfonctionnements majeurs avec contournement temporaire possible.',
    },
    {
      'id': 'medium',
      'title': 'Priorité Normale',
      'responseTarget': '24 Heures',
      'resolutionTarget': '48 Heures',
      'color': const Color(0xFF10B981),
      'description': 'Demandes d\'assistance générales, factures ou questions d\'utilisation.',
    },
    {
      'id': 'low',
      'title': 'Priorité Basse',
      'responseTarget': '48 Heures',
      'resolutionTarget': '72 Heures',
      'color': const Color(0xFF94A3B8),
      'description': 'Suggestions d\'améliorations ou demandes non urgentes.',
    },
  ];

  final List<Map<String, dynamic>> _defaultTemplates = [
    {
      'title': 'Accusé de réception',
      'category': 'Général',
      'content': 'Bonjour, nous avons bien pris en compte votre demande et un agent du support technique est en train de l\'examiner.',
    },
    {
      'title': 'Validation paiement reçue',
      'category': 'Facturation',
      'content': 'Votre virement bancaire a été validé avec succès. Votre abonnement LogiTech Pro est désormais actif.',
    },
    {
      'title': 'Demande de capture d\'écran',
      'category': 'Technique',
      'content': 'Afin de diagnostiquer précisément le problème, pouvez-vous nous transmettre une capture d\'écran complète de l\'erreur affichée ?',
    },
    {
      'title': 'Mise à jour & correctif',
      'category': 'Technique',
      'content': 'Le correctif a été déployé avec succès sur nos serveurs. Veuillez redémarrer l\'application pour en bénéficier.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
  }

  @override
  void didUpdateWidget(ConfigurationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      setState(() {
        _selectedTab = widget.initialTabIndex;
      });
    }
  }

  void _showAddTemplateDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String category = 'Technique';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nouveau Modèle de Réponse Rapide'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Titre du modèle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Ex: Demande de justificatif bancaire',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Catégorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Technique', child: Text('Technique')),
                    DropdownMenuItem(value: 'Facturation', child: Text('Facturation')),
                    DropdownMenuItem(value: 'Général', child: Text('Général')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 14),
                const Text('Texte du message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Bonjour, ...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                final t = titleController.text.trim();
                final c = contentController.text.trim();
                if (t.isEmpty || c.isEmpty) return;

                await FirebaseFirestore.instance.collection('canned_templates').add({
                  'title': t,
                  'category': category,
                  'content': c,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Modèle ajouté avec succès !'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              child: const Text('Enregistrer le modèle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSlaDialog(Map<String, dynamic> sla) {
    final responseController = TextEditingController(text: sla['responseTarget']);
    final resolutionController = TextEditingController(text: sla['resolutionTarget']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier les objectifs SLA : ${sla['title']}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Délai cible 1ère réponse', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: responseController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Délai cible de résolution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: resolutionController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                sla['responseTarget'] = responseController.text.trim();
                sla['resolutionTarget'] = resolutionController.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Objectifs SLA mis à jour !'), backgroundColor: Color(0xFF10B981)),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _selectedTab == 0
            ? _buildSlaTab()
            : _selectedTab == 1
                ? _buildTemplatesTab()
                : _buildCategoriesTab(),
      ),
    );
  }

  Widget _buildSlaTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paramètres des Délais SLA (Service Level Agreement)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configurez les délais maximaux contractuels pour la première prise en charge et la résolution définitive selon la priorité.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          ..._slaTargets.map((sla) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _slaCard(sla),
              )),
        ],
      ),
    );
  }

  Widget _slaCard(Map<String, dynamic> sla) {
    final Color color = sla['color'];

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4.5,
              color: color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(sla['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text('1ère Rép: ${sla['responseTarget']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text('Résolution: ${sla['resolutionTarget']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(sla['description'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: () => _showEditSlaDialog(sla),
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text('Modifier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Modèles de Réponse Rapide (Canned Responses)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 4),
                Text(
                  'Messages pré-enregistrés pour répondre en un clic aux questions récurrentes des clients.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showAddTemplateDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Nouveau Modèle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('canned_templates').snapshots(),
            builder: (context, snapshot) {
              final customDocs = snapshot.data?.docs ?? [];
              final allTemplates = <Map<String, dynamic>>[
                ..._defaultTemplates,
                ...customDocs.map((d) => {'id': d.id, ...d.data()}),
              ];

              return ListView.separated(
                itemCount: allTemplates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = allTemplates[index];
                  final isCustom = t.containsKey('id');

                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      title: Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      subtitle: Text(t['content'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                            child: Text(t['category'] ?? 'Général', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ),
                          if (isCustom) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('canned_templates').doc(t['id']).delete();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    final categories = [
      {
        'title': 'Problèmes Techniques & Bugs',
        'subtitle': 'Erreurs logicielles, plantages, calculs TVA et problèmes d\'impression.',
        'icon': Icons.build_circle_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Facturation, Paiement & Abonnements',
        'subtitle': 'Validation des virements bancaires, renouvellements et gestion des licences.',
        'icon': Icons.credit_card_rounded,
        'color': const Color(0xFF059669),
      },
      {
        'title': 'Synchronisation & Connectivité',
        'subtitle': 'Problèmes de synchronisation SQLite <-> Firestore et conflits multi-appareils.',
        'icon': Icons.sync_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Comptes, Rôles & Sécurité',
        'subtitle': 'Réinitialisation de mot de passe, permissions d\'accès et gestion des utilisateurs.',
        'icon': Icons.admin_panel_settings_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catégories de Tickets & Routage',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Arborescence standard utilisée pour router et classifier les demandes des clients.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (cat['color'] as Color).withValues(alpha: 0.1),
                      child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 20),
                    ),
                    title: Text(cat['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    subtitle: Text(cat['subtitle'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
