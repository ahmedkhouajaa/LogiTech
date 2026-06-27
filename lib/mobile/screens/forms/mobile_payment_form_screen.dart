import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/payments/payments_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../models/payment_model.dart';
import '../../../../models/customer.dart';
import '../../../../models/supplier.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/helpers.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

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

    if (widget.existing != null) {
      final p = widget.existing!;
      _direction = p.direction;
      _contactType = p.contactType;
      _selectedContactId = p.contactId;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un contact'), backgroundColor: AppColors.error));
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le montant doit être supérieur à 0'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<PaymentsBloc>();
      
      String number = widget.existing?.paymentNumber ?? '';
      if (number.isEmpty) {
        String prefix = _direction == 'encaissement' ? 'REC' : 'PAY';
        number = generateDocNumber(prefix, DateTime.now().millisecondsSinceEpoch % 1000000);
      }

      final paymentId = widget.existing?.id ?? _uuid.v4();
      final payment = Payment(
        id: paymentId,
        paymentNumber: number,
        direction: _direction,
        contactId: _selectedContactId!,
        contactType: _contactType,
        amount: _amount,
        method: _method,
        reference: _reference.trim().isEmpty ? null : _reference.trim(),
        paymentDate: _paymentDate,
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        status: _status,
      );

      if (_isEditing) {
        bloc.add(UpdatePayment(payment));
      } else {
        bloc.add(AddPayment(payment));
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<String>(
                    label: 'Type de paiement',
                    value: _direction,
                    items: const [
                      DropdownMenuItem(value: 'encaissement', child: Text('Encaissement (Reçu)')),
                      DropdownMenuItem(value: 'decaissement', child: Text('Décaissement (Payé)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _direction = v;
                          // Usually encaissement = from customer, decaissement = to supplier
                          _contactType = v == 'encaissement' ? 'customer' : 'supplier';
                          _selectedContactId = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<String>(
                    label: 'Type de contact',
                    value: _contactType,
                    items: const [
                      DropdownMenuItem(value: 'customer', child: Text('Client')),
                      DropdownMenuItem(value: 'supplier', child: Text('Fournisseur')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _contactType = v;
                          _selectedContactId = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_contactType == 'customer')
                  BlocBuilder<CustomersBloc, CustomersState>(
                    builder: (context, state) {
                      final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                      return AbsorbPointer(
                        absorbing: widget.isReadOnly,
                        child: SmartDropdown<String>(
                          label: 'Client *',
                          value: _selectedContactId,
                          items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (v) => setState(() => _selectedContactId = v),
                          hint: 'Sélectionner un client',
                        ),
                      );
                    },
                  )
                else
                  BlocBuilder<SuppliersBloc, SuppliersState>(
                    builder: (context, state) {
                      final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                      return AbsorbPointer(
                        absorbing: widget.isReadOnly,
                        child: SmartDropdown<String>(
                          label: 'Fournisseur *',
                          value: _selectedContactId,
                          items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                          onChanged: (v) => setState(() => _selectedContactId = v),
                          hint: 'Sélectionner un fournisseur',
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<String>(
                    label: 'Méthode de paiement',
                    value: _method,
                    items: const [
                      DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                      DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                      DropdownMenuItem(value: 'virement', child: Text('Virement')),
                      DropdownMenuItem(value: 'carte', child: Text('Carte Bancaire')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _method = v);
                    },
                  ),
                ),
                const SizedBox(height: 16),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<String>(
                    label: 'Statut',
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: 'paid', child: Text('Payé')),
                      DropdownMenuItem(value: 'pending', child: Text('En attente')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Annulé')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                ),
                const SizedBox(height: 16),
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
