import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'shimmer_effect.dart';

/// Skeleton table row matching the exact layout & proportions of desktop tables.
class ShimmerTableRow extends StatelessWidget {
  final bool isEven;
  final List<Widget>? customCells;
  final double refWidth;
  final double dateWidth;
  final double clientWidth;
  final double statusWidth;
  final double amountWidth;

  const ShimmerTableRow({
    super.key,
    this.isEven = true,
    this.customCells,
    this.refWidth = 110,
    this.dateWidth = 130,
    this.clientWidth = 140,
    this.statusWidth = 70,
    this.amountWidth = 90,
  });

  const ShimmerTableRow.custom({
    super.key,
    required List<Widget> cells,
    this.isEven = true,
  })  : customCells = cells,
        refWidth = 110,
        dateWidth = 130,
        clientWidth = 140,
        statusWidth = 70,
        amountWidth = 90;

  @override
  Widget build(BuildContext context) {
    final bgColor = isEven
        ? AppColors.surface
        : AppColors.background.withValues(alpha: 0.3);

    if (customCells != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: bgColor,
        child: Row(children: customCells!),
      );
    }

    return Container(
      // Exact same padding as real rows
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: bgColor,
      child: Row(
        children: [
          // ── Checkbox space ──────────────────────────────────────
          const SizedBox(
            width: 32,
            child: Center(
              child: ShimmerBox(width: 16, height: 16, borderRadius: 3),
            ),
          ),

          // ── Reference + Date ────────────────────────────────────
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShimmerBox(width: refWidth, height: 13, borderRadius: 4),
                const SizedBox(height: 6),
                ShimmerBox(width: dateWidth, height: 11, borderRadius: 4),
              ],
            ),
          ),

          // ── Client ──────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const ShimmerBox(width: 14, height: 14, borderRadius: 3),
                const SizedBox(width: 6),
                ShimmerBox(width: clientWidth, height: 13, borderRadius: 4),
              ],
            ),
          ),

          // ── Statut badge ────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShimmerBox(
                  width: statusWidth, height: 22, borderRadius: 4),
            ),
          ),

          // ── Montant ─────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: ShimmerBox(width: amountWidth, height: 13, borderRadius: 4),
          ),

          // ── Actions icon ─────────────────────────────────────────
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: ShimmerBox(width: 20, height: 13, borderRadius: 4),
            ),
          ),
        ],
      ),
    );
  }
}

/// A generic Desktop Skeleton Table helper that wraps header shell and 6 skeleton rows
class ShimmerTable extends StatelessWidget {
  final List<Widget> headerColumns;
  final Widget Function(int index)? rowBuilder;

  const ShimmerTable({
    super.key,
    required this.headerColumns,
    this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('generic_table_shimmer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                      color: AppColors.background,
                    ),
                    child: Row(children: headerColumns),
                  ),
                  // Table body shimmer rows
                  Expanded(
                    child: AppShimmer(
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 6,
                        separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          if (rowBuilder != null) {
                            return rowBuilder!(index);
                          }
                          return ShimmerTableRow(
                            isEven: index % 2 == 0,
                            refWidth: index % 2 == 0 ? 120 : 135,
                            dateWidth: index % 2 == 0 ? 140 : 125,
                            clientWidth: index % 2 == 0 ? 150 : 120,
                            statusWidth: index % 2 == 0 ? 75 : 65,
                            amountWidth: index % 2 == 0 ? 95 : 85,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
