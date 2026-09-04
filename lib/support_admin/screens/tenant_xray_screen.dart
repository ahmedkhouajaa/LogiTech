import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TenantXRayScreen extends StatelessWidget {
  final String enterpriseId;

  const TenantXRayScreen({super.key, required this.enterpriseId});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('X-Ray Inspection : $enterpriseId'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          firestore.collection('enterprises').doc(enterpriseId).get(),
          firestore.collection('invoices').where('enterpriseId', isEqualTo: enterpriseId).count().get(),
          firestore.collection('users').where('enterpriseId', isEqualTo: enterpriseId).get(),
          firestore.collection('subscription_payments').where('enterpriseId', isEqualTo: enterpriseId).get(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Erreur lors du chargement : ${snapshot.error}'));
          }

          final enterpriseDoc = snapshot.data![0] as DocumentSnapshot<Map<String, dynamic>>;
          final invoiceCount = (snapshot.data![1] as AggregateQuerySnapshot).count;
          final usersSnap = snapshot.data![2] as QuerySnapshot<Map<String, dynamic>>;
          final paymentsSnap = snapshot.data![3] as QuerySnapshot<Map<String, dynamic>>;

          final entData = enterpriseDoc.data() ?? {};
          final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
          final trialEnd = (entData['trialEndDate'] as Timestamp?)?.toDate();
          final isUpgraded = entData['isUpgraded'] == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Enterprise Info Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 26, backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.business_rounded, color: Color(0xFF2563EB), size: 26)),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entData['name'] ?? 'Entreprise sans nom', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Text('Matricule Fiscal : ${entData['taxNumber'] ?? "Non renseigné"} • Tél : ${entData['phone'] ?? "N/A"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isUpgraded ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isUpgraded ? 'ABONNEMENT ACTIF' : 'PÉRIODE D\'ESSAI',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isUpgraded ? const Color(0xFF059669) : const Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Metrics Row
                Row(
                  children: [
                    _metricCard('Factures Créées', invoiceCount.toString(), Icons.receipt_long_rounded),
                    const SizedBox(width: 12),
                    _metricCard('Utilisateurs Actifs', usersSnap.docs.length.toString(), Icons.people_rounded),
                    const SizedBox(width: 12),
                    _metricCard('Expiration Licence', trialEnd != null ? dateFormat.format(trialEnd) : 'Inconnue', Icons.verified_user_rounded),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. User List
                const Text('Utilisateurs & Collaborateurs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: usersSnap.docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = usersSnap.docs[index].data();
                      return ListTile(
                        leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                        title: Text(u['name'] ?? u['email'] ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text('Rôle : ${u['role'] ?? "collaborator"} • Email : ${u['email'] ?? "N/A"}', style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Payment History
                const Text('Historique des Paiements', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                  child: paymentsSnap.docs.isEmpty
                      ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Aucun paiement enregistré', style: TextStyle(color: Colors.black54))))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: paymentsSnap.docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = paymentsSnap.docs[index].data();
                            final status = p['status'] ?? 'pending';
                            final isPaid = status == 'paid';

                            return ListTile(
                              leading: Icon(isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                              title: Text('${p['planName'] ?? "Abonnement"} • ${p['amount']} DT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Statut : ${status.toUpperCase()} • Méthode : ${p['method'] ?? "Virement"}', style: const TextStyle(fontSize: 11)),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF2563EB), size: 20),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}
