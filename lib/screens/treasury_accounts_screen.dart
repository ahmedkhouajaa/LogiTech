import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../models/treasury_account.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/data_table_widget.dart';
import '../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/treasury_transaction.dart';
import '../models/project.dart';
import '../services/expense_category_service.dart';
import 'package:intl/intl.dart';

class TreasuryAccountsScreen extends StatefulWidget {
  const TreasuryAccountsScreen({super.key});

  @override
  State<TreasuryAccountsScreen> createState() => _TreasuryAccountsScreenState();
}

class _TreasuryAccountsScreenState extends State<TreasuryAccountsScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
  }

  void _showAccountDialog(BuildContext context, [TreasuryAccount? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<TreasuryAccountsBloc>(),
        child: _CreateTreasuryAccountDialog(existing: existing),
      ),
    );
  }

  void _showExpenseDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<TreasuryTransactionsBloc>()),
          BlocProvider.value(value: context.read<TreasuryAccountsBloc>()),
          BlocProvider.value(value: context.read<ProjectsBloc>()),
        ],
        child: const _CreateExpenseDialog(),
      ),
    );
    
    // Refresh accounts list to reflect any balance changes
    if (context.mounted) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (context.mounted) {
          context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Comptes de Tresorerie',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAccountDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter Compte'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showExpenseDialog(context),
                          icon: const Icon(Icons.attach_money_rounded, size: 18),
                          label: const Text('Ajouter Depense'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  const Text(
                    'Comptes de Tresorerie',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _showAccountDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ajouter un Compte'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showExpenseDialog(context),
                    icon: const Icon(Icons.attach_money_rounded, size: 18),
                    label: const Text('Ajouter une Depense'),
                  ),
                ],
              ),
        ),

        // Table
        Expanded(
          child: BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
            builder: (context, state) {
              if (state is TreasuryAccountsLoading) return const Center(child: CircularProgressIndicator());
              if (state is TreasuryAccountsError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is TreasuryAccountsLoaded) {
                final filtered = _search.isEmpty
                    ? state.accounts
                    : state.accounts.where((a) => a.name.toLowerCase().contains(_search)).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DataTableWidget<TreasuryAccount>(
                      columns: const ['Nom du Compte', 'Type', 'Solde', 'Actions'],
                      rows: filtered,
                      emptyMessage: 'Aucun compte trouve',
                      cellBuilder: (acc) => [
                        DataCell(Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(acc.type == 'bank' ? 'Compte Bancaire' : 'Caisse')),
                        DataCell(
                          Text(
                            formatCurrencyDT(acc.balance),
                            style: TextStyle(
                              color: acc.balance < 0 ? AppColors.error : AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                                onPressed: () => _showAccountDialog(context, acc),
                                tooltip: 'Modifier',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                onPressed: () => context.read<TreasuryAccountsBloc>().add(DeleteTreasuryAccount(acc.id)),
                                tooltip: 'Supprimer',
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

class _CreateTreasuryAccountDialog extends StatefulWidget {
  final TreasuryAccount? existing;

  const _CreateTreasuryAccountDialog({this.existing});

  @override
  State<_CreateTreasuryAccountDialog> createState() => _CreateTreasuryAccountDialogState();
}

class _CreateTreasuryAccountDialogState extends State<_CreateTreasuryAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _agencyCtrl;
  late final TextEditingController _ibanCtrl;
  String? _selectedBank;
  late String _selectedCurrency;

  final List<String> _tunisianBanks = [
    'Al Baraka Bank',
    'Amen Bank',
    'Arab Tunisian Bank (ATB)',
    'Attijari Bank',
    'Banque de l\'Habitat (BH)',
    'Banque Internationale Arabe de Tunisie (BIAT)',
    'Banque Nationale Agricole (BNA)',
    'Banque de Tunisie (BT)',
    'Banque de Tunisie et des Emirats (BTE)',
    'Banque Zitouna',
    'Banque Tuniso-Libyenne (BTL)',
    'Banque Tuniso-Koweitienne (BTK)',
    'Citi Bank',
    'Qatar National Bank (QNB)',
    'Société Tunisienne de Banque (STB)',
    'Union Bancaire pour le Commerce et l\'Industrie (UBCI)',
    'Union Internationale de Banques (UIB)',
    'Wifak Bank'
  ];

  final List<Map<String, String>> _worldCurrencies = [
    {'code': 'TND', 'name': 'Tunisian Dinar', 'flag': '🇹🇳'},
    {'code': 'USD', 'name': 'US Dollar', 'flag': '🇺🇸'},
    {'code': 'EUR', 'name': 'Euro', 'flag': '🇪🇺'},
    {'code': 'GBP', 'name': 'British Pound', 'flag': '🇬🇧'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'flag': '🇨🇦'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'flag': '🇦🇺'},
    {'code': 'CHF', 'name': 'Swiss Franc', 'flag': '🇨🇭'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'flag': '🇯🇵'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'flag': '🇨🇳'},
    {'code': 'AED', 'name': 'UAE Dirham', 'flag': '🇦🇪'},
    {'code': 'SAR', 'name': 'Saudi Riyal', 'flag': '🇸🇦'},
    {'code': 'DZD', 'name': 'Algerian Dinar', 'flag': '🇩🇿'},
    {'code': 'MAD', 'name': 'Moroccan Dirham', 'flag': '🇲🇦'},
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? 'cash';
    _selectedCurrency = e?.currency ?? 'TND';
    if (!_worldCurrencies.any((c) => c['code'] == _selectedCurrency)) {
      _worldCurrencies.add({'code': _selectedCurrency, 'name': _selectedCurrency, 'flag': '🏳️'});
    }
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _agencyCtrl = TextEditingController(text: e?.agency ?? '');
    _ibanCtrl = TextEditingController(text: e?.iban ?? '');
    _selectedBank = e?.bankName;
    if (_selectedBank != null && !_tunisianBanks.contains(_selectedBank)) {
      _tunisianBanks.add(_selectedBank!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _agencyCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final acc = TreasuryAccount(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        internalName: _nameCtrl.text.trim(), // Use name as internal name
        type: _type,
        bankName: _type == 'bank' ? _selectedBank : null,
        agency: _type == 'bank' ? _agencyCtrl.text.trim() : null,
        iban: _type == 'bank' ? _ibanCtrl.text.trim() : null,
        currency: _selectedCurrency,
        balance: widget.existing?.balance ?? 0.0,
      );

      if (widget.existing == null) {
        context.read<TreasuryAccountsBloc>().add(CreateTreasuryAccount(acc));
      } else {
        context.read<TreasuryAccountsBloc>().add(UpdateTreasuryAccount(acc));
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? 'Creer un Compte de Tresorerie' : 'Modifier le Compte',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: const Text('Creer'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Type Selector
              const Text('Type de Compte', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton('Caisse', 'cash', _type == 'cash', () => setState(() => _type = 'cash')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeButton('Compte Bancaire', 'bank', _type == 'bank', () => setState(() => _type = 'bank')),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Nom du Compte', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Entrez le nom du compte',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                ),
                style: const TextStyle(fontSize: 13),
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 6),
              const Text('Nom interne visible uniquement par vous', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 16),

              if (_type == 'bank') ...[
                const Text('Banque', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedBank,
                  hint: const Text('Sélectionnez une banque', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                  icon: const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textTertiary),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  items: _tunisianBanks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (v) => setState(() => _selectedBank = v),
                  validator: (v) => v == null ? 'Requis' : null,
                ),
                const SizedBox(height: 16),

                const Text('Agence', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _agencyCtrl,
                  decoration: InputDecoration(
                    hintText: "Entrez le nom de l'agence",
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),

                const Text('IBAN', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ibanCtrl,
                  decoration: InputDecoration(
                    hintText: 'TN59XXXXXXXXXXXXXXXXXXXX',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
              ],

              // Currency indicator
              const Text('Devise', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                icon: const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textTertiary),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                items: _worldCurrencies.map((c) {
                  return DropdownMenuItem(
                    value: c['code'],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c['flag']!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text('${c['code']} - ${c['name']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v!),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, String value, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : AppColors.textSecondary)),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateExpenseDialog extends StatefulWidget {
  const _CreateExpenseDialog();

  @override
  State<_CreateExpenseDialog> createState() => _CreateExpenseDialogState();
}

class _CreateExpenseDialogState extends State<_CreateExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _reasonCtrl;
  late TextEditingController _withholdingTaxRateCtrl;
  DateTime _date = DateTime.now();
  String? _selectedAccountId;
  String _selectedCategory = 'salaries';
  bool _applyWithholdingTax = false;
  String? _selectedProjectId;

  Map<String, String> _categories = {};

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '0');
    _reasonCtrl = TextEditingController();
    _withholdingTaxRateCtrl = TextEditingController(text: '0');
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await ExpenseCategoryService.loadCategories();
    setState(() {
      _categories = cats;
      if (cats.isNotEmpty && !cats.containsKey(_selectedCategory)) {
        _selectedCategory = cats.keys.first;
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _withholdingTaxRateCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate() && _selectedAccountId != null) {
      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final rate = _applyWithholdingTax ? (double.tryParse(_withholdingTaxRateCtrl.text.replaceAll(',', '.')) ?? 0.0) : 0.0;

      final transaction = TreasuryTransaction(
        transactionNumber: 'DEP-${DateTime.now().millisecondsSinceEpoch}',
        accountId: _selectedAccountId!,
        type: 'expense',
        amount: amount,
        category: _selectedCategory,
        dateTransaction: _date,
        description: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        projectId: _selectedProjectId,
        withholdingTaxRate: rate,
        withholdingTax: amount * (rate / 100),
      );

      context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(transaction));
      Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Nouvelle Dépense',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Fermer'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: const Text('Créer'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount and Date
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Montant', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _amountCtrl,
                            decoration: InputDecoration(
                              suffixText: 'DT',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                            ),
                            style: const TextStyle(fontSize: 13),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Requis';
                              if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Invalide';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(color: AppColors.border),
                                color: Colors.white,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('dd MMM yyyy', 'fr_FR').format(_date), style: const TextStyle(fontSize: 13)),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textTertiary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Account
                const Text('Compte de Trésorerie', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                  builder: (context, state) {
                    List<TreasuryAccount> accounts = [];
                    if (state is TreasuryAccountsLoaded) {
                      accounts = state.accounts;
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedAccountId,
                      hint: const Text('Sélectionner un compte de trésorerie', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textTertiary),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                      onChanged: (v) => setState(() => _selectedAccountId = v),
                      validator: (v) => v == null ? 'Requis' : null,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Category
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Catégorie de Dépense', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                    TextButton.icon(
                      onPressed: () async {
                        final updated = await showDialog<Map<String, String>>(
                          context: context,
                          builder: (_) => _ManageExpenseCategoriesDialog(initialCategories: _categories),
                        );
                        if (updated != null) {
                          setState(() {
                            _categories = updated;
                            if (updated.isNotEmpty && !updated.containsKey(_selectedCategory)) {
                              _selectedCategory = updated.keys.first;
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.edit_rounded, size: 14, color: AppColors.textSecondary),
                      label: const Text('Modifier les catégories de dépense', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_categories.isEmpty)
                  const Text('Aucune catégorie.', style: TextStyle(color: AppColors.textTertiary, fontSize: 13))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.keys.map((k) => IntrinsicWidth(child: _buildCategoryButton(k))).toList(),
                  ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Withholding Tax
                Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text('Appliquer une retenue à la source ?', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTypeButton('Non', false, !_applyWithholdingTax, () => setState(() => _applyWithholdingTax = false)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTypeButton('Oui', true, _applyWithholdingTax, () => setState(() => _applyWithholdingTax = true)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_applyWithholdingTax) ...[
                  const SizedBox(height: 16),
                  const Text('Taux de Retenue (%)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _withholdingTaxRateCtrl,
                    decoration: InputDecoration(
                      suffixText: '%',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    style: const TextStyle(fontSize: 13),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requis';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Invalide';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),

                // Project
                const Text('Projet (Optionnel)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                BlocBuilder<ProjectsBloc, ProjectsState>(
                  builder: (context, state) {
                    List<Project> projects = [];
                    if (state is ProjectsLoaded) {
                      projects = state.projects;
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedProjectId,
                      hint: const Text('Sélectionner un projet', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                      icon: const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textTertiary),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      items: projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (v) => setState(() => _selectedProjectId = v),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Reason
                const Text('Raison (Optionnel)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'Entrez la raison ou la description de la dépense',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                  style: const TextStyle(fontSize: 13),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String key) {
    final isSelected = _selectedCategory == key;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = key),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _categories[key]!,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, bool value, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: isSelected ? AppColors.primary : AppColors.textSecondary)),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManageExpenseCategoriesDialog extends StatefulWidget {
  final Map<String, String> initialCategories;
  const _ManageExpenseCategoriesDialog({required this.initialCategories});

  @override
  State<_ManageExpenseCategoriesDialog> createState() => _ManageExpenseCategoriesDialogState();
}

class _ManageExpenseCategoriesDialogState extends State<_ManageExpenseCategoriesDialog> {
  late Map<String, String> _categories;
  final TextEditingController _newCategoryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categories = Map.from(widget.initialCategories);
  }

  void _save() async {
    await ExpenseCategoryService.saveCategories(_categories);
    if (mounted) Navigator.pop(context, _categories);
  }

  void _add() {
    final text = _newCategoryCtrl.text.trim();
    if (text.isNotEmpty) {
      final key = text.toLowerCase().replaceAll(' ', '_');
      if (!_categories.containsKey(key)) {
        setState(() {
          _categories[key] = text;
          _newCategoryCtrl.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Catégories de Dépense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: ListView(
                children: _categories.entries.map((e) {
                  return ListTile(
                    title: Text(e.value),
                    trailing: e.key == 'other'
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                            onPressed: () => setState(() => _categories.remove(e.key)),
                          ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nouvelle catégorie (ex: 🚕 Transport)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _add, child: const Text('Ajouter')),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}
