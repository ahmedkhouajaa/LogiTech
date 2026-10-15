import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/production_workcenter.dart';
import '../services/production_service.dart';
import '../services/connectivity_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';
import '../l10n/app_localizations.dart';

class ProductionWorkcentersScreen extends StatefulWidget {
  const ProductionWorkcentersScreen({super.key});

  @override
  State<ProductionWorkcentersScreen> createState() =>
      _ProductionWorkcentersScreenState();
}

class _ProductionWorkcentersScreenState
    extends State<ProductionWorkcentersScreen> {
  final currencyFmt =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: ProductionService.instance.workcentersNotifier,
      builder: (context, _) {
        final all = ProductionService.instance.workcentersNotifier.value;
        final filtered = all.where((wc) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return wc.name.toLowerCase().contains(q) ||
                wc.code.toLowerCase().contains(q);
          }
          return true;
        }).toList();

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
                          context.tr('Postes de Travail & Ateliers'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filtered.length} postes et lignes de production configurés',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openWorkcenterDialog(context, null),
                      icon: const Icon(Icons.add_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Nouveau Poste de Travail',
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

                // Search Bar (Styled to match Image 2)
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par code ou nom...',
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
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                const SizedBox(height: 16),

                // Workcenters List
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun poste de travail configuré.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final wc = filtered[i];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.precision_manufacturing_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 20),
                                ),
                                title: Row(
                                  children: [
                                    Text(wc.code,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5)),
                                    const SizedBox(width: 8),
                                    Text(wc.name,
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF64748B)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(wc.type.label,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF475569))),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Coût horaire : ${currencyFmt.format(wc.hourlyCost)}/h'
                                  ' • Capacité : ${wc.capacityHoursPerDay.toStringAsFixed(0)} h/jour'
                                  ' • Efficacité : ${wc.efficiency.toStringAsFixed(0)} %',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: wc.active,
                                      activeThumbColor: const Color(0xFF2563EB),
                                      onChanged: (v) async {
                                        if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
                                        await ProductionService.instance
                                            .saveWorkcenter(wc.copyWith(active: v));
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      onPressed: () =>
                                          _openWorkcenterDialog(context, wc),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Color(0xFFEF4444)),
                                      onPressed: () {
                                        OfflineActionHelper.executeAction(
                                          context: context,
                                          action: 'delete',
                                          customActionLabel:
                                              'Êtes-vous sûr de vouloir supprimer ce poste de travail ?',
                                          onConfirmed: () async {
                                            await ProductionService.instance
                                                .deleteWorkcenter(wc.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: const Text('Poste de travail supprimé avec succès'),
                                                  backgroundColor: AppColors.success,
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
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

  void _openWorkcenterDialog(
      BuildContext context, ProductionWorkcenter? initialWc) {
    final codeCtrl = TextEditingController(text: initialWc?.code ?? 'P-01');
    final nameCtrl = TextEditingController(text: initialWc?.name ?? '');
    final costCtrl =
        TextEditingController(text: initialWc?.hourlyCost.toString() ?? '45.0');
    final capCtrl = TextEditingController(
        text: initialWc?.capacityHoursPerDay.toString() ?? '8.0');
    final effCtrl = TextEditingController(
        text: initialWc?.efficiency.toString() ?? '100.0');
    WorkcenterType type = initialWc?.type ?? WorkcenterType.machine;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final isDark = Theme.of(dCtx).brightness == Brightness.dark;
            return AlertDialog(
              title: Text(initialWc == null
                  ? 'Nouveau Poste de Travail'
                  : 'Modifier le Poste de Travail'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: codeCtrl,
                            decoration: _inputDeco('Code (ex: P-01)', isDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: nameCtrl,
                            decoration:
                                _inputDeco('Nom (ex: Tour CN, Découpe Laser)', isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<WorkcenterType>(
                      initialValue: type,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _inputDeco('Type de poste', isDark),
                      items: WorkcenterType.values
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.label, style: const TextStyle(fontSize: 12.5))))
                          .toList(),
                      onChanged: (v) =>
                          setDState(() => type = v ?? WorkcenterType.machine),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDeco('Taux horaire (TND/h)', isDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: capCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDeco('Capacité (h/jour)', isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: effCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('Efficacité nominale (%)', isDark),
                    ),
                  ],
                ),
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
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          if (initialWc != null) {
                            if (!await OfflineActionHelper.checkOnlineOrShowError(dCtx)) return;
                          }
                          setDState(() => isSaving = true);
                          try {
                            final isOnline = ConnectivityService.instance.isOnline;
                            final wc = ProductionWorkcenter(
                              id: initialWc?.id ?? const Uuid().v4(),
                              code: codeCtrl.text.trim(),
                              name: name,
                              type: type,
                              hourlyCost:
                                  double.tryParse(costCtrl.text.trim()) ?? 0.0,
                              capacityHoursPerDay:
                                  double.tryParse(capCtrl.text.trim()) ?? 8.0,
                              efficiency:
                                  double.tryParse(effCtrl.text.trim()) ?? 100.0,
                              active: initialWc?.active ?? true,
                            );
                            await ProductionService.instance.saveWorkcenter(wc);
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
                                              ? 'Poste de travail enregistré avec succès'
                                              : 'Poste enregistré hors ligne. Il sera synchronisé dès la reconnexion.',
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
                                SnackBar(
                                  content: Text('Erreur: $e'),
                                  backgroundColor: AppColors.error,
                                ),
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
