import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/crm_opportunity.dart';
import '../models/crm_activity.dart';
import '../models/customer.dart';
import '../blocs/customers/customers_bloc.dart';
import '../services/crm_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class CrmOpportunitiesScreen extends StatefulWidget {
  const CrmOpportunitiesScreen({super.key});

  @override
  State<CrmOpportunitiesScreen> createState() => _CrmOpportunitiesScreenState();
}

class _CrmOpportunitiesScreenState extends State<CrmOpportunitiesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedStageId;
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
        CrmService.instance.activitiesNotifier,
      ]),
      builder: (context, _) {
        final allOpps = CrmService.instance.opportunitiesNotifier.value;
        final stages = CrmService.instance.stagesNotifier.value;

        // Apply filters
        final filtered = allOpps.where((opp) {
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matches = opp.title.toLowerCase().contains(q) ||
                opp.customerName.toLowerCase().contains(q) ||
                opp.source.toLowerCase().contains(q);
            if (!matches) return false;
          }
          if (_selectedStageId != null && opp.stageId != _selectedStageId) return false;
          if (_selectedPriority != null && opp.priority != _selectedPriority) return false;
          return true;
        }).toList();

        final totalValue = filtered.fold(0.0, (acc, o) => acc + o.expectedRevenue);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Action & Title Bar
                _buildTopBar(context, isDark, filtered.length, totalValue),
                const SizedBox(height: 16),

                // Search & Filter Bar
                _buildFilterBar(isDark, stages),
                const SizedBox(height: 16),

                // Main Table / List View
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: filtered.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildOpportunitiesTable(isDark, filtered, stages),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, int count, double totalValue) {
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
                  child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Suivi des Opportunités'),
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
              '$count affaire(s) filtrée(s) • Valeur totale : ${currencyFmt.format(totalValue)}',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _openCreateOpportunityDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Text('Nouvelle Opportunité', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(bool isDark, List<CrmStage> stages) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Box
          SizedBox(
            width: 250,
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher une affaire, client...',
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

          // Stage Dropdown Filter
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedStageId,
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
                  'Toutes les étapes',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Toutes les étapes', style: TextStyle(fontSize: 12.5))),
                  ...stages.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12.5)))),
                ],
                onChanged: (v) => setState(() => _selectedStageId = v),
              ),
            ),
          ),

          // Priority Filter
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
                  'Toutes les priorités',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Toutes les priorités', style: TextStyle(fontSize: 12.5))),
                  DropdownMenuItem(value: 0, child: Text('Basse', style: TextStyle(fontSize: 12.5))),
                  DropdownMenuItem(value: 1, child: Text('Normale', style: TextStyle(fontSize: 12.5))),
                  DropdownMenuItem(value: 2, child: Text('Haute', style: TextStyle(fontSize: 12.5))),
                  DropdownMenuItem(value: 3, child: Text('Urgente', style: TextStyle(fontSize: 12.5))),
                ],
                onChanged: (v) => setState(() => _selectedPriority = v),
              ),
            ),
          ),

          // Reset button
          if (_searchQuery.isNotEmpty || _selectedStageId != null || _selectedPriority != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchCtrl.clear();
                  _searchQuery = '';
                  _selectedStageId = null;
                  _selectedPriority = null;
                });
              },
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('Réinitialiser'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(
            'Aucune opportunité trouvée',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text('Créez votre première affaire ou modifiez vos critères de recherche.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openCreateOpportunityDialog(context),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('Créer une Opportunité', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunitiesTable(bool isDark, List<CrmOpportunity> opps, List<CrmStage> stages) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Affaire / Titre', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Client / Contact', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Étape', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Montant Estimé', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Probabilité', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Clôture Estimée', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Priorité', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: opps.map((opp) {
            final stage = stages.where((s) => s.id == opp.stageId).firstOrNull;
            final stageColor = stage?.color ?? const Color(0xFF2563EB);

            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () => _openOpportunityDetailModal(context, opp),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(opp.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(opp.customerName)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: stageColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(opp.stageName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stageColor)),
                  ),
                ),
                DataCell(Text(currencyFmt.format(opp.expectedRevenue), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('${opp.probability} %')),
                DataCell(Text(opp.expectedCloseDate != null ? dateFmt.format(opp.expectedCloseDate!) : 'Non définie')),
                DataCell(_buildPriorityBadge(opp.priority)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Voir la fiche complète',
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF2563EB)),
                        onPressed: () => _openOpportunityDetailModal(context, opp),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                        onPressed: () => _confirmDeleteOpportunity(context, opp),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(int priority) {
    Color color;
    String label;
    switch (priority) {
      case 3:
        color = const Color(0xFFEF4444);
        label = 'Urgente';
        break;
      case 2:
        color = const Color(0xFFF59E0B);
        label = 'Haute';
        break;
      case 1:
        color = const Color(0xFF3B82F6);
        label = 'Normale';
        break;
      default:
        color = const Color(0xFF64748B);
        label = 'Basse';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
    );
  }

  // ---------------------------------------------------------------------------
  // CREATE OPPORTUNITY DIALOG
  // ---------------------------------------------------------------------------
  void _openCreateOpportunityDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();

    String selectedCustomerName = '';
    String selectedCustomerId = '';
    String? selectedCustomerPhone;
    String? selectedCustomerEmail;
    bool isLead = false;

    String selectedStageId = 'new';
    String selectedStageName = 'Piste / Nouveau';
    int probability = 10;
    int priority = 1;
    DateTime? closeDate = DateTime.now().add(const Duration(days: 30));
    String source = 'Prospection directe';

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            final isDark = Theme.of(dCtx).brightness == Brightness.dark;
            final stages = CrmService.instance.stagesNotifier.value;
            final customersState = context.watch<CustomersBloc>().state;
            List<Customer> allCustomers = [];
            if (customersState is CustomersLoaded) {
              allCustomers = customersState.customers;
            }

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_business_rounded, color: Color(0xFF2563EB), size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text('Créer une Opportunité Commerciale', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Titre de l'affaire
                      const Text('Titre de l\'affaire *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: _inputDeco('Ex : Contrat de maintenance annuelle, Vente licences...', isDark),
                      ),
                      const SizedBox(height: 14),

                      // Client / Contact selector
                      const Text('Client ou Prospect associé *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCustomerId.isNotEmpty ? selectedCustomerId : null,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        decoration: _dropdownDeco('Sélectionner un client ou prospect', isDark),
                        items: allCustomers.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(c.isLead ? Icons.contact_phone_outlined : Icons.person_outline, size: 16, color: c.isLead ? const Color(0xFFF59E0B) : const Color(0xFF2563EB)),
                                const SizedBox(width: 8),
                                Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                                if (c.isLead)
                                  const Text(' (Prospect)', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
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
                      const SizedBox(height: 14),

                      // Montant & Étape
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Montant Estimé (TND)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: amountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDeco('0.00', isDark),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Étape du Pipeline', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedStageId,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  decoration: _dropdownDeco(null, isDark),
                                  items: stages.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12.5)))).toList(),
                                  onChanged: (sid) {
                                    if (sid != null) {
                                      final s = stages.firstWhere((st) => st.id == sid);
                                      setDState(() {
                                        selectedStageId = s.id;
                                        selectedStageName = s.name;
                                        probability = s.defaultProbability;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Probabilité & Clôture estimée
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Probabilité de succès ($probability %)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                Slider(
                                  value: probability.toDouble(),
                                  min: 0,
                                  max: 100,
                                  divisions: 20,
                                  activeColor: const Color(0xFF2563EB),
                                  label: '$probability %',
                                  onChanged: (val) => setDState(() => probability = val.toInt()),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date de clôture cible', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: dCtx,
                                      initialDate: closeDate ?? DateTime.now().add(const Duration(days: 30)),
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 720)),
                                    );
                                    if (picked != null) setDState(() => closeDate = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Text(closeDate != null ? dateFmt.format(closeDate!) : 'Sélectionner...'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Priorité & Source
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Priorité', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  initialValue: priority,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  decoration: _dropdownDeco(null, isDark),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('Basse', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 1, child: Text('Normale', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 2, child: Text('Haute', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 3, child: Text('Urgente', style: TextStyle(fontSize: 12.5))),
                                  ],
                                  onChanged: (v) => setDState(() => priority = v ?? 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Source de la piste', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: source,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  decoration: _dropdownDeco(null, isDark),
                                  items: const [
                                    DropdownMenuItem(value: 'Prospection directe', child: Text('Prospection directe', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 'Site web / Formulaire', child: Text('Site web / Formulaire', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 'Recommandation', child: Text('Recommandation', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 'Salon / Événement', child: Text('Salon / Événement', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 'Réseaux sociaux', child: Text('Réseaux sociaux', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 'Autre', child: Text('Autre', style: TextStyle(fontSize: 12.5))),
                                  ],
                                  onChanged: (s) => setDState(() => source = s ?? 'Prospection directe'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      const Text('Notes & Observations', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: _inputDeco('Détails sur le besoin du client...', isDark),
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir un titre')));
                                return;
                              }
                              if (selectedCustomerId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un client ou prospect')));
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
                                stageId: selectedStageId,
                                stageName: selectedStageName,
                                expectedRevenue: amount,
                                probability: probability,
                                expectedCloseDate: closeDate,
                                priority: priority,
                                source: source,
                                notes: notesCtrl.text.trim(),
                              );

                              try {
                                await CrmService.instance.saveOpportunity(opp);
                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);

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
                                                  ? 'Opportunité "$title" créée avec succès !'
                                                  : 'Opportunité "$title" enregistrée (hors ligne - en attente de synchronisation)',
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
                                if (dialogCtx.mounted) {
                                  setDState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Enregistrer & Fermer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // OPPORTUNITY FULL DETAIL MODAL
  // ---------------------------------------------------------------------------
  void _openOpportunityDetailModal(BuildContext context, CrmOpportunity opp) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setModalState) {
            final isDark = Theme.of(dCtx).brightness == Brightness.dark;
            final stages = CrmService.instance.stagesNotifier.value;
            final activities = CrmService.instance.activitiesNotifier.value.where((a) => a.opportunityId == opp.id).toList();

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Close
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(opp.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${opp.customerName} • Source : ${opp.source}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Stepper Status Bar (Piste -> Qualification -> Proposition -> Négociation -> Gagné)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: stages.map((s) {
                            final isCurrent = s.id == opp.stageId;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () async {
                                  final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                                  if (!isOnline) return;
                                  await CrmService.instance.updateOpportunityStage(opp.id, s.id, s.name);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? s.color : s.color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: s.color.withValues(alpha: isCurrent ? 1.0 : 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      if (isCurrent) const Icon(Icons.check, size: 14, color: Colors.white),
                                      if (isCurrent) const SizedBox(width: 4),
                                      Text(
                                        s.name,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent ? Colors.white : s.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action Toolbar
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openAddActivityDialog(context, opp),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Planifier Activité'),
                          ),
                          if (!opp.isWon)
                            ElevatedButton.icon(
                              onPressed: () async {
                                final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                                if (!isOnline) return;
                                await CrmService.instance.updateOpportunityStage(opp.id, 'won', 'Gagné (Signé)');
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Affaire marquée Gagnée ! 🎉'), backgroundColor: Color(0xFF10B981)));
                                }
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                              label: const Text('Gagné !', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                            ),
                          if (!opp.isLost)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                                if (!isOnline) return;
                                await CrmService.instance.updateOpportunityStage(opp.id, 'lost', 'Perdu / Sans suite');
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                              label: const Text('Perdu', style: TextStyle(color: Color(0xFFEF4444))),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF4444))),
                            ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Opportunity details summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 10,
                          children: [
                            _buildSummaryItem('Montant estimé', currencyFmt.format(opp.expectedRevenue), const Color(0xFF2563EB)),
                            _buildSummaryItem('Probabilité', '${opp.probability} %', const Color(0xFF8B5CF6)),
                            _buildSummaryItem('CA Pondéré', currencyFmt.format(opp.weightedRevenue), const Color(0xFF10B981)),
                            _buildSummaryItem('Clôture cible', opp.expectedCloseDate != null ? dateFmt.format(opp.expectedCloseDate!) : 'Non définie', const Color(0xFF0F172A)),
                            _buildSummaryItem('Devis liés', '${opp.quoteIds.length} devis', const Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Activities List Section
                      Text('Activités & Actions planifiées (${activities.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (activities.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Aucune activité planifiée pour cette affaire.'))
                      else
                        ...activities.map((a) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(a.type.icon, color: a.type.color),
                            title: Text(a.title, style: TextStyle(decoration: a.isDone ? TextDecoration.lineThrough : null)),
                            subtitle: Text('Échéance : ${dateFmt.format(a.dueDate)}'),
                            trailing: Checkbox(
                              value: a.isDone,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (v) {
                                if (v != null) {
                                  CrmService.instance.toggleActivityDone(a.id, v);
                                  setModalState(() {});
                                }
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String val, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valColor)),
      ],
    );
  }



  void _openAddActivityDialog(BuildContext context, CrmOpportunity opp) {
    final titleCtrl = TextEditingController();
    CrmActivityType selectedType = CrmActivityType.call;
    DateTime dueDate = DateTime.now().add(const Duration(days: 2));

    showDialog(
      context: context,
      builder: (actCtx) {
        return StatefulBuilder(
          builder: (aCtx, setAState) {
            return AlertDialog(
              title: const Text('Planifier une activité commerciale', style: TextStyle(fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Type d\'action', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<CrmActivityType>(
                    initialValue: selectedType,
                    dropdownColor: Theme.of(aCtx).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(aCtx).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    decoration: _dropdownDeco(null, Theme.of(aCtx).brightness == Brightness.dark),
                    items: CrmActivityType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label, style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (v) => setAState(() => selectedType = v ?? CrmActivityType.call),
                  ),
                  const SizedBox(height: 12),
                  const Text('Objet / Titre', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: titleCtrl,
                    decoration: _inputDeco('Ex : Appel de relance, Présentation démo...', Theme.of(aCtx).brightness == Brightness.dark),
                  ),
                  const SizedBox(height: 12),
                  const Text('Date d\'échéance', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: aCtx,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setAState(() => dueDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(dateFmt.format(dueDate)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(actCtx), child: const Text('Annuler')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;

                    final act = CrmActivity(
                      id: const Uuid().v4(),
                      enterpriseId: opp.enterpriseId,
                      opportunityId: opp.id,
                      opportunityTitle: opp.title,
                      customerId: opp.customerId,
                      customerName: opp.customerName,
                      type: selectedType,
                      title: title,
                      dueDate: dueDate,
                    );
                    await CrmService.instance.saveActivity(act);
                    if (actCtx.mounted) Navigator.pop(actCtx);
                  },
                  child: const Text('Créer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteOpportunity(BuildContext context, CrmOpportunity opp) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'supprimer cette opportunité',
      onConfirmed: () {
        CrmService.instance.deleteOpportunity(opp.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opportunité "${opp.title}" supprimée.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
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
