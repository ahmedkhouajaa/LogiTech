import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final bool showPlansOnly;

  const PaymentHistoryScreen({super.key, this.showPlansOnly = false});

  @override
  Widget build(BuildContext context) {
    if (showPlansOnly) {
      return _buildPlansView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique des Transactions & Règlements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Grand livre des abonnements validés, montants TTC et durées de licence associées.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('subscription_payments')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('Aucune transaction enregistrée', style: TextStyle(color: Colors.black54)));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = docs[index].data();
                      final status = p['status'] ?? 'pending';
                      final isPaid = status == 'paid';
                      final amount = p['amount'] ?? 0.0;
                      final planName = p['planName'] ?? 'Abonnement';
                      final enterpriseId = p['enterpriseId'] ?? 'N/A';
                      final date = (p['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            child: Icon(isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded, color: isPaid ? const Color(0xFF10B981) : const Color(0xFFD97706), size: 20),
                          ),
                          title: Row(
                            children: [
                              Text('$planName • $amount DT TTC', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706))),
                              ),
                            ],
                          ),
                          subtitle: Text('Entreprise : $enterpriseId • Méthode : ${p['method'] ?? "Virement"}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          trailing: Text(DateFormat('dd/MM/yyyy HH:mm').format(date), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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

  Widget _buildPlansView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Plans d\'Abonnement & Tarification Active', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Grille tarifaire officielle configurée dans LogiTech Pro.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            Row(
              children: [
                _planCard('Plan Mensuel', '59 DT', 'TTC / 30 jours', 'Essentiel pour démarrage', const [
                  'Multi-utilisateurs & Rôles',
                  'Facturation & Devis illimités',
                  'Gestion de stock & inventaire',
                  'Support client standard',
                ]),
                const SizedBox(width: 16),
                _planCard('Plan Annuel (Recommandé)', '599 DT', 'TTC / 365 jours', 'Économisez 15% (109 DT)', const [
                  'Toutes les fonctionnalités incluses',
                  'Support technique prioritaire 24/7',
                  'Assistance à l\'importation des données',
                  'Garantie SLA 1 heure',
                ], isPopular: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(String title, String price, String period, String subtitle, List<String> features, {bool isPopular = false}) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isPopular ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isPopular ? 2 : 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isPopular ? const Color(0xFF2563EB) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(width: 6),
                  Text(period, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              const Divider(height: 32),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 8),
                        Text(f, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
