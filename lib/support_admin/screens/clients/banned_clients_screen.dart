import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BannedClientsScreen extends StatelessWidget {
  const BannedClientsScreen({super.key});

  void _reactivateClient(BuildContext context, String userId, String userName, String userEmail, List<Map<String, dynamic>> userEnterprises) {
    final enterpriseNames = userEnterprises.map((e) => e['name'] ?? 'Entreprise').join(', ');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la réactivation'),
        content: Text(
          'Voulez-vous réactiver le compte client "$userName" ($userEmail) ?\nL\'accès sera immédiatement rétabli ainsi que ses ${userEnterprises.length} entreprise(s) ($enterpriseNames).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final firestore = FirebaseFirestore.instance;
              final batch = firestore.batch();

              // 1. Unban User
              batch.update(firestore.collection('users').doc(userId), {
                'isBanned': false,
                'isDisabled': false,
                'status': 'active',
                'banReason': null,
                'unbannedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              // 2. Unban all their enterprises
              for (final ent in userEnterprises) {
                final entId = ent['id'] as String?;
                if (entId != null && entId.isNotEmpty) {
                  batch.update(firestore.collection('enterprises').doc(entId), {
                    'isBanned': false,
                    'status': 'active',
                    'banReason': null,
                    'unbannedAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
              }

              // 3. Audit log
              batch.set(firestore.collection('audit_logs').doc(), {
                'action': 'UNBAN_CLIENT_AND_ENTERPRISES',
                'targetUserId': userId,
                'targetUserName': userName,
                'targetUserEmail': userEmail,
                'enterprisesCount': userEnterprises.length,
                'reason': 'Réactivation manuelle par SuperAdmin',
                'timestamp': FieldValue.serverTimestamp(),
              });

              await batch.commit();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Client "$userName" et ses entreprises réactivés avec succès !'), backgroundColor: const Color(0xFF059669)),
                );
              }
            },
            child: const Text('Réactiver le client'),
          ),
        ],
      ),
    );
  }

  void _deletePermanently(BuildContext context, String userId, String userName, List<Map<String, dynamic>> userEnterprises) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suppression Définitive (SuperAdmin)'),
        content: Text(
          'Attention : Vous êtes sur le point de supprimer DÉFINITIVEMENT le client "$userName" et toutes ses ${userEnterprises.length} entreprise(s). Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final firestore = FirebaseFirestore.instance;
              final batch = firestore.batch();

              batch.delete(firestore.collection('users').doc(userId));
              for (final ent in userEnterprises) {
                final entId = ent['id'] as String?;
                if (entId != null && entId.isNotEmpty) {
                  batch.delete(firestore.collection('enterprises').doc(entId));
                }
              }

              final auditRef = firestore.collection('audit_logs').doc();
              batch.set(auditRef, {
                'action': 'DELETE_CLIENT_AND_ENTERPRISES_PERMANENT',
                'targetUserId': userId,
                'targetUserName': userName,
                'timestamp': FieldValue.serverTimestamp(),
              });

              await batch.commit();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Client "$userName" supprimé définitivement.'), backgroundColor: const Color(0xFFDC2626)),
                );
              }
            },
            child: const Text('Supprimer définitivement'),
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
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Clients Bannis / Suspendus',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Liste des comptes clients suspendus et de toutes leurs entreprises bloquées.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
                builder: (context, enterpriseSnapshot) {
                  final allEnterprises = enterpriseSnapshot.data?.docs ?? [];
                  final Map<String, Map<String, dynamic>> entMap = {};
                  for (final doc in allEnterprises) {
                    entMap[doc.id] = {'id': doc.id, ...doc.data()};
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final userDocs = userSnapshot.data?.docs ?? [];

                      // Find banned users OR users with banned enterprises
                      final bannedUsers = userDocs.where((doc) {
                        final data = doc.data();
                        final isUserBanned = data['isBanned'] == true ||
                            data['isDisabled'] == true ||
                            data['status'] == 'banned' ||
                            data['status'] == 'disabled' ||
                            data['isActive'] == false;

                        if (isUserBanned) return true;

                        // Check if any enterprise owned by this user is banned
                        final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
                        if (curEnt != null && entMap[curEnt]?['isBanned'] == true) return true;

                        return false;
                      }).toList();

                      if (bannedUsers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF10B981)),
                              SizedBox(height: 12),
                              Text('Aucun client banni actuellement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              SizedBox(height: 4),
                              Text('Tous les comptes clients et entreprises sont en règle et actifs.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: bannedUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final userDoc = bannedUsers[index];
                          final data = userDoc.data();
                          final userId = userDoc.id;
                          final name = data['name'] ?? data['displayName'] ?? 'Client sans nom';
                          final email = data['email'] ?? 'N/A';
                          final phone = data['phone'] ?? 'N/A';
                          final banReason = data['banReason'] ?? 'Suspension administrative / Défaut de paiement';
                          final bannedAt = (data['bannedAt'] as Timestamp?)?.toDate();

                          // Resolve user's enterprises
                          final userEntIds = <String>{};
                          final curEnt = data['currentEnterpriseId'] ?? data['enterpriseId'];
                          if (curEnt != null && curEnt.toString().isNotEmpty) userEntIds.add(curEnt.toString());
                          final entList = data['enterprises'];
                          if (entList is List) {
                            for (final e in entList) {
                              if (e != null && e.toString().isNotEmpty) userEntIds.add(e.toString());
                            }
                          }
                          for (final ent in allEnterprises) {
                            if (ent.data()['ownerId'] == userId) {
                              userEntIds.add(ent.id);
                            }
                          }

                          final userEnterprises = userEntIds
                              .map((eid) => entMap[eid] ?? {'id': eid, 'name': 'Entreprise ($eid)'})
                              .toList();

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(width: 4.5, color: const Color(0xFFEF4444)),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const CircleAvatar(
                                                radius: 20,
                                                backgroundColor: Color(0xFFFEE2E2),
                                                child: Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A))),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                                                          child: const Text('COMPTE BANNI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'ID Client : $userId • Email : $email • Tél : $phone ${bannedAt != null ? "• Banni le : ${dateFormat.format(bannedAt)}" : ""}',
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF059669),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    onPressed: () => _reactivateClient(context, userId, name, email, userEnterprises),
                                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                                    label: const Text('Réactiver le Client'),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    tooltip: 'Supprimer définitivement',
                                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                                    onPressed: () => _deletePermanently(context, userId, name, userEnterprises),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF1F2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFECDD3)),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Motif du bannissement : $banReason',
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF9F1239), fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Enterprises list
                                          if (userEnterprises.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.business_rounded, size: 14, color: Color(0xFF64748B)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Entreprises bloquées (${userEnterprises.length}) : ',
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    userEnterprises.map((e) => e['name'] ?? 'Entreprise').join(', '),
                                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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
