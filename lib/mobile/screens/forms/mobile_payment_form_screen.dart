import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/payments/payments_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../models/payment_model.dart';
import '../../../../models/customer.dart';
import '../../../../models/supplier.dart';
import '../../../../blocs/treasury_accounts/treasury_accounts_bloc.dart';
import '../../../../models/treasury_account.dart';
import '../../../../blocs/treasury_transactions/treasury_transactions_bloc.dart';
import '../../../../models/treasury_transaction.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../../../database/database_helper.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';
import '../../../../widgets/searchable_dropdown_field.dart';
import '../../../../screens/customers_screen.dart';
import '../../../../screens/suppliers_screen.dart';

class MobilePaymentFormScreen extends StatefulWidget {
  final Payment? existing;
  final bool isReadOnly;
  
  const MobilePaymentFormScreen({
    super.key, 
    this.existing, 
    this.isReadOnly = false,
  });

  @override
  State<MobilePaymentFormScreen> createState() => _MobilePaymentFormScreenState();
}

class _MobilePaymentFormScreenState extends State<MobilePaymentFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String _direction = 'encaissement'; // encaissement / decaissement
  String _contactType = 'customer'; // customer / supplier
  String? _selectedContactId;
  String? _selectedContactName;
  String? _selectedAccountId;
  String? _selectedAccountName;
  String _method = 'especes'; // especes, cheque, virement, carte
  double _amount = 0;
  DateTime _paymentDate = DateTime.now();
  String _reference = '';
  String _notes = '';
  String _status = 'paid';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<SuppliersBloc>().add(LoadSuppliers());
    context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());

    if (widget.existing != null) {
      final p = widget.existing!;
      _direction = p.direction;
      _contactType = p.contactType;
      _selectedContactId = p.contactId;
      _selectedContactName = p.contactName;
      _selectedAccountId = p.accountId;
      _selectedAccountName = p.accountName;
      _method = p.method;
      _amount = p.amount;
      _paymentDate = p.paymentDate;
      _reference = p.reference ?? '';
      _notes = p.notes ?? '';
      _status = p.status;
    }
  }

  Future<void> _save() async {
    if (widget.isReadOnly) return;
    if (_selectedContactId == null || _selectedContactId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez sélectionner un contact'), backgroundColor: AppColors.error));
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Le montant doit être supérieur à 0'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<PaymentsBloc>();
      
      String number = widget.existing?.paymentNumber ?? '';
      if (number.isEmpty) {
        final seq = await DatabaseHelper.instance.getNextPaymentSequence();
        number = _direction == 'encaissement'
            ? generateDocNumber(DocPrefix.paymentIn, seq)
            : generateDocNumber(DocPrefix.paymentOut, seq);
      }

      String? contactName = _selectedContactName;
      if (_contactType == 'customer') {
        final custState = context.read<CustomersBloc>().state;
        if (custState is CustomersLoaded) {
          final found = custState.customers.firstWhere((c) => c.id == _selectedContactId, orElse: () => Customer(id: '', name: '', code: ''));
          if (found.id.isNotEmpty) {
            contactName = found.companyName?.isNotEmpty == true ? found.companyName! : found.name;
          }
        }
      } else {
        final suppState = context.read<SuppliersBloc>().state;
        if (suppState is SuppliersLoaded) {
          final found = suppState.suppliers.firstWhere((s) => s.id == _selectedContactId, orElse: () => Supplier(id: '', code: '', name: ''));
          if (found.id.isNotEmpty) {
            contactName = found.companyName?.isNotEmpty == true ? found.companyName! : (found.responsibleName?.isNotEmpty == true ? found.responsibleName! : found.name);
          }
        }
      }

      String? accountName = _selectedAccountName;
      final tState = context.read<TreasuryAccountsBloc>().state;
      if (tState is TreasuryAccountsLoaded) {
        final found = tState.accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => TreasuryAccount(id: '', name: '', type: 'cash'));
        if (found.id.isNotEmpty) {
          accountName = found.name;
        }
      }

      final paymentId = widget.existing?.id ?? _uuid.v4();
      final payment = Payment(
        id: paymentId,
        paymentNumber: number,
        direction: _direction,
        contactId: _selectedContactId!,
        contactType: _contactType,
        contactName: contactName,
        amount: _amount,
        method: _method,
        accountId: _selectedAccountId,
        accountName: accountName,
        reference: _reference.trim().isEmpty ? null : _reference.trim(),
        paymentDate: _paymentDate,
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        status: _status,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        bloc.add(UpdatePayment(payment));
      } else {
        bloc.add(AddPayment(payment));
        if (_selectedAccountId != null && _selectedAccountId!.isNotEmpty) {
          final tx = TreasuryTransaction(
            id: const Uuid().v4(),
            transactionNumber: 'TR-TEMP', // Will be regenerated by bloc
            accountId: _selectedAccountId!,
            accountName: accountName,
            dateTransaction: _paymentDate,
            type: _direction == 'encaissement' ? 'income' : 'expense',
            amount: payment.amount,
            description: 'Paiement ${payment.paymentNumber}${contactName != null ? ' - $contactName' : ''}',
            paymentId: payment.id,
          );
          context.read<TreasuryTransactionsBloc>().add(CreateTreasuryTransaction(tx));
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Paiement mis à jour' : 'Paiement créé avec succès'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors de la sauvegarde: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: widget.isReadOnly ? 'Détails du paiement' : (_isEditing ? 'Modifier le paiement' : 'Nouveau paiement'),
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: () {
        if (!widget.isReadOnly) _save();
      },
      children: [
        MobileFormSection(
          title: 'Informations Générales',
          icon: Icons.payments_outlined,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartSearchableSelector(
                    label: 'Type de paiement',
                    hint: 'Sélectionner le type',
                    selectedText: _direction == 'encaissement' ? 'Encaissement (Reçu)' : 'Décaissement (Payé)',
                    onTap: () async {
                      final res = await showSimpleOptionSelectDialog(
                        context,
                        'Sélectionner le type de paiement',
                        const [
                          {'value': 'encaissement', 'label': 'Encaissement (Reçu)'},
                          {'value': 'decaissement', 'label': 'Décaissement (Payé)'},
                        ],
                        selectedValue: _direction,
                      );
                      if (res != null && mounted) {
                        setState(() {
                          _direction = res;
                          _contactType = res == 'encaissement' ? 'customer' : 'supplier';
                          _selectedContactId = null;
                        });
                      }
                    },
                  ),
                ),
                SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartSearchableSelector(
                    label: 'Type de contact',
                    hint: 'Sélectionner le contact',
                    selectedText: _contactType == 'customer' ? 'Client' : 'Fournisseur',
                    onTap: () async {
                      final res = await showSimpleOptionSelectDialog(
                        context,
                        'Sélectionner le type de contact',
                        const [
                          {'value': 'customer', 'label': 'Client'},
                          {'value': 'supplier', 'label': 'Fournisseur'},
                        ],
                        selectedValue: _contactType,
                      );
                      if (res != null && mounted) {
                        setState(() {
                          _contactType = res;
                          _selectedContactId = null;
                        });
                      }
                    },
                  ),
                ),
                SizedBox(height: 16),
                if (_contactType == 'customer')
                  BlocBuilder<CustomersBloc, CustomersState>(
                    builder: (context, state) {
                      final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: AbsorbPointer(
                              absorbing: widget.isReadOnly,
                              child: SmartSearchableSelector(
                                label: 'Client *',
                                hint: 'Sélectionner un client',
                                selectedText: _selectedContactId != null
                                    ? (customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedContactId, orElse: () => null)?.companyName?.isNotEmpty == true
                                        ? customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedContactId, orElse: () => null)!.companyName!
                                        : customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedContactId, orElse: () => null)?.name)
                                    : null,
                                onTap: () async {
                                  final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedContactId);
                                  if (res != null && mounted) {
                                    setState(() => _selectedContactId = res);
                                  }
                                },
                              ),
                            ),
                          ),
                          if (!widget.isReadOnly) ...[
                            SizedBox(width: 8),
                            Container(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final newId = await showDialog<String>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<CustomersBloc>(),
                                      child: const CustomerDialog(existing: null),
                                    ),
                                  );
                                  if (newId != null && mounted) {
                                    setState(() {
                                      _selectedContactId = newId;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Icon(Icons.person_add_alt_1_rounded),
                              ),
                            ),
                          ]
                        ],
                      );
                    },
                  )
                else
                  BlocBuilder<SuppliersBloc, SuppliersState>(
                    builder: (context, state) {
                      final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: AbsorbPointer(
                              absorbing: widget.isReadOnly,
                              child: SmartSearchableSelector(
                                label: 'Fournisseur *',
                                hint: 'Sélectionner un fournisseur',
                                selectedText: _selectedContactId != null
                                    ? (suppliers.cast<Supplier?>().firstWhere((s) => s?.id == _selectedContactId, orElse: () => null)?.companyName?.isNotEmpty == true
                                        ? suppliers.cast<Supplier?>().firstWhere((s) => s?.id == _selectedContactId, orElse: () => null)!.companyName!
                                        : suppliers.cast<Supplier?>().firstWhere((s) => s?.id == _selectedContactId, orElse: () => null)?.name)
                                    : null,
                                onTap: () async {
                                  final res = await showSupplierSelectDialog(context, suppliers, selectedSupplierId: _selectedContactId);
                                  if (res != null && mounted) {
                                    setState(() => _selectedContactId = res);
                                  }
                                },
                              ),
                            ),
                          ),
                          if (!widget.isReadOnly) ...[
                            SizedBox(width: 8),
                            Container(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final newId = await showDialog<String>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<SuppliersBloc>(),
                                      child: SupplierDialog(existing: null),
                                    ),
                                  );
                                  if (newId != null && mounted) {
                                    setState(() {
                                      _selectedContactId = newId;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Icon(Icons.person_add_alt_1_rounded),
                              ),
                            ),
                          ]
                        ],
                      );
                    },
                  ),
                SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDatePicker(
                    label: 'Date de paiement',
                    value: _paymentDate,
                    onChanged: (v) => setState(() => _paymentDate = v),
                  ),
                ),
              ],
            ),
          ),
        ),

        MobileFormSection(
          title: 'Détails du montant',
          icon: Icons.account_balance_wallet_outlined,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartTextInput(
                    label: 'Montant *',
                    initialValue: _amount > 0 ? _amount.toString() : '',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => _amount = double.tryParse(v) ?? 0,
                  ),
                ),
                SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartSearchableSelector(
                    label: 'Méthode de paiement',
                    hint: 'Sélectionner la méthode',
                    selectedText: _method == 'especes'
                        ? 'Espèces'
                        : (_method == 'cheque'
                            ? 'Chèque'
                            : (_method == 'virement' ? 'Virement' : 'Carte Bancaire')),
                    onTap: () async {
                      final res = await showSimpleOptionSelectDialog(
                        context,
                        'Sélectionner la méthode de paiement',
                        const [
                          {'value': 'especes', 'label': 'Espèces'},
                          {'value': 'cheque', 'label': 'Chèque'},
                          {'value': 'virement', 'label': 'Virement'},
                          {'value': 'carte', 'label': 'Carte Bancaire'},
                        ],
                        selectedValue: _method,
                      );
                      if (res != null && mounted) {
                        setState(() => _method = res);
                      }
                    },
                  ),
                ),
                SizedBox(height: 16),
                BlocBuilder<TreasuryAccountsBloc, TreasuryAccountsState>(
                  builder: (context, state) {
                    List<TreasuryAccount> tAccounts = [];
                    if (state is TreasuryAccountsLoaded) {
                      tAccounts = state.accounts;
                    }
                    final selectedAcc = tAccounts.cast<TreasuryAccount?>().firstWhere(
                      (a) => a?.id == _selectedAccountId,
                      orElse: () => null,
                    );
                    final displayName = selectedAcc != null
                        ? '${selectedAcc.name} (${formatCurrencyDT(selectedAcc.balance)})'
                        : _selectedAccountName;

                    return AbsorbPointer(
                      absorbing: widget.isReadOnly,
                      child: SmartSearchableSelector(
                        label: 'Compte de trésorerie',
                        hint: 'Sélectionner un compte',
                        selectedText: displayName,
                        onTap: () async {
                          final res = await showTreasuryAccountSelectDialog(
                            context,
                            tAccounts,
                            selectedAccountId: _selectedAccountId,
                          );
                          if (res != null && mounted) {
                            final found = tAccounts.firstWhere((a) => a.id == res, orElse: () => TreasuryAccount(id: '', name: '', type: 'cash'));
                            setState(() {
                              _selectedAccountId = res;
                              _selectedAccountName = found.name;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
                SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartTextInput(
                    label: 'Référence (Chèque / Virement)',
                    initialValue: _reference,
                    onChanged: (v) => _reference = v,
                  ),
                ),
              ],
            ),
          ),
        ),

        MobileFormSection(
          title: 'Notes & Statut',
          icon: Icons.notes_outlined,
          isInitiallyExpanded: false,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartSearchableSelector(
                    label: 'Statut',
                    hint: 'Sélectionner le statut',
                    selectedText: _status == 'paid'
                        ? 'Payé'
                        : (_status == 'pending' ? 'En attente' : 'Annulé'),
                    onTap: () async {
                      final res = await showSimpleOptionSelectDialog(
                        context,
                        'Sélectionner le statut',
                        const [
                          {'value': 'paid', 'label': 'Payé'},
                          {'value': 'pending', 'label': 'En attente'},
                          {'value': 'cancelled', 'label': 'Annulé'},
                        ],
                        selectedValue: _status,
                      );
                      if (res != null && mounted) {
                        setState(() => _status = res);
                      }
                    },
                  ),
                ),
                SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartTextInput(
                    label: 'Notes',
                    initialValue: _notes,
                    maxLines: 3,
                    onChanged: (v) => _notes = v,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
