import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../models/treasury_account.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/data_table_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Text(
                'Comptes de Trésorerie',
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
                onPressed: () {
                  // TODO: Navigate to create expense (will be added in next step)
                },
                icon: const Icon(Icons.attach_money_rounded, size: 18),
                label: const Text('Ajouter une Dépense'),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
            builder: (context, state) {
              if (state is TreasuryAccountsLoading) return const Center(child: CircularProgressIndicator());
              if (state is TreasuryAccountsError) return Center(child: Text('Erreur: \${state.message}'));
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
                      emptyMessage: 'Aucun compte trouvé',
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
  late final TextEditingController _internalNameCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _agencyCtrl;
  late final TextEditingController _ibanCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? 'cash';
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _internalNameCtrl = TextEditingController(text: e?.internalName ?? '');
    _bankNameCtrl = TextEditingController(text: e?.bankName ?? '');
    _agencyCtrl = TextEditingController(text: e?.agency ?? '');
    _ibanCtrl = TextEditingController(text: e?.iban ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _internalNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _agencyCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final acc = TreasuryAccount(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        internalName: _internalNameCtrl.text.trim(),
        type: _type,
        bankName: _type == 'bank' ? _bankNameCtrl.text.trim() : null,
        agency: _type == 'bank' ? _agencyCtrl.text.trim() : null,
        iban: _type == 'bank' ? _ibanCtrl.text.trim() : null,
        currency: 'TND',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing == null ? 'Créer un Compte de Trésorerie' : 'Modifier le Compte',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
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
                        label: const Text('Créer'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Type Selector
              const Text('Type de Compte', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
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

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom du Compte *', hintText: 'Entrez le nom du compte'),
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _internalNameCtrl,
                decoration: const InputDecoration(labelText: 'Nom interne visible uniquement par vous'),
              ),
              const SizedBox(height: 12),

              if (_type == 'bank') ...[
                TextFormField(
                  controller: _bankNameCtrl,
                  decoration: const InputDecoration(labelText: 'Banque', hintText: 'Sélectionnez une banque'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _agencyCtrl,
                  decoration: const InputDecoration(labelText: 'Agence', hintText: "Entrez le nom de l'agence"),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ibanCtrl,
                  decoration: const InputDecoration(labelText: 'IBAN', hintText: 'TN59XXXXXXXXXXXXXXXXXXXX'),
                ),
                const SizedBox(height: 12),
              ],

              // Currency indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: const [
                    Text('🇹🇳', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('TND - Tunisian Dinar', style: TextStyle(fontWeight: FontWeight.w500)),
                    Spacer(),
                    Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ],
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
