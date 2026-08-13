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
import '../services/enterprise_service.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../widgets/shimmer_effect.dart';
import '../widgets/shimmer_table_row.dart';

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
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(bottom: BorderSide(color: Colors.transparent)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clients', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Gerer vos clients', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
              ),
              SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => _showDialog(context, null),
                icon: Icon(Icons.person_add_alt_1_rounded, size: 20, color: Colors.white),
                label: Text('Nouveau Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
              if (state is CustomersLoading || state is CustomersInitial) {
                return AppShimmer(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    itemCount: 6,
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (_, index) => Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ShimmerBox(width: 44, height: 44, borderRadius: 14),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                ShimmerBox(width: 150, height: 14, borderRadius: 4),
                                SizedBox(height: 8),
                                ShimmerBox(width: 100, height: 11, borderRadius: 4),
                              ],
                            ),
                          ),
                          ShimmerBox(width: 80, height: 24, borderRadius: 6),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (state is CustomersError) return AppErrorWidget(message: state.message);
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
                        SizedBox(height: 16),
                        Text('Aucun client trouve', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final isEntreprise = c.customerType == 'entreprise';
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: Offset(0, 4)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: Offset(0, 2)),
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
                            padding: EdgeInsets.all(20),
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
                                      isEntreprise ? Icons.domain_rounded : Icons.person_outline_rounded,
                                      color: AppColors.textSecondary,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                
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
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                      SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.tag_rounded, size: 14, color: AppColors.textTertiary),
                                          SizedBox(width: 4),
                                          Text(c.code, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                          if (c.email != null && c.email!.isNotEmpty) ...[
                                            SizedBox(width: 12),
                                            Icon(Icons.email_outlined, size: 14, color: AppColors.textTertiary),
                                            SizedBox(width: 4),
                                            Text(c.email!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          ],
                                          if (c.phone != null && c.phone!.isNotEmpty) ...[
                                            SizedBox(width: 12),
                                            Icon(Icons.phone_outlined, size: 14, color: AppColors.textTertiary),
                                            SizedBox(width: 4),
                                            Text(c.phone!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                /*
                                // Solde
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Solde Actuel', style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                                      SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                */
                                
                                // Actions
                                SizedBox(width: 16),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: AppColors.textTertiary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 4,
                                  onSelected: (val) {
                                    if (val == 'edit') _showDialog(context, c);
                                    if (val == 'delete') context.read<CustomersBloc>().add(DeleteCustomer(c.id));
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Modifier')])),
                                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.error))])),
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
              return SizedBox();
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
  const CustomerDialog({super.key, this.existing});
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

  // Dynamic Bank Accounts & Financier
  late List<TextEditingController> _bankAccountControllers;
  late final TextEditingController _privateNoteCtrl;
  late final TextEditingController _tvaAttestationCtrl;
  late final TextEditingController _tvaStartDateCtrl;
  late final TextEditingController _tvaEndDateCtrl;

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
    final c = widget.existing;
    _customerType = c?.customerType ?? 'entreprise';
    _deliverySameAsBilling = c?.deliverySameAsBilling ?? true;
    _tvaSuspension = c?.tvaSuspension ?? false;
    _selectedPriceList = 'Prix par defaut';

    _codeCtrl = TextEditingController(text: c?.code ?? 'CL-002');
    if (c == null) {
      _loadNextCode();
    }
    _companyNameCtrl = TextEditingController(text: c?.companyName ?? '');
    _responsibleNameCtrl = TextEditingController(text: c?.responsibleName ?? (c?.customerType == 'particulier' ? c?.name : '') ?? '');
    _cinCtrl = TextEditingController(text: c?.cinNumber ?? '');
    _birthDateCtrl = TextEditingController(text: c?.birthDate ?? '');
    
    String phoneVal = c?.phone ?? '';
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
    
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _referenceCtrl = TextEditingController(text: c?.referenceCode ?? '');
    _taxCtrl = TextEditingController(text: c?.taxId ?? '');

    _billingStreetCtrl = TextEditingController(text: c?.streetAddress ?? c?.address ?? '');
    _billingCityCtrl = TextEditingController(text: c?.city ?? '');
    _billingPostalCodeCtrl = TextEditingController(text: c?.postalCode ?? '');

    _deliveryStreetCtrl = TextEditingController(text: c?.deliveryStreet ?? '');
    _deliveryCityCtrl = TextEditingController(text: c?.deliveryCity ?? '');
    _deliveryPostalCodeCtrl = TextEditingController(text: c?.deliveryPostalCode ?? '');

    // Initialize dynamic bank accounts
    if (c?.bankAccount != null && c!.bankAccount!.trim().isNotEmpty) {
      final accounts = c.bankAccount!.split(RegExp(r'[\n,]|\|'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      _bankAccountControllers = accounts.isNotEmpty
          ? accounts.map((acc) => TextEditingController(text: acc)).toList()
          : [TextEditingController()];
    } else {
      _bankAccountControllers = [TextEditingController()];
    }

    _privateNoteCtrl = TextEditingController(text: c?.privateNote ?? c?.notes ?? '');
    _tvaAttestationCtrl = TextEditingController(text: c?.tvaAttestation ?? '');
    _tvaStartDateCtrl = TextEditingController(text: c?.tvaStartDate ?? '');
    _tvaEndDateCtrl = TextEditingController(text: c?.tvaEndDate ?? '');

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
        _selectedPriceList = c.priceList;
        if (!_priceLists.contains(c.priceList)) {
          _priceLists.add(c.priceList);
        }
      }
    }

    _billingStreetCtrl.addListener(_syncDeliveryAddress);
    _billingCityCtrl.addListener(_syncDeliveryAddress);
    _billingPostalCodeCtrl.addListener(_syncDeliveryAddress);
  }

  Future<void> _loadNextCode() async {
    final nextCode = await DatabaseHelper.instance.getNextCustomerSequence();
    if (mounted && widget.existing == null) {
      _codeCtrl.text = nextCode;
    }
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
      _privateNoteCtrl, _tvaAttestationCtrl, _tvaStartDateCtrl, _tvaEndDateCtrl
    ]) {
      c.dispose();
    }
    for (var ctrl in _bankAccountControllers) {
      ctrl.dispose();
    }
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
            // Responsive Header
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
                    child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: isMobile ? 20 : 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.existing == null ? 'Créer un Nouveau Client' : 'Modifier le Client',
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
                      label: Text(widget.existing == null ? 'Créer' : 'Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
            
            // TabBar Header (Scrollable on Android to prevent overflow)
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
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: isMobile ? 12 : 13),
                tabs: const [
                  Tab(text: 'Informations', icon: Icon(Icons.info_outline_rounded, size: 18)),
                  Tab(text: 'Adresses', icon: Icon(Icons.location_on_outlined, size: 18)),
                  Tab(text: 'Financier', icon: Icon(Icons.account_balance_wallet_outlined, size: 18)),
                ],
              ),
            ),
            
            // TabBarView Content (Scrollable Layouts with Material Cards)
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInformationsTab(isMobile),
                    _buildAdressesTab(isMobile),
                    _buildFinancierTab(isMobile),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Footer
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
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
                      if (_tabController.index > 0)
                        OutlinedButton.icon(
                          onPressed: () => _tabController.animateTo(_tabController.index - 1),
                          icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                          label: Text('Précédent', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.border),
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          ),
                        )
                      else
                        SizedBox.shrink(),
                      
                      const Spacer(),

                      if (_tabController.index < _tabController.length - 1)
                        ElevatedButton(
                          onPressed: () {
                            if (_validateCurrentTab()) {
                              _tabController.animateTo(_tabController.index + 1);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 12),
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
                      else
                        ElevatedButton.icon(
                          onPressed: _save,
                          icon: Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          label: Text('Terminer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 12),
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

  // Reusable Material Card helper for distinct section hierarchy
  Widget _buildMaterialCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    bool isMobile = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  // TAB 1: Informations
  Widget _buildInformationsTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card 1: Type d'Entreprise
          _buildMaterialCard(
            title: "Type de Client",
            icon: Icons.business_rounded,
            isMobile: isMobile,
            child: Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    label: 'Entreprise',
                    value: 'entreprise',
                    isSelected: _customerType == 'entreprise',
                    onTap: () => setState(() => _customerType = 'entreprise'),
                  ),
                ),
                SizedBox(width: 12),
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
          ),
          SizedBox(height: isMobile ? 10 : 16),

          // Card 2: Informations Principales
          _buildMaterialCard(
            title: _customerType == 'entreprise' ? "Détails de l'Entreprise" : "Identité & Contact",
            icon: _customerType == 'entreprise' ? Icons.domain_rounded : Icons.person_rounded,
            isMobile: isMobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_customerType == 'entreprise') ...[
                  isMobile
                      ? Column(
                          children: [
                            AppTextField(
                              label: 'Raison Sociale / Nom de l\'Entreprise *',
                              hint: 'Ex: LogiTech SARL',
                              controller: _companyNameCtrl,
                              validator: (v) => v!.trim().isEmpty ? 'Le nom de l\'entreprise est requis' : null,
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            AppTextField(
                              label: 'Nom du responsable',
                              hint: 'Ex: Mohamed Ali',
                              controller: _responsibleNameCtrl,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'Raison Sociale / Nom de l\'Entreprise *',
                                hint: 'Ex: LogiTech SARL',
                                controller: _companyNameCtrl,
                                validator: (v) => v!.trim().isEmpty ? 'Le nom de l\'entreprise est requis' : null,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: AppTextField(
                                label: 'Nom du responsable',
                                hint: 'Ex: Mohamed Ali',
                                controller: _responsibleNameCtrl,
                              ),
                            ),
                          ],
                        ),
                ] else ...[
                  AppTextField(
                    label: 'Nom Complet *',
                    hint: 'Ex: Mohamed Ali',
                    controller: _responsibleNameCtrl,
                    validator: (v) => v!.trim().isEmpty ? 'Le nom est requis' : null,
                  ),
                ],
                SizedBox(height: isMobile ? 8 : 12),
                isMobile
                    ? Column(
                        children: [
                          AppTextField(
                            label: 'Email Personnel *',
                            hint: 'Ex: contact@client.tn',
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v!.trim().isEmpty) return 'L\'email est requis';
                              if (!v.contains('@')) return 'Email invalide';
                              return null;
                            },
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          AppTextField(
                            label: 'Code Référence',
                            hint: 'Ex: REF-2026',
                            controller: _referenceCtrl,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Email Personnel *',
                              hint: 'Ex: contact@client.tn',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v!.trim().isEmpty) return 'L\'email est requis';
                                if (!v.contains('@')) return 'Email invalide';
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: AppTextField(
                              label: 'Code Référence',
                              hint: 'Ex: REF-2026',
                              controller: _referenceCtrl,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 10 : 16),

          // Card 3: Coordonnées & Fiscalité
          _buildMaterialCard(
            title: "Coordonnées & Fiscalité",
            icon: Icons.badge_outlined,
            isMobile: isMobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_customerType == 'entreprise') ...[
                  AppTextField(
                    label: 'Matricule Fiscal',
                    hint: '1234567X/A/M/000',
                    controller: _taxCtrl,
                  ),
                ] else ...[
                  isMobile
                      ? Column(
                          children: [
                            AppTextField(
                              label: 'Numéro CIN',
                              hint: '8 chiffres (Ex: 08123456)',
                              controller: _cinCtrl,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v!.trim().isNotEmpty && v.trim().length != 8) {
                                  return 'Le CIN doit contenir exactement 8 chiffres';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            AppTextField(
                              label: 'Date de Naissance',
                              hint: 'JJ/MM/AAAA',
                              controller: _birthDateCtrl,
                              readOnly: true,
                              suffix: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                              onTap: _selectBirthDate,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'Numéro CIN',
                                hint: '8 chiffres (Ex: 08123456)',
                                controller: _cinCtrl,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v!.trim().isNotEmpty && v.trim().length != 8) {
                                    return 'Le CIN doit contenir exactly 8 chiffres';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 16),
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
                          ],
                        ),
                ],
                SizedBox(height: isMobile ? 8 : 12),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Numéro de Téléphone *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        PopupMenuButton<Map<String, String>>(
                          onSelected: (item) {
                            setState(() {
                              _selectedFlag = item['flag']!;
                              _selectedCountryCode = item['code']!;
                            });
                          },
                          offset: Offset(0, isMobile ? 40 : 48),
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
                            height: isMobile ? 40 : 48,
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
                              hintText: 'Ex: 20 123 456',
                              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 10 : 12),
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
        ],
      ),
    );
  }

  // TAB 2: Adresses
  Widget _buildAdressesTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card 1: Adresse de Facturation
          _buildMaterialCard(
            title: "Adresse de Facturation",
            icon: Icons.receipt_long_outlined,
            isMobile: isMobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Adresse de la rue',
                  hint: 'Ex: 123 Rue de la République',
                  controller: _billingStreetCtrl,
                ),
                SizedBox(height: isMobile ? 8 : 12),
                isMobile
                    ? Column(
                        children: [
                          AppTextField(
                            label: 'Ville',
                            hint: 'Ex: Tunis',
                            controller: _billingCityCtrl,
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          AppTextField(
                            label: 'Code postal',
                            hint: 'Ex: 1000',
                            controller: _billingPostalCodeCtrl,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Ville',
                              hint: 'Ex: Tunis',
                              controller: _billingCityCtrl,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: AppTextField(
                              label: 'Code postal',
                              hint: 'Ex: 1000',
                              controller: _billingPostalCodeCtrl,
                            ),
                          ),
                        ],
                      ),
                SizedBox(height: isMobile ? 8 : 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    SizedBox(height: 4),
                    Container(
                      height: isMobile ? 40 : 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Text('🇹🇳', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 10),
                          Text('Tunisie', style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 10 : 16),

          // Card 2: Adresse de Livraison
          _buildMaterialCard(
            title: "Adresse de Livraison",
            icon: Icons.local_shipping_outlined,
            isMobile: isMobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _deliverySameAsBilling ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surfaceAlt.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: _deliverySameAsBilling ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Switch(
                        value: _deliverySameAsBilling,
                        activeColor: AppColors.primary,
                        onChanged: (v) {
                          setState(() {
                            _deliverySameAsBilling = v;
                            if (_deliverySameAsBilling) {
                              _deliveryStreetCtrl.text = _billingStreetCtrl.text;
                              _deliveryCityCtrl.text = _billingCityCtrl.text;
                              _deliveryPostalCodeCtrl.text = _billingPostalCodeCtrl.text;
                            }
                          });
                        },
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Identique à l\'adresse de facturation',
                          style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_deliverySameAsBilling) ...[
                  SizedBox(height: isMobile ? 10 : 16),
                  AppTextField(
                    label: 'Adresse de la rue',
                    hint: 'Ex: 456 Avenue de la Liberté',
                    controller: _deliveryStreetCtrl,
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  isMobile
                      ? Column(
                          children: [
                            AppTextField(
                              label: 'Ville',
                              hint: 'Ex: Sfax',
                              controller: _deliveryCityCtrl,
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            AppTextField(
                              label: 'Code postal',
                              hint: 'Ex: 3000',
                              controller: _deliveryPostalCodeCtrl,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'Ville',
                                hint: 'Ex: Sfax',
                                controller: _deliveryCityCtrl,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: AppTextField(
                                label: 'Code postal',
                                hint: 'Ex: 3000',
                                controller: _deliveryPostalCodeCtrl,
                              ),
                            ),
                          ],
                        ),
                  SizedBox(height: isMobile ? 8 : 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Container(
                        height: isMobile ? 40 : 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Text('🇹🇳', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 10),
                            Text('Tunisie', style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: Financier
  Widget _buildFinancierTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card 1: Dynamic Bank Accounts
          _buildMaterialCard(
            title: "Comptes Bancaires (RIB / IBAN)",
            icon: Icons.account_balance_rounded,
            isMobile: isMobile,
            trailing: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _bankAccountControllers.add(TextEditingController());
                });
              },
              icon: Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: Text('Ajouter', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_bankAccountControllers.isEmpty) ...[
                  Text('Aucun compte bancaire renseigné.', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                ] else ...[
                  ...List.generate(_bankAccountControllers.length, (index) {
                    final ctrl = _bankAccountControllers[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == _bankAccountControllers.length - 1 ? 0 : 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: isMobile ? 40 : 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Center(
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: ctrl,
                              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Saisissez le RIB (20 chiffres) ou l\'IBAN',
                                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 10 : 12),
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
                          if (_bankAccountControllers.length > 1) ...[
                            SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  ctrl.dispose();
                                  _bankAccountControllers.removeAt(index);
                                });
                              },
                              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              tooltip: 'Supprimer ce compte',
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          SizedBox(height: isMobile ? 10 : 16),

          // Card 2: Exonération & TVA Suspension Toggle
          _buildMaterialCard(
            title: "Exonération & TVA",
            icon: Icons.gavel_rounded,
            isMobile: isMobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: _tvaSuspension ? AppColors.successLight.withValues(alpha: 0.3) : AppColors.surfaceAlt.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: _tvaSuspension ? AppColors.success.withValues(alpha: 0.4) : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _tvaSuspension ? Icons.verified_rounded : Icons.info_outline_rounded,
                        color: _tvaSuspension ? AppColors.success : AppColors.textSecondary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suspension / Exonération de TVA',
                              style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              _tvaSuspension ? 'Le client bénéficie d\'une exemption active de TVA' : 'Facturation avec taux de TVA standard',
                              style: TextStyle(fontSize: 12, color: _tvaSuspension ? AppColors.success : AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _tvaSuspension,
                        activeColor: AppColors.success,
                        onChanged: (v) => setState(() => _tvaSuspension = v),
                      ),
                    ],
                  ),
                ),
                // Animated Conditional Fields when toggled ON
                AnimatedCrossFade(
                  firstChild: SizedBox.shrink(),
                  secondChild: Padding(
                    padding: EdgeInsets.only(top: isMobile ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'N° d\'Attestation / Décision de Suspension *',
                          hint: 'Ex: 2026/DGI/12345',
                          controller: _tvaAttestationCtrl,
                          validator: (v) => _tvaSuspension && (v == null || v.trim().isEmpty)
                              ? 'Le numéro d\'attestation est requis pour la suspension'
                              : null,
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        isMobile
                            ? Column(
                                children: [
                                  AppTextField(
                                    label: 'Date de Début',
                                    hint: 'JJ/MM/AAAA',
                                    controller: _tvaStartDateCtrl,
                                    readOnly: true,
                                    suffix: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                                    onTap: () => _selectDate(_tvaStartDateCtrl),
                                  ),
                                  SizedBox(height: isMobile ? 8 : 12),
                                  AppTextField(
                                    label: 'Date d\'Expiration *',
                                    hint: 'JJ/MM/AAAA',
                                    controller: _tvaEndDateCtrl,
                                    readOnly: true,
                                    suffix: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                                    onTap: () => _selectDate(_tvaEndDateCtrl),
                                    validator: (v) => _tvaSuspension && (v == null || v.trim().isEmpty)
                                        ? 'Date d\'expiration requise'
                                        : null,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      label: 'Date de Début',
                                      hint: 'JJ/MM/AAAA',
                                      controller: _tvaStartDateCtrl,
                                      readOnly: true,
                                      suffix: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                                      onTap: () => _selectDate(_tvaStartDateCtrl),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: AppTextField(
                                      label: 'Date d\'Expiration *',
                                      hint: 'JJ/MM/AAAA',
                                      controller: _tvaEndDateCtrl,
                                      readOnly: true,
                                      suffix: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                                      onTap: () => _selectDate(_tvaEndDateCtrl),
                                      validator: (v) => _tvaSuspension && (v == null || v.trim().isEmpty)
                                          ? 'Date d\'expiration requise'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                  crossFadeState: _tvaSuspension ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 10 : 16),

          // Card 3: Tarification & Liste de Prix
          _buildMaterialCard(
            title: "Tarification & Liste de Prix",
            icon: Icons.sell_outlined,
            isMobile: isMobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sélectionnez ou créez une grille tarifaire pour ce client :',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: isMobile ? 40 : 48,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPriceList,
                            isExpanded: true,
                            style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                            items: _priceLists.map((name) => DropdownMenuItem(
                              value: name,
                              child: Row(
                                children: [
                                  Icon(Icons.discount_outlined, size: 16, color: AppColors.textTertiary),
                                  SizedBox(width: 8),
                                  Text(name),
                                ],
                              ),
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
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddPriceListDialog,
                      icon: Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: Text(isMobile ? 'Créer' : 'Nouvelle liste', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        minimumSize: Size(0, isMobile ? 40 : 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 10 : 16),

          // Card 4: Note Privée
          _buildMaterialCard(
            title: "Note Privée (Interne)",
            icon: Icons.lock_outline_rounded,
            isMobile: isMobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remarques confidentielles (invisibles sur les factures et documents).',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _privateNoteCtrl,
                  maxLines: 3,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Notes internes sur le client...',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: EdgeInsets.all(isMobile ? 10 : 14),
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
              ],
            ),
          ),
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
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16),
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
              Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  bool _validateCurrentTab() {
    if (_tabController.index == 0) {
      if (_customerType == 'entreprise' && _companyNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner la raison sociale'), backgroundColor: AppColors.error));
        return false;
      }
      if (_customerType == 'particulier' && _responsibleNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner le nom complet'), backgroundColor: AppColors.error));
        return false;
      }
      if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner un email valide'), backgroundColor: AppColors.error));
        return false;
      }
    } else if (_tabController.index == 2) {
      if (_tvaSuspension && (_tvaAttestationCtrl.text.trim().isEmpty || _tvaEndDateCtrl.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner les détails de l\'attestation de suspension TVA'), backgroundColor: AppColors.error));
        return false;
      }
    }
    return true;
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

  Future<void> _selectDate(TextEditingController ctrl) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      locale: const Locale('fr'),
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
        ctrl.text = '$day/$month/$year';
      });
    }
  }

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
        final isMobileDialog = MediaQuery.of(ctx).size.width < 600;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          insetPadding: EdgeInsets.all(isMobileDialog ? 16 : 40),
          child: Container(
            width: isMobileDialog ? MediaQuery.of(ctx).size.width : 500,
            padding: EdgeInsets.all(isMobileDialog ? 16 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Créer une liste de prix personnalisée',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                SizedBox(height: 16),
                AppTextField(
                  label: 'Nom de la liste de prix *',
                  hint: 'Ex: Prix Grossiste',
                  controller: nameController,
                ),
                SizedBox(height: 16),
                Text(
                  'Définir les tarifs des articles :',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: products.map((prod) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  prod.name,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: priceControllers[prod.id],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Annuler'),
                    ),
                    SizedBox(width: 12),
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
                      child: Text('Valider'),
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
    if (!_formKey.currentState!.validate()) {
      if (_customerType == 'entreprise' && _companyNameCtrl.text.trim().isEmpty) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner le nom de l\'entreprise (Tab Informations)'), backgroundColor: AppColors.error));
        return;
      }
      if (_customerType == 'particulier' && _responsibleNameCtrl.text.trim().isEmpty) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner le nom complet (Tab Informations)'), backgroundColor: AppColors.error));
        return;
      }
      if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner un email valide (Tab Informations)'), backgroundColor: AppColors.error));
        return;
      }
      if (_tvaSuspension && (_tvaAttestationCtrl.text.trim().isEmpty || _tvaEndDateCtrl.text.trim().isEmpty)) {
        _tabController.animateTo(2);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner les détails de l\'attestation de suspension TVA (Tab Financier)'), backgroundColor: AppColors.error));
        return;
      }
      return;
    }

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

    final bankAccountsList = _bankAccountControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final bankAccountVal = bankAccountsList.isEmpty ? null : bankAccountsList.join('\n');

    final customer = Customer(
      id: widget.existing?.id ?? const Uuid().v4(),
      code: _codeCtrl.text.trim(),
      name: clientName,
      enterpriseId: widget.existing?.enterpriseId ?? EnterpriseService.instance.currentEnterpriseId,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty 
          ? null 
          : (_phoneCtrl.text.trim().startsWith('+') || _phoneCtrl.text.trim().startsWith('00')
              ? _phoneCtrl.text.trim()
              : '$_selectedCountryCode ${_phoneCtrl.text.trim()}'),
      address: _billingStreetCtrl.text.trim().isEmpty ? null : _billingStreetCtrl.text.trim(),
      city: _billingCityCtrl.text.trim().isEmpty ? null : _billingCityCtrl.text.trim(),
      taxId: _customerType == 'entreprise' ? (_taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim()) : null,
      rc: widget.existing?.rc,
      notes: _privateNoteCtrl.text.trim().isEmpty ? null : _privateNoteCtrl.text.trim(),
      updatedAt: DateTime.now(),

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
      bankAccount: bankAccountVal,
      tvaSuspension: _tvaSuspension,
      tvaAttestation: _tvaSuspension ? (_tvaAttestationCtrl.text.trim().isEmpty ? null : _tvaAttestationCtrl.text.trim()) : null,
      tvaStartDate: _tvaSuspension ? (_tvaStartDateCtrl.text.trim().isEmpty ? null : _tvaStartDateCtrl.text.trim()) : null,
      tvaEndDate: _tvaSuspension ? (_tvaEndDateCtrl.text.trim().isEmpty ? null : _tvaEndDateCtrl.text.trim()) : null,
      priceList: priceListVal,
      privateNote: _privateNoteCtrl.text.trim().isEmpty ? null : _privateNoteCtrl.text.trim(),
    );

    if (widget.existing == null) {
      context.read<CustomersBloc>().add(AddCustomer(customer));
    } else {
      context.read<CustomersBloc>().add(UpdateCustomer(customer));
    }
    Navigator.pop(context, customer);
  }
}

