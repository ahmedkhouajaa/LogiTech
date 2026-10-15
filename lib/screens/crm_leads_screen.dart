import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../blocs/customers/customers_bloc.dart';
import '../models/customer.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';
import '../services/permission_service.dart';
import '../services/enterprise_service.dart';
import '../models/user_management_model.dart';
import '../services/crm_service.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class CrmLeadsScreen extends StatefulWidget {
  const CrmLeadsScreen({super.key});

  @override
  State<CrmLeadsScreen> createState() => _CrmLeadsScreenState();
}

class _CrmLeadsScreenState extends State<CrmLeadsScreen> {
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

  void _convertLeadToClient(Customer lead) {
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
                Text('Le prospect "${lead.name}" a été converti en Client officiel !'),
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

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Qualifier en Opportunité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Créer une nouvelle affaire commerciale dans votre pipeline pour ce prospect.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                const Text('Titre de l\'opportunité', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Montant Estimé (TND)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
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
                  final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                  if (!isOnline) return;

                  setDialogState(() => isSaving = true);
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
                      setDialogState(() => isSaving = false);
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
                    : const Text('Qualifier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddLeadDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Nouveau Prospect (Lead)'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(context.tr('Ajouter un contact commercial ou une piste'), style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: contactCtrl,
                              enabled: !isSaving,
                              decoration: _leadInputDeco(
                                labelText: context.tr('Contact / Responsable'),
                                prefixIcon: Icons.person_outline_rounded,
                                isDark: isDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              enabled: !isSaving,
                              decoration: _leadInputDeco(
                                labelText: context.tr('Téléphone'),
                                prefixIcon: Icons.phone_outlined,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !isSaving,
                              decoration: _leadInputDeco(
                                labelText: context.tr('E-mail'),
                                prefixIcon: Icons.email_outlined,
                                isDark: isDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: cityCtrl,
                              enabled: !isSaving,
                              decoration: _leadInputDeco(
                                labelText: context.tr('Ville'),
                                prefixIcon: Icons.location_on_outlined,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        maxLines: 2,
                        enabled: !isSaving,
                        decoration: _leadInputDeco(
                          labelText: context.tr('Besoin exprimé / Remarques'),
                          prefixIcon: Icons.notes_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(context.tr('Annuler')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSaving ? null : () {
                  if (formKey.currentState?.validate() == true) {
                    setDialogState(() => isSaving = true);
                    final isOnline = ConnectivityService.instance.isOnline;
                    final newLead = Customer(
                      id: const Uuid().v4(),
                      code: 'LEAD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      name: nameCtrl.text.trim(),
                      responsibleName: contactCtrl.text.trim().isNotEmpty ? contactCtrl.text.trim() : null,
                      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      city: cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : null,
                      notes: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
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
                                    ? 'Nouveau prospect "${newLead.name}" enregistré avec succès !'
                                    : 'Prospect "${newLead.name}" enregistré (hors ligne - en attente de synchronisation)',
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
        );
      },
    );
  }

  void _showEditLeadDialog(Customer lead) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: lead.name);
    final contactCtrl = TextEditingController(text: lead.responsibleName ?? '');
    final phoneCtrl = TextEditingController(text: lead.phone ?? '');
    final emailCtrl = TextEditingController(text: lead.email ?? '');
    final cityCtrl = TextEditingController(text: lead.city ?? '');
    final noteCtrl = TextEditingController(text: lead.notes ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
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
                    Text(context.tr('Modifier le prospect'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${lead.code} - ${lead.name}', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: contactCtrl,
                              enabled: !isSaving,
                              decoration: _leadInputDeco(
                                labelText: context.tr('Contact / Responsable'),
                                prefixIcon: Icons.person_outline_rounded,
                                isDark: isDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              enabled: !isSaving,
                              decoration: _leadInputDeco(
                                labelText: context.tr('Téléphone'),
                                prefixIcon: Icons.phone_outlined,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !isSaving,
                              decoration: _leadInputDeco(
                                labelText: context.tr('E-mail'),
                                prefixIcon: Icons.email_outlined,
                                isDark: isDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: cityCtrl,
                              enabled: !isSaving,
                              decoration: _leadInputDeco(
                                labelText: context.tr('Ville'),
                                prefixIcon: Icons.location_on_outlined,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        maxLines: 2,
                        enabled: !isSaving,
                        decoration: _leadInputDeco(
                          labelText: context.tr('Besoin exprimé / Remarques'),
                          prefixIcon: Icons.notes_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(context.tr('Annuler')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSaving ? null : () async {
                  if (formKey.currentState?.validate() == true) {
                    final isOnline = await OfflineActionHelper.checkOnlineOrShowError(context);
                    if (!isOnline) return;

                    setDialogState(() => isSaving = true);
                    final updatedLead = lead.copyWith(
                      name: nameCtrl.text.trim(),
                      responsibleName: contactCtrl.text.trim().isNotEmpty ? contactCtrl.text.trim() : null,
                      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      city: cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : null,
                      notes: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                      updatedAt: DateTime.now(),
                    );
                    context.read<CustomersBloc>().add(UpdateCustomer(updatedLead));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Prospect "${updatedLead.name}" mis à jour avec succès !'),
                        backgroundColor: const Color(0xFF2563EB),
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
                    : Text(context.tr('Enregistrer les modifications')),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<CustomersBloc, CustomersState>(
      listener: (context, state) {
        if (_isFirstLoad && (state is CustomersLoaded || state is CustomersError)) {
          setState(() {
            _isFirstLoad = false;
          });
        }
      },
      builder: (context, cState) {
        List<Customer> allCustomers = [];
        if (cState is CustomersLoaded) {
          allCustomers = cState.customers;
        }

        // Filter only leads
        final leads = allCustomers.where((c) => c.isLead).toList();

        // Apply search query
        final filteredLeads = leads.where((l) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return l.name.toLowerCase().contains(q) ||
              (l.phone ?? '').toLowerCase().contains(q) ||
              (l.email ?? '').toLowerCase().contains(q) ||
              (l.city ?? '').toLowerCase().contains(q) ||
              (l.responsibleName ?? '').toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              _buildHeader(context, leads.length),

              // 2. Search & Toolbar
              _buildToolbar(),

              // 3. Leads Table UI
              Expanded(
                child: (_isFirstLoad || cState is CustomersLoading || cState is CustomersInitial)
                    ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : filteredLeads.isEmpty
                        ? _buildEmptyState()
                        : _buildLeadsTable(filteredLeads, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.contact_phone_rounded, color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr('Prospects & Pistes (Leads)'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Text(
                        '$count prospects',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                ),
                Text(
                  context.tr('Gérez vos contacts commerciaux avant leur conversion en clients facturables'),
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('Actualiser'),
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: () => context.read<CustomersBloc>().add(LoadCustomers()),
          ),
          const SizedBox(width: 10),
          if (PermissionService.instance.canCreate(UserPermissionResources.crmLeads))
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(context.tr('Nouveau prospect')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _showAddLeadDialog,
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 12.5),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: context.tr('Rechercher un prospect par nom, téléphone, email ou ville...'),
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.contact_phone_outlined, size: 48, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? context.tr('Aucun prospect correspondant') : context.tr('Aucun prospect enregistré'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Enregistrez vos pistes commerciales pour leur envoyer des devis et suivre vos opportunités.'),
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(context.tr('Ajouter un prospect')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _showAddLeadDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsTable(List<Customer> leads, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
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
              final availableWidth = constraints.maxWidth;
              // Calculate column spacing to distribute available width evenly without overflowing
              final double colSpacing = ((availableWidth - 720.0) / 7.0).clamp(8.0, 24.0);

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
                      dataRowMinHeight: 50,
                      dataRowMaxHeight: 62,
                      columnSpacing: colSpacing,
                      horizontalMargin: 12,
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
                                    radius: 13,
                                    backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                    child: Text(
                                      lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'P',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    lead.name,
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                  if (lead.notes != null && lead.notes!.isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    Tooltip(
                                      message: lead.notes!,
                                      child: Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textTertiary),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // 3. Contact
                            DataCell(
                              Text(
                                (lead.responsibleName != null && lead.responsibleName!.isNotEmpty)
                                    ? lead.responsibleName!
                                    : '-',
                                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ),

                            // 4. Téléphone + Quick Call/WA buttons
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (lead.phone != null && lead.phone!.isNotEmpty) ? lead.phone! : '-',
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                                  ),
                                  if (lead.phone != null && lead.phone!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    IconButton(
                                      tooltip: 'Appeler',
                                      icon: const Icon(Icons.phone_rounded, size: 15, color: Color(0xFF2563EB)),
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      padding: const EdgeInsets.all(2),
                                      onPressed: () => launchUrl(Uri.parse('tel:${lead.phone}')),
                                    ),
                                    const SizedBox(width: 3),
                                    IconButton(
                                      tooltip: 'WhatsApp',
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF10B981)),
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      padding: const EdgeInsets.all(2),
                                      onPressed: () {
                                        final cleanPhone = lead.phone!.replaceAll(RegExp(r'\s+'), '');
                                        launchUrl(Uri.parse('https://wa.me/$cleanPhone'), mode: LaunchMode.externalApplication);
                                      },
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
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                  ),
                                  if (lead.email != null && lead.email!.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Envoyer un e-mail',
                                      icon: const Icon(Icons.mail_outline_rounded, size: 15, color: Color(0xFF7C3AED)),
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      padding: const EdgeInsets.all(2),
                                      onPressed: () => launchUrl(Uri.parse('mailto:${lead.email}')),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // 6. Ville
                            DataCell(
                              Text(
                                (lead.city != null && lead.city!.isNotEmpty) ? lead.city! : '-',
                                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ),

                            // 7. Actions CRM (Qualifier + Convertir)
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => _qualifyLeadToOpportunity(lead),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: context.tr('Convertir en Client officiel'),
                                    child: InkWell(
                                      onTap: () => _convertLeadToClient(lead),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                            ),
                                          ],
                                        ),
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
                                      tooltip: context.tr('Modifier'),
                                      icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF2563EB)),
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () => _showEditLeadDialog(lead),
                                    ),
                                  if (PermissionService.instance.canDelete(UserPermissionResources.crmLeads))
                                    IconButton(
                                      tooltip: context.tr('Supprimer'),
                                      icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () => _confirmDeleteLead(lead),
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
      ),
    );
  }

  InputDecoration _leadInputDeco({
    required String labelText,
    IconData? prefixIcon,
    required bool isDark,
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
        borderSide: BorderSide(color: Color(0xFF7C3AED), width: 1.5),
      ),
    );
  }
}
