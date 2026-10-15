import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/production_order.dart';
import '../../models/production_workcenter.dart';
import '../../services/production_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';
import '../../l10n/app_localizations.dart';

class MobileProductionPlanningScreen extends StatefulWidget {
  const MobileProductionPlanningScreen({super.key});

  @override
  State<MobileProductionPlanningScreen> createState() =>
      _MobileProductionPlanningScreenState();
}

class _MobileProductionPlanningScreenState
    extends State<MobileProductionPlanningScreen> {
  final dateFmt = DateFormat('dd/MM/yyyy');
  String? _selectedWorkcenterId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        ProductionService.instance.ordersNotifier,
        ProductionService.instance.workcentersNotifier,
      ]),
      builder: (context, _) {
        final workcenters =
            ProductionService.instance.workcentersNotifier.value;
        final orders = ProductionService.instance.ordersNotifier.value;

        final plannableOrders = orders
            .where((o) =>
                o.status == ProductionOrderStatus.confirmed ||
                o.status == ProductionOrderStatus.planned ||
                o.status == ProductionOrderStatus.inProgress)
            .toList();

        final filteredOrders = _selectedWorkcenterId == null
            ? plannableOrders
            : plannableOrders.where((o) {
                return o.operationLines
                    .any((op) => op.workcenterId == _selectedWorkcenterId);
              }).toList();

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: CustomScrollView(
            slivers: [
              // Workcenters horizontal scroll of load
              SliverToBoxAdapter(
                child: Container(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('Charge des Ateliers (Semaine)'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            if (_selectedWorkcenterId != null)
                              GestureDetector(
                                onTap: () => setState(
                                    () => _selectedWorkcenterId = null),
                                child: const Text(
                                  'Effacer filtre',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 120,
                        child: workcenters.isEmpty
                            ? Center(
                                child: Text(
                                  'Aucun poste configuré',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                itemCount: workcenters.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, i) {
                                  final wc = workcenters[i];
                                  final isSelected =
                                      _selectedWorkcenterId == wc.id;
                                  return _buildWorkcenterLoadCard(
                                      context, wc, plannableOrders, isDark, isSelected);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title Header for Timeline
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ordres Planifiés (${filteredOrders.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Trier par date de début',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Timeline List of Orders
              filteredOrders.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month_outlined,
                                size: 48,
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 10),
                            Text(
                              'Aucun ordre en cours de planification',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final order = filteredOrders[index];
                            return _buildOrderScheduleCard(
                                context, order, isDark);
                          },
                          childCount: filteredOrders.length,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkcenterLoadCard(
    BuildContext context,
    ProductionWorkcenter wc,
    List<ProductionOrder> orders,
    bool isDark,
    bool isSelected,
  ) {
    // Total minutes planned for this workcenter across active orders
    double totalMinutes = 0;
    for (final o in orders) {
      for (final op in o.operationLines) {
        if (op.workcenterId == wc.id) {
          totalMinutes += op.plannedMinutes;
        }
      }
    }
    final totalHours = totalMinutes / 60.0;
    final weeklyCapacityHours = wc.capacityHoursPerDay * 5.0; // 5 days week
    final loadRatio = weeklyCapacityHours > 0
        ? (totalHours / weeklyCapacityHours).clamp(0.0, 2.0)
        : 0.0;
    final loadPct = (loadRatio * 100).toInt();

    final Color color;
    if (loadPct > 100) {
      color = const Color(0xFFEF4444);
    } else if (loadPct > 80) {
      color = const Color(0xFFF59E0B);
    } else {
      color = const Color(0xFF10B981);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWorkcenterId = isSelected ? null : wc.id;
        });
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${totalHours.toStringAsFixed(1)}h / ${weeklyCapacityHours.toStringAsFixed(0)}h',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$loadPct%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (loadPct > 100)
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Color(0xFFEF4444)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (loadRatio).clamp(0.0, 1.0),
                    backgroundColor: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderScheduleCard(
      BuildContext context, ProductionOrder order, bool isDark) {
    final statusColor = order.status.color;
    final isDelayed = order.isDelayed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDelayed
              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.number,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.productName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.widgets_outlined,
                  size: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Qté: ${order.qtyPlanned.toStringAsFixed(0)} ${order.unit}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              if (isDelayed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'En retard',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range_outlined,
                      size: 14,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    '${order.plannedStart != null ? dateFmt.format(order.plannedStart!) : "-"} → ${order.plannedEnd != null ? dateFmt.format(order.plannedEnd!) : "-"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _openRescheduleDialog(context, order),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_calendar_rounded,
                          size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Replanifier',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openRescheduleDialog(BuildContext context, ProductionOrder order) {
    DateTime start = order.plannedStart ?? DateTime.now();
    DateTime end =
        order.plannedEnd ?? DateTime.now().add(const Duration(days: 3));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Replanifier ${order.number}',
              style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Date début prévue'),
                subtitle: Text(dateFmt.format(start)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDState(() => start = picked);
                  }
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Date fin prévue'),
                subtitle: Text(dateFmt.format(end)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: end,
                    firstDate: start,
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDState(() => end = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!await OfflineActionHelper.checkOnlineOrShowError(dialogCtx)) return;
                      setDState(() => isSaving = true);
                      try {
                        await ProductionService.instance
                            .planOrder(order.id, start: start, end: end);
                        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Planification mise à jour avec succès'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogCtx.mounted) {
                          setDState(() => isSaving = false);
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Valider',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
