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
        // Modern Action Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: Colors.transparent,
            border: Border(bottom: BorderSide(color: Colors.transparent)),
          ),
          child: Row(
            children: [
              const Text('Fournisseurs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              SizedBox(
                width: 300,
                child: AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => _showDialog(context, null),
                icon: const Icon(Icons.factory_rounded, size: 20, color: Colors.white),
                label: const Text('Nouveau Fournisseur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: BlocBuilder<SuppliersBloc, SuppliersState>(
            builder: (context, state) {
              if (state is SuppliersLoading) return const Center(child: CircularProgressIndicator());
              if (state is SuppliersError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is SuppliersLoaded) {
                final filtered = _search.isEmpty ? state.suppliers
                    : state.suppliers.where((s) => s.name.toLowerCase().contains(_search) || s.code.toLowerCase().contains(_search)).toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.factory_outlined, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('Aucun fournisseur trouve', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () => _showDialog(context, s),
                          hoverColor: const Color(0xFF7C3AED).withValues(alpha: 0.02),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                                    ]
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Info
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.tag_rounded, size: 14, color: AppColors.textTertiary),
                                          const SizedBox(width: 4),
                                          Text(s.code, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                          if (s.email != null && s.email!.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.email_outlined, size: 14, color: AppColors.textTertiary),
                                            const SizedBox(width: 4),
                                            Text(s.email!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          ],
                                          if (s.phone != null && s.phone!.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.textTertiary),
                                            const SizedBox(width: 4),
                                            Text(s.phone!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Solde
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Dette', style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: s.balance > 0 ? AppColors.errorLight : AppColors.successLight.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          formatCurrency(s.balance),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: s.balance > 0 ? AppColors.error : AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Actions
                                const SizedBox(width: 16),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 4,
                                  onSelected: (val) {
                                    if (val == 'edit') _showDialog(context, s);
                                    if (val == 'delete') context.read<SuppliersBloc>().add(DeleteSupplier(s.id));
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Modifier')])),
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.error))])),
                                  ],
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
              return const SizedBox();
            },
          ),
        ),
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

class _SupplierDialogState extends State<_SupplierDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _cityCtrl, _taxCtrl, _rcCtrl, _notesCtrl;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
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
                    widget.existing == null ? 'Creer un Nouveau Fournisseur' : 'Modifier le Fournisseur',
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
                    label: Text(widget.existing == null ? 'Creer' : 'Enregistrer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
            // TabBar Header
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF7C3AED),
                unselectedLabelColor: AppColors.textTertiary,
                indicatorColor: const Color(0xFF7C3AED),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Informations', icon: Icon(Icons.info_outline_rounded, size: 20)),
                  Tab(text: 'Localisation', icon: Icon(Icons.location_on_outlined, size: 20)),
                  Tab(text: 'Financier & Notes', icon: Icon(Icons.account_balance_wallet_outlined, size: 20)),
                ],
              ),
            ),
            
            // TabBarView Content
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Informations Generales
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(child: AppTextField(label: 'Code *', controller: _codeCtrl, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                            const SizedBox(width: 16),
                            Expanded(child: AppTextField(label: 'Nom / Raison Sociale *', controller: _nameCtrl, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: AppTextField(label: 'Telephone', controller: _phoneCtrl, keyboardType: TextInputType.phone)),
                            const SizedBox(width: 16),
                            Expanded(child: AppTextField(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress)),
                          ]),
                        ],
                      ),
                    ),
                    
                    // TAB 2: Localisation
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(flex: 2, child: AppTextField(label: 'Adresse', controller: _addressCtrl)),
                            const SizedBox(width: 16),
                            Expanded(child: AppTextField(label: 'Ville', controller: _cityCtrl)),
                          ]),
                        ],
                      ),
                    ),
                    
                    // TAB 3: Informations Fiscales & Notes
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(child: AppTextField(label: 'NIF (Numero d\'Identification Fiscale)', controller: _taxCtrl)),
                            const SizedBox(width: 16),
                            Expanded(child: AppTextField(label: 'RC (Registre de Commerce)', controller: _rcCtrl)),
                          ]),
                          const SizedBox(height: 16),
                          AppTextField(label: 'Notes privees', controller: _notesCtrl, maxLines: 5, hint: 'Ajouter une note sur ce fournisseur...'),
                        ],
                      ),
                    ),
                  ],
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
