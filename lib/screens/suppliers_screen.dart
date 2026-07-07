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
                  backgroundColor: AppColors.primary,
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
                          hoverColor: AppColors.primary.withValues(alpha: 0.02),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      s.supplierType == 'entreprise' ? Icons.domain_rounded : Icons.person_outline_rounded,
                                      color: AppColors.textSecondary,
                                      size: 24,
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
                                      Row(
                                        children: [
                                          Text(
                                            s.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: s.supplierType == 'entreprise' ? AppColors.infoLight : Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: s.supplierType == 'entreprise' ? AppColors.info.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              s.supplierType == 'entreprise' ? 'Entreprise' : 'Particulier',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: s.supplierType == 'entreprise' ? AppColors.info : Colors.purple),
                                            ),
                                          ),
                                        ],
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
      child: SupplierDialog(existing: existing),
    ));
  }
}

class SupplierDialog extends StatefulWidget {
  final Supplier? existing;
  const SupplierDialog({this.existing});
  @override
  State<SupplierDialog> createState() => SupplierDialogState();
}

class SupplierDialogState extends State<SupplierDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late String _supplierType;
  late bool _deliverySameAsBilling;
  bool _deliveryExpanded = true;
  bool _bankExpanded = false;

  late final TextEditingController _codeCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _cityCtrl, _postalCodeCtrl, _deliveryStreetCtrl, _deliveryCityCtrl, _deliveryPostalCodeCtrl, _taxCtrl, _rcCtrl, _notesCtrl, _bankAccountCtrl;
  late final TextEditingController _companyNameCtrl, _responsibleNameCtrl, _cinCtrl, _birthDateCtrl, _referenceCtrl;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final s = widget.existing;
    _supplierType = s?.supplierType ?? 'entreprise';
    _deliverySameAsBilling = s?.deliverySameAsBilling ?? true;

    _codeCtrl = TextEditingController(text: s?.code ?? 'FOU-${DateTime.now().millisecondsSinceEpoch % 10000}');
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    
    _companyNameCtrl = TextEditingController(text: s?.companyName ?? '');
    _responsibleNameCtrl = TextEditingController(text: s?.responsibleName ?? (s?.supplierType == 'particulier' ? s?.name : '') ?? '');
    _cinCtrl = TextEditingController(text: s?.cinNumber ?? '');
    _birthDateCtrl = TextEditingController(text: s?.birthDate ?? '');
    _referenceCtrl = TextEditingController(text: s?.referenceCode ?? '');
    
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _cityCtrl = TextEditingController(text: s?.city ?? '');
    _postalCodeCtrl = TextEditingController(text: s?.postalCode ?? '');

    _deliveryStreetCtrl = TextEditingController(text: s?.deliveryStreet ?? '');
    _deliveryCityCtrl = TextEditingController(text: s?.deliveryCity ?? '');
    _deliveryPostalCodeCtrl = TextEditingController(text: s?.deliveryPostalCode ?? '');

    _taxCtrl = TextEditingController(text: s?.taxId ?? '');
    _rcCtrl = TextEditingController(text: s?.rc ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _bankAccountCtrl = TextEditingController(text: s?.bankAccount ?? '');

    _addressCtrl.addListener(_syncDeliveryAddress);
    _cityCtrl.addListener(_syncDeliveryAddress);
    _postalCodeCtrl.addListener(_syncDeliveryAddress);
  }

  void _syncDeliveryAddress() {
    if (_deliverySameAsBilling) {
      setState(() {
        _deliveryStreetCtrl.text = _addressCtrl.text;
        _deliveryCityCtrl.text = _cityCtrl.text;
        _deliveryPostalCodeCtrl.text = _postalCodeCtrl.text;
      });
    }
  }

  @override
  void dispose() {
    _addressCtrl.removeListener(_syncDeliveryAddress);
    _cityCtrl.removeListener(_syncDeliveryAddress);
    _postalCodeCtrl.removeListener(_syncDeliveryAddress);

    for (var c in [
      _codeCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, 
      _addressCtrl, _cityCtrl, _postalCodeCtrl,
      _deliveryStreetCtrl, _deliveryCityCtrl, _deliveryPostalCodeCtrl,
      _taxCtrl, _rcCtrl, _notesCtrl, _bankAccountCtrl,
      _companyNameCtrl, _responsibleNameCtrl, _cinCtrl, _birthDateCtrl, _referenceCtrl
    ]) { c.dispose(); }
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
                  const Icon(Icons.factory_rounded, color: AppColors.primary),
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
                      backgroundColor: AppColors.primary,
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
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Informations', icon: Icon(Icons.info_outline_rounded, size: 20)),
                  Tab(text: 'Adresses', icon: Icon(Icons.location_on_outlined, size: 20)),
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
                          // Section 1: Type d'Entreprise
                          const Text(
                            "Type d'Entreprise",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTypeButton(
                                  label: 'Entreprise',
                                  value: 'entreprise',
                                  isSelected: _supplierType == 'entreprise',
                                  onTap: () => setState(() => _supplierType = 'entreprise'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTypeButton(
                                  label: 'Particulier',
                                  value: 'particulier',
                                  isSelected: _supplierType == 'particulier',
                                  onTap: () => setState(() => _supplierType = 'particulier'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Section 2: Conditional Fields (Company vs Individual)
                          if (_supplierType == 'entreprise') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Nom de l\'Entreprise *',
                                    hint: 'Saisissez le nom de l\'entreprise',
                                    controller: _companyNameCtrl,
                                    validator: (v) => v!.trim().isEmpty ? 'Le nom de l\'entreprise est requis' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Nom du responsable',
                                    hint: 'Saisissez le nom du responsable',
                                    controller: _responsibleNameCtrl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Email Personnel *',
                                    hint: 'Saisissez l\'email personnel',
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) => v!.trim().isEmpty ? 'L\'email personnel est requis' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Reference',
                                    hint: 'Saisissez le code de reference',
                                    controller: _referenceCtrl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Matricule Fiscal',
                                    hint: '1234567X/X/X/000',
                                    controller: _taxCtrl,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Spacer(),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Nom du responsable *',
                                    hint: 'Saisissez le nom du responsable',
                                    controller: _responsibleNameCtrl,
                                    validator: (v) => v!.trim().isEmpty ? 'Le nom du responsable est requis' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Email Personnel *',
                                    hint: 'Saisissez l\'email personnel',
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) => v!.trim().isEmpty ? 'L\'email personnel est requis' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Reference',
                                    hint: 'Saisissez le code de reference',
                                    controller: _referenceCtrl,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: AppTextField(
                                    label: 'Numero CIN',
                                    hint: 'Saisissez le numero CIN (8 chiffres)',
                                    controller: _cinCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v!.trim().isNotEmpty && v.trim().length != 8) {
                                        return 'Le CIN doit contenir exactement 8 chiffres';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Date de Naissance',
                                    hint: 'JJ/MM/AAAA',
                                    controller: _birthDateCtrl,
                                    readOnly: true,
                                    suffix: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                                    onTap: _selectBirthDate,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Spacer(),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Numero de Telephone (with flag & +216 prefix)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Numero de Telephone',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: const Row(
                                      children: [
                                        Text('🇹🇳', style: TextStyle(fontSize: 18)),
                                        SizedBox(width: 6),
                                        Text('+216', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                        SizedBox(width: 4),
                                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'Saisissez le numero de telephone',
                                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                        filled: true,
                                        fillColor: AppColors.surfaceAlt,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: const BorderSide(color: AppColors.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: const BorderSide(color: AppColors.border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // TAB 2: Adresses
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBillingAddressSection(),
                          const SizedBox(height: 20),
                          _buildDeliveryAddressSection(),
                        ],
                      ),
                    ),
                    
                    // TAB 3: Informations Fiscales & Notes
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBankAccountSection(),
                          const SizedBox(height: 24),
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

  Widget _buildBillingAddressSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adresse de Facturation',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Adresse de la rue',
            hint: 'Saisissez l\'adresse de la rue',
            controller: _addressCtrl,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Ville',
                  hint: 'Saisissez la ville',
                  controller: _cityCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Code postal',
                  hint: 'Saisissez le code postal',
                  controller: _postalCodeCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: const Row(
                  children: [
                    Text('🇹🇳', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('Tunisia', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    Spacer(),
                    Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _deliveryExpanded = !_deliveryExpanded),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.md),
              topRight: const Radius.circular(AppRadius.md),
              bottomLeft: Radius.circular(_deliveryExpanded ? 0 : AppRadius.md),
              bottomRight: Radius.circular(_deliveryExpanded ? 0 : AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Adresse de Livraison',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Icon(
                    _deliveryExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_deliveryExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _deliverySameAsBilling,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (v) {
                          setState(() {
                            _deliverySameAsBilling = v ?? false;
                            if (_deliverySameAsBilling) {
                              _deliveryStreetCtrl.text = _addressCtrl.text;
                              _deliveryCityCtrl.text = _cityCtrl.text;
                              _deliveryPostalCodeCtrl.text = _postalCodeCtrl.text;
                            }
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Identique a l\'adresse de facturation',
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Adresse de la rue',
                    hint: 'Saisissez l\'adresse de la rue',
                    controller: _deliveryStreetCtrl,
                    readOnly: _deliverySameAsBilling,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Ville',
                          hint: 'Saisissez la ville',
                          controller: _deliveryCityCtrl,
                          readOnly: _deliverySameAsBilling,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          label: 'Code postal',
                          hint: 'Saisissez le code postal',
                          controller: _deliveryPostalCodeCtrl,
                          readOnly: _deliverySameAsBilling,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: const Row(
                          children: [
                            Text('🇹🇳', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Text('Tunisia', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankAccountSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _bankExpanded = !_bankExpanded),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.md),
              topRight: const Radius.circular(AppRadius.md),
              bottomLeft: Radius.circular(_bankExpanded ? 0 : AppRadius.md),
              bottomRight: Radius.circular(_bankExpanded ? 0 : AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Comptes Bancaires',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Icon(
                    _bankExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_bankExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppTextField(
                label: 'Numero de compte / IBAN',
                hint: 'Saisissez le compte bancaire',
                controller: _bankAccountCtrl,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('fr'),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year;
      setState(() {
        _birthDateCtrl.text = '$day/$month/$year';
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    final String clientName = _supplierType == 'entreprise'
        ? _companyNameCtrl.text.trim()
        : _responsibleNameCtrl.text.trim();

    final supplier = Supplier(
      id: widget.existing?.id ?? const Uuid().v4(),
      code: _codeCtrl.text.trim(),
      name: clientName,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      postalCode: _postalCodeCtrl.text.trim().isEmpty ? null : _postalCodeCtrl.text.trim(),
      country: 'Tunisia',
      deliveryStreet: _deliveryStreetCtrl.text.trim().isEmpty ? null : _deliveryStreetCtrl.text.trim(),
      deliveryCity: _deliveryCityCtrl.text.trim().isEmpty ? null : _deliveryCityCtrl.text.trim(),
      deliveryPostalCode: _deliveryPostalCodeCtrl.text.trim().isEmpty ? null : _deliveryPostalCodeCtrl.text.trim(),
      deliveryCountry: 'Tunisia',
      deliverySameAsBilling: _deliverySameAsBilling,
      bankAccount: _bankAccountCtrl.text.trim().isEmpty ? null : _bankAccountCtrl.text.trim(),
      taxId: _supplierType == 'entreprise' ? (_taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim()) : null,
      rc: _rcCtrl.text.trim().isEmpty ? null : _rcCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      updatedAt: DateTime.now(),
      
      supplierType: _supplierType,
      companyName: _supplierType == 'entreprise' ? _companyNameCtrl.text.trim() : null,
      responsibleName: _responsibleNameCtrl.text.trim().isEmpty ? null : _responsibleNameCtrl.text.trim(),
      cinNumber: _supplierType == 'particulier' ? (_cinCtrl.text.trim().isEmpty ? null : _cinCtrl.text.trim()) : null,
      birthDate: _supplierType == 'particulier' ? (_birthDateCtrl.text.trim().isEmpty ? null : _birthDateCtrl.text.trim()) : null,
      referenceCode: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
    );
    if (widget.existing == null) {
      context.read<SuppliersBloc>().add(AddSupplier(supplier));
    } else {
      context.read<SuppliersBloc>().add(UpdateSupplier(supplier));
    }
    Navigator.pop(context);
  }
}
