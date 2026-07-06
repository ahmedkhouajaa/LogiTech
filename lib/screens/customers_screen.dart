import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/customers/customers_bloc.dart';
import '../models/customer.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
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
              const Text('Clients', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              SizedBox(
                width: 300,
                child: AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => _showDialog(context, null),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: Colors.white),
                label: const Text('Nouveau Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
          child: BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              if (state is CustomersLoading) return const Center(child: CircularProgressIndicator());
              if (state is CustomersError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is CustomersLoaded) {
                final filtered = _search.isEmpty
                    ? state.customers
                    : state.customers.where((c) => c.name.toLowerCase().contains(_search) || c.code.toLowerCase().contains(_search) || (c.phone ?? '').contains(_search)).toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('Aucun client trouve', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final isEntreprise = c.customerType == 'entreprise';
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
                          onTap: () => _showDialog(context, c),
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
                                    gradient: isEntreprise 
                                      ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)])
                                      : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(color: (isEntreprise ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                                    ]
                                  ),
                                  child: Center(
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
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
                                      Row(
                                        children: [
                                          Text(
                                            c.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isEntreprise ? AppColors.infoLight : Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isEntreprise ? AppColors.info.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              isEntreprise ? 'Entreprise' : 'Particulier',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isEntreprise ? AppColors.info : Colors.purple),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.tag_rounded, size: 14, color: AppColors.textTertiary),
                                          const SizedBox(width: 4),
                                          Text(c.code, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                          if (c.email != null && c.email!.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.email_outlined, size: 14, color: AppColors.textTertiary),
                                            const SizedBox(width: 4),
                                            Text(c.email!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          ],
                                          if (c.phone != null && c.phone!.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.textTertiary),
                                            const SizedBox(width: 4),
                                            Text(c.phone!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                                      const Text('Solde Actuel', style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: c.balance < 0 ? AppColors.errorLight : AppColors.successLight.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          formatCurrency(c.balance),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: c.balance < 0 ? AppColors.error : AppColors.success,
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
                                    if (val == 'edit') _showDialog(context, c);
                                    if (val == 'delete') context.read<CustomersBloc>().add(DeleteCustomer(c.id));
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

  void _showDialog(BuildContext context, Customer? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomersBloc>(),
        child: CustomerDialog(existing: existing),
      ),
    );
  }
}

class CustomerDialog extends StatefulWidget {
  final Customer? existing;
  const CustomerDialog({this.existing});
  @override
  State<CustomerDialog> createState() => CustomerDialogState();
}

class CustomerDialogState extends State<CustomerDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late String _customerType;
  late bool _deliverySameAsBilling;
  late bool _tvaSuspension;
  late String _selectedPriceList;
  List<String> _priceLists = ['Prix par defaut'];
  Map<String, Map<String, double>> _customPriceLists = {}; // priceListName -> {productId -> customPrice}

  late final TextEditingController _codeCtrl;
  late final TextEditingController _companyNameCtrl;
  late final TextEditingController _responsibleNameCtrl;
  late final TextEditingController _cinCtrl;
  late final TextEditingController _birthDateCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _taxCtrl;
  
  // Billing Address
  late final TextEditingController _billingStreetCtrl;
  late final TextEditingController _billingCityCtrl;
  late final TextEditingController _billingPostalCodeCtrl;
  
  // Delivery Address
  late final TextEditingController _deliveryStreetCtrl;
  late final TextEditingController _deliveryCityCtrl;
  late final TextEditingController _deliveryPostalCodeCtrl;

  // Collapsible sections state
  bool _deliveryExpanded = true;
  bool _bankExpanded = false;

  late final TextEditingController _bankAccountCtrl;
  late final TextEditingController _privateNoteCtrl;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final c = widget.existing;
    _customerType = c?.customerType ?? 'entreprise';
    _deliverySameAsBilling = c?.deliverySameAsBilling ?? true;
    _tvaSuspension = c?.tvaSuspension ?? false;
    _selectedPriceList = 'Prix par defaut';

    _codeCtrl = TextEditingController(text: c?.code ?? 'CLI-${DateTime.now().millisecondsSinceEpoch % 10000}');
    _companyNameCtrl = TextEditingController(text: c?.companyName ?? '');
    _responsibleNameCtrl = TextEditingController(text: c?.responsibleName ?? (c?.customerType == 'particulier' ? c?.name : '') ?? '');
    _cinCtrl = TextEditingController(text: c?.cinNumber ?? '');
    _birthDateCtrl = TextEditingController(text: c?.birthDate ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _referenceCtrl = TextEditingController(text: c?.referenceCode ?? '');
    _taxCtrl = TextEditingController(text: c?.taxId ?? '');

    _billingStreetCtrl = TextEditingController(text: c?.streetAddress ?? c?.address ?? '');
    _billingCityCtrl = TextEditingController(text: c?.city ?? '');
    _billingPostalCodeCtrl = TextEditingController(text: c?.postalCode ?? '');

    _deliveryStreetCtrl = TextEditingController(text: c?.deliveryStreet ?? '');
    _deliveryCityCtrl = TextEditingController(text: c?.deliveryCity ?? '');
    _deliveryPostalCodeCtrl = TextEditingController(text: c?.deliveryPostalCode ?? '');

    _bankAccountCtrl = TextEditingController(text: c?.bankAccount ?? '');
    _privateNoteCtrl = TextEditingController(text: c?.privateNote ?? c?.notes ?? '');

    // Restore price list if custom
    if (c?.priceList != null && c!.priceList.isNotEmpty && c.priceList != 'default') {
      try {
        final decoded = jsonDecode(c.priceList);
        if (decoded is Map && decoded.containsKey('name')) {
          final name = decoded['name'] as String;
          _selectedPriceList = name;
          if (!_priceLists.contains(name)) {
            _priceLists.add(name);
          }
          final pricesMap = decoded['prices'] as Map?;
          if (pricesMap != null) {
            final Map<String, double> prodPrices = {};
            pricesMap.forEach((k, v) {
              prodPrices[k.toString()] = (v as num).toDouble();
            });
            _customPriceLists[name] = prodPrices;
          }
        }
      } catch (_) {
        // Fallback if it is just a string name
        _selectedPriceList = c.priceList;
        if (!_priceLists.contains(c.priceList)) {
          _priceLists.add(c.priceList);
        }
      }
    }

    // Set listeners for billing address to sync with delivery if checked
    _billingStreetCtrl.addListener(_syncDeliveryAddress);
    _billingCityCtrl.addListener(_syncDeliveryAddress);
    _billingPostalCodeCtrl.addListener(_syncDeliveryAddress);
  }

  void _syncDeliveryAddress() {
    if (_deliverySameAsBilling) {
      setState(() {
        _deliveryStreetCtrl.text = _billingStreetCtrl.text;
        _deliveryCityCtrl.text = _billingCityCtrl.text;
        _deliveryPostalCodeCtrl.text = _billingPostalCodeCtrl.text;
      });
    }
  }

  @override
  void dispose() {
    _billingStreetCtrl.removeListener(_syncDeliveryAddress);
    _billingCityCtrl.removeListener(_syncDeliveryAddress);
    _billingPostalCodeCtrl.removeListener(_syncDeliveryAddress);

    for (var c in [
      _codeCtrl, _companyNameCtrl, _responsibleNameCtrl, _cinCtrl, _birthDateCtrl,
      _phoneCtrl, _emailCtrl, _referenceCtrl, _taxCtrl, _billingStreetCtrl, _billingCityCtrl,
      _billingPostalCodeCtrl, _deliveryStreetCtrl, _deliveryCityCtrl, _deliveryPostalCodeCtrl,
      _bankAccountCtrl, _privateNoteCtrl
    ]) {
      c.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1000,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Redesigned Header to match screenshot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                ),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(
                    widget.existing == null ? 'Creer un Nouveau Client' : 'Modifier le Client',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // AI Scan Button (BETA)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Scanner avec l\'IA bientot disponible !')),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.purple),
                      label: Row(
                        children: [
                          const Text(
                            'Scanner avec l\'IA',
                            style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BETA',
                              style: TextStyle(color: Colors.purple, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.purple, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  // Retour Button
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
                  // Creer / Enregistrer Button
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
                  Tab(text: 'Financier', icon: Icon(Icons.account_balance_wallet_outlined, size: 20)),
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
                    // TAB 1: Informations
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
                                  isSelected: _customerType == 'entreprise',
                                  onTap: () => setState(() => _customerType = 'entreprise'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTypeButton(
                                  label: 'Particulier',
                                  value: 'particulier',
                                  isSelected: _customerType == 'particulier',
                                  onTap: () => setState(() => _customerType = 'particulier'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Section 2: Conditional Fields (Company vs Individual)
                          if (_customerType == 'entreprise') ...[
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
                                  // Country dropdown styled simulator
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
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section 3: Shared Fields (Billing Address)
                          _buildBillingAddressSection(),
                          const SizedBox(height: 20),

                          // Delivery Address Section (Collapsible)
                          _buildDeliveryAddressSection(),
                        ],
                      ),
                    ),
                    
                    // TAB 3: Financier
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Bank Accounts Section (Collapsible)
                          _buildBankAccountSection(),
                          const SizedBox(height: 24),

                          // TVA suspension checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: _tvaSuspension,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (v) => setState(() => _tvaSuspension = v ?? false),
                              ),
                              const Expanded(
                                child: Text(
                                  'Ce client possede un permis de suspension de TVA',
                                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Price List Dropdown + Create Price List
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Liste de Prix',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedPriceList,
                                          isExpanded: true,
                                          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                          items: _priceLists.map((name) => DropdownMenuItem(
                                            value: name,
                                            child: Text(name),
                                          )).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _selectedPriceList = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // "+" Button
                                  SizedBox(
                                    height: 44,
                                    width: 44,
                                    child: ElevatedButton(
                                      onPressed: _showAddPriceListDialog,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.surfaceAlt,
                                        foregroundColor: AppColors.textPrimary,
                                        elevation: 0,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          side: const BorderSide(color: AppColors.border),
                                        ),
                                      ),
                                      child: const Icon(Icons.add_rounded, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Choisissez une liste de prix par defaut pour ce client',
                                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Private Note (3-4 lines height)
                          AppTextField(
                            label: 'Note privee',
                            hint: 'Saisissez une note privee concernant ce client',
                            controller: _privateNoteCtrl,
                            maxLines: 4,
                          ),
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

  // Helper widget for Type buttons
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

  // Billing Address Section widget
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
            controller: _billingStreetCtrl,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Ville',
                  hint: 'Saisissez la ville',
                  controller: _billingCityCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Code postal',
                  hint: 'Saisissez le code postal',
                  controller: _billingPostalCodeCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Country: Fixed Tunisia dropdown layout simulation
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

  // Delivery Address Section (Collapsible)
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
          // Collapsible Header
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
                  // Checkbox: Same as Billing
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
                              _deliveryStreetCtrl.text = _billingStreetCtrl.text;
                              _deliveryCityCtrl.text = _billingCityCtrl.text;
                              _deliveryPostalCodeCtrl.text = _billingPostalCodeCtrl.text;
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

  // Bank Accounts Section (Collapsible)
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
          // Header
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

  // Date Picker with French formatting
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

  // Dialog to Add a custom price list
  void _showAddPriceListDialog() async {
    final products = await DatabaseHelper.instance.getProducts();
    if (!mounted) return;
    
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord ajouter des produits dans l\'application !')),
      );
      return;
    }

    final nameController = TextEditingController();
    final Map<String, TextEditingController> priceControllers = {};
    for (var prod in products) {
      priceControllers[prod.id] = TextEditingController(text: prod.sellingPrice.toString());
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Creer une liste de prix personnalisee',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Nom de la liste de prix *',
                  hint: 'Ex: Prix Grossiste',
                  controller: nameController,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Definir les tarifs des articles :',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: products.map((prod) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  prod.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: priceControllers[prod.id],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      filled: true,
                                      fillColor: AppColors.surfaceAlt,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                        borderSide: BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final listName = nameController.text.trim();
                        if (listName.isEmpty) return;

                        final Map<String, double> prices = {};
                        priceControllers.forEach((k, v) {
                          prices[k] = double.tryParse(v.text.trim()) ?? 0.0;
                        });

                        setState(() {
                          if (!_priceLists.contains(listName)) {
                            _priceLists.add(listName);
                          }
                          _customPriceLists[listName] = prices;
                          _selectedPriceList = listName;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: const Text('Valider'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Serialize custom price list to JSON string if it's not default
    String priceListVal = 'default';
    if (_selectedPriceList != 'Prix par defaut') {
      final customPrices = _customPriceLists[_selectedPriceList] ?? {};
      priceListVal = jsonEncode({
        'name': _selectedPriceList,
        'prices': customPrices,
      });
    }

    final String clientName = _customerType == 'entreprise'
        ? _companyNameCtrl.text.trim()
        : _responsibleNameCtrl.text.trim();

    final customer = Customer(
      id: widget.existing?.id ?? const Uuid().v4(),
      code: _codeCtrl.text.trim(),
      name: clientName,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _billingStreetCtrl.text.trim().isEmpty ? null : _billingStreetCtrl.text.trim(),
      city: _billingCityCtrl.text.trim().isEmpty ? null : _billingCityCtrl.text.trim(),
      taxId: _customerType == 'entreprise' ? (_taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim()) : null,
      rc: widget.existing?.rc, // keep existing rc if any
      notes: _privateNoteCtrl.text.trim().isEmpty ? null : _privateNoteCtrl.text.trim(),
      updatedAt: DateTime.now(),

      // New columns values
      customerType: _customerType,
      companyName: _customerType == 'entreprise' ? _companyNameCtrl.text.trim() : null,
      responsibleName: _responsibleNameCtrl.text.trim().isEmpty ? null : _responsibleNameCtrl.text.trim(),
      cinNumber: _customerType == 'particulier' ? (_cinCtrl.text.trim().isEmpty ? null : _cinCtrl.text.trim()) : null,
      birthDate: _customerType == 'particulier' ? (_birthDateCtrl.text.trim().isEmpty ? null : _birthDateCtrl.text.trim()) : null,
      referenceCode: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
      streetAddress: _billingStreetCtrl.text.trim().isEmpty ? null : _billingStreetCtrl.text.trim(),
      postalCode: _billingPostalCodeCtrl.text.trim().isEmpty ? null : _billingPostalCodeCtrl.text.trim(),
      country: 'Tunisia',
      deliveryStreet: _deliveryStreetCtrl.text.trim().isEmpty ? null : _deliveryStreetCtrl.text.trim(),
      deliveryCity: _deliveryCityCtrl.text.trim().isEmpty ? null : _deliveryCityCtrl.text.trim(),
      deliveryPostalCode: _deliveryPostalCodeCtrl.text.trim().isEmpty ? null : _deliveryPostalCodeCtrl.text.trim(),
      deliveryCountry: 'Tunisia',
      deliverySameAsBilling: _deliverySameAsBilling,
      bankAccount: _bankAccountCtrl.text.trim().isEmpty ? null : _bankAccountCtrl.text.trim(),
      tvaSuspension: _tvaSuspension,
      priceList: priceListVal,
      privateNote: _privateNoteCtrl.text.trim().isEmpty ? null : _privateNoteCtrl.text.trim(),
    );

    if (widget.existing == null) {
      context.read<CustomersBloc>().add(AddCustomer(customer));
    } else {
      context.read<CustomersBloc>().add(UpdateCustomer(customer));
    }
    Navigator.pop(context);
  }
}
