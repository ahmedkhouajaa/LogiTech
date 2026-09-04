import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/admin_billing_service.dart';

class PaymentValidationScreen extends StatelessWidget {
  const PaymentValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demandes de Paiement en Attente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Validez les virements bancaires reçus pour activer ou renouveler automatiquement les abonnements des entreprises.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('subscription_payments')
                    .where('status', isEqualTo: 'pending')
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
                          Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                          SizedBox(height: 12),
                          Text('Aucun paiement en attente de validation', style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final paymentId = doc.id;
                      final planName = data['planName'] ?? 'Plan';
                      final amount = data['amount'] ?? 0.0;
                      final enterpriseId = data['enterpriseId'] ?? '';
                      final method = data['method'] ?? 'bank_transfer';
                      final durationDays = data['durationDays'] ?? (planName == 'Plan Annuel' ? 365 : 30);
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('$planName • $amount DT TTC', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('EN ATTENTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Entreprise ID : $enterpriseId • Méthode : $method', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text('Demande créée le : ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () => _confirmValidation(context, paymentId, enterpriseId, durationDays, planName),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Valider le Paiement'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  void _confirmValidation(BuildContext context, String paymentId, String enterpriseId, int durationDays, String planName) {
    final reasonController = TextEditingController(text: 'Virement bancaire vérifié et validé.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valider le paiement & Activer la licence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Êtes-vous sûr de vouloir valider le $planName pour l\'entreprise $enterpriseId ?\nL\'abonnement sera étendu de $durationDays jours.'),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Motif / Réf Virement',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await AdminBillingService.instance.validatePaymentAndExtendLicense(
                paymentId: paymentId,
                enterpriseId: enterpriseId,
                durationDays: durationDays,
                reason: reasonController.text,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paiement validé avec succès !'), backgroundColor: Color(0xFF059669)),
                );
              }
            },
            child: const Text('Confirmer la Validation'),
          ),
        ],
      ),
    );
  }
}
