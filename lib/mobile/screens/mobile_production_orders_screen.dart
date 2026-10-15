import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/production_order.dart';
import '../../services/production_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';

class MobileProductionOrdersScreen extends StatefulWidget {
  const MobileProductionOrdersScreen({super.key});

  @override
  State<MobileProductionOrdersScreen> createState() =>
      _MobileProductionOrdersScreenState();
}

class _MobileProductionOrdersScreenState
    extends State<MobileProductionOrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  ProductionOrderStatus? _statusFilter;
  final dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: ProductionService.instance.ordersNotifier,
      builder: (context, _) {
        final all = ProductionService.instance.ordersNotifier.value;
        final filtered = all.where((o) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            if (!o.number.toLowerCase().contains(q) &&
                !o.productName.toLowerCase().contains(q)) {
              return false;
            }
          }
          if (_statusFilter != null && o.status != _statusFilter) {
            return false;
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Column(
            children: [
              // Search & Dropdown Filter bar (Matching Image 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un OF...',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                              borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ProductionOrderStatus?>(
                          value: _statusFilter,
                          hint: Text(
                            'Tous',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tous', style: TextStyle(fontSize: 12.5)),
                            ),
                            ...ProductionOrderStatus.values.map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(s.icon, size: 14, color: s.color),
                                    const SizedBox(width: 6),
                                    Text(s.label, style: const TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _statusFilter = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Orders List
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('Aucun ordre de fabrication trouvé.',
                            style: TextStyle(color: Color(0xFF94A3B8))),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final o = filtered[i];
                          return _buildOrderCard(o, isDark);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(ProductionOrder o, bool isDark) {
    return InkWell(
      onTap: () => _openOrderBottomSheet(context, o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(o.number,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (o.priority >= 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Urgent',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444))),
                      ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: o.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(o.status.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: o.status.color)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(o.productName,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${o.qtyProduced.toInt()} / ${o.qtyPlanned.toInt()} ${o.unit}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  o.plannedEnd != null
                      ? 'Échéance: ${dateFmt.format(o.plannedEnd!)}'
                      : '-',
                  style:
                      const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (o.progressPercentage / 100.0).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation(o.status.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openOrderBottomSheet(BuildContext context, ProductionOrder o) {
    bool isActionLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${o.number} - ${o.productName}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Statut actuel : ${o.status.label}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: o.status.color),
                  ),
                  const Divider(height: 24),
                  const Text('Actions d\'avancement de fabrication :',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (o.status == ProductionOrderStatus.draft)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB)),
                        onPressed: isActionLoading
                            ? null
                            : () async {
                                if (!await OfflineActionHelper.checkOnlineOrShowError(sheetCtx)) return;
                                setSheetState(() => isActionLoading = true);
                                try {
                                  await ProductionService.instance.confirmOrder(o.id);
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Ordre confirmé avec succès'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => isActionLoading = false);
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              },
                        child: isActionLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Confirmer l\'ordre',
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  if (o.status == ProductionOrderStatus.confirmed)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6)),
                        onPressed: isActionLoading
                            ? null
                            : () async {
                                if (!await OfflineActionHelper.checkOnlineOrShowError(sheetCtx)) return;
                                setSheetState(() => isActionLoading = true);
                                try {
                                  await ProductionService.instance.planOrder(o.id);
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Ordre planifié avec succès'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => isActionLoading = false);
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              },
                        child: isActionLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Planifier l\'ordre',
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  if (o.status == ProductionOrderStatus.planned ||
                      o.status == ProductionOrderStatus.confirmed)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B)),
                        onPressed: isActionLoading
                            ? null
                            : () async {
                                if (!await OfflineActionHelper.checkOnlineOrShowError(sheetCtx)) return;
                                setSheetState(() => isActionLoading = true);
                                try {
                                  await ProductionService.instance.startOrder(o.id);
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Fabrication démarrée'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => isActionLoading = false);
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              },
                        child: isActionLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Démarrer la fabrication',
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  if (o.status == ProductionOrderStatus.inProgress)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981)),
                        onPressed: isActionLoading
                            ? null
                            : () async {
                                if (!await OfflineActionHelper.checkOnlineOrShowError(sheetCtx)) return;
                                setSheetState(() => isActionLoading = true);
                                try {
                                  final rem = o.qtyPlanned - o.qtyProduced;
                                  await ProductionService.instance.declareProduction(
                                    orderId: o.id,
                                    qtyProduced: rem > 0 ? rem : 1.0,
                                  );
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Production finie déclarée'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => isActionLoading = false);
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              },
                        child: isActionLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Déclarer la production finie',
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  if (o.status == ProductionOrderStatus.qualityCheck)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981)),
                        onPressed: isActionLoading
                            ? null
                            : () async {
                                if (!await OfflineActionHelper.checkOnlineOrShowError(sheetCtx)) return;
                                setSheetState(() => isActionLoading = true);
                                try {
                                  await ProductionService.instance.completeOrder(o.id);
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('OF validé et clôturé avec succès'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => isActionLoading = false);
                                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              },
                        child: isActionLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Valider et Clôturer l\'OF',
                                style: TextStyle(color: Colors.white)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
