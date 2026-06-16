import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../models/supplier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    context.read<SuppliersBloc>().add(LoadSuppliers());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header & KPIs
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gestion des Fournisseurs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Gérez vos fournisseurs et vos dettes envers eux.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              BlocBuilder<SuppliersBloc, SuppliersState>(
                builder: (context, state) {
                  int totalSuppliers = 0;
                  double totalOwed = 0;

                  if (state is SuppliersLoaded) {
                    totalSuppliers = state.suppliers.length;
                    totalOwed = state.suppliers.fold(0, (sum, s) => sum + s.balance);
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: DashboardCard(
                          title: 'Total Fournisseurs',
                          value: totalSuppliers.toString(),
                          icon: Icons.factory_rounded,
                          gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: DashboardCard(
                          title: 'Total Dettes',
                          value: formatCurrency(totalOwed),
                          icon: Icons.account_balance_wallet_rounded,
                          gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      const Expanded(child: SizedBox()), // Placeholder for balance layout
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        // Action Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
              const Spacer(),
              AppButton(label: 'Nouveau fournisseur', icon: Icons.add_rounded, onPressed: () => _showDialog(context, null)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: BlocBuilder<SuppliersBloc, SuppliersState>(
            builder: (context, state) {
              if (state is SuppliersLoading) return const Center(child: CircularProgressIndicator());
              if (state is SuppliersError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is SuppliersLoaded) {
                final filtered = _search.isEmpty ? state.suppliers
                    : state.suppliers.where((s) => s.name.toLowerCase().contains(_search) || s.code.toLowerCase().contains(_search)).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Supplier>(
                      columns: const ['Code', 'Fournisseur', 'Téléphone', 'Email', 'Ville', 'Solde'],
                      rows: filtered,
                      emptyMessage: 'Aucun fournisseur trouvé',
                      cellBuilder: (s) => [
                        DataCell(Text(s.code, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        )),
                        DataCell(Text(s.phone ?? '—')),
                        DataCell(Text(s.email ?? '—')),
                        DataCell(Text(s.city ?? '—')),
                        DataCell(Text(formatCurrency(s.balance), style: TextStyle(color: s.balance > 0 ? AppColors.error : AppColors.textPrimary, fontWeight: FontWeight.w600))),
                      ],
                      onEdit: (s) => _showDialog(context, s),
                      onDelete: (s) => context.read<SuppliersBloc>().add(DeleteSupplier(s.id)),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  void _showDialog(BuildContext context, Supplier? existing) {
    showDialog(context: context, builder: (_) => BlocProvider.value(
      value: context.read<SuppliersBloc>(),
      child: _SupplierDialog(existing: existing),
    ));
  }
}

class _SupplierDialog extends StatefulWidget {
  final Supplier? existing;
  const _SupplierDialog({this.existing});
  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _cityCtrl, _taxCtrl, _rcCtrl, _notesCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _codeCtrl = TextEditingController(text: s?.code ?? 'FOU-${DateTime.now().millisecondsSinceEpoch % 10000}');
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _cityCtrl = TextEditingController(text: s?.city ?? '');
    _taxCtrl = TextEditingController(text: s?.taxId ?? '');
    _rcCtrl = TextEditingController(text: s?.rc ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    for (var c in [_codeCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _cityCtrl, _taxCtrl, _rcCtrl, _notesCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 800,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.lg), topRight: Radius.circular(AppRadius.lg)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.factory_rounded, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    widget.existing == null ? 'Créer un Nouveau Fournisseur' : 'Modifier le Fournisseur',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                    label: const Text('Retour', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                    label: Text(widget.existing == null ? 'Créer' : 'Enregistrer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text("Informations Générales", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: AppTextField(label: 'Code *', controller: _codeCtrl, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                        const SizedBox(width: 16),
                        Expanded(child: AppTextField(label: 'Nom / Raison Sociale *', controller: _nameCtrl, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: AppTextField(label: 'Téléphone', controller: _phoneCtrl, keyboardType: TextInputType.phone)),
                        const SizedBox(width: 16),
                        Expanded(child: AppTextField(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress)),
                      ]),
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 24),
                      const Text("Localisation", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(flex: 2, child: AppTextField(label: 'Adresse', controller: _addressCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: AppTextField(label: 'Ville', controller: _cityCtrl)),
                      ]),
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 24),
                      const Text("Informations Fiscales & Notes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: AppTextField(label: 'NIF (Numéro d\'Identification Fiscale)', controller: _taxCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: AppTextField(label: 'RC (Registre de Commerce)', controller: _rcCtrl)),
                      ]),
                      const SizedBox(height: 16),
                      AppTextField(label: 'Notes privées', controller: _notesCtrl, maxLines: 3, hint: 'Ajouter une note sur ce fournisseur...'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final supplier = Supplier(
      id: widget.existing?.id ?? const Uuid().v4(),
      code: _codeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      taxId: _taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim(),
      rc: _rcCtrl.text.trim().isEmpty ? null : _rcCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    if (widget.existing == null) {
      context.read<SuppliersBloc>().add(AddSupplier(supplier));
    } else {
      context.read<SuppliersBloc>().add(UpdateSupplier(supplier));
    }
    Navigator.pop(context);
  }
}
