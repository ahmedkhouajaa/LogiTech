import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../utils/file_download_helper.dart';

class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({super.key});

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedAction = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportHistoryCsv(List<QueryDocumentSnapshot<Map<String, dynamic>>> logs) async {
    if (logs.isEmpty) return;

    final csvBuffer = StringBuffer();
    csvBuffer.writeln('ID,Date,Agent,Action,Entreprise Cible,Motif / Details');

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    for (final doc in logs) {
      final data = doc.data();
      final date = (data['timestamp'] as Timestamp?)?.toDate();
      final dateStr = date != null ? dateFormat.format(date) : 'N/A';
      final agent = (data['agentEmail'] ?? 'SuperAdmin').toString();
      final action = (data['action'] ?? 'N/A').toString();
      final target = (data['targetCompanyName'] ?? data['targetEnterpriseId'] ?? data['targetUserEmail'] ?? 'N/A').toString().replaceAll(',', ' ');
      final reason = (data['reason'] ?? data['details'] ?? '').toString().replaceAll(',', ' ');

      csvBuffer.writeln('${doc.id},$dateStr,$agent,$action,$target,$reason');
    }

    final fileName = 'historique_clients_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    await FileDownloadHelper.saveStringFile(
      csvBuffer.toString(),
      fileName,
      mimeType: 'text/csv',
      context: context,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Historique exporté : $fileName'), backgroundColor: const Color(0xFF10B981)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

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
                const Icon(Icons.history_rounded, color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Historique & Piste d\'Audit Clients',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Traçabilité complète de toutes les modifications (licences, statuts, mots de passe, paiements).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Search Bar & Action Filter
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Rechercher dans l\'historique par agent, entreprise, motif...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Action Filter Dropdown
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAction,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Toutes les actions')),
                        DropdownMenuItem(value: 'LICENSE_EXTEND', child: Text('Extension Licence')),
                        DropdownMenuItem(value: 'VALIDATE_PAYMENT', child: Text('Validation Paiement')),
                        DropdownMenuItem(value: 'BAN_CLIENT', child: Text('Bannissement Client')),
                        DropdownMenuItem(value: 'UNBAN_CLIENT', child: Text('Réactivation Client')),
                        DropdownMenuItem(value: 'PASSWORD_RESET_EMAIL_SENT', child: Text('Reset Mot de Passe')),
                      ],
                      onChanged: (v) => v != null ? setState(() => _selectedAction = v) : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Audit Logs Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('audit_logs').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final query = _searchController.text.trim().toLowerCase();

                  final filtered = docs.where((doc) {
                    final data = doc.data();
                    final action = (data['action'] ?? '').toString();
                    final agent = (data['agentEmail'] ?? '').toString().toLowerCase();
                    final target = (data['targetCompanyName'] ?? data['targetEnterpriseId'] ?? data['targetUserEmail'] ?? '').toString().toLowerCase();
                    final reason = (data['reason'] ?? data['details'] ?? '').toString().toLowerCase();

                    if (_selectedAction != 'all' && action != _selectedAction) return false;

                    if (query.isNotEmpty) {
                      return agent.contains(query) || target.contains(query) || reason.contains(query) || action.toLowerCase().contains(query);
                    }
                    return true;
                  }).toList();

                  // Sort by latest timestamp descending
                  filtered.sort((a, b) {
                    final aDate = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    final bDate = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    return bDate.compareTo(aDate);
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('Aucune trace d\'audit trouvée', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Text('${filtered.length} événements enregistrés', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _exportHistoryCsv(filtered),
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Télécharger CSV'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = filtered[index].data();
                            final action = (data['action'] ?? 'ACTION').toString();
                            final agent = data['agentEmail'] ?? 'SuperAdmin';
                            final target = data['targetCompanyName'] ?? data['targetEnterpriseId'] ?? data['targetUserEmail'] ?? 'Général';
                            final reason = data['reason'] ?? data['details'] ?? 'Aucun motif fourni';
                            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

                            Color actionColor = const Color(0xFF2563EB);
                            IconData actionIcon = Icons.info_outline_rounded;

                            if (action.contains('BAN')) {
                              actionColor = action.contains('UNBAN') ? const Color(0xFF059669) : const Color(0xFFDC2626);
                              actionIcon = action.contains('UNBAN') ? Icons.check_circle_rounded : Icons.block_rounded;
                            } else if (action.contains('PAYMENT') || action.contains('LICENSE')) {
                              actionColor = const Color(0xFF10B981);
                              actionIcon = Icons.verified_rounded;
                            } else if (action.contains('PASSWORD')) {
                              actionColor = const Color(0xFFF59E0B);
                              actionIcon = Icons.key_rounded;
                            }

                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: actionColor.withValues(alpha: 0.1),
                                  child: Icon(actionIcon, color: actionColor, size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: actionColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(action, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: actionColor)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Cible : $target',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 3),
                                    Text('Motif : $reason', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Par : $agent • ${timestamp != null ? dateFormat.format(timestamp) : "Récemment"}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
