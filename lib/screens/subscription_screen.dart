import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/trial_service.dart';
import '../models/subscription_payment.dart';
import '../services/subscription_payment_service.dart';
import '../utils/constants.dart';
import '../widgets/payment_confirmation_dialog.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  void _openPaymentDialog(BuildContext context, {
    required String planName,
    required double priceTtc,
    required int durationDays,
  }) {
    PaymentConfirmationDialog.show(
      context,
      planName: planName,
      priceTtc: priceTtc,
      durationDays: durationDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trial = TrialService.instance.currentTrial;
    final isExpired = trial?.isTrialExpired ?? false;
    final startDate = trial?.trialStartDate ?? DateTime.now().subtract(const Duration(days: 7));
    final endDate = trial?.trialEndDate ?? DateTime.now();

    final dateFormat = DateFormat('dd MMM, yyyy HH:mm', 'fr_FR');
    final dateRangeStr = '${dateFormat.format(startDate)} → ${dateFormat.format(endDate)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF39C12), size: 22),
            const SizedBox(width: 8),
            Text(
              'Abonnement & Licence',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Top Header Card ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF39C12), size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Abonnement',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              // Status pill (Expiré / Actif / Essai)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isExpired ? const Color(0xFFE74C3C) : AppColors.success,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  isExpired ? 'Expiré' : (trial?.isUpgraded == true ? 'Actif' : 'Essai gratuit'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateRangeStr,
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ─── 3 Metrics Cards Row ───────────────────────────
                          isMobile
                              ? Column(
                                  children: [
                                    _buildMetricCard(
                                      icon: Icons.apartment_rounded,
                                      iconBg: const Color(0xFFEBF5FB),
                                      iconColor: const Color(0xFF2980B9),
                                      title: 'Entreprises illimitées',
                                    ),
                                    const SizedBox(height: 10),
                                    _buildMetricCard(
                                      icon: Icons.people_rounded,
                                      iconBg: const Color(0xFFE8F8F5),
                                      iconColor: const Color(0xFF27AE60),
                                      title: 'Utilisateurs illimités',
                                    ),
                                    const SizedBox(height: 10),
                                    _buildMetricCard(
                                      icon: Icons.group_rounded,
                                      iconBg: const Color(0xFFFEF9E7),
                                      iconColor: const Color(0xFFF39C12),
                                      title: 'Utilisateurs illimités',
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricCard(
                                        icon: Icons.apartment_rounded,
                                        iconBg: const Color(0xFFEBF5FB),
                                        iconColor: const Color(0xFF2980B9),
                                        title: 'Entreprises illimitées',
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _buildMetricCard(
                                        icon: Icons.people_rounded,
                                        iconBg: const Color(0xFFE8F8F5),
                                        iconColor: const Color(0xFF27AE60),
                                        title: 'Utilisateurs illimités',
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _buildMetricCard(
                                        icon: Icons.group_rounded,
                                        iconBg: const Color(0xFFFEF9E7),
                                        iconColor: const Color(0xFFF39C12),
                                        title: 'Utilisateurs illimités',
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── 3 Pricing Cards Row ─────────────────────────────────
                    isMobile
                        ? Column(
                            children: [
                              _buildMonthlyPlanCard(context),
                              const SizedBox(height: 20),
                              _buildAnnualPlanCard(context),
                              const SizedBox(height: 20),
                              _buildCustomPlanCard(context),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildMonthlyPlanCard(context)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildAnnualPlanCard(context)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildCustomPlanCard(context)),
                            ],
                          ),
                    const SizedBox(height: 36),

                    // ─── Historique des paiements Section (Image Match!) ────
                    _buildPaymentHistorySection(context, isMobile),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Metric Card Builder ─────────────────────────────────────────────
  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card 1: Plan Mensuel ────────────────────────────────────────────
  Widget _buildMonthlyPlanCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Plan Mensuel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('59 DT ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black)),
              const Text('TTC ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
              Text('30 jours', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 20),
          _featureRow('Utilisateurs illimités'),
          _featureRow('Entrepôts illimités'),
          _featureRow('Documents illimités'),
          _featureRow('Accès pendant 30 jours'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFF27AE60), size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '-50% sur la deuxième entreprise',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openPaymentDialog(
                context,
                planName: 'Plan Mensuel',
                priceTtc: 59.0,
                durationDays: 30,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: const Text('Choisir le plan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card 2: Plan Annuel (Populaire) ─────────────────────────────────
  Widget _buildAnnualPlanCard(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: const Color(0xFF2ECC71), width: 1.5),
            boxShadow: AppShadows.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Plan Annuel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Économisez 15% (109 DT)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('599 DT ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black)),
                  const Text('TTC ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                  Text('365 jours', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 2),
              const Text('≈ 50 DT /mois', style: TextStyle(fontSize: 12, color: Color(0xFF27AE60), fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              _featureRow('Utilisateurs illimités'),
              _featureRow('Entrepôts illimités'),
              _featureRow('Documents illimités'),
              _featureRow('Accès pendant 365 jours'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFF27AE60), size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '-50% sur la deuxième entreprise',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openPaymentDialog(
                    context,
                    planName: 'Plan Annuel',
                    priceTtc: 599.0,
                    durationDays: 365,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  child: const Text('Choisir le plan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        // Populaire Badge on Top Right (Changed from Meilleure offre!)
        Positioned(
          top: -12,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Populaire',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Card 3: Plan Personnalisé (Changed from Plan à Vie!) ─────────────
  Widget _buildCustomPlanCard(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: const Color(0xFFF39C12), width: 1.5),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plan Personnalisé', // Changed from Plan à Vie as requested!
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9E7),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Center(
                  child: Text(
                    'Contactez notre équipe',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD68910)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _featureRow('Accès sur mesure'),
              _featureRow('Utilisateurs illimités'),
              _featureRow('Entrepôts illimités'),
              _featureRow('Documents illimités'),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openPaymentDialog(
                    context,
                    planName: 'Plan Personnalisé',
                    priceTtc: 990.0,
                    durationDays: 365,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD35400),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  child: const Text('Contacter-nous', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        // Entreprise Badge on Top Right
        Positioned(
          top: -12,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD35400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_outline_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Entreprise',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Historique des paiements Section (Image Match!) ────────────────
  Widget _buildPaymentHistorySection(BuildContext context, bool isMobile) {
    final dateFormat = DateFormat('dd MMMM, yyyy HH:mm', 'fr_FR');
    final amountFormat = NumberFormat('#,##0.000', 'fr_FR');

    return StreamBuilder<List<SubscriptionPayment>>(
      stream: SubscriptionPaymentService.instance.getPaymentsStream(),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique des paiements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Column(
                children: [
                  // ─── Table Header ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFC),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: isMobile
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Paiement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                              Text('Statut / Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ],
                          )
                        : Row(
                            children: const [
                              Expanded(flex: 3, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54))),
                              Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54))),
                              Expanded(flex: 3, child: Text('Méthode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54))),
                              Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54))),
                              Expanded(flex: 2, child: Text('Payé le', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54))),
                              SizedBox(width: 160, child: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54))),
                            ],
                          ),
                  ),

                  // ─── Table Body / Rows ─────────────────────────────────────
                  if (payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textTertiary),
                            const SizedBox(height: 8),
                            Text(
                              'Aucun historique de paiement pour le moment',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                      itemBuilder: (context, index) {
                        final p = payments[index];
                        final dateStr = dateFormat.format(p.createdAt);
                        final paidStr = p.paidAt != null ? dateFormat.format(p.paidAt!) : '-';
                        final amountStr = '${amountFormat.format(p.amount)} DT';

                        if (isMobile) {
                          return Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.planName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      amountStr,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      p.method == 'card' ? Icons.credit_card_rounded : Icons.account_balance_rounded,
                                      size: 14,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        p.methodLabel,
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusBadge(p.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dateStr,
                                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 18),
                                      color: Colors.black54,
                                      tooltip: 'Voir détails',
                                      onPressed: () => _showPaymentDetailsModal(context, p),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton.icon(
                                      onPressed: () => _openPaymentDialog(
                                        context,
                                        planName: p.planName,
                                        priceTtc: p.amount > 1.0 ? p.amount - 1.0 : p.amount,
                                        durationDays: p.durationDays,
                                      ),
                                      icon: const Icon(Icons.sync_rounded, size: 13),
                                      label: const Text('Ressayer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        // Desktop Table Row (Image match)
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              // Date
                              Expanded(
                                flex: 3,
                                child: Text(dateStr, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              ),
                              // Montant
                              Expanded(
                                flex: 2,
                                child: Text(
                                  amountStr,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                                ),
                              ),
                              // Méthode
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Icon(
                                      p.method == 'card' ? Icons.credit_card_outlined : Icons.account_balance_outlined,
                                      size: 16,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(p.methodLabel, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                  ],
                                ),
                              ),
                              // Statut
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildStatusBadge(p.status),
                                ),
                              ),
                              // Payé le
                              Expanded(
                                flex: 2,
                                child: Text(paidStr, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              ),
                              // Actions
                              SizedBox(
                                width: 160,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 19),
                                      color: Colors.black54,
                                      tooltip: 'Voir détails',
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showPaymentDetailsModal(context, p),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _openPaymentDialog(
                                        context,
                                        planName: p.planName,
                                        priceTtc: p.amount > 1.0 ? p.amount - 1.0 : p.amount,
                                        durationDays: p.durationDays,
                                      ),
                                      icon: const Icon(Icons.sync_rounded, size: 15),
                                      label: const Text('Ressayer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // ─── Table Pagination Footer (Image Match!) ────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFD),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.md)),
                      border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
                    ),
                    child: isMobile
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${payments.length} résultat(s)',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              Row(
                                children: [
                                  _buildPaginationArrow(icon: Icons.chevron_left_rounded, enabled: false),
                                  const SizedBox(width: 6),
                                  _buildPaginationArrow(icon: Icons.chevron_right_rounded, enabled: false),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Row(
                                children: [
                                  Text('Lignes  ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: const [
                                        Text('10', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        SizedBox(width: 4),
                                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 24),
                              Text('Page 1 sur 1', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text(
                                'Affichage de ${payments.isEmpty ? 0 : 1} à ${payments.length} sur ${payments.length} résultats',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 16),
                              _buildPaginationArrow(icon: Icons.chevron_left_rounded, enabled: false),
                              const SizedBox(width: 6),
                              _buildPaginationArrow(icon: Icons.chevron_right_rounded, enabled: false),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Status Badge Widget ──────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    if (status == 'paid') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8F5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF27AE60)),
            SizedBox(width: 4),
            Text('Validé', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
          ],
        ),
      );
    }

    if (status == 'failed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFDEDEC),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFE74C3C)),
            SizedBox(width: 4),
            Text('Échoué', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE74C3C))),
          ],
        ),
      );
    }

    // Default: 'pending' (En attente) - Grey pill with clock (Image match)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF667085)),
          SizedBox(width: 5),
          Text('En attente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF344054))),
        ],
      ),
    );
  }

  Widget _buildPaginationArrow({required IconData icon, required bool enabled}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 18, color: enabled ? Colors.black87 : Colors.black26),
    );
  }

  void _showPaymentDetailsModal(BuildContext context, SubscriptionPayment payment) {
    final dateFormat = DateFormat('dd MMMM, yyyy HH:mm', 'fr_FR');
    final amountFormat = NumberFormat('#,##0.000', 'fr_FR');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Détails du paiement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Plan souscrit :', payment.planName),
            _detailRow('Montant TTC :', '${amountFormat.format(payment.amount)} DT'),
            _detailRow('Méthode :', payment.methodLabel),
            _detailRow('Statut :', payment.statusLabel),
            _detailRow('Date d\'initiation :', dateFormat.format(payment.createdAt)),
            _detailRow('Payé le :', payment.paidAt != null ? dateFormat.format(payment.paidAt!) : 'En attente de validation'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── Feature Row Item Builder ────────────────────────────────────────
  Widget _featureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFFEBF5FB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF2980B9), size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
