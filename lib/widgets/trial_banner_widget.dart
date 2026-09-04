import 'package:flutter/material.dart';
import '../services/trial_service.dart';
import '../utils/constants.dart';

import '../screens/subscription_screen.dart';

class TrialBannerWidget extends StatelessWidget {
  const TrialBannerWidget({super.key});

  void _openSubscription(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TrialInfo?>(
      valueListenable: TrialService.instance.trialNotifier,
      builder: (context, trial, _) {
        if (trial == null) {
          return const SizedBox.shrink();
        }

        final isTrial = trial.isTrial;
        final days = trial.daysRemaining;

        // 1. TRIAL EXPIRED BANNER
        if (trial.isTrialExpired) {
          return InkWell(
            onTap: () => _openSubscription(context),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEDEC),
                border: Border.all(
                  color: const Color(0xFFE74C3C),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE74C3C),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                        children: [
                          TextSpan(
                            text: 'Essai expiré - ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          TextSpan(
                            text: 'Cliquez ici pour mettre à niveau votre plan',
                            style: TextStyle(
                              color: Color(0xFF1B4F72),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 2. ACTIVE TRIAL COUNTDOWN BANNER (e.g. 6 jours, 11 jours)
        if (isTrial) {
          return InkWell(
            onTap: () => _openSubscription(context),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        children: [
                          const TextSpan(
                            text: 'Essai gratuit : ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: '$days jour(s) restant(s) - ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: days <= 2 ? AppColors.warning : AppColors.primary,
                            ),
                          ),
                          const TextSpan(
                            text: 'Cliquez ici pour mettre à niveau votre plan',
                            style: TextStyle(
                              color: Color(0xFF1B4F72),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 3. ACTIVE PAID SUBSCRIPTION BANNER (pro, annual, enterprise, monthly)
        if (days <= 0) {
          return InkWell(
            onTap: () => _openSubscription(context),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEDEC),
                border: Border.all(color: const Color(0xFFE74C3C)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFE74C3C), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Abonnement expiré - Cliquez ici pour renouveler votre licence',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE74C3C)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 3. VIP SUBSCRIPTION BANNER (Shows "Abonnement VIP" without remaining days countdown)
        if (trial.isVip || days >= 3000) {
          return InkWell(
            onTap: () => _openSubscription(context),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        children: [
                          TextSpan(
                            text: 'Abonnement VIP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          TextSpan(
                            text: ' - ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                          TextSpan(
                            text: 'Gérer votre plan',
                            style: TextStyle(
                              color: Color(0xFF1B4F72),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return InkWell(
          onTap: () => _openSubscription(context),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF059669),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      children: [
                        const TextSpan(
                          text: 'Abonnement Premium : ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                        TextSpan(
                          text: '$days jour(s) restant(s) - ',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                        const TextSpan(
                          text: 'Gérer votre plan',
                          style: TextStyle(
                            color: Color(0xFF1B4F72),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
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
  }
}
