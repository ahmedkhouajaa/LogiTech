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
        // Page Header & KPIs
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gestion des Clients', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Gérez vos clients, leurs coordonnées et soldes.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  int totalClients = 0;
                  double totalBalance = 0;
                  int debtors = 0;

                  if (state is CustomersLoaded) {
                    totalClients = state.customers.length;
                    totalBalance = state.customers.fold(0, (sum, c) => sum + c.balance);
                    debtors = state.customers.where((c) => c.balance < 0).length;
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: DashboardCard(
                          title: 'Total Clients',
                          value: totalClients.toString(),
                          icon: Icons.people_alt_rounded,
                          gradientColors: const [Color(0xFF1a56db), Color(0xFF3B82F6)],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: DashboardCard(
                          title: 'Solde Total',
                          value: formatCurrency(totalBalance),
                          icon: Icons.account_balance_wallet_rounded,
                          gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: DashboardCard(
                          title: 'Clients Débiteurs',
                          value: debtors.toString(),
                          icon: Icons.warning_amber_rounded,
                          gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                        ),
                      ),
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
              AppButton(
                label: 'Nouveau client',
                icon: Icons.add_rounded,
                onPressed: () => _showDialog(context, null),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              if (state is CustomersLoading) return const Center(child: CircularProgressIndicator());
              if (state is CustomersError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is CustomersLoaded) {
                final filtered = _search.isEmpty
                    ? state.customers
                    : state.customers.where((c) => c.name.toLowerCase().contains(_search) || c.code.toLowerCase().contains(_search) || (c.phone ?? '').contains(_search)).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Customer>(
                      columns: const ['Code', 'Client', 'Téléphone', 'Email', 'Ville', 'Solde'],
                      rows: filtered,
                      emptyMessage: 'Aucun client trouvé',
                      cellBuilder: (c) => [
                        DataCell(Text(c.code, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        )),
                        DataCell(Text(c.phone ?? '—')),
                        DataCell(Text(c.email ?? '—')),
                        DataCell(Text(c.city ?? '—')),
                        DataCell(Text(formatCurrency(c.balance), style: TextStyle(color: c.balance < 0 ? AppColors.error : AppColors.textPrimary, fontWeight: FontWeight.w600))),
                      ],
                      onEdit: (c) => _showDialog(context, c),
                      onDelete: (c) => context.read<CustomersBloc>().add(DeleteCustomer(c.id)),
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

  void _showDialog(BuildContext context, Customer? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomersBloc>(),
        child: _CustomerDialog(existing: existing),
      ),
    );
  }
}

class _CustomerDialog extends StatefulWidget {
  final Customer? existing;
  const _CustomerDialog({this.existing});
  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _customerType;
  late bool _deliverySameAsBilling;
  late bool _tvaSuspension;
  late String _selectedPriceList;
  List<String> _priceLists = ['Prix par défaut'];
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

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _customerType = c?.customerType ?? 'entreprise';
    _deliverySameAsBilling = c?.deliverySameAsBilling ?? true;
    _tvaSuspension = c?.tvaSuspension ?? false;
    _selectedPriceList = 'Prix par défaut';

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
                    widget.existing == null ? 'Créer un Nouveau Client' : 'Modifier le Client',
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
                          const SnackBar(content: Text('Scanner avec l\'IA bientôt disponible !')),
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
                  // Créer / Enregistrer Button
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                    label: Text(widget.existing == null ? 'Créer' : 'Enregistrer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
            
            // Scrollable Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
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
                                label: 'Référence',
                                hint: 'Saisissez le code de référence',
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
                                label: 'Référence',
                                hint: 'Saisissez le code de référence',
                                controller: _referenceCtrl,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppTextField(
                                label: 'Numéro CIN',
                                hint: 'Saisissez le numéro CIN (8 chiffres)',
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

                      // Numéro de Téléphone (with flag & +216 prefix)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Numéro de Téléphone',
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
                                    hintText: 'Saisissez le numéro de téléphone',
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
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 24),

                      // Section 3: Shared Fields (Billing Address)
                      _buildBillingAddressSection(),
                      const SizedBox(height: 20),

                      // Delivery Address Section (Collapsible)
                      _buildDeliveryAddressSection(),
                      const SizedBox(height: 20),

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
                              'Ce client possède un permis de suspension de TVA',
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
                            'Choisissez une liste de prix par défaut pour ce client',
                            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Private Note (3-4 lines height)
                      AppTextField(
                        label: 'Note privée',
                        hint: 'Saisissez une note privée concernant ce client',
                        controller: _privateNoteCtrl,
                        maxLines: 4,
                      ),
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
                          'Identique à l\'adresse de facturation',
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
                label: 'Numéro de compte / IBAN',
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
                  'Créer une liste de prix personnalisée',
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
                  'Définir les tarifs des articles :',
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
    if (_selectedPriceList != 'Prix par défaut') {
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
