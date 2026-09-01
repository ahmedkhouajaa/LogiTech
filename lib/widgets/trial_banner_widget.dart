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
        if (trial == null || trial.isUpgraded) {
          return const SizedBox.shrink();
        }

        final isExpired = trial.isTrialExpired;

        if (isExpired) {
          // EXPIRED TRIAL BANNER (Matching user's screenshot!)
          return InkWell(
            onTap: () => _openSubscription(context),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEDEC), // Light red background matching screenshot
                border: Border.all(
                  color: const Color(0xFFE74C3C), // Red border matching screenshot
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

        // ACTIVE TRIAL COUNTDOWN BANNER (7, 6, 5, 4, 3, 2, 1 days)
        final days = trial.daysRemaining;

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
                        TextSpan(
                          text: 'Essai gratuit : ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
      },
    );
  }
}
