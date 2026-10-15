import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/production_workcenter.dart';
import '../../services/production_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';

class MobileProductionWorkcentersScreen extends StatefulWidget {
  const MobileProductionWorkcentersScreen({super.key});

  @override
  State<MobileProductionWorkcentersScreen> createState() =>
      _MobileProductionWorkcentersScreenState();
}

class _MobileProductionWorkcentersScreenState
    extends State<MobileProductionWorkcentersScreen> {
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
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF2563EB),
            onPressed: () => _openWorkcenterDialog(context, null),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: Column(
            children: [
              // Search Bar (Matching Image 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un poste de charge...',
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

              // Subheader
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} postes configurés',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Workcenters List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.precision_manufacturing_outlined,
                                size: 48,
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun poste de charge trouvé',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final wc = filtered[index];
                          return _buildWorkcenterCard(context, wc, isDark);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkcenterCard(
      BuildContext context, ProductionWorkcenter wc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  wc.type == WorkcenterType.machine
                      ? Icons.precision_manufacturing
                      : wc.type == WorkcenterType.workshop
                          ? Icons.storefront
                          : Icons.pan_tool,
                  size: 20,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wc.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${wc.code}  •  ${wc.type.label}',
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
              Switch(
                value: wc.active,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) async {
                  if (!await OfflineActionHelper.checkOnlineOrShowError(context)) return;
                  await ProductionService.instance
                      .saveWorkcenter(wc.copyWith(active: val));
                },
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coût horaire',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${currencyFmt.format(wc.hourlyCost)} / h',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Capacité/jour',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${wc.capacityHoursPerDay.toStringAsFixed(1)} h',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Efficience',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${(wc.efficiency * 100).toStringAsFixed(0)} %',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: Color(0xFF2563EB)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openWorkcenterDialog(context, wc),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDelete(wc),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ProductionWorkcenter wc) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'Voulez-vous supprimer le poste "${wc.name}" ?',
      onConfirmed: () async {
        await ProductionService.instance.deleteWorkcenter(wc.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Poste de travail supprimé avec succès'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  void _openWorkcenterDialog(
      BuildContext context, ProductionWorkcenter? initial) {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: initial?.code ?? '');
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    WorkcenterType type = initial?.type ?? WorkcenterType.machine;
    final costCtrl = TextEditingController(
        text: (initial?.hourlyCost ?? 25.0).toStringAsFixed(2));
    final capCtrl = TextEditingController(
        text: (initial?.capacityHoursPerDay ?? 8.0).toStringAsFixed(1));
    final effCtrl = TextEditingController(
        text: ((initial?.efficiency ?? 0.85) * 100).toStringAsFixed(0));

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              initial == null ? 'Nouveau Poste' : 'Modifier Poste',
              style: const TextStyle(fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Code Poste *'),
                      validator: (v) => v?.trim().isEmpty ?? true
                          ? 'Le code est requis'
                          : null,
                    ),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nom du Poste *'),
                      validator: (v) => v?.trim().isEmpty ?? true
                          ? 'Le nom est requis'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<WorkcenterType>(
                      initialValue: type,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      decoration: _dropdownDeco('Type', isDark),
                      items: WorkcenterType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label, style: const TextStyle(fontSize: 12.5)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDState(() => type = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: costCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Coût horaire (TND/h) *'),
                      keyboardType: TextInputType.number,
                    ),
                  TextFormField(
                    controller: capCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Capacité journalière (heures/j) *'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: effCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Efficience (%) *'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB)),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        if (initial != null) {
                          if (!await OfflineActionHelper.checkOnlineOrShowError(dialogCtx)) return;
                        }
                        setDState(() => isSaving = true);
                        try {
                          final hourly = double.tryParse(costCtrl.text) ?? 25.0;
                          final cap = double.tryParse(capCtrl.text) ?? 8.0;
                          final effPct = double.tryParse(effCtrl.text) ?? 85.0;
                          final isOnline = ConnectivityService.instance.isOnline;
                          final wc = ProductionWorkcenter(
                            id: initial?.id ?? const Uuid().v4(),
                            code: codeCtrl.text.trim(),
                            name: nameCtrl.text.trim(),
                            type: type,
                            hourlyCost: hourly,
                            capacityHoursPerDay: cap,
                            efficiency: (effPct / 100.0).clamp(0.1, 1.0),
                            active: initial?.active ?? true,
                          );
                          await ProductionService.instance.saveWorkcenter(wc);
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
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
                          if (dialogCtx.mounted) {
                            setDState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
                            );
                          }
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
    ),
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
