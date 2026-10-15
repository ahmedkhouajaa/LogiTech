import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/production_quality_check.dart';
import '../../models/production_order.dart';
import '../../services/connectivity_service.dart';
import '../../services/production_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';

class MobileProductionQualityScreen extends StatefulWidget {
  const MobileProductionQualityScreen({super.key});

  @override
  State<MobileProductionQualityScreen> createState() =>
      _MobileProductionQualityScreenState();
}

class _MobileProductionQualityScreenState
    extends State<MobileProductionQualityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([
        ProductionService.instance.qualityChecksNotifier,
        ProductionService.instance.nonConformitiesNotifier,
      ]),
      builder: (context, _) {
        final checks = ProductionService.instance.qualityChecksNotifier.value;
        final ncs = ProductionService.instance.nonConformitiesNotifier.value;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2563EB),
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                tabs: [
                  Tab(text: 'Contrôles (${checks.length})'),
                  Tab(text: 'Non-Conformités (${ncs.length})'),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF2563EB),
            onPressed: () {
              if (_tabController.index == 0) {
                _openNewCheckDialog(context);
              } else {
                _openNewNcDialog(context);
              }
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildChecksTab(context, checks, isDark),
              _buildNcsTab(context, ncs, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChecksTab(
      BuildContext context, List<ProductionQualityCheck> checks, bool isDark) {
    if (checks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_outlined,
                size: 48,
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'Aucun contrôle qualité enregistré',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: checks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final check = checks[index];
        final resColor = check.result.color;

        return InkWell(
          onTap: () => _showCheckDetailsSheet(context, check),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      check.orderNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: resColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        check.result.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: resColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  check.productName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Inspecté: ${check.qtyChecked.toStringAsFixed(0)} | Rebut: ${check.qtyRejected.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateFmt.format(check.inspectionDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (check.points.isNotEmpty) ...[
                  const Divider(height: 18),
                  Text(
                    '${check.points.where((p) => p.isPassed).length} / ${check.points.length} points validés',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNcsTab(BuildContext context,
      List<ProductionNonConformity> ncs, bool isDark) {
    if (ncs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_problem_outlined,
                size: 48,
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'Aucune fiche de non-conformité',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: ncs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final nc = ncs[index];
        final sevColor = nc.severityColor;

        return InkWell(
          onTap: () => _showNcDetailsSheet(context, nc),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      nc.defectType,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sevColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            nc.severity.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sevColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(nc.status)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusLabel(nc.status),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(nc.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'OF: ${nc.orderNumber}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (nc.rootCause.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cause : ${nc.rootCause}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Action : ${nc.correctiveAction.isNotEmpty ? nc.correctiveAction : "En attente"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                      ),
                    ),
                    Text(
                      dateFmt.format(nc.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolue':
        return const Color(0xFF10B981);
      case 'encours':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'resolue':
        return 'Résolue';
      case 'encours':
        return 'En cours';
      default:
        return 'Ouverte';
    }
  }

  void _showCheckDetailsSheet(
      BuildContext context, ProductionQualityCheck check) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contrôle Qualité • ${check.orderNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: check.result.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      check.result.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: check.result.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Article: ${check.productName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Inspecteur: ${check.inspectorName ?? "-"}  •  Date: ${dateFmt.format(check.inspectionDate)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const Divider(height: 20),
              const Text('Points de contrôle :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ...check.points.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          p.isPassed
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 16,
                          color: p.isPassed
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${p.title}${p.actualValue.isNotEmpty ? " (${p.actualValue})" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              if (check.notes != null && check.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Remarques : ${check.notes}',
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showNcDetailsSheet(
      BuildContext context, ProductionNonConformity nc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${nc.defectType} • ${nc.severity.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: nc.status,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ouverte',
                            child: Text('Ouverte',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEF4444))),
                          ),
                          DropdownMenuItem(
                            value: 'enCours',
                            child: Text('En cours',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF59E0B))),
                          ),
                          DropdownMenuItem(
                            value: 'resolue',
                            child: Text('Résolue',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981))),
                          ),
                        ],
                        onChanged: (newSt) async {
                          if (newSt != null) {
                            if (!await OfflineActionHelper.checkOnlineOrShowError(ctx)) return;
                            await ProductionService.instance
                                .updateNonConformityStatus(nc.id, newSt);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('OF: ${nc.orderNumber}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              if (nc.rootCause.isNotEmpty) ...[
                const Text('Cause racine :',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(nc.rootCause, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
              ],
              if (nc.correctiveAction.isNotEmpty) ...[
                const Text('Action corrective :',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(nc.correctiveAction,
                    style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openNewCheckDialog(BuildContext context) {
    final orders = ProductionService.instance.ordersNotifier.value;
    ProductionOrder? selectedOrder;
    QualityCheckResult result = QualityCheckResult.conforme;
    final inspCtrl = TextEditingController(text: 'Contrôleur Qualité');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Nouveau Contrôle Qualité',
                  style: TextStyle(fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ProductionOrder>(
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _dropdownDeco('Ordre de fabrication *', isDark),
                      items: orders
                          .map((o) => DropdownMenuItem(
                                value: o,
                                child: Text('${o.number} - ${o.productName}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDState(() => selectedOrder = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<QualityCheckResult>(
                      initialValue: result,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _dropdownDeco('Résultat', isDark),
                      items: QualityCheckResult.values
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.label,
                                    style: TextStyle(color: r.color, fontSize: 12.5)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDState(() => result = v);
                      },
                    ),
                  TextField(
                    controller: inspCtrl,
                    decoration: const InputDecoration(labelText: 'Inspecteur'),
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Remarques'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB)),
                onPressed: selectedOrder == null || isSaving
                    ? null
                    : () async {
                        setDState(() => isSaving = true);
                        try {
                          final isOnline = ConnectivityService.instance.isOnline;
                          final check = ProductionQualityCheck(
                            id: const Uuid().v4(),
                            orderId: selectedOrder!.id,
                            orderNumber: selectedOrder!.number,
                            productId: selectedOrder!.productId,
                            productName: selectedOrder!.productName,
                            inspectionDate: DateTime.now(),
                            inspectorName: inspCtrl.text.trim(),
                            result: result,
                            qtyChecked: selectedOrder!.qtyPlanned,
                            qtyRejected: result == QualityCheckResult.nonConforme
                                ? selectedOrder!.qtyPlanned
                                : 0,
                            points: [
                              QualityCheckPoint(
                                  title: 'Conformité visuelle et finitions',
                                  isPassed: result != QualityCheckResult.nonConforme),
                              QualityCheckPoint(
                                  title: 'Respect des tolérances dimensionnelles',
                                  isPassed: result != QualityCheckResult.nonConforme),
                              QualityCheckPoint(
                                  title: 'Test de fonctionnalité',
                                  isPassed: result != QualityCheckResult.nonConforme),
                            ],
                            notes: notesCtrl.text.trim(),
                          );
                          await ProductionService.instance.saveQualityCheck(check);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      isOnline
                                          ? Icons.check_circle_rounded
                                          : Icons.cloud_off_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isOnline
                                            ? 'Inspection enregistrée avec succès'
                                            : 'Inspection enregistrée hors ligne. Elle sera synchronisée dès la reconnexion.',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor:
                                    isOnline ? AppColors.success : AppColors.warning,
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
                    : const Text('Valider',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

  void _openNewNcDialog(BuildContext context) {
    final orders = ProductionService.instance.ordersNotifier.value;
    ProductionOrder? selectedOrder;
    String severity = 'moyenne';
    final defectCtrl = TextEditingController(text: 'Défaut dimensionnel');
    final causeCtrl = TextEditingController();
    final actionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Déclarer une Non-Conformité',
                  style: TextStyle(fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ProductionOrder>(
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _dropdownDeco('Ordre de fabrication *', isDark),
                      items: orders
                          .map((o) => DropdownMenuItem(
                                value: o,
                                child: Text('${o.number} - ${o.productName}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setDState(() => selectedOrder = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: defectCtrl,
                      decoration: const InputDecoration(labelText: 'Type de défaut *'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: severity,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _dropdownDeco('Gravité', isDark),
                      items: const [
                        DropdownMenuItem(value: 'faible', child: Text('Faible', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'moyenne', child: Text('Moyenne', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'critique', child: Text('Critique', style: TextStyle(fontSize: 12.5))),
                      ],
                      onChanged: (v) {
                        if (v != null) setDState(() => severity = v);
                      },
                    ),
                  TextField(
                    controller: causeCtrl,
                    decoration: const InputDecoration(labelText: 'Cause racine'),
                  ),
                  TextField(
                    controller: actionCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Action corrective'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB)),
                onPressed: (selectedOrder == null || defectCtrl.text.isEmpty || isSaving)
                    ? null
                    : () async {
                        setDState(() => isSaving = true);
                        try {
                          final isOnline = ConnectivityService.instance.isOnline;
                          final nc = ProductionNonConformity(
                            id: const Uuid().v4(),
                            checkId: '',
                            orderId: selectedOrder!.id,
                            orderNumber: selectedOrder!.number,
                            defectType: defectCtrl.text.trim(),
                            severity: severity,
                            rootCause: causeCtrl.text.trim(),
                            correctiveAction: actionCtrl.text.trim(),
                            status: 'ouverte',
                          );
                          await ProductionService.instance.saveNonConformity(nc);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      isOnline
                                          ? Icons.check_circle_rounded
                                          : Icons.cloud_off_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isOnline
                                            ? 'Non-conformité enregistrée avec succès'
                                            : 'Non-conformité enregistrée hors ligne. Elle sera synchronisée dès la reconnexion.',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor:
                                    isOnline ? AppColors.success : AppColors.warning,
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
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

  InputDecoration _dropdownDeco(String? label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 12.5,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
  }
}
