import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatelessWidget {
  final bool showLoginLogsOnly;

  const AuditLogScreen({super.key, this.showLoginLogsOnly = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showLoginLogsOnly ? 'Historique des Connexions & Sessions' : 'Journal d\'Audit & Sécurité Immuable',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Toutes les actions d\'administration (validations, attributions, clôtures) sont enregistrées de façon permanente.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('audit_logs')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.shield_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('Aucun événement d\'audit enregistré pour le moment', style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = docs[index].data();
                      final action = log['action'] ?? 'ACTION';
                      final agent = log['agentEmail'] ?? 'Support Agent';
                      final target = log['targetEnterpriseId'] ?? log['targetTicketId'] ?? '';
                      final reason = log['reason'] ?? '';
                      final timestamp = (log['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getActionColor(action).withValues(alpha: 0.1),
                            child: Icon(_getActionIcon(action), color: _getActionColor(action), size: 18),
                          ),
                          title: Row(
                            children: [
                              Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text('par $agent', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (target.isNotEmpty) Text('Cible : $target', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                              if (reason.isNotEmpty) Text('Motif : $reason', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ),
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

  Color _getActionColor(String action) {
    if (action.contains('VALIDATE')) return const Color(0xFF059669);
    if (action.contains('ASSIGN')) return const Color(0xFF2563EB);
    if (action.contains('ESCALAT') || action.contains('BREACH')) return const Color(0xFFDC2626);
    return const Color(0xFF475569);
  }

  IconData _getActionIcon(String action) {
    if (action.contains('VALIDATE')) return Icons.verified_rounded;
    if (action.contains('ASSIGN')) return Icons.person_add_rounded;
    if (action.contains('ESCALAT')) return Icons.warning_amber_rounded;
    return Icons.history_rounded;
  }
}
