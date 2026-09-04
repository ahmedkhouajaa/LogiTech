import 'package:flutter/material.dart';

class AnalyticsReportsScreen extends StatelessWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rapports, Métriques & Satisfaction Client (CSAT)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Analyse des performances globales de l\'équipe support et conformité SLA.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),

            // Top Summary KPI Row
            Row(
              children: [
                _metricBox('Conformité SLA', '98.4%', Icons.check_circle_rounded, const Color(0xFF10B981)),
                const SizedBox(width: 14),
                _metricBox('Délai Moyen 1ère Réponse', '14 min', Icons.timer_rounded, const Color(0xFF2563EB)),
                const SizedBox(width: 14),
                _metricBox('Score CSAT Global', '4.9 / 5', Icons.star_rounded, const Color(0xFFF59E0B)),
                const SizedBox(width: 14),
                _metricBox('Taux de Résolution', '96.2%', Icons.task_alt_rounded, const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 24),

            // CSAT Breakdown Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.thumb_up_rounded, color: Color(0xFF2563EB), size: 20),
                        SizedBox(width: 10),
                        Text('Distribution des Notes de Satisfaction Client (CSAT)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _csatRatingBar('⭐⭐⭐⭐⭐ (Très Satisfait)', 0.85, '85% (142 avis)'),
                    const SizedBox(height: 10),
                    _csatRatingBar('⭐⭐⭐⭐ (Satisfait)', 0.11, '11% (18 avis)'),
                    const SizedBox(height: 10),
                    _csatRatingBar('⭐⭐⭐ (Moyen)', 0.03, '3% (5 avis)'),
                    const SizedBox(height: 10),
                    _csatRatingBar('⭐⭐ / ⭐ (Insatisfait)', 0.01, '1% (2 avis)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _csatRatingBar(String title, double fraction, String countText) {
    return Row(
      children: [
        SizedBox(width: 200, child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: fraction, minHeight: 12, backgroundColor: const Color(0xFFF1F5F9), color: const Color(0xFF10B981)),
          ),
        ),
        const SizedBox(width: 14),
        Text(countText, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
      ],
    );
  }
}
