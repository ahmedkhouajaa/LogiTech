import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../models/crm_opportunity.dart';
import '../models/customer.dart';
import '../blocs/customers/customers_bloc.dart';
import '../services/crm_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class CrmPipelineScreen extends StatefulWidget {
  const CrmPipelineScreen({super.key});

  @override
  State<CrmPipelineScreen> createState() => _CrmPipelineScreenState();
}

class _CrmPipelineScreenState extends State<CrmPipelineScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int? _selectedPriority;

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
        CrmService.instance.isLoadingNotifier,
      ]),
      builder: (context, _) {
        final opps = CrmService.instance.opportunitiesNotifier.value;
        final stages = CrmService.instance.stagesNotifier.value;

        // Filter opportunities
        final filteredOpps = opps.where((opp) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matches = opp.title.toLowerCase().contains(q) ||
                opp.customerName.toLowerCase().contains(q) ||
                opp.source.toLowerCase().contains(q);
            if (!matches) return false;
          }
          if (_selectedPriority != null && opp.priority != _selectedPriority) return false;
          return true;
        }).toList();

        final totalPipeline = filteredOpps.where((o) => !o.isLost).fold(0.0, (acc, o) => acc + o.expectedRevenue);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                _buildHeader(context, isDark, filteredOpps.length, totalPipeline),
                const SizedBox(height: 16),

                // Search & Filter controls
                _buildFilterControls(isDark),
                const SizedBox(height: 16),

                // Kanban Board Columns
                Expanded(
                  child: stages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _buildKanbanBoard(isDark, filteredOpps, stages),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, int count, double total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.view_kanban_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Pipeline de Vente Visuel'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$count opportunité(s) • Valeur active : ${currencyFmt.format(total)} • Glissez-déposez pour changer d\'étape',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _openAddOpportunityDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Text('Nouvelle Affaire', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Search input
          Expanded(
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
                  hintText: 'Filtrer les affaires par nom, client...',
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
          const SizedBox(width: 12),

          // Priority dropdown
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _selectedPriority,
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
                hint: Text(
                  'Toutes priorités',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Toutes priorités', style: TextStyle(fontSize: 12.5))),
                  DropdownMenuItem(value: 3, child: Text('Urgente', style: TextStyle(fontSize: 12.5))),
                  DropdownMenuItem(value: 2, child: Text('Haute', style: TextStyle(fontSize: 12.5))),
                  DropdownMenuItem(value: 1, child: Text('Normale', style: TextStyle(fontSize: 12.5))),
                  DropdownMenuItem(value: 0, child: Text('Basse', style: TextStyle(fontSize: 12.5))),
                ],
                onChanged: (v) => setState(() => _selectedPriority = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanBoard(bool isDark, List<CrmOpportunity> opps, List<CrmStage> stages) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: stages.length,
      itemBuilder: (context, index) {
        final stage = stages[index];
        final stageOpps = opps.where((o) => o.stageId == stage.id).toList();
        final stageTotal = stageOpps.fold(0.0, (acc, o) => acc + o.expectedRevenue);

        return Container(
          width: 300,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Column Header
              _buildColumnHeader(stage, stageOpps.length, stageTotal, isDark),

              // DragTarget List Area
              Expanded(
                child: DragTarget<CrmOpportunity>(
                  onWillAcceptWithDetails: (details) => details.data.stageId != stage.id,
                  onAcceptWithDetails: (details) async {
                    final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                    if (!isOnline) return;
                    final droppedOpp = details.data;
                    CrmService.instance.updateOpportunityStage(droppedOpp.id, stage.id, stage.name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Affaire "${droppedOpp.title}" déplacée vers ${stage.name}'),
                        backgroundColor: stage.color,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = candidateData.isNotEmpty;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isHovered ? stage.color.withValues(alpha: 0.12) : Colors.transparent,
                        border: isHovered ? Border.all(color: stage.color, width: 2) : null,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                      child: stageOpps.isEmpty
                          ? Center(
                              child: Text(
                                'Déposez une affaire ici',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.builder(
                              itemCount: stageOpps.length,
                              itemBuilder: (context, idx) {
                                final opp = stageOpps[idx];
                                return _buildOpportunityCard(opp, stage, isDark);
                              },
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

  Widget _buildColumnHeader(CrmStage stage, int count, double total, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: stage.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    stage.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: stage.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stage.color),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Ajouter dans ${stage.name}',
                    onPressed: () => _openAddOpportunityDialog(context, initialStageId: stage.id, initialStageName: stage.name),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(currencyFmt.format(total), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stage.color)),
              Text('${stage.defaultProbability}% proba.', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(CrmOpportunity opp, CrmStage stage, bool isDark) {
    return Draggable<CrmOpportunity>(
      data: opp,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 270,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: stage.color, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(opp.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(currencyFmt.format(opp.expectedRevenue), style: TextStyle(fontWeight: FontWeight.bold, color: stage.color)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _cardContent(opp, stage, isDark),
      ),
      child: _cardContent(opp, stage, isDark),
    );
  }

  Widget _cardContent(CrmOpportunity opp, CrmStage stage, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Priority Star
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  opp.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (opp.priority > 1)
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: opp.priority == 3 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Client name
          Row(
            children: [
              Icon(opp.isLead ? Icons.contact_phone_outlined : Icons.person_outline, size: 13, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  opp.customerName,
                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Expected Amount & Probability
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currencyFmt.format(opp.expectedRevenue),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: stage.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${opp.probability}%',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: stage.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bottom card metadata: expected close date
          if (opp.expectedCloseDate != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                dateFmt.format(opp.expectedCloseDate!),
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }

  void _openAddOpportunityDialog(BuildContext context, {String? initialStageId, String? initialStageName}) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '0');

    String selectedCustomerId = '';
    String selectedCustomerName = '';
    String? selectedCustomerPhone;
    String? selectedCustomerEmail;
    bool isLead = false;

    String stageId = initialStageId ?? 'new';
    String stageName = initialStageName ?? 'Piste / Nouveau';

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Nouvelle Affaire Commerciale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Titre de l\'affaire', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    enabled: !isSaving,
                    decoration: _inputDeco('Ex : Projet ERP LogiTech', isDark),
                  ),
                  const SizedBox(height: 12),
                  const Text('Client ou Prospect', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCustomerId.isNotEmpty ? selectedCustomerId : null,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    decoration: _dropdownDeco('Sélectionner un contact', isDark),
                    items: allCustomers.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                      );
                    }).toList(),
                    onChanged: isSaving ? null : (id) {
                      if (id != null) {
                        final c = allCustomers.firstWhere((cust) => cust.id == id);
                        setDState(() {
                          selectedCustomerId = c.id;
                          selectedCustomerName = c.name;
                          selectedCustomerPhone = c.phone;
                          selectedCustomerEmail = c.email;
                          isLead = c.isLead;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Montant Estimé (TND)', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    enabled: !isSaving,
                    decoration: _inputDeco('0.00', isDark),
                  ),
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
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty || selectedCustomerId.isEmpty) {
                      return;
                    }
                    setDState(() => isSaving = true);
                    final isOnline = ConnectivityService.instance.isOnline;
                    final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

                    final opp = CrmOpportunity(
                      id: const Uuid().v4(),
                      enterpriseId: '',
                      title: title,
                      customerId: selectedCustomerId,
                      customerName: selectedCustomerName,
                      customerPhone: selectedCustomerPhone,
                      customerEmail: selectedCustomerEmail,
                      isLead: isLead,
                      stageId: stageId,
                      stageName: stageName,
                      expectedRevenue: amount,
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
                                        ? 'Affaire "$title" créée avec succès !'
                                        : 'Affaire "$title" enregistrée (hors ligne - en attente de synchronisation)',
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
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
}
