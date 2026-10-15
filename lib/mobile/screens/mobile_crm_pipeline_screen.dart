import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/crm_opportunity.dart';
import '../../services/crm_service.dart';
import '../../utils/offline_action_helper.dart';

class MobileCrmPipelineScreen extends StatefulWidget {
  const MobileCrmPipelineScreen({super.key});

  @override
  State<MobileCrmPipelineScreen> createState() => _MobileCrmPipelineScreenState();
}

class _MobileCrmPipelineScreenState extends State<MobileCrmPipelineScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedStageId = 'all';

  final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);
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
      listenable: Listenable.merge([
        CrmService.instance.opportunitiesNotifier,
        CrmService.instance.stagesNotifier,
      ]),
      builder: (context, _) {
        final opps = CrmService.instance.opportunitiesNotifier.value;
        final stages = CrmService.instance.stagesNotifier.value;

        final filtered = opps.where((opp) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            if (!opp.title.toLowerCase().contains(q) && !opp.customerName.toLowerCase().contains(q)) return false;
          }
          if (_selectedStageId != 'all' && opp.stageId != _selectedStageId) return false;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Rechercher dans le pipeline...',
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
                  ),
                ),
              ),

              // Stages Horizontal Filter Chips
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: _selectedStageId == 'all',
                        label: Text('Tous (${opps.length})'),
                        onSelected: (_) => setState(() => _selectedStageId = 'all'),
                      ),
                    ),
                    ...stages.map((st) {
                      final count = opps.where((o) => o.stageId == st.id).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: _selectedStageId == st.id,
                          label: Text('${st.name} ($count)'),
                          selectedColor: st.color.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _selectedStageId = st.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // List of Opportunity Cards
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('Aucune affaire dans cette étape.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final opp = filtered[idx];
                          final stage = stages.where((s) => s.id == opp.stageId).firstOrNull;
                          final stageColor = stage?.color ?? const Color(0xFF2563EB);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        opp.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _showChangeStageSheet(context, opp, stages),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: stageColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          opp.stageName,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stageColor),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(opp.customerName, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      currencyFmt.format(opp.expectedRevenue),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                    ),
                                    Text('${opp.probability}% succès', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showChangeStageSheet(context, opp, stages),
                                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                      label: const Text('Changer d\'étape', style: TextStyle(fontSize: 11.5)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangeStageSheet(BuildContext context, CrmOpportunity opp, List<CrmStage> stages) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Déplacer "${opp.title}"', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...stages.map((s) {
                  return ListTile(
                    leading: Icon(Icons.circle, color: s.color, size: 14),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: s.id == opp.stageId ? const Icon(Icons.check, color: Color(0xFF2563EB)) : null,
                    onTap: () async {
                      final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                      if (!isOnline) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      CrmService.instance.updateOpportunityStage(opp.id, s.id, s.name);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
