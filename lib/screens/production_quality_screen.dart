import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/production_quality_check.dart';
import '../models/production_order.dart';
import '../services/production_service.dart';
import '../services/connectivity_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../l10n/app_localizations.dart';

class ProductionQualityScreen extends StatefulWidget {
  const ProductionQualityScreen({super.key});

  @override
  State<ProductionQualityScreen> createState() =>
      _ProductionQualityScreenState();
}

class _ProductionQualityScreenState extends State<ProductionQualityScreen>
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
        final checks =
            ProductionService.instance.qualityChecksNotifier.value;
        final ncs =
            ProductionService.instance.nonConformitiesNotifier.value;

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
                          context.tr('Contrôle Qualité & Non-Conformités'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${checks.length} inspections réalisées • ${ncs.where((nc) => nc.status != "resolue").length} non-conformités en cours',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openAddQualityCheckDialog(context),
                      icon: const Icon(Icons.add_task_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Nouvelle Inspection',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'Inspections & Contrôles (${checks.length})'),
                      Tab(text: 'Fiches de Non-Conformité (${ncs.length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChecksList(checks, isDark),
                      _buildNonConformitiesList(ncs, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChecksList(List<ProductionQualityCheck> checks, bool isDark) {
    if (checks.isEmpty) {
      return const Center(
          child: Text('Aucune inspection qualité enregistrée.',
              style: TextStyle(color: Color(0xFF94A3B8))));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        itemCount: checks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final c = checks[i];
          return ListTile(
            leading: Icon(
              c.result == QualityCheckResult.conforme
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: c.result.color,
              size: 24,
            ),
            title: Text('${c.orderNumber} - ${c.productName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: Text(
              'Inspecteur : ${c.inspectorName ?? "Qualité"} • Contrôlés : ${c.qtyChecked.toInt()} • Rejetés : ${c.qtyRejected.toInt()} • ${dateFmt.format(c.inspectionDate)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.result.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.result.color.withValues(alpha: 0.3)),
              ),
              child: Text(
                c.result.label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: c.result.color),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNonConformitiesList(
      List<ProductionNonConformity> ncs, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openAddNonConformityDialog(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Déclarer une Non-Conformité'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: ncs.isEmpty
                ? const Center(
                    child: Text('Aucune non-conformité active.',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.separated(
                    itemCount: ncs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final nc = ncs[i];
                      return ListTile(
                        leading: Icon(Icons.report_problem_rounded,
                            color: nc.severityColor),
                        title: Text(
                            '${nc.orderNumber} - Défaut : ${nc.defectType} (${nc.severity.toUpperCase()})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: Text(
                          'Cause : ${nc.rootCause} • Action : ${nc.correctiveAction}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        trailing: Container(
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
                                fontSize: 12.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'ouverte',
                                    child: Text('Ouverte',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFEF4444)))),
                                DropdownMenuItem(
                                    value: 'enCours',
                                    child: Text('En cours',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFF59E0B)))),
                                DropdownMenuItem(
                                    value: 'resolue',
                                    child: Text('Résolue',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF10B981)))),
                              ],
                              onChanged: (newStatus) async {
                                if (newStatus != null) {
                                  if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
                                  await ProductionService.instance
                                      .updateNonConformityStatus(nc.id, newStatus);
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _openAddQualityCheckDialog(BuildContext context) {
    final orders = ProductionService.instance.ordersNotifier.value;
    ProductionOrder? selectedOrder = orders.isNotEmpty ? orders.first : null;
    QualityCheckResult result = QualityCheckResult.conforme;
    final qtyCheckedCtrl = TextEditingController(text: '10');
    final qtyRejectedCtrl = TextEditingController(text: '0');
    final inspectorCtrl = TextEditingController(text: 'Contrôleur Qualité');
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final isDark = Theme.of(dCtx).brightness == Brightness.dark;
            return AlertDialog(
              title: const Text('Nouvelle Inspection Qualité'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ordre de Fabrication *'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<ProductionOrder>(
                      initialValue: selectedOrder,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _inputDeco(null, isDark),
                      items: orders
                          .map((o) => DropdownMenuItem(
                              value: o, child: Text('${o.number} - ${o.productName}', style: const TextStyle(fontSize: 12.5))))
                          .toList(),
                      onChanged: (o) => setDState(() => selectedOrder = o),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtyCheckedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDeco('Qté contrôlée', isDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: qtyRejectedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDeco('Qté rejetée', isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Résultat du contrôle *'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<QualityCheckResult>(
                      initialValue: result,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _inputDeco(null, isDark),
                      items: QualityCheckResult.values
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.label, style: const TextStyle(fontSize: 12.5))))
                          .toList(),
                      onChanged: (r) => setDState(() => result = r ?? QualityCheckResult.conforme),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: inspectorCtrl,
                      decoration: _inputDeco('Nom de l\'inspecteur', isDark),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: _inputDeco('Remarques / Observations', isDark),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: (selectedOrder == null || isSaving)
                      ? null
                      : () async {
                          setDState(() => isSaving = true);
                          try {
                            final isOnline = ConnectivityService.instance.isOnline;
                            final qc = ProductionQualityCheck(
                              id: const Uuid().v4(),
                              orderId: selectedOrder!.id,
                              orderNumber: selectedOrder!.number,
                              productId: selectedOrder!.productId,
                              productName: selectedOrder!.productName,
                              result: result,
                              qtyChecked: double.tryParse(qtyCheckedCtrl.text.trim()) ?? 0.0,
                              qtyRejected: double.tryParse(qtyRejectedCtrl.text.trim()) ?? 0.0,
                              inspectorName: inspectorCtrl.text.trim(),
                              notes: notesCtrl.text.trim(),
                            );
                            await ProductionService.instance.saveQualityCheck(qc);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
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
                      : const Text('Enregistrer l\'inspection',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openAddNonConformityDialog(BuildContext context) {
    final orders = ProductionService.instance.ordersNotifier.value;
    ProductionOrder? selectedOrder = orders.isNotEmpty ? orders.first : null;
    final defectCtrl = TextEditingController(text: 'Défaut dimensionnel');
    final causeCtrl = TextEditingController(text: 'Usure d\'outil');
    final actionCtrl = TextEditingController(text: 'Remplacement de plaquette');
    String severity = 'moyenne';

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final isDark = Theme.of(dCtx).brightness == Brightness.dark;
            return AlertDialog(
              title: const Text('Déclarer une Non-Conformité'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ProductionOrder>(
                      initialValue: selectedOrder,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _inputDeco('OF concerné', isDark),
                      items: orders
                          .map((o) => DropdownMenuItem(
                              value: o, child: Text('${o.number} - ${o.productName}', style: const TextStyle(fontSize: 12.5))))
                          .toList(),
                      onChanged: (o) => setDState(() => selectedOrder = o),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: defectCtrl,
                      decoration: _inputDeco('Type de défaut', isDark),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: severity,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _inputDeco('Gravité', isDark),
                      items: const [
                        DropdownMenuItem(value: 'faible', child: Text('Faible', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'moyenne', child: Text('Moyenne', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'critique', child: Text('Critique', style: TextStyle(fontSize: 12.5))),
                      ],
                      onChanged: (v) => setDState(() => severity = v ?? 'moyenne'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: causeCtrl,
                      decoration: _inputDeco('Cause racine identifiée', isDark),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: actionCtrl,
                      decoration: _inputDeco('Action corrective / décision', isDark),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  onPressed: selectedOrder == null || isSaving
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
                            );
                            await ProductionService.instance.saveNonConformity(nc);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
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
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDeco(String? hint, [bool isDark = false]) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
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
