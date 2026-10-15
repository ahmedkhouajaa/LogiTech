import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/production_order.dart';
import '../models/production_workcenter.dart';
import '../services/production_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../l10n/app_localizations.dart';

class ProductionPlanningScreen extends StatefulWidget {
  const ProductionPlanningScreen({super.key});

  @override
  State<ProductionPlanningScreen> createState() =>
      _ProductionPlanningScreenState();
}

class _ProductionPlanningScreenState extends State<ProductionPlanningScreen> {
  final dateFmt = DateFormat('dd/MM/yyyy');

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

        // Active orders that are planned or in progress
        final plannableOrders = orders
            .where((o) =>
                o.status == ProductionOrderStatus.confirmed ||
                o.status == ProductionOrderStatus.planned ||
                o.status == ProductionOrderStatus.inProgress)
            .toList();

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Planification & Charge des Ateliers'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plannableOrders.length} ordres en cours de planification • ${workcenters.length} postes actifs',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Workcenters Capacity & Load Overview Cards
                Text('Charge vs Capacité par Poste de Travail',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 12),
                if (workcenters.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Aucun poste de travail configuré. Créez vos machines et ateliers dans "Postes de travail".',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                else
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: workcenters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (ctx, i) {
                        final wc = workcenters[i];
                        return _buildWorkcenterLoadCard(
                            wc, plannableOrders, isDark);
                      },
                    ),
                  ),
                const SizedBox(height: 24),

                // Timeline / Scheduled Orders Section
                Text('Planning des Ordres de Fabrication',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 12),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: plannableOrders.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun ordre à planifier actuellement.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: plannableOrders.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final o = plannableOrders[i];
                              return _buildPlanningOrderRow(o, isDark);
                            },
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

  Widget _buildWorkcenterLoadCard(ProductionWorkcenter wc,
      List<ProductionOrder> orders, bool isDark) {
    // Calculate total planned minutes on this workcenter across active orders
    double totalMinutes = 0.0;
    for (final o in orders) {
      for (final op in o.operationLines) {
        if (op.workcenterId == wc.id && op.status != 'done') {
          totalMinutes += (op.plannedMinutes - op.actualMinutes)
              .clamp(0.0, op.plannedMinutes);
        }
      }
    }
    final loadHours = totalMinutes / 60.0;
    final capacity = wc.capacityHoursPerDay > 0 ? wc.capacityHoursPerDay : 8.0;
    final loadRatio = (loadHours / capacity).clamp(0.0, 2.0);

    Color loadColor = const Color(0xFF10B981);
    if (loadRatio > 1.0) {
      loadColor = const Color(0xFFEF4444); // Surcharge
    } else if (loadRatio > 0.8) {
      loadColor = const Color(0xFFF59E0B);
    }

    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  wc.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: loadColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(loadRatio * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: loadColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Charge: ${loadHours.toStringAsFixed(1)}h / ${capacity.toStringAsFixed(0)}h/j',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: loadRatio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(loadColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningOrderRow(ProductionOrder o, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: o.status.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(o.status.icon, color: o.status.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${o.number} - ${o.productName}',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  'Quantité : ${o.qtyProduced.toInt()} / ${o.qtyPlanned.toInt()} ${o.unit} • ${o.operationLines.length} opérations',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Début : ${o.plannedStart != null ? dateFmt.format(o.plannedStart!) : "-"}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Cible : ${o.plannedEnd != null ? dateFmt.format(o.plannedEnd!) : "-"}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openRescheduleDialog(context, o),
            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
            label: const Text('Replanifier'),
          ),
        ],
      ),
    );
  }

  void _openRescheduleDialog(BuildContext context, ProductionOrder o) {
    DateTime start = o.plannedStart ?? DateTime.now();
    DateTime end = o.plannedEnd ?? DateTime.now().add(const Duration(days: 3));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              title: Text('Replanifier l\'OF ${o.number}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date de début de fabrication :'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                         context: dCtx,
                        initialDate: start,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDState(() => start = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(dateFmt.format(start)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Date de fin cible :'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dCtx,
                        initialDate: end,
                        firstDate: start,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDState(() => end = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(dateFmt.format(end)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB)),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!await OfflineActionHelper.checkOnlineOrShowError(dCtx)) return;
                          setDState(() => isSaving = true);
                          try {
                            await ProductionService.instance.planOrder(
                              o.id,
                              start: start,
                              end: end,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Planification mise à jour avec succès'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDState(() => isSaving = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
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
                      : const Text('Enregistrer',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
