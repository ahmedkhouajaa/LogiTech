import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'shimmer_effect.dart';
import 'shimmer_table_row.dart';

/// Skeleton shimmer loading widget for the Dashboard.
class DashboardShimmerWidget extends StatelessWidget {
  const DashboardShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return AppShimmer(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPI Skeleton Row ──────────────────────────────────────
            if (isMobile)
              Column(
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildKpiCardSkeleton(),
                  ),
                ),
              )
            else
              Row(
                children: List.generate(
                  4,
                  (index) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 3 ? AppSpacing.md : 0),
                      child: _buildKpiCardSkeleton(),
                    ),
                  ),
                ),
              ),

            SizedBox(height: AppSpacing.lg),

            // ── Recent Invoices Skeleton Table ────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      ShimmerBox(width: 150, height: 18, borderRadius: 4),
                      ShimmerBox(width: 80, height: 14, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Column(
                    children: List.generate(
                      5,
                      (index) => ShimmerTableRow(
                        isEven: index % 2 == 0,
                        refWidth: 100 + (index % 2) * 20,
                        dateWidth: 120,
                        clientWidth: 130 + (index % 3) * 15,
                        statusWidth: 70,
                        amountWidth: 85 + (index % 2) * 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCardSkeleton() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBox(width: 110, height: 12, borderRadius: 4),
              ShimmerBox(width: 32, height: 32, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerBox(width: 140, height: 22, borderRadius: 4),
          const SizedBox(height: 8),
          const ShimmerBox(width: 90, height: 11, borderRadius: 4),
        ],
      ),
    );
  }
}
