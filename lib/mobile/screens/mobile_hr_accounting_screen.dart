import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/enterprise/enterprise_bloc.dart';
import '../../blocs/payroll/payroll_bloc.dart';
import '../../blocs/payroll/payroll_state.dart';
import '../../models/hr_accounting_entry.dart';
import '../../models/payslip.dart';
import '../../models/payslip_batch.dart';
import '../../services/connectivity_service.dart';
import '../../services/hr_accounting_service.dart';
import '../../utils/constants.dart';
import '../../utils/offline_action_helper.dart';

class MobileHrAccountingScreen extends StatefulWidget {
  const MobileHrAccountingScreen({super.key});

  @override
  State<MobileHrAccountingScreen> createState() => _MobileHrAccountingScreenState();
}

class _MobileHrAccountingScreenState extends State<MobileHrAccountingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    final enterpriseState = context.read<EnterpriseBloc>().state;
    if (enterpriseState is EnterpriseLoaded && enterpriseState.currentEnterpriseId != null) {
      HrAccountingService.instance.seedInitialRubricsIfEmpty(enterpriseState.currentEnterpriseId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EnterpriseBloc, EnterpriseState>(
      listener: (context, state) {
        if (state is EnterpriseLoaded && state.currentEnterpriseId != null) {
          HrAccountingService.instance.seedInitialRubricsIfEmpty(state.currentEnterpriseId!);
        }
      },
      child: BlocBuilder<EnterpriseBloc, EnterpriseState>(
        builder: (context, entState) {
          final enterpriseId = entState is EnterpriseLoaded ? (entState.currentEnterpriseId ?? '') : '';
          final enterpriseName = entState is EnterpriseLoaded
              ? (entState.enterprises.firstWhere((e) => e.id == enterpriseId, orElse: () => entState.enterprises.first).name)
              : 'red';

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Column(
              children: [
                // Top Header Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Exports comptables',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Écritures de paie au format FEC',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_tabController.index == 0) {
                                _openNewFecDialog(context, enterpriseId, enterpriseName);
                              } else {
                                _openAddRubricDialog(context, enterpriseId, enterpriseName);
                              }
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              _tabController.index == 0 ? 'Export FEC' : 'Rubrique',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF0F172A),
                        unselectedLabelColor: const Color(0xFF64748B),
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 2.5,
                        dividerColor: const Color(0xFFE2E8F0),
                        tabs: const [
                          Tab(text: 'Exports FEC'),
                          Tab(text: 'Plan comptable'),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Exports FEC
                      _buildExportsTab(context, enterpriseId, enterpriseName),

                      // Tab 2: Plan comptable
                      _buildPlanComptableTab(context, enterpriseId, enterpriseName),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExportsTab(BuildContext context, String enterpriseId, String enterpriseName) {
    return StreamBuilder<List<FecExport>>(
      stream: HrAccountingService.instance.getExportsStream(enterpriseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final exports = snapshot.data ?? [];
        if (exports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text('Aucun export', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  const Text(
                    'Générez votre premier export FEC depuis un run de paie.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openNewFecDialog(context, enterpriseId, enterpriseName),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nouvel export FEC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final currFormat = NumberFormat('#,##0.00', 'fr_FR');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: exports.length,
          itemBuilder: (context, index) {
            final exp = exports[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Text(exp.batchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Généré', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Entité : ${exp.legalEntity} • ${exp.formattedDate}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text('Total : ${currFormat.format(exp.totalDebit)} TND (${exp.recordCount} écritures)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => HrAccountingService.instance.downloadFecExport(context, exp),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Télécharger'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            OfflineActionHelper.executeAction(
                              context: context,
                              action: 'delete',
                              customActionLabel: 'Supprimer l\'export',
                              onConfirmed: () async {
                                await HrAccountingService.instance.deleteExport(exp.id);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanComptableTab(BuildContext context, String enterpriseId, String enterpriseName) {
    return StreamBuilder<List<HrAccountingRubric>>(
      stream: HrAccountingService.instance.getRubricsStream(enterpriseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rubrics = snapshot.data ?? [];
        final filtered = rubrics.where((r) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return r.code.toLowerCase().contains(q) ||
              r.debitAccount.contains(q) ||
              r.debitLabel.toLowerCase().contains(q) ||
              r.creditAccount.contains(q) ||
              r.creditLabel.toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            // Search input (100% white, NO inner grey bubble)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                          decoration: const InputDecoration(
                            hintText: 'Rechercher une rubrique...',
                            hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      InkWell(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final r = filtered[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openEditRubricDialog(context, r, enterpriseName),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(r.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(r.journal, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Débit : ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                Expanded(
                                  child: Text('${r.debitAccount} - ${r.debitLabel}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text('Crédit : ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                Expanded(
                                  child: Text('${r.creditAccount} - ${r.creditLabel}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(r.legalEntity, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _openEditRubricDialog(context, r, enterpriseName),
                                      style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                      child: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        OfflineActionHelper.executeAction(
                                          context: context,
                                          action: 'delete',
                                          customActionLabel: 'Supprimer la rubrique',
                                          onConfirmed: () async {
                                            await HrAccountingService.instance.deleteRubric(r.id);
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openNewFecDialog(BuildContext context, String enterpriseId, String enterpriseName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileNewFecSheet(enterpriseId: enterpriseId, enterpriseName: enterpriseName),
    );
  }

  void _openAddRubricDialog(BuildContext context, String enterpriseId, String enterpriseName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileEditRubricSheet(enterpriseId: enterpriseId, enterpriseName: enterpriseName),
    );
  }

  void _openEditRubricDialog(BuildContext context, HrAccountingRubric rubric, String enterpriseName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileEditRubricSheet(
        enterpriseId: rubric.enterpriseId ?? '',
        enterpriseName: enterpriseName,
        rubric: rubric,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// MOBILE BOTTOM SHEET: NOUVEL EXPORT FEC
// ──────────────────────────────────────────────────────────────────
class _MobileNewFecSheet extends StatefulWidget {
  final String enterpriseId;
  final String enterpriseName;

  const _MobileNewFecSheet({required this.enterpriseId, required this.enterpriseName});

  @override
  State<_MobileNewFecSheet> createState() => _MobileNewFecSheetState();
}

class _MobileNewFecSheetState extends State<_MobileNewFecSheet> {
  late String _selectedEntity;
  String? _selectedRun;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedEntity = widget.enterpriseName.isNotEmpty ? widget.enterpriseName : 'red';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PayrollBloc, PayrollState>(
      builder: (context, payrollState) {
        final batches = payrollState is PayrollLoaded ? payrollState.batches : <PayslipBatch>[];
        final payslips = payrollState is PayrollLoaded ? payrollState.payslips : <Payslip>[];

        final runOptions = <String>[];
        for (final b in batches) {
          runOptions.add('${b.name} (${b.status == 'closed' ? 'Verrouillé' : 'Brouillon'})');
        }
        if (!runOptions.any((r) => r.startsWith('Septembre 2026'))) {
          runOptions.add('Septembre 2026 (Verrouillé)');
        }
        if (!runOptions.any((r) => r.startsWith('Août 2026'))) {
          runOptions.add('Août 2026 (Verrouillé)');
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nouvel export FEC', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Entité juridique', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCBD5E1))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEntity,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    focusColor: Colors.transparent,
                    items: [
                      DropdownMenuItem(value: widget.enterpriseName, child: Text(widget.enterpriseName)),
                      const DropdownMenuItem(value: 'red', child: Text('red')),
                      const DropdownMenuItem(value: 'Toutes les entités', child: Text('Toutes les entités')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedEntity = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Run de paie', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCBD5E1))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRun,
                    hint: const Text('Sélectionner un run verrouillé', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    focusColor: Colors.transparent,
                    items: runOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRun = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: (_selectedRun == null || _isGenerating)
                      ? null
                      : () async {
                          setState(() => _isGenerating = true);
                          try {
                            final cleanBatchName = _selectedRun!.split(' (').first;
                            final exp = await HrAccountingService.instance.generateFecExport(
                              enterpriseId: widget.enterpriseId,
                              legalEntity: _selectedEntity,
                              batchName: cleanBatchName,
                              payslips: payslips,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Export FEC pour "$cleanBatchName" généré !'),
                                  backgroundColor: const Color(0xFF10B981),
                                  action: SnackBarAction(
                                    label: 'Télécharger',
                                    textColor: Colors.white,
                                    onPressed: () => HrAccountingService.instance.downloadFecExport(context, exp),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                            }
                          } finally {
                            if (mounted) setState(() => _isGenerating = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Générer l\'export FEC', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// MOBILE BOTTOM SHEET: AJOUTER / MODIFIER RUBRIQUE
// ──────────────────────────────────────────────────────────────────
// ──────────────────────────────────────────────────────────────────
// MOBILE BOTTOM SHEET: AJOUTER / MODIFIER RUBRIQUE (Screenshots 1 & 2)
// ──────────────────────────────────────────────────────────────────
class _MobileEditRubricSheet extends StatefulWidget {
  final String enterpriseId;
  final String enterpriseName;
  final HrAccountingRubric? rubric;

  const _MobileEditRubricSheet({
    required this.enterpriseId,
    required this.enterpriseName,
    this.rubric,
  });

  @override
  State<_MobileEditRubricSheet> createState() => _MobileEditRubricSheetState();
}

class _MobileEditRubricSheetState extends State<_MobileEditRubricSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _debitAccountCtrl;
  late TextEditingController _debitLabelCtrl;
  late TextEditingController _creditAccountCtrl;
  late TextEditingController _creditLabelCtrl;
  late TextEditingController _auxiliaryAccountCtrl;
  late TextEditingController _journalCodeCtrl;
  late TextEditingController _journalLabelCtrl;
  late String _selectedEntity;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.rubric;
    _codeCtrl = TextEditingController(text: r?.code ?? '');
    _debitAccountCtrl = TextEditingController(text: r?.debitAccount ?? '');
    _debitLabelCtrl = TextEditingController(text: r?.debitLabel ?? '');
    _creditAccountCtrl = TextEditingController(text: r?.creditAccount ?? '');
    _creditLabelCtrl = TextEditingController(text: r?.creditLabel ?? '');
    _auxiliaryAccountCtrl = TextEditingController(text: r?.auxiliaryAccount ?? '');
    _journalCodeCtrl = TextEditingController(text: r?.journal ?? 'OD');
    _journalLabelCtrl = TextEditingController(text: r?.journalLabel ?? 'Paie');
    _selectedEntity = r?.legalEntity ?? 'Toutes les entités';
    _isActive = r?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _debitAccountCtrl.dispose();
    _debitLabelCtrl.dispose();
    _creditAccountCtrl.dispose();
    _creditLabelCtrl.dispose();
    _auxiliaryAccountCtrl.dispose();
    _journalCodeCtrl.dispose();
    _journalLabelCtrl.dispose();
    super.dispose();
  }

  void _resetFromDefaultTemplate() {
    final code = _codeCtrl.text.trim();
    final template = HrAccountingService.defaultRubricTemplates.firstWhere(
      (t) => t['code'] == code,
      orElse: () => {},
    );
    if (template.isNotEmpty) {
      setState(() {
        _debitAccountCtrl.text = template['debitAccount'] ?? '';
        _debitLabelCtrl.text = template['debitLabel'] ?? '';
        _creditAccountCtrl.text = template['creditAccount'] ?? '';
        _creditLabelCtrl.text = template['creditLabel'] ?? '';
        _journalCodeCtrl.text = template['journal'] ?? 'OD';
        _journalLabelCtrl.text = 'Paie';
        _auxiliaryAccountCtrl.text = '';
        _isActive = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rubric != null;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with back arrow and title (Screenshot 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Text(
                  isEditing ? 'Modifier la ligne' : 'Nouvelle ligne comptable',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field 1: Rubrique de paie *
                    const Text(
                      'Rubrique de paie *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    if (isEditing) ...[
                      // Disabled read-only field matching Screenshot 1
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${_codeCtrl.text} — ${_debitLabelCtrl.text}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'La rubrique n\'est pas modifiable : supprimez la ligne et créez-en une nouvelle pour changer de rubrique.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        initialValue: HrAccountingService.defaultRubricTemplates.any((t) => t['code'] == _codeCtrl.text)
                            ? _codeCtrl.text
                            : null,
                        decoration: InputDecoration(
                          hintText: 'Choisir une rubrique...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                        isExpanded: true,
                        items: HrAccountingService.defaultRubricTemplates.map((t) {
                          return DropdownMenuItem(
                            value: t['code'],
                            child: Text('${t['code']} — ${t['debitLabel']}', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match = HrAccountingService.defaultRubricTemplates.firstWhere((t) => t['code'] == val, orElse: () => {});
                            if (match.isNotEmpty) {
                              setState(() {
                                _codeCtrl.text = match['code'] ?? '';
                                _debitAccountCtrl.text = match['debitAccount'] ?? '';
                                _debitLabelCtrl.text = match['debitLabel'] ?? '';
                                _creditAccountCtrl.text = match['creditAccount'] ?? '';
                                _creditLabelCtrl.text = match['creditLabel'] ?? '';
                                if (match['journal'] != null) _journalCodeCtrl.text = match['journal']!;
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _codeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Code personnalisé',
                          hintText: 'Ex. ABSENCE_UNPAID',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Field 2: Entité juridique
                    const Text(
                      'Entité juridique',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedEntity,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                          items: [
                            const DropdownMenuItem(value: 'Toutes les entités', child: Text('Toutes les entités juridiques')),
                            DropdownMenuItem(value: widget.enterpriseName, child: Text(widget.enterpriseName)),
                            const DropdownMenuItem(value: 'red', child: Text('red')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedEntity = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cette ligne s\'applique à toutes les entités juridiques de l\'organisation.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // Row 3: Compte débit * & Libellé débit *
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Compte débit *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _debitAccountCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: '425000',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Libellé débit *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _debitLabelCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Personnel rémunérations',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Row 4: Compte crédit * & Libellé crédit *
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Compte crédit *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _creditAccountCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: '640000',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Libellé crédit *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _creditLabelCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Salaires et compléments',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Field 5: Compte auxiliaire (optionnel) from Screenshot 2
                    const Text('Compte auxiliaire (optionnel)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _auxiliaryAccountCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ex. 401000',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Row 6: Code journal * & Libellé du journal * from Screenshot 2
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Code journal *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _journalCodeCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'OD',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Libellé du journal *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _journalLabelCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Paie',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section 7: Ligne active toggle card from Screenshot 2
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Switch(
                                value: _isActive,
                                activeThumbColor: Colors.white,
                                activeTrackColor: AppColors.primary,
                                onChanged: (v) => setState(() => _isActive = v),
                              ),
                              const SizedBox(width: 8),
                              const Text('Ligne active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'La rubrique alimente les écritures des prochains exports FEC.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (isEditing) ...[
                      // Section 8: Réinitialiser depuis le plan par défaut from Screenshot 2
                      InkWell(
                        onTap: () {
                          _resetFromDefaultTemplate();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ligne réinitialisée aux valeurs par défaut'), backgroundColor: Color(0xFF10B981)),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF0F172A)),
                            SizedBox(width: 6),
                            Text(
                              'Réinitialiser depuis le plan par défaut',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Section 9: Supprimer cette ligne from Screenshot 2
                      InkWell(
                        onTap: () {
                          if (widget.rubric == null) return;
                          final nav = Navigator.of(context);
                          OfflineActionHelper.executeAction(
                            context: context,
                            action: 'delete',
                            customActionLabel: 'Supprimer cette ligne',
                            onConfirmed: () async {
                              await HrAccountingService.instance.deleteRubric(widget.rubric!.id);
                              nav.pop();
                            },
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Supprimer cette ligne',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'La rubrique ne sera plus reprise dans les prochains exports FEC. Les exports déjà générés ne changent pas.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Pinned Bottom Actions Bar matching Screenshot 2
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;

                          final isEditing = widget.rubric != null;
                          if (isEditing) {
                            final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
                            if (!allowed) return;
                          }

                          setState(() => _isSaving = true);
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final toSave = (widget.rubric ??
                                    HrAccountingRubric(
                                      id: '',
                                      code: _codeCtrl.text.trim(),
                                      debitAccount: _debitAccountCtrl.text.trim(),
                                      debitLabel: _debitLabelCtrl.text.trim(),
                                      creditAccount: _creditAccountCtrl.text.trim(),
                                      creditLabel: _creditLabelCtrl.text.trim(),
                                      journal: _journalCodeCtrl.text.trim(),
                                      journalLabel: _journalLabelCtrl.text.trim(),
                                      auxiliaryAccount: _auxiliaryAccountCtrl.text.trim(),
                                      isActive: _isActive,
                                      legalEntity: _selectedEntity,
                                      enterpriseId: widget.enterpriseId,
                                    ))
                                .copyWith(
                              code: _codeCtrl.text.trim(),
                              debitAccount: _debitAccountCtrl.text.trim(),
                              debitLabel: _debitLabelCtrl.text.trim(),
                              creditAccount: _creditAccountCtrl.text.trim(),
                              creditLabel: _creditLabelCtrl.text.trim(),
                              journal: _journalCodeCtrl.text.trim(),
                              journalLabel: _journalLabelCtrl.text.trim(),
                              auxiliaryAccount: _auxiliaryAccountCtrl.text.trim(),
                              isActive: _isActive,
                              legalEntity: _selectedEntity,
                              enterpriseId: widget.enterpriseId,
                            );

                            await HrAccountingService.instance.saveRubric(toSave);
                            nav.pop();
                            final isOnline = ConnectivityService.instance.isOnline;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      isOnline ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isOnline
                                            ? 'Ligne comptable enregistrée !'
                                            : 'Ligne comptable enregistrée hors ligne - en attente de synchronisation',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: isOnline ? AppColors.success : AppColors.warning,
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
