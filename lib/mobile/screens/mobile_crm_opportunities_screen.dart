import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/crm_opportunity.dart';
import '../../models/customer.dart';
import '../../blocs/customers/customers_bloc.dart';
import '../../services/crm_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/offline_action_helper.dart';
import '../../utils/constants.dart';

class MobileCrmOpportunitiesScreen extends StatefulWidget {
  const MobileCrmOpportunitiesScreen({super.key});

  @override
  State<MobileCrmOpportunitiesScreen> createState() => _MobileCrmOpportunitiesScreenState();
}

class _MobileCrmOpportunitiesScreenState extends State<MobileCrmOpportunitiesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedStageId;

  final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 2);
  final dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
  }

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
        final allOpps = CrmService.instance.opportunitiesNotifier.value;
        final stages = CrmService.instance.stagesNotifier.value;

        final filtered = allOpps.where((opp) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            if (!opp.title.toLowerCase().contains(q) && !opp.customerName.toLowerCase().contains(q)) return false;
          }
          if (_selectedStageId != null && opp.stageId != _selectedStageId) return false;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF2563EB),
            onPressed: () => _openCreateDialog(context),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Nouvelle Affaire', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                      hintText: 'Rechercher une affaire...',
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
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: _selectedStageId == null,
                        label: const Text('Toutes'),
                        onSelected: (_) => setState(() => _selectedStageId = null),
                      ),
                    ),
                    ...stages.map((st) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: _selectedStageId == st.id,
                          label: Text(st.name),
                          selectedColor: st.color.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _selectedStageId = st.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // List of Opportunities
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('Aucune affaire trouvée', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
                                    Text(currencyFmt.format(opp.expectedRevenue), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    Text('${opp.probability}% succès', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _showChangeStageSheet(context, opp, stages),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      child: const Text('Étape', style: TextStyle(fontSize: 11.5)),
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
                Text('Changer l\'étape pour "${opp.title}"', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  void _openCreateDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '0');
    String selectedCustId = '';
    String selectedCustName = '';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final customersState = context.watch<CustomersBloc>().state;
            List<Customer> allCustomers = [];
            if (customersState is CustomersLoaded) {
              allCustomers = customersState.customers;
            }

            return AlertDialog(
              title: const Text('Nouvelle Opportunité', style: TextStyle(fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Titre de l\'affaire', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(controller: titleCtrl, enabled: !isSaving, decoration: _inputDeco('Ex : Projet ERP LogiTech', isDark)),
                  const SizedBox(height: 12),
                  const Text('Client / Prospect', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCustId.isNotEmpty ? selectedCustId : null,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    decoration: _dropdownDeco('Sélectionner un contact', isDark),
                    items: allCustomers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: isSaving ? null : (id) {
                      if (id != null) {
                        final c = allCustomers.firstWhere((x) => x.id == id);
                        setDState(() {
                          selectedCustId = c.id;
                          selectedCustName = c.name;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Montant Estimé (TND)', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(controller: amountCtrl, keyboardType: TextInputType.number, enabled: !isSaving, decoration: _inputDeco('0.00', isDark)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: isSaving ? null : () async {
                    if (titleCtrl.text.trim().isEmpty || selectedCustId.isEmpty) return;
                    setDState(() => isSaving = true);
                    final isOnline = ConnectivityService.instance.isOnline;
                    final amt = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                    final opp = CrmOpportunity(
                      id: const Uuid().v4(),
                      enterpriseId: '',
                      title: titleCtrl.text.trim(),
                      customerId: selectedCustId,
                      customerName: selectedCustName,
                      stageId: 'new',
                      stageName: 'Piste / Nouveau',
                      expectedRevenue: amt,
                    );
                    try {
                      await CrmService.instance.saveOpportunity(opp);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(isOnline ? Icons.check_circle_rounded : Icons.cloud_off_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isOnline
                                        ? 'Opportunité créée avec succès !'
                                        : 'Opportunité enregistrée (hors ligne - en attente de synchronisation)',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: isOnline ? const Color(0xFF10B981) : AppColors.warning,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setDState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Créer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDeco(String? hint, bool isDark) {
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

  InputDecoration _dropdownDeco(String? hint, bool isDark) {
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
