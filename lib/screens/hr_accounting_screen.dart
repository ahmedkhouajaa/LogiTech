import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/enterprise/enterprise_bloc.dart';
import '../blocs/payroll/payroll_bloc.dart';
import '../blocs/payroll/payroll_state.dart';
import '../models/hr_accounting_entry.dart';
import '../models/payslip.dart';
import '../models/payslip_batch.dart';
import '../services/connectivity_service.dart';
import '../services/hr_accounting_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';

class HrAccountingScreen extends StatefulWidget {
  const HrAccountingScreen({super.key});

  @override
  State<HrAccountingScreen> createState() => _HrAccountingScreenState();
}

class _HrAccountingScreenState extends State<HrAccountingScreen> with SingleTickerProviderStateMixin {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section matching Image 1 & 2
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Exports comptables',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Exportez vos écritures de paie au format FEC.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),

                          // Top Right CTA Button in AppColors.primary
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
                              _tabController.index == 0 ? 'Nouvel export FEC' : 'Ajouter une rubrique',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Tabs (Exports FEC | Plan comptable)
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: const Color(0xFF0F172A),
                        unselectedLabelColor: const Color(0xFF64748B),
                        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 2.5,
                        indicatorSize: TabBarIndicatorSize.label,
                        dividerColor: const Color(0xFFE2E8F0),
                        tabs: const [
                          Tab(text: 'Exports FEC'),
                          Tab(text: 'Plan comptable'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Tab View Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Exports FEC (Screenshot 1)
                      _buildExportsFecTab(context, enterpriseId, enterpriseName),

                      // Tab 2: Plan comptable (Screenshot 2)
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

  // ─── TAB 1: EXPORTS FEC ──────────────────────────────────────────
  Widget _buildExportsFecTab(BuildContext context, String enterpriseId, String enterpriseName) {
    return StreamBuilder<List<FecExport>>(
      stream: HrAccountingService.instance.getExportsStream(enterpriseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final exports = snapshot.data ?? [];

        if (exports.isEmpty) {
          // Empty state matching Screenshot 1
          return Padding(
            padding: const EdgeInsets.all(28.0),
            child: Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Aucun export',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Générez votre premier export FEC depuis un run de paie verrouillé.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => _openNewFecDialog(context, enterpriseId, enterpriseName),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Nouvel export FEC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(28.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pinned Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 18,
                          child: Text(
                            'RUN DE PAIE',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 14,
                          child: Text(
                            'ENTITÉ JURIDIQUE',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 12,
                          child: Text(
                            'DATE D\'EXPORT',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 10,
                          child: Text(
                            'ÉCRITURES',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 13,
                          child: Text(
                            'TOTAL DÉBIT',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 13,
                          child: Text(
                            'TOTAL CRÉDIT',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 9,
                          child: Text(
                            'STATUT',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 15,
                          child: Text(
                            'ACTIONS',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rows List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: exports.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final exp = exports[index];
                      final currFormat = NumberFormat('#,##0.00', 'fr_FR');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 18,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      exp.batchName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 14,
                              child: Text(exp.legalEntity, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              flex: 12,
                              child: Text(exp.formattedDate, style: const TextStyle(fontSize: 12.5)),
                            ),
                            Expanded(
                              flex: 10,
                              child: Text('${exp.recordCount} lignes', style: const TextStyle(fontSize: 12.5)),
                            ),
                            Expanded(
                              flex: 13,
                              child: Text('${currFormat.format(exp.totalDebit)} TND', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              flex: 13,
                              child: Text('${currFormat.format(exp.totalCredit)} TND', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              flex: 9,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: const Text('Généré', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 15,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => _openFecPreview(context, exp),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Text('Aperçu', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => HrAccountingService.instance.downloadFecExport(context, exp),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Text('Télécharger', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () {
                                      OfflineActionHelper.executeAction(
                                        context: context,
                                        action: 'delete',
                                        customActionLabel: 'Supprimer l\'export FEC',
                                        onConfirmed: () async {
                                          await HrAccountingService.instance.deleteExport(exp.id);
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 2: PLAN COMPTABLE (Screenshot 2) ─────────────────────────
  Widget _buildPlanComptableTab(BuildContext context, String enterpriseId, String enterpriseName) {
    return StreamBuilder<List<HrAccountingRubric>>(
      stream: HrAccountingService.instance.getRubricsStream(enterpriseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRubrics = snapshot.data ?? [];
        final filtered = allRubrics.where((r) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return r.code.toLowerCase().contains(q) ||
              r.debitAccount.contains(q) ||
              r.debitLabel.toLowerCase().contains(q) ||
              r.creditAccount.contains(q) ||
              r.creditLabel.toLowerCase().contains(q) ||
              r.journal.toLowerCase().contains(q);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search input (100% white container, NO inner grey bubble)
              Container(
                width: 380,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2, offset: const Offset(0, 1)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            hintText: 'Rechercher une rubrique ou un compte...',
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
              const SizedBox(height: 16),

              // Table matching Screenshot 2
              // Full-width responsive table matching design tokens (no horizontal scroll)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        // Table Header (Pinned at top)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 18,
                                child: Text(
                                  'CODE RUBRIQUE',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: Text(
                                  'COMPTE DÉBIT',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 23,
                                child: Text(
                                  'LIBELLÉ DÉBIT',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 10,
                                child: Text(
                                  'COMPTE CRÉDIT',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 23,
                                child: Text(
                                  'LIBELLÉ CRÉDIT',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 8,
                                child: Text(
                                  'JOURNAL',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 14,
                                child: Text(
                                  'ENTITÉ JURIDIQUE',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 12,
                                child: Text(
                                  'ACTIONS',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Rows (Vertically scrollable)
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final r = filtered[index];
                              return Material(
                                color: Colors.white,
                                child: InkWell(
                                  onTap: () => _openEditRubricDialog(context, r, enterpriseName),
                                  hoverColor: const Color(0xFFF8FAFC),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 18,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              r.code,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: Color(0xFF0F172A),
                                                letterSpacing: 0.1,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 10,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              r.debitAccount,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 23,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              r.debitLabel,
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 10,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              r.creditAccount,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 23,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              r.creditLabel,
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 8,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                r.journal,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 14,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              r.legalEntity,
                                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 12,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () => _openEditRubricDialog(context, r, enterpriseName),
                                                borderRadius: BorderRadius.circular(4),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                  child: Text(
                                                    'Modifier',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Supprimer',
                                                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF94A3B8)),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── DIALOG 1: NOUVEL EXPORT FEC (Screenshot 3) ───────────────────
  void _openNewFecDialog(BuildContext context, String enterpriseId, String enterpriseName) {
    showDialog(
      context: context,
      builder: (ctx) => _NewFecExportDialog(enterpriseId: enterpriseId, enterpriseName: enterpriseName),
    );
  }

  // ─── DIALOG 2: AJOUTER / MODIFIER RUBRIQUE (Side-Sheet / Drawer) ─────────
  void _openAddRubricDialog(BuildContext context, String enterpriseId, String enterpriseName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: _EditAccountingRubricDialog(enterpriseId: enterpriseId, enterpriseName: enterpriseName),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }

  void _openEditRubricDialog(BuildContext context, HrAccountingRubric rubric, String enterpriseName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: _EditAccountingRubricDialog(
            enterpriseId: rubric.enterpriseId ?? '',
            enterpriseName: enterpriseName,
            rubric: rubric,
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }

  // ─── MODAL APERÇU DU FEC ──────────────────────────────────────────
  void _openFecPreview(BuildContext context, FecExport export) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.article_outlined, color: Color(0xFF1A56DB), size: 22),
                const SizedBox(width: 8),
                Text('Aperçu FEC - ${export.fileName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 780,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Entité : ${export.legalEntity}  •  Date : ${export.formattedDate}  •  ${export.recordCount} écritures',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copier dans le presse-papiers',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: export.fecContent));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contenu FEC copié !')));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        export.fecContent,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Télécharger le fichier'),
            onPressed: () {
              Navigator.pop(ctx);
              HrAccountingService.instance.downloadFecExport(context, export);
            },
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// DIALOG WIDGET: NOUVEL EXPORT FEC (Matching Screenshot 3)
// ──────────────────────────────────────────────────────────────────
class _NewFecExportDialog extends StatefulWidget {
  final String enterpriseId;
  final String enterpriseName;

  const _NewFecExportDialog({required this.enterpriseId, required this.enterpriseName});

  @override
  State<_NewFecExportDialog> createState() => _NewFecExportDialogState();
}

class _NewFecExportDialogState extends State<_NewFecExportDialog> {
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

        // Prepare runs list
        final runOptions = <String>[];
        if (batches.isNotEmpty) {
          for (final b in batches) {
            runOptions.add('${b.name} (${b.status == 'closed' ? 'Verrouillé' : 'Brouillon'})');
          }
        }
        // Fallback default runs matching screenshot 3
        if (!runOptions.any((r) => r.startsWith('Septembre 2026'))) {
          runOptions.add('Septembre 2026 (Verrouillé)');
        }
        if (!runOptions.any((r) => r.startsWith('Août 2026'))) {
          runOptions.add('Août 2026 (Verrouillé)');
        }
        if (!runOptions.any((r) => r.startsWith('Juillet 2026'))) {
          runOptions.add('Juillet 2026 (Verrouillé)');
        }

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nouvel export FEC',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Field 1: Entité juridique
                const Text(
                  'Entité juridique',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
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
                      focusColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
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
                const SizedBox(height: 18),

                // Field 2: Run de paie
                const Text(
                  'Run de paie',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
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
                      value: _selectedRun,
                      isExpanded: true,
                      hint: const Text(
                        'Sélectionner un run verrouillé',
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                      dropdownColor: Colors.white,
                      focusColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                      items: runOptions.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRun = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Bottom buttons: Annuler & Générer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
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
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Export FEC pour "$cleanBatchName" généré avec succès !'),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isGenerating = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      child: _isGenerating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Générer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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
}

// ──────────────────────────────────────────────────────────────────
// DIALOG WIDGET: AJOUTER / MODIFIER RUBRIQUE (Matching Screenshot 4)
// ──────────────────────────────────────────────────────────────────
class _EditAccountingRubricDialog extends StatefulWidget {
  final String enterpriseId;
  final String enterpriseName;
  final HrAccountingRubric? rubric;

  const _EditAccountingRubricDialog({
    required this.enterpriseId,
    required this.enterpriseName,
    this.rubric,
  });

  @override
  State<_EditAccountingRubricDialog> createState() => _EditAccountingRubricDialogState();
}

class _EditAccountingRubricDialogState extends State<_EditAccountingRubricDialog> {
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
  bool _codeHasError = false;
  bool _isSaving = false;

  List<Map<String, String>> get _rubricPresets => HrAccountingService.defaultRubricTemplates;

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
    _journalLabelCtrl = TextEditingController(text: r?.journalLabel ?? (r?.journal == 'BQ' ? 'Banque' : 'Paie'));
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
    final match = HrAccountingService.defaultRubricTemplates.firstWhere(
      (t) => t['code'] == code,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      setState(() {
        _debitAccountCtrl.text = match['debitAccount'] ?? '';
        _debitLabelCtrl.text = match['debitLabel'] ?? '';
        _creditAccountCtrl.text = match['creditAccount'] ?? '';
        _creditLabelCtrl.text = match['creditLabel'] ?? '';
        _journalCodeCtrl.text = match['journal'] ?? 'OD';
        _journalLabelCtrl.text = match['journal'] == 'BQ' ? 'Banque' : 'Paie';
        _auxiliaryAccountCtrl.clear();
        _isActive = true;
      });
    }
  }

  void _fillPresetDefaults(String code) {
    final match = HrAccountingService.defaultRubricTemplates.firstWhere(
      (t) => t['code'] == code,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      _debitAccountCtrl.text = match['debitAccount'] ?? '';
      _debitLabelCtrl.text = match['debitLabel'] ?? '';
      _creditAccountCtrl.text = match['creditAccount'] ?? '';
      _creditLabelCtrl.text = match['creditLabel'] ?? '';
      _journalCodeCtrl.text = match['journal'] ?? 'OD';
      _journalLabelCtrl.text = match['journal'] == 'BQ' ? 'Banque' : 'Paie';
      _auxiliaryAccountCtrl.clear();
      _isActive = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rubric != null;

    return Container(
      width: 520,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(-4, 0)),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Header with Back Arrow matching Screenshot 1
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF0F172A)),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isEditing ? 'Modifier la ligne' : 'Nouvelle ligne du plan comptable',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Body matching Screenshots 1 & 2
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                      const SizedBox(height: 8),
                      if (isEditing) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${_codeCtrl.text} — ${_debitLabelCtrl.text}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _codeHasError ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                              width: _codeHasError ? 1.5 : 1.0,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _codeCtrl.text.isNotEmpty && _rubricPresets.any((p) => p['code'] == _codeCtrl.text)
                                  ? _codeCtrl.text
                                  : null,
                              isExpanded: true,
                              hint: Text(
                                _codeCtrl.text.isNotEmpty ? _codeCtrl.text : 'Rechercher une rubrique',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _codeCtrl.text.isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                ),
                              ),
                              dropdownColor: Colors.white,
                              focusColor: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                              items: _rubricPresets.map((p) {
                                return DropdownMenuItem(
                                  value: p['code'],
                                  child: Text('${p['code']} (${p['debitLabel']})', style: const TextStyle(fontSize: 12.5)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _codeCtrl.text = val;
                                    _codeHasError = false;
                                    _fillPresetDefaults(val);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        if (_codeHasError)
                          const Padding(
                            padding: EdgeInsets.only(top: 4, left: 4),
                            child: Text('Champ obligatoire', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11.5)),
                          ),
                      ],
                      const SizedBox(height: 18),

                      // Field 2: Entité juridique
                      const Text(
                        'Entité juridique',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
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
                            focusColor: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
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
                      const SizedBox(height: 18),

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
                                    hintText: 'Ex. 425000',
                                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                    hintText: 'Ex. Personnel rémunérations dues',
                                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                    hintText: 'Ex. 640000',
                                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                    hintText: 'Ex. Salaires et compléments',
                                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                      const SizedBox(height: 18),

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
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      const SizedBox(height: 20),

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
                            OfflineActionHelper.executeAction(
                              context: context,
                              action: 'delete',
                              customActionLabel: 'Supprimer cette ligne',
                              onConfirmed: () async {
                                await HrAccountingService.instance.deleteRubric(widget.rubric!.id);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ligne supprimée'), backgroundColor: Colors.red),
                                  );
                                }
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
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Actions Bar matching Screenshots 1 & 2
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (_codeCtrl.text.trim().isEmpty) {
                              setState(() => _codeHasError = true);
                              return;
                            }
                            if (!_formKey.currentState!.validate()) return;

                            final isEditing = widget.rubric != null;
                            if (isEditing) {
                              final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
                              if (!allowed) return;
                            }

                            setState(() => _isSaving = true);
                            try {
                              final rubricToSave = (widget.rubric ??
                                      HrAccountingRubric(
                                        id: '',
                                        code: _codeCtrl.text.trim(),
                                        debitAccount: _debitAccountCtrl.text.trim(),
                                        debitLabel: _debitLabelCtrl.text.trim(),
                                        creditAccount: _creditAccountCtrl.text.trim(),
                                        creditLabel: _creditLabelCtrl.text.trim(),
                                        journal: _journalCodeCtrl.text.trim(),
                                        journalLabel: _journalLabelCtrl.text.trim(),
                                        auxiliaryAccount: _auxiliaryAccountCtrl.text.trim().isEmpty ? null : _auxiliaryAccountCtrl.text.trim(),
                                        legalEntity: _selectedEntity,
                                        isActive: _isActive,
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
                                auxiliaryAccount: _auxiliaryAccountCtrl.text.trim().isEmpty ? null : _auxiliaryAccountCtrl.text.trim(),
                                legalEntity: _selectedEntity,
                                isActive: _isActive,
                                enterpriseId: widget.enterpriseId,
                              );

                              await HrAccountingService.instance.saveRubric(rubricToSave);
                              if (context.mounted) {
                                final isOnline = ConnectivityService.instance.isOnline;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
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
                                                ? 'Rubrique comptable enregistrée avec succès !'
                                                : 'Rubrique enregistrée hors ligne - en attente de synchronisation',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: isOnline ? AppColors.success : AppColors.warning,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isSaving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
