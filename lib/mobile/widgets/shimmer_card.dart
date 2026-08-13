import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/shimmer_effect.dart';

/// Mobile skeleton card matching the exact structure of MobileDevisCard.
/// Wrap a list of these in [AppShimmer] to animate them.
class ShimmerCard extends StatelessWidget {
  final double refWidth;
  final double statusWidth;
  final double dateWidth;
  final double clientWidth;
  final double amountWidth;

  const ShimmerCard({
    super.key,
    this.refWidth = 120,
    this.statusWidth = 75,
    this.dateWidth = 90,
    this.clientWidth = 125,
    this.amountWidth = 75,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Exact same margin as MobileDevisCard
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      // Exact same inner padding as MobileDevisCard
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: Ref badge · Status chip · Chevron ──────────
            Row(
              children: [
                ShimmerBox(width: refWidth, height: 24, borderRadius: 6),
                const Spacer(),
                ShimmerBox(width: statusWidth, height: 24, borderRadius: 20),
                const SizedBox(width: 6),
                const ShimmerBox(width: 16, height: 16, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 12),

            // ── Date row ─────────────────────────────────────────────
            Row(
              children: [
                const ShimmerBox(width: 14, height: 14, borderRadius: 3),
                const SizedBox(width: 6),
                ShimmerBox(width: dateWidth, height: 13, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 8),

            // ── Client · Amount row ──────────────────────────────────
            Row(
              children: [
                const ShimmerBox(width: 14, height: 14, borderRadius: 3),
                const SizedBox(width: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ShimmerBox(
                        width: clientWidth, height: 13, borderRadius: 4),
                  ),
                ),
                ShimmerBox(width: amountWidth, height: 14, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
