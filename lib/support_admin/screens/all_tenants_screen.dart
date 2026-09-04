import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tenant_xray_screen.dart';

class AllTenantsScreen extends StatelessWidget {
  final bool showStatsOnly;

  const AllTenantsScreen({super.key, this.showStatsOnly = false});

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
              showStatsOnly ? 'Statistiques & Métriques des Entreprises (Tenants)' : 'Annuaire Complet des Entreprises',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Consultez la liste exhaustive de tous les tenants enregistrés sur la plateforme LogiTech Pro.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('Aucune entreprise trouvée', style: TextStyle(color: Colors.black54)));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final entId = docs[index].id;
                      final name = data['name'] ?? 'Entreprise sans nom';
                      final tax = data['taxNumber'] ?? 'Non renseigné';
                      final isUpgraded = data['isUpgraded'] == true;

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.business_rounded, color: Color(0xFF2563EB))),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isUpgraded ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isUpgraded ? 'ABONNÉ' : 'ESSAI',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUpgraded ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('ID : $entId • Matricule : $tax • Tél : ${data['phone'] ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                          trailing: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TenantXRayScreen(enterpriseId: entId)),
                              );
                            },
                            icon: const Icon(Icons.manage_search_rounded, size: 16),
                            label: const Text('X-Ray'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
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
