import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/customers/customers_bloc.dart';
import '../../models/customer.dart';
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../services/permission_service.dart';
import '../../services/enterprise_service.dart';
import '../../services/crm_service.dart';
import '../../models/user_management_model.dart';
import '../../services/connectivity_service.dart';
import '../../utils/offline_action_helper.dart';

class MobileCrmLeadsScreen extends StatefulWidget {
  const MobileCrmLeadsScreen({super.key});

  @override
  State<MobileCrmLeadsScreen> createState() => _MobileCrmLeadsScreenState();
}

class _MobileCrmLeadsScreenState extends State<MobileCrmLeadsScreen> {
  bool _isFirstLoad = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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

  void _convertLead(Customer lead) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'validate',
      customActionLabel: 'convertir en client officiel',
      onConfirmed: () {
        final updated = lead.copyWith(isLead: false, updatedAt: DateTime.now());
        context.read<CustomersBloc>().add(UpdateCustomer(updated));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Le prospect "${lead.name}" est maintenant un Client officiel !')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _qualifyLeadToOpportunity(Customer lead) {
    final titleCtrl = TextEditingController(text: 'Projet ${lead.name}');
    final amountCtrl = TextEditingController(text: '0');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      context.tr('Qualifier en Opportunité'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Créer une nouvelle affaire commerciale dans votre pipeline pour ce prospect.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  enabled: !isSaving,
                  decoration: _leadInputDeco(
                    labelText: 'Titre de l\'opportunité',
                    isDark: isDark,
                    focusColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  enabled: !isSaving,
                  decoration: _leadInputDeco(
                    labelText: 'Montant Estimé (TND)',
                    isDark: isDark,
                    focusColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving ? null : () async {
                    final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                    if (!isOnline) return;

                    setSheetState(() => isSaving = true);
                    final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                    try {
                      await CrmService.instance.createOpportunityFromLead(
                        lead,
                        dealTitle: titleCtrl.text.trim(),
                        amount: amount,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Affaire créée avec succès dans le Pipeline pour "${lead.name}" !'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setSheetState(() => isSaving = false);
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
                      : const Text('Qualifier dans le Pipeline', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(context.tr('Annuler')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteLead(Customer lead) {
    OfflineActionHelper.executeAction(
      context: context,
      action: 'delete',
      customActionLabel: 'supprimer ce prospect',
      onConfirmed: () {
        context.read<CustomersBloc>().add(DeleteCustomer(lead.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prospect "${lead.name}" supprimé.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showAddLeadSheet() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF7C3AED), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.tr('Nouveau Prospect (Lead)'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: '${context.tr("Nom du prospect / Raison sociale")} *',
                        prefixIcon: Icons.business_rounded,
                        isDark: isDark,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Ce champ est obligatoire') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactCtrl,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: context.tr('Personne de contact'),
                        prefixIcon: Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: context.tr('Téléphone'),
                        prefixIcon: Icons.phone_outlined,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: context.tr('E-mail'),
                        prefixIcon: Icons.email_outlined,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cityCtrl,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: context.tr('Ville'),
                        prefixIcon: Icons.location_on_outlined,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSaving ? null : () {
                        if (formKey.currentState?.validate() == true) {
                          setSheetState(() => isSaving = true);
                          final isOnline = ConnectivityService.instance.isOnline;
                          final newLead = Customer(
                            id: const Uuid().v4(),
                            code: 'LEAD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                            name: nameCtrl.text.trim(),
                            responsibleName: contactCtrl.text.trim().isNotEmpty ? contactCtrl.text.trim() : null,
                            phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                            email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                            city: cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : null,
                            isLead: true,
                            enterpriseId: EnterpriseService.instance.currentEnterpriseId,
                          );
                          context.read<CustomersBloc>().add(AddCustomer(newLead));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(isOnline ? Icons.check_circle_rounded : Icons.cloud_off_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isOnline
                                          ? 'Prospect "${newLead.name}" ajouté avec succès !'
                                          : 'Prospect "${newLead.name}" ajouté (hors ligne - en attente de synchronisation)',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: isOnline ? const Color(0xFF7C3AED) : AppColors.warning,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(context.tr('Enregistrer le prospect')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditLeadSheet(Customer lead) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: lead.name);
    final contactCtrl = TextEditingController(text: lead.responsibleName ?? '');
    final phoneCtrl = TextEditingController(text: lead.phone ?? '');
    final emailCtrl = TextEditingController(text: lead.email ?? '');
    final cityCtrl = TextEditingController(text: lead.city ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Modifier le prospect'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${lead.code} - ${lead.name}',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: '${context.tr("Nom du prospect / Raison sociale")} *',
                        prefixIcon: Icons.business_rounded,
                        isDark: isDark,
                        focusColor: const Color(0xFF2563EB),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Ce champ est obligatoire') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactCtrl,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: context.tr('Personne de contact'),
                        prefixIcon: Icons.person_outline_rounded,
                        isDark: isDark,
                        focusColor: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: context.tr('Téléphone'),
                        prefixIcon: Icons.phone_outlined,
                        isDark: isDark,
                        focusColor: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: context.tr('E-mail'),
                        prefixIcon: Icons.email_outlined,
                        isDark: isDark,
                        focusColor: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cityCtrl,
                      enabled: !isSaving,
                      decoration: _leadInputDeco(
                        labelText: context.tr('Ville'),
                        prefixIcon: Icons.location_on_outlined,
                        isDark: isDark,
                        focusColor: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSaving ? null : () async {
                        if (formKey.currentState?.validate() == true) {
                          final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                          if (!isOnline) return;

                          setSheetState(() => isSaving = true);
                          final updated = lead.copyWith(
                            name: nameCtrl.text.trim(),
                            responsibleName: contactCtrl.text.trim().isNotEmpty ? contactCtrl.text.trim() : null,
                            phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                            email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                            city: cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : null,
                            updatedAt: DateTime.now(),
                          );
                          context.read<CustomersBloc>().add(UpdateCustomer(updated));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Prospect "${updated.name}" mis à jour avec succès !'),
                              backgroundColor: const Color(0xFF2563EB),
                            ),
                          );
                        }
                      },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(context.tr('Enregistrer les modifications')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<CustomersBloc, CustomersState>(
        listener: (context, state) {
          if (_isFirstLoad && (state is CustomersLoaded || state is CustomersError)) {
            setState(() {
              _isFirstLoad = false;
            });
          }
        },
        builder: (context, cState) {
          List<Customer> all = [];
          if (cState is CustomersLoaded) {
            all = cState.customers;
          }

          final leads = all.where((c) => c.isLead).toList();
          final filtered = leads.where((l) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return l.name.toLowerCase().contains(q) ||
                (l.phone ?? '').toLowerCase().contains(q) ||
                (l.city ?? '').toLowerCase().contains(q) ||
                (l.responsibleName ?? '').toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: context.tr('Rechercher un prospect...'),
                      hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),

              // Leads Count Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} prospect${filtered.length > 1 ? "s" : ""}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Leads Table (Horizontal & Vertical scroll)
              Expanded(
                child: (_isFirstLoad || cState is CustomersLoading || cState is CustomersInitial)
                    ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.contact_phone_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  context.tr('Aucun prospect trouvé'),
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : _buildMobileLeadsTable(filtered, isDark),
              ),
            ],
          );
        },
      ),
      floatingActionButton: PermissionService.instance.canCreate(UserPermissionResources.crmLeads)
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: _showAddLeadSheet,
              child: const Icon(Icons.person_add_rounded, size: 26),
            )
          : null,
    );
  }

  Widget _buildMobileLeadsTable(List<Customer> leads, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 80),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    ),
                    headingRowHeight: 46,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 64,
                    columnSpacing: 18,
                    horizontalMargin: 14,
                    columns: [
                      DataColumn(
                        label: Text(
                          context.tr('Code'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          context.tr('Prospect'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          context.tr('Contact'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          context.tr('Téléphone'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          context.tr('E-mail'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          context.tr('Ville'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          context.tr('Actions CRM'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          context.tr('Actions'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                    rows: leads.map((lead) {
                      return DataRow(
                        cells: [
                          // 1. Code Badge
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                lead.code,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                              ),
                            ),
                          ),

                          // 2. Prospect
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                  child: Text(
                                    lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'P',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lead.name,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),

                          // 3. Contact
                          DataCell(
                            Text(
                              (lead.responsibleName != null && lead.responsibleName!.isNotEmpty) ? lead.responsibleName! : '-',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),

                          // 4. Téléphone + Quick Call/WA buttons
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (lead.phone != null && lead.phone!.isNotEmpty) ? lead.phone! : '-',
                                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                ),
                                if (lead.phone != null && lead.phone!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF2563EB)),
                                    onPressed: () => launchUrl(Uri.parse('tel:${lead.phone}')),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF10B981)),
                                    onPressed: () {
                                      final clean = lead.phone!.replaceAll(RegExp(r'\s+'), '');
                                      launchUrl(Uri.parse('https://wa.me/$clean'), mode: LaunchMode.externalApplication);
                                    },
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // 5. E-mail
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (lead.email != null && lead.email!.isNotEmpty) ? lead.email! : '-',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                if (lead.email != null && lead.email!.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.mail_outline_rounded, size: 16, color: Color(0xFF7C3AED)),
                                    onPressed: () => launchUrl(Uri.parse('mailto:${lead.email}')),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // 6. Ville
                          DataCell(
                            Text(
                              (lead.city != null && lead.city!.isNotEmpty) ? lead.city! : '-',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),

                          // 7. Actions CRM (Qualifier & Convertir)
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _qualifyLeadToOpportunity(lead),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.auto_graph_rounded, size: 12, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        Text(
                                          context.tr('Qualifier'),
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _convertLead(lead),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF10B981)),
                                        const SizedBox(width: 4),
                                        Text(
                                          context.tr('Convertir'),
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 8. Actions (Modifier + Supprimer)
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (PermissionService.instance.canUpdate(UserPermissionResources.crmLeads))
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                    onPressed: () => _showEditLeadSheet(lead),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                if (PermissionService.instance.canDelete(UserPermissionResources.crmLeads))
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                    onPressed: () => _confirmDeleteLead(lead),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _leadInputDeco({
    required String labelText,
    IconData? prefixIcon,
    required bool isDark,
    Color focusColor = const Color(0xFF7C3AED),
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        fontSize: 12.5,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              size: 18,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            )
          : null,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
    );
  }
}
