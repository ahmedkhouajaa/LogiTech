import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PasswordManagementScreen extends StatefulWidget {
  const PasswordManagementScreen({super.key});

  @override
  State<PasswordManagementScreen> createState() => _PasswordManagementScreenState();
}

class _PasswordManagementScreenState extends State<PasswordManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail(String userEmail, String userName) async {
    if (userEmail.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: userEmail);

      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'PASSWORD_RESET_EMAIL_SENT',
        'targetUserEmail': userEmail,
        'targetUserName': userName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email de réinitialisation envoyé avec succès à $userEmail !'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi : ${e.toString()}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _toggleUserAccount(String userId, String userEmail, bool isCurrentlyDisabled) async {
    final action = isCurrentlyDisabled ? 'Activer' : 'Désactiver';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action le compte utilisateur'),
        content: Text('Voulez-vous vraiment $action le compte de "$userEmail" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyDisabled ? const Color(0xFF059669) : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('users').doc(userId).update({
                'isDisabled': !isCurrentlyDisabled,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              await FirebaseFirestore.instance.collection('audit_logs').add({
                'action': isCurrentlyDisabled ? 'ENABLE_USER_ACCOUNT' : 'DISABLE_USER_ACCOUNT',
                'targetUserId': userId,
                'targetUserEmail': userEmail,
                'timestamp': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Compte $userEmail ${isCurrentlyDisabled ? "activé" : "désactivé"}.'),
                    backgroundColor: isCurrentlyDisabled ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            child: Text('Confirmer $action'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

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
                const Icon(Icons.key_rounded, color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Gestion des Mots de Passe & Accès Utilisateurs',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Réinitialisez les mots de passe des comptes clients, envoyez des liens sécurisés et gérez l\'état des accès.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Search input
            SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Rechercher un utilisateur par nom, email, entreprise ou ID...',
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
            const SizedBox(height: 16),

            // Users Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final query = _searchController.text.trim().toLowerCase();

                  final filtered = docs.where((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    final enterpriseId = (data['enterpriseId'] ?? '').toString().toLowerCase();
                    final role = (data['role'] ?? '').toString().toLowerCase();

                    if (query.isNotEmpty) {
                      return name.contains(query) || email.contains(query) || enterpriseId.contains(query) || role.contains(query) || doc.id.toLowerCase().contains(query);
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.person_search_rounded, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('Aucun utilisateur trouvé', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data();
                      final userId = doc.id;
                      final name = data['name'] ?? data['displayName'] ?? 'Utilisateur';
                      final email = data['email'] ?? '';
                      final role = (data['role'] ?? 'Utilisateur').toString().toUpperCase();
                      final entId = data['enterpriseId'] ?? 'N/A';
                      final isDisabled = data['isDisabled'] == true;
                      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isDisabled ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0), width: 1.0),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(width: 4.5, color: isDisabled ? const Color(0xFFEF4444) : const Color(0xFF2563EB)),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isDisabled ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                        child: Icon(isDisabled ? Icons.person_off_rounded : Icons.person_rounded, color: isDisabled ? const Color(0xFFDC2626) : const Color(0xFF2563EB), size: 20),
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
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                                  child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                                ),
                                                if (isDisabled) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                                    child: const Text('COMPTE BLOQUÉ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Email : $email • Entreprise ID : $entId ${updatedAt != null ? '• Dernier changement : ${dateFormat.format(updatedAt)}' : ''}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: isDisabled ? 'Activer le compte' : 'Désactiver le compte',
                                            icon: Icon(isDisabled ? Icons.check_circle_outline_rounded : Icons.block_rounded, color: isDisabled ? const Color(0xFF059669) : const Color(0xFFDC2626), size: 20),
                                            onPressed: () => _toggleUserAccount(userId, email, isDisabled),
                                          ),
                                          const SizedBox(width: 6),
                                          ElevatedButton.icon(
                                            onPressed: email.isNotEmpty ? () => _sendPasswordResetEmail(email, name) : null,
                                            icon: const Icon(Icons.send_rounded, size: 14),
                                            label: const Text('Envoyer Reset MDP'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2563EB),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
        ),
      ),
    );
  }
}
