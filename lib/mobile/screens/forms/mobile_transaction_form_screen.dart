import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../../../../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../models/treasury_transaction.dart';
import '../../../../models/treasury_account.dart';
import '../../../../models/project.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

class MobileTransactionFormScreen extends StatefulWidget {
  final TreasuryTransaction? existing;
  final bool isReadOnly;

  const MobileTransactionFormScreen({
    super.key,
    this.existing,
    this.isReadOnly = false,
  });

  @override
  State<MobileTransactionFormScreen> createState() => _MobileTransactionFormScreenState();
}

class _MobileTransactionFormScreenState extends State<MobileTransactionFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String _type = 'income'; // income, expense
  String? _accountId;
  String? _projectId;
  String _category = 'other';
  double _amount = 0;
  DateTime _dateTransaction = DateTime.now();
  String _description = '';
  double _withholdingTaxRate = 0.0;
  double _withholdingTax = 0.0;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
    context.read<ProjectsBloc>().add(LoadProjects());

    if (widget.existing != null) {
      final t = widget.existing!;
      _type = t.type;
      _accountId = t.accountId;
      _projectId = t.projectId;
      _category = t.category ?? 'other';
      _amount = t.amount;
      _dateTransaction = t.dateTransaction;
      _description = t.description ?? '';
      _withholdingTaxRate = t.withholdingTaxRate;
      _withholdingTax = t.withholdingTax;
    }
  }

  void _calculateWithholdingTax() {
    if (_withholdingTaxRate > 0) {
      _withholdingTax = _amount * (_withholdingTaxRate / 100);
    } else {
      _withholdingTax = 0.0;
    }
  }

  Future<void> _save() async {
    if (widget.isReadOnly) return;
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un compte'), backgroundColor: AppColors.error));
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir un montant valide'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<TreasuryTransactionsBloc>();
      
      String number = widget.existing?.transactionNumber ?? '';
      if (number.isEmpty) {
        number = 'TR-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      }

      final transaction = TreasuryTransaction(
        id: widget.existing?.id ?? _uuid.v4(),
        transactionNumber: number,
        accountId: _accountId!,
        type: _type,
        amount: _amount,
        category: _category,
        dateTransaction: _dateTransaction,
        description: _description.trim().isEmpty ? null : _description.trim(),
        projectId: _projectId,
        withholdingTax: _withholdingTax,
        withholdingTaxRate: _withholdingTaxRate,
      );

      if (_isEditing) {
        bloc.add(DeleteTreasuryTransaction(transaction.id));
        bloc.add(CreateTreasuryTransaction(transaction));
      } else {
        bloc.add(CreateTreasuryTransaction(transaction));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Transaction mise à jour' : 'Transaction ajoutée'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: widget.isReadOnly ? 'Détails de la transaction' : (_isEditing ? 'Modifier la transaction' : 'Nouvelle transaction'),
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: () {
        if (!widget.isReadOnly) _save();
      },
      children: [
        MobileFormSection(
          title: 'Détails de l\'opération',
          icon: Icons.sync_alt_rounded,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<String>(
                    label: 'Type de mouvement',
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Revenu / Entrée')),
                      DropdownMenuItem(value: 'expense', child: Text('Dépense / Sortie')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                  builder: (context, state) {
                    final accounts = state is TreasuryAccountsLoaded ? state.accounts : <TreasuryAccount>[];
                    return AbsorbPointer(
                      absorbing: widget.isReadOnly,
                      child: SmartDropdown<String>(
                        label: 'Compte trésorerie *',
                        value: _accountId,
                        items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                        onChanged: (v) => setState(() => _accountId = v),
                        hint: 'Sélectionner un compte',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartTextInput(
                    label: 'Montant *',
                    initialValue: _amount > 0 ? _amount.toString() : '',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      setState(() {
                        _amount = double.tryParse(v) ?? 0;
                        _calculateWithholdingTax();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDatePicker(
                    label: 'Date',
                    value: _dateTransaction,
                    onChanged: (v) => setState(() => _dateTransaction = v),
                  ),
                ),
              ],
            ),
          ),
        ),

        MobileFormSection(
          title: 'Informations complémentaires',
          icon: Icons.info_outline_rounded,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<String>(
                    label: 'Catégorie',
                    value: _category,
                    items: const [
                      DropdownMenuItem(value: 'sales', child: Text('Ventes')),
                      DropdownMenuItem(value: 'purchases', child: Text('Achats')),
                      DropdownMenuItem(value: 'salaries', child: Text('Salaires')),
                      DropdownMenuItem(value: 'taxes', child: Text('Taxes et impôts')),
                      DropdownMenuItem(value: 'rent', child: Text('Loyer')),
                      DropdownMenuItem(value: 'other', child: Text('Autre')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<ProjectsBloc, ProjectsState>(
                  builder: (context, state) {
                    final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                    return AbsorbPointer(
                      absorbing: widget.isReadOnly,
                      child: SmartDropdown<String>(
                        label: 'Projet associé (Optionnel)',
                        value: _projectId,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Aucun')),
                          ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                        ],
                        onChanged: (v) => setState(() => _projectId = v),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartTextInput(
                    label: 'Description',
                    initialValue: _description,
                    maxLines: 2,
                    onChanged: (v) => _description = v,
                  ),
                ),
              ],
            ),
          ),
        ),

        MobileFormSection(
          title: 'Retenue à la source',
          icon: Icons.percent_rounded,
          isInitiallyExpanded: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartTextInput(
                    label: 'Taux (RS) %',
                    initialValue: _withholdingTaxRate > 0 ? _withholdingTaxRate.toString() : '',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      setState(() {
                        _withholdingTaxRate = double.tryParse(v) ?? 0;
                        _calculateWithholdingTax();
                      });
                    },
                  ),
                ),
                if (_withholdingTax > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant RS calculé:', style: TextStyle(color: AppColors.textSecondary)),
                        Text(formatCurrencyDT(_withholdingTax), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
