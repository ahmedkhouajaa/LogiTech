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
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';

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
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fournisseurs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Gérer vos fournisseurs', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 250,
                height: 32,
                child: AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
              ),
              if (PermissionService.instance.canCreate(UserPermissionResources.suppliers)) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showDialog(context, null),
                  icon: const Icon(Icons.factory_rounded, size: 18, color: Colors.white),
                  label: const Text('Nouveau Fournisseur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        
        Expanded(
          child: BlocBuilder<SuppliersBloc, SuppliersState>(
            builder: (context, state) {
              if (state is SuppliersLoading || state is SuppliersInitial) {
                return AppShimmer(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
                    itemCount: 8,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, index) => Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          ShimmerBox(width: 36, height: 36, borderRadius: 10),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                ShimmerBox(width: 150, height: 12, borderRadius: 4),
                                SizedBox(height: 6),
                                ShimmerBox(width: 100, height: 10, borderRadius: 4),
                              ],
                            ),
                          ),
                          ShimmerBox(width: 70, height: 20, borderRadius: 4),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (state is SuppliersError) return AppErrorWidget(message: state.message);
              if (state is SuppliersLoaded) {
                final filtered = _search.isEmpty ? state.suppliers
                    : state.suppliers.where((s) => s.name.toLowerCase().contains(_search) || s.code.toLowerCase().contains(_search)).toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.factory_outlined, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Aucun fournisseur trouvé', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    final isDefault = s.isDefault || s.name.trim().toLowerCase() == 'fournisseur passager';
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () {
                            if (isDefault) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Cet élément est un élément par défaut et ne peut pas être modifié.'),
                                  backgroundColor: AppColors.warning,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else {
                              _showDialog(context, s);
                            }
                          },
                          hoverColor: AppColors.primary.withValues(alpha: 0.02),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      s.supplierType == 'entreprise' ? Icons.domain_rounded : Icons.person_outline_rounded,
                                      color: AppColors.textSecondary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
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
                                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: s.supplierType == 'entreprise' ? AppColors.infoLight : Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: s.supplierType == 'entreprise' ? AppColors.info.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              s.supplierType == 'entreprise' ? 'Entreprise' : 'Particulier',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: s.supplierType == 'entreprise' ? AppColors.info : Colors.purple),
                                            ),
                                          ),
                                          if (isDefault) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.lock_rounded, size: 10, color: AppColors.primary),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'Par défaut',
                                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.tag_rounded, size: 12, color: AppColors.textTertiary),
                                          const SizedBox(width: 3),
                                          Text(s.code, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                          if (s.email != null && s.email!.isNotEmpty) ...[
                                            const SizedBox(width: 10),
                                            Icon(Icons.email_outlined, size: 12, color: AppColors.textTertiary),
                                            const SizedBox(width: 3),
                                            Text(s.email!, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                          ],
                                          if (s.phone != null && s.phone!.isNotEmpty) ...[
                                            const SizedBox(width: 10),
                                            Icon(Icons.phone_outlined, size: 12, color: AppColors.textTertiary),
                                            const SizedBox(width: 3),
                                            Text(s.phone!, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Actions
                                const SizedBox(width: 12),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textTertiary),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 4,
                                  onSelected: (val) {
                                    if (val == 'edit') _showDialog(context, s);
                                    if (val == 'delete') context.read<SuppliersBloc>().add(DeleteSupplier(s.id));
                                  },
                                  itemBuilder: (context) => [
                                    if (!isDefault) ...[
                                      if (PermissionService.instance.canUpdate(UserPermissionResources.suppliers))
                                        PopupMenuItem(value: 'edit', height: 36, child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: AppColors.primary), const SizedBox(width: 8), const Text('Modifier', style: TextStyle(fontSize: 13))])),
                                      if (PermissionService.instance.canDelete(UserPermissionResources.suppliers))
                                        PopupMenuItem(value: 'delete', height: 36, child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error), const SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.error, fontSize: 13))])),
                                    ] else ...[
                                      PopupMenuItem(
                                        enabled: false,
                                        height: 36,
                                        child: Row(
                                          children: [
                                            Icon(Icons.lock_rounded, size: 14, color: AppColors.textTertiary),
                                            const SizedBox(width: 8),
                                            Text('Élément protégé', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
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
  
  String _selectedCountryCode = '+216';
  String _selectedFlag = '🇹🇳';
  
  static const List<Map<String, String>> _countryPrefixes = [
    {'flag': '🇹🇳', 'code': '+216', 'name': 'Tunisie'},
    {'flag': '🇫🇷', 'code': '+33', 'name': 'France'},
    {'flag': '🇩🇿', 'code': '+213', 'name': 'Algérie'},
    {'flag': '🇲🇦', 'code': '+212', 'name': 'Maroc'},
    {'flag': '🇱🇾', 'code': '+218', 'name': 'Libye'},
    {'flag': '🇨🇦', 'code': '+1', 'name': 'Canada / USA'},
    {'flag': '🇩🇪', 'code': '+49', 'name': 'Allemagne'},
    {'flag': '🇮🇹', 'code': '+39', 'name': 'Italie'},
    {'flag': '🇪🇸', 'code': '+34', 'name': 'Espagne'},
    {'flag': '🇬🇧', 'code': '+44', 'name': 'Royaume-Uni'},
    {'flag': '🇧🇪', 'code': '+32', 'name': 'Belgique'},
    {'flag': '🇨🇭', 'code': '+41', 'name': 'Suisse'},
  ];

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
    
    String phoneVal = s?.phone ?? '';
    _selectedCountryCode = '+216';
    _selectedFlag = '🇹🇳';
    if (phoneVal.isNotEmpty) {
      for (final prefix in _countryPrefixes) {
        if (phoneVal.startsWith(prefix['code']!)) {
          _selectedCountryCode = prefix['code']!;
          _selectedFlag = prefix['flag']!;
          phoneVal = phoneVal.substring(prefix['code']!.length).trim();
          break;
        }
      }
    }
    _phoneCtrl = TextEditingController(text: phoneVal);
    
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile ? EdgeInsets.symmetric(horizontal: 20, vertical: 36) : EdgeInsets.symmetric(horizontal: 80, vertical: 48),
      child: Container(
        width: isMobile ? size.width : 650,
        constraints: BoxConstraints(maxHeight: size.height * 0.80),
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
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                ),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.factory_rounded, color: AppColors.primary, size: isMobile ? 20 : 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.existing == null ? 'Creer un Nouveau Fournisseur' : 'Modifier le Fournisseur',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMobile) ...[
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      tooltip: 'Fermer',
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text('Retour', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: Icon(Icons.save_rounded, size: 16, color: Colors.white),
                      label: Text(widget.existing == null ? 'Creer' : 'Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // TabBar Header
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
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
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section 1: Type d'Entreprise
                          Text(
                            "Type d'Entreprise",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          SizedBox(height: 8),
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
                              SizedBox(width: 16),
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
                          SizedBox(height: 24),

                          // Section 2: Conditional Fields (Company vs Individual)
                          if (_supplierType == 'entreprise') ...[
                            isMobile
                                ? Column(
                                    children: [
                                      AppTextField(
                                        label: 'Nom de l\'Entreprise *',
                                        hint: 'Saisissez le nom de l\'entreprise',
                                        controller: _companyNameCtrl,
                                        validator: (v) => v!.trim().isEmpty ? 'Le nom de l\'entreprise est requis' : null,
                                      ),
                                      SizedBox(height: 12),
                                      AppTextField(
                                        label: 'Nom du responsable',
                                        hint: 'Saisissez le nom du responsable',
                                        controller: _responsibleNameCtrl,
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          label: 'Nom de l\'Entreprise *',
                                          hint: 'Saisissez le nom de l\'entreprise',
                                          controller: _companyNameCtrl,
                                          validator: (v) => v!.trim().isEmpty ? 'Le nom de l\'entreprise est requis' : null,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: AppTextField(
                                          label: 'Nom du responsable',
                                          hint: 'Saisissez le nom du responsable',
                                          controller: _responsibleNameCtrl,
                                        ),
                                      ),
                                    ],
                                  ),
                            SizedBox(height: 16),
                            isMobile
                                ? Column(
                                    children: [
                                      AppTextField(
                                        label: 'Email Personnel *',
                                        hint: 'Saisissez l\'email personnel',
                                        controller: _emailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (v) => v!.trim().isEmpty ? 'L\'email personnel est requis' : null,
                                      ),
                                      SizedBox(height: 12),
                                      AppTextField(
                                        label: 'Reference',
                                        hint: 'Saisissez le code de reference',
                                        controller: _referenceCtrl,
                                      ),
                                    ],
                                  )
                                : Row(
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
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: AppTextField(
                                          label: 'Reference',
                                          hint: 'Saisissez le code de reference',
                                          controller: _referenceCtrl,
                                        ),
                                      ),
                                    ],
                                  ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Matricule Fiscal',
                                    hint: '1234567X/X/X/000',
                                    controller: _taxCtrl,
                                  ),
                                ),
                                SizedBox(width: 16),
                                const Spacer(),
                              ],
                            ),
                          ] else ...[
                            isMobile
                                ? Column(
                                    children: [
                                      AppTextField(
                                        label: 'Nom du responsable *',
                                        hint: 'Saisissez le nom du responsable',
                                        controller: _responsibleNameCtrl,
                                        validator: (v) => v!.trim().isEmpty ? 'Le nom du responsable est requis' : null,
                                      ),
                                      SizedBox(height: 12),
                                      AppTextField(
                                        label: 'Email Personnel *',
                                        hint: 'Saisissez l\'email personnel',
                                        controller: _emailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (v) => v!.trim().isEmpty ? 'L\'email personnel est requis' : null,
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          label: 'Nom du responsable *',
                                          hint: 'Saisissez le nom du responsable',
                                          controller: _responsibleNameCtrl,
                                          validator: (v) => v!.trim().isEmpty ? 'Le nom du responsable est requis' : null,
                                        ),
                                      ),
                                      SizedBox(width: 16),
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
                            SizedBox(height: 16),
                            isMobile
                                ? Column(
                                    children: [
                                      AppTextField(
                                        label: 'Reference',
                                        hint: 'Saisissez le code de reference',
                                        controller: _referenceCtrl,
                                      ),
                                      SizedBox(height: 12),
                                      AppTextField(
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
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          label: 'Reference',
                                          hint: 'Saisissez le code de reference',
                                          controller: _referenceCtrl,
                                        ),
                                      ),
                                      SizedBox(width: 16),
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
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Date de Naissance',
                                    hint: 'JJ/MM/AAAA',
                                    controller: _birthDateCtrl,
                                    readOnly: true,
                                    suffix: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                                    onTap: _selectBirthDate,
                                  ),
                                ),
                                SizedBox(width: 16),
                                const Spacer(),
                              ],
                            ),
                          ],
                          SizedBox(height: 16),

                          // Numero de Telephone (with flag & +216 prefix)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Numero de Telephone *',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  PopupMenuButton<Map<String, String>>(
                                    onSelected: (item) {
                                      setState(() {
                                        _selectedFlag = item['flag']!;
                                        _selectedCountryCode = item['code']!;
                                      });
                                    },
                                    offset: const Offset(0, 44),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                    itemBuilder: (context) => _countryPrefixes.map((item) => PopupMenuItem(
                                      value: item,
                                      child: Row(
                                        children: [
                                          Text(item['flag']!, style: const TextStyle(fontSize: 18)),
                                          const SizedBox(width: 8),
                                          Text(item['code']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(item['name']!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    )).toList(),
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_selectedFlag, style: const TextStyle(fontSize: 18)),
                                          const SizedBox(width: 6),
                                          Text(_selectedCountryCode, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                          const SizedBox(width: 4),
                                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Téléphone obligatoire' : null,
                                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'Saisissez le numero de telephone',
                                        hintStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                        filled: true,
                                        fillColor: AppColors.surfaceAlt,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: AppColors.border),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: AppColors.primary, width: 2),
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
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBillingAddressSection(),
                          SizedBox(height: 20),
                          _buildDeliveryAddressSection(),
                        ],
                      ),
                    ),
                    
                    // TAB 3: Informations Fiscales & Notes
                    SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBankAccountSection(),
                          SizedBox(height: 24),
                          isMobile
                              ? Column(
                                  children: [
                                    AppTextField(label: 'NIF (Numero d\'Identification Fiscale)', controller: _taxCtrl),
                                    SizedBox(height: 12),
                                    AppTextField(label: 'RC (Registre de Commerce)', controller: _rcCtrl),
                                  ],
                                )
                              : Row(children: [
                                  Expanded(child: AppTextField(label: 'NIF (Numero d\'Identification Fiscale)', controller: _taxCtrl)),
                                  SizedBox(width: 16),
                                  Expanded(child: AppTextField(label: 'RC (Registre de Commerce)', controller: _rcCtrl)),
                                ]),
                          SizedBox(height: 16),
                          AppTextField(label: 'Notes privees', controller: _notesCtrl, maxLines: 5, hint: 'Ajouter une note sur ce fournisseur...'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Navigation
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _tabController.index > 0
                          ? OutlinedButton.icon(
                              onPressed: () => _tabController.animateTo(_tabController.index - 1),
                              icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                              label: Text('Précédent', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.border),
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                              ),
                            )
                          : SizedBox(width: 100),
                      _tabController.index < _tabController.length - 1
                          ? ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState?.validate() ?? true) {
                                  _tabController.animateTo(_tabController.index + 1);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Suivant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                                ],
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _save,
                              icon: Icon(Icons.check_rounded, size: 16, color: Colors.white),
                              label: Text('Terminer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                elevation: 0,
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
    );
  }

  Widget _buildBillingAddressSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adresse de Facturation',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(height: 16),
          AppTextField(
            label: 'Adresse de la rue',
            hint: 'Saisissez l\'adresse de la rue',
            controller: _addressCtrl,
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Ville',
                  hint: 'Saisissez la ville',
                  controller: _cityCtrl,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Code postal',
                  hint: 'Saisissez le code postal',
                  controller: _postalCodeCtrl,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              SizedBox(height: 6),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Row(
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
        color: AppColors.surface,
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
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Adresse de Livraison',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Spacer(),
                  Icon(
                    _deliveryExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_deliveryExpanded) ...[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: EdgeInsets.all(16),
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
                      Expanded(
                        child: Text(
                          'Identique a l\'adresse de facturation',
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  AppTextField(
                    label: 'Adresse de la rue',
                    hint: 'Saisissez l\'adresse de la rue',
                    controller: _deliveryStreetCtrl,
                    readOnly: _deliverySameAsBilling,
                  ),
                  SizedBox(height: 12),
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
                      SizedBox(width: 12),
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
                  SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      SizedBox(height: 6),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
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
        color: AppColors.surface,
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
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Comptes Bancaires',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Spacer(),
                  Icon(
                    _bankExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_bankExpanded) ...[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: EdgeInsets.all(16),
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
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: isMobile ? 38 : 46,
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFEFF6FF) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (isSelected) ...[
              Spacer(),
              Icon(Icons.check_circle_rounded, color: AppColors.primary, size: isMobile ? 16 : 18),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: Locale('fr'),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.surface,
              surface: AppColors.surface,
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
      phone: _phoneCtrl.text.trim().isEmpty 
          ? null 
          : (_phoneCtrl.text.trim().startsWith('+') || _phoneCtrl.text.trim().startsWith('00')
              ? _phoneCtrl.text.trim()
              : '$_selectedCountryCode ${_phoneCtrl.text.trim()}'),
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
    Navigator.pop(context, supplier.id);
  }
}
