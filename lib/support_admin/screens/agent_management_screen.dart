import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_presence_helper.dart';

class AgentManagementScreen extends StatefulWidget {
  final bool showOnlyPresence;
  final bool showOnlyPerformance;

  const AgentManagementScreen({
    super.key,
    this.showOnlyPresence = false,
    this.showOnlyPerformance = false,
  });

  @override
  State<AgentManagementScreen> createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showInviteAgentDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'support_agent';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.person_add_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Inviter un Agent Support'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nom complet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Ex: Amine Ben Salem', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                const Text('Email professionnel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(hintText: 'agent@logitech.tn', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                const Text('Rôle Support', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'support_agent', child: Text('Agent Support (Tickets & Assistance)')),
                    DropdownMenuItem(value: 'support_lead', child: Text('Lead Support (Escalades & Validation)')),
                    DropdownMenuItem(value: 'superadmin', child: Text('SuperAdmin (Accès Intégral)')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final name = nameController.text.trim();
                      if (email.isEmpty) return;

                      setDialogState(() => isLoading = true);
                      try {
                        await _firestore.collection('support_agents').add({
                          'name': name.isNotEmpty ? name : email.split('@').first,
                          'email': email,
                          'role': selectedRole,
                          'status': 'invited',
                          'invitedAt': FieldValue.serverTimestamp(),
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invitation enregistrée avec succès !'), backgroundColor: Color(0xFF10B981)),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Envoyer l\'invitation'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.showOnlyPresence
                          ? 'Présence & Activité en Direct'
                          : widget.showOnlyPerformance
                              ? 'Performance & Leaderboard de l\'Équipe'
                              : 'Gestion de l\'Équipe Support & Rôles',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Supervisez les agents, la charge de travail, l\'activation et la disponibilité en temps réel.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showInviteAgentDialog,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Inviter un Agent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Agents Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore.collection('support_agents_presence').snapshots(),
                builder: (context, presenceSnap) {
                  final presenceDocs = presenceSnap.data?.docs ?? [];
                  final presenceMap = <String, Map<String, dynamic>>{};

                  for (final p in presenceDocs) {
                    final data = p.data();
                    final email = data['email']?.toString().toLowerCase();
                    if (email != null) {
                      presenceMap[email] = data;
                    }
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore.collection('support_agents').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];

                      return ListView.separated(
                        itemCount: docs.length + 1, // +1 for default admin
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // Default System SuperAdmin Card
                            final pData = presenceMap['support@logitech.tn'];
                            final isOnline = pData?['isOnline'] == true;
                            final lastConn = pData?['lastHeartbeat'];

                            return _agentCard(
                              name: 'Support LogiTech (SuperAdmin)',
                              email: 'support@logitech.tn',
                              role: 'superadmin',
                              isOnline: isOnline,
                              lastConnected: lastConn,
                              agentData: const {'status': 'active', 'isActive': true},
                              resolvedCount: 24,
                            );
                          }

                          final data = docs[index - 1].data();
                          final email = (data['email'] ?? '').toString();
                          final pData = presenceMap[email.toLowerCase()];
                          final isOnline = pData?['isOnline'] == true;
                          final lastConn = pData?['lastHeartbeat'] ?? data['invitedAt'] ?? data['createdAt'];

                          return _agentCard(
                            name: data['name'] ?? email.split('@').first,
                            email: email,
                            role: data['role'] ?? 'support_agent',
                            isOnline: isOnline,
                            lastConnected: lastConn,
                            agentData: data,
                            resolvedCount: 0,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agentCard({
    required String name,
    required String email,
    required String role,
    required bool isOnline,
    required dynamic lastConnected,
    required Map<String, dynamic> agentData,
    required int resolvedCount,
  }) {
    final actInfo = UserPresenceHelper.getActivationInfo(agentData);
    final lastConnStr = UserPresenceHelper.formatLastConnected(lastConnected);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 8),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ),
                      const SizedBox(width: 6),
                      // Activation Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: actInfo.backgroundColor, borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(actInfo.icon, size: 10, color: actInfo.color),
                            const SizedBox(width: 3),
                            Text(actInfo.shortLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: actInfo.color)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Presence & Offline last connection
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOnline ? 'EN LIGNE' : 'HORS LIGNE • Vu: $lastConnStr',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$resolvedCount tickets résolus', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Text('Disponibilité : 100%', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
