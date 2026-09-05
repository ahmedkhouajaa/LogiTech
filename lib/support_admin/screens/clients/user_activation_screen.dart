import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_presence_helper.dart';

class UserActivationScreen extends StatefulWidget {
  const UserActivationScreen({super.key});

  @override
  State<UserActivationScreen> createState() => _UserActivationScreenState();
}

class _UserActivationScreenState extends State<UserActivationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activationFilter = 'all'; // 'all', 'active', 'invited', 'banned'
  String _presenceFilter = 'all';   // 'all', 'online', 'offline'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            // Header Title
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Activation & Connexion des Utilisateurs (User Activation)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Superviser le statut de connexion des comptes clients en temps réel (En Ligne / Hors Ligne) et l\'historique des connexions.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Real-time Stream of Users
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userDocs = userSnap.data?.docs ?? [];
                  int totalUsers = userDocs.length;
                  int activeCount = 0;
                  int invitedCount = 0;
                  int bannedCount = 0;
                  int onlineCount = 0;

                  for (final doc in userDocs) {
                    final data = doc.data();
                    final actInfo = UserPresenceHelper.getActivationInfo(data);
                    final isOnline = UserPresenceHelper.isUserOnline(data);

                    if (isOnline) onlineCount++;
                    if (actInfo.statusKey == 'active') activeCount++;
                    if (actInfo.statusKey == 'invited') invitedCount++;
                    if (actInfo.statusKey == 'banned') bannedCount++;
                  }

                  final query = _searchController.text.trim().toLowerCase();

                  // Filtered users
                  final filtered = userDocs.where((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    final phone = (data['phone'] ?? '').toString().toLowerCase();
                    final actInfo = UserPresenceHelper.getActivationInfo(data);
                    final isOnline = UserPresenceHelper.isUserOnline(data);

                    // Activation Filter
                    if (_activationFilter == 'active' && actInfo.statusKey != 'active') return false;
                    if (_activationFilter == 'invited' && actInfo.statusKey != 'invited') return false;
                    if (_activationFilter == 'banned' && actInfo.statusKey != 'banned') return false;

                    // Presence Filter
                    if (_presenceFilter == 'online' && !isOnline) return false;
                    if (_presenceFilter == 'offline' && isOnline) return false;

                    // Search matching
                    if (query.isNotEmpty) {
                      final matches = name.contains(query) || email.contains(query) || phone.contains(query) || doc.id.toLowerCase().contains(query);
                      if (!matches) return false;
                    }

                    return true;
                  }).toList();

                  return Column(
                    children: [
                      // Metric Cards Overview
                      Row(
                        children: [
                          Expanded(child: _metricCard('Total Utilisateurs', '$totalUsers', Icons.people_alt_rounded, const Color(0xFF2563EB))),
                          const SizedBox(width: 12),
                          Expanded(child: _metricCard('Comptes Activés', '$activeCount', Icons.check_circle_rounded, const Color(0xFF059669))),
                          const SizedBox(width: 12),
                          Expanded(child: _metricCard('En Attente d\'Activation', '$invitedCount', Icons.mark_email_unread_rounded, const Color(0xFFD97706))),
                          const SizedBox(width: 12),
                          Expanded(child: _metricCard('En Ligne (Actifs)', '$onlineCount', Icons.sensors_rounded, const Color(0xFF10B981))),
                          const SizedBox(width: 12),
                          Expanded(child: _metricCard('Comptes Suspendus', '$bannedCount', Icons.block_rounded, const Color(0xFFDC2626))),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Search & Filter Bar
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
                                  hintText: 'Rechercher par nom, email, téléphone, ID...',
                                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Filter Activation
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
                                value: _activationFilter,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Toutes activations')),
                                  DropdownMenuItem(value: 'active', child: Text('Activés uniquement')),
                                  DropdownMenuItem(value: 'invited', child: Text('En attente (Invitations)')),
                                  DropdownMenuItem(value: 'banned', child: Text('Suspendus / Bannis')),
                                ],
                                onChanged: (v) => v != null ? setState(() => _activationFilter = v) : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Filter Presence
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
                                value: _presenceFilter,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Toutes présences')),
                                  DropdownMenuItem(value: 'online', child: Text('En Ligne')),
                                  DropdownMenuItem(value: 'offline', child: Text('Hors Ligne (Dernier vu)')),
                                ],
                                onChanged: (v) => v != null ? setState(() => _presenceFilter = v) : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // User List
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.person_off_rounded, size: 44, color: Color(0xFF94A3B8)),
                                    SizedBox(height: 10),
                                    Text('Aucun utilisateur ne correspond à ce filtre.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final doc = filtered[index];
                                  final data = doc.data();
                                  final userId = doc.id;
                                  final name = data['name'] ?? data['displayName'] ?? (data['email'] != null ? data['email'].toString().split('@').first : 'Utilisateur');
                                  final email = data['email'] ?? 'N/A';
                                  final phone = data['phone'] ?? 'N/A';
                                  final role = (data['role'] ?? 'user').toString().toUpperCase();
                                  final isOnline = UserPresenceHelper.isUserOnline(data);
                                  final lastConnTimestamp = data['lastLoginAt'] ?? data['lastHeartbeat'] ?? data['lastConnectedAt'] ?? data['updatedAt'];
                                  final lastConnStr = UserPresenceHelper.formatLastConnected(lastConnTimestamp);
                                  final actInfo = UserPresenceHelper.getActivationInfo(data);

                                  return Card(
                                    elevation: 0,
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: actInfo.isActivated ? const Color(0xFFE2E8F0) : actInfo.color.withValues(alpha: 0.4), width: 1.0),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: actInfo.backgroundColor,
                                            child: Icon(actInfo.icon, color: actInfo.color, size: 20),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                                    const SizedBox(width: 8),
                                                    // Activation Status Badge
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                      decoration: BoxDecoration(color: actInfo.backgroundColor, borderRadius: BorderRadius.circular(4)),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(actInfo.icon, size: 11, color: actInfo.color),
                                                          const SizedBox(width: 4),
                                                          Text(actInfo.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: actInfo.color)),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    // Presence Badge with Last Connected
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: isOnline ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: isOnline ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 6,
                                                            height: 6,
                                                            decoration: BoxDecoration(
                                                              color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 5),
                                                          Text(
                                                            isOnline ? 'EN LIGNE' : 'HORS LIGNE • Dernier vu: $lastConnStr',
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: isOnline ? const Color(0xFF059669) : const Color(0xFF64748B),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                                      child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Email : $email • Tél : $phone • ID : $userId',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
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


  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }
}
