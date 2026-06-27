import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/checks_traites/checks_traites_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../models/check_traite.dart';
import '../../../../models/customer.dart';
import '../../../../models/supplier.dart';
import '../../../../utils/constants.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

class MobileCheckTraiteFormScreen extends StatefulWidget {
  final CheckTraite? existing;
  final bool isReadOnly;

  const MobileCheckTraiteFormScreen({
    super.key,
    this.existing,
    this.isReadOnly = false,
  });

  @override
  State<MobileCheckTraiteFormScreen> createState() => _MobileCheckTraiteFormScreenState();
}

class _MobileCheckTraiteFormScreenState extends State<MobileCheckTraiteFormScreen> {
  final _uuid = const Uuid();
  bool _isLoading = false;

  String _type = 'check_received'; // check_received, check_issued, traite_received, traite_issued
  String _contactType = 'customer'; // customer or supplier based on type
  String? _selectedContactId;
  String _partyName = '';
  
  String _documentNumber = '';
  double _amount = 0;
  String _bankName = '';
  String _bankAccount = '';
  DateTime _issueDate = DateTime.now();
  DateTime _maturityDate = DateTime.now().add(const Duration(days: 30));
  String _status = 'pending';
  String _notes = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());
    context.read<SuppliersBloc>().add(LoadSuppliers());

    if (widget.existing != null) {
      final ct = widget.existing!;
      _type = ct.type;
      _contactType = (_type == 'check_received' || _type == 'traite_received') ? 'customer' : 'supplier';
      _selectedContactId = ct.partyId;
      _partyName = ct.partyName;
      _documentNumber = ct.documentNumber;
      _amount = ct.amount;
      _bankName = ct.bankName ?? '';
      _bankAccount = ct.bankAccount ?? '';
      _issueDate = ct.issueDate;
      _maturityDate = ct.maturityDate;
      _status = ct.status;
      _notes = ct.notes ?? '';
    } else {
      _documentNumber = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    }
  }

  Future<void> _save() async {
    if (widget.isReadOnly) return;
    
    if (_documentNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir le numéro du document'), backgroundColor: AppColors.error));
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir un montant valide'), backgroundColor: AppColors.error));
      return;
    }
    if (_selectedContactId == null && _partyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner ou saisir un contact'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bloc = context.read<ChecksTraitesBloc>();

      // Extract contact name if selected from dropdown
      String finalPartyName = _partyName;
      if (_selectedContactId != null) {
        if (_contactType == 'customer') {
          final state = context.read<CustomersBloc>().state;
          if (state is CustomersLoaded) {
            final c = state.customers.firstWhere((e) => e.id == _selectedContactId, orElse: () => state.customers.first);
            finalPartyName = c.name;
          }
        } else {
          final state = context.read<SuppliersBloc>().state;
          if (state is SuppliersLoaded) {
            final s = state.suppliers.firstWhere((e) => e.id == _selectedContactId, orElse: () => state.suppliers.first);
            finalPartyName = s.name;
          }
        }
      }

      final checkTraite = CheckTraite(
        id: widget.existing?.id ?? _uuid.v4(),
        documentNumber: _documentNumber,
        type: _type,
        amount: _amount,
        partyName: finalPartyName,
        partyId: _selectedContactId,
        bankName: _bankName.trim().isEmpty ? null : _bankName.trim(),
        bankAccount: _bankAccount.trim().isEmpty ? null : _bankAccount.trim(),
        issueDate: _issueDate,
        maturityDate: _maturityDate,
        status: _status,
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
      );

      if (_isEditing) {
        // As a workaround since UpdateCheckTraite isn't fully supported in bloc,
        // we might only update status or emit a Create that acts as update if databaseHelper uses REPLACE.
        // Actually, for now we will just re-create it or delete and create.
        bloc.add(DeleteCheckTraite(checkTraite.id));
        bloc.add(CreateCheckTraite(checkTraite));
      } else {
        bloc.add(CreateCheckTraite(checkTraite));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Document mis à jour' : 'Document créé avec succès'),
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
      title: widget.isReadOnly ? 'Détails du document' : (_isEditing ? 'Modifier le document' : 'Nouveau document'),
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: () {
        if (!widget.isReadOnly) _save();
      },
      children: [
        MobileFormSection(
          title: 'Informations Générales',
          icon: Icons.account_balance_wallet_outlined,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<String>(
                    label: 'Type de document',
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'check_received', child: Text('Chèque reçu')),
                      DropdownMenuItem(value: 'check_issued', child: Text('Chèque émis')),
                      DropdownMenuItem(value: 'traite_received', child: Text('Traite reçue')),
                      DropdownMenuItem(value: 'traite_issued', child: Text('Traite émise')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _type = v;
                          _contactType = (v == 'check_received' || v == 'traite_received') ? 'customer' : 'supplier';
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
                          label: 'Client (Optionnel)',
                          value: _selectedContactId,
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Aucun / Saisie libre')),
                            ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (v) => setState(() => _selectedContactId = v),
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
                          label: 'Fournisseur (Optionnel)',
                          value: _selectedContactId,
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Aucun / Saisie libre')),
                            ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (v) => setState(() => _selectedContactId = v),
                        ),
                      );
                    },
                  ),
                if (_selectedContactId == null) ...[
                  const SizedBox(height: 16),
                  AbsorbPointer(
                    absorbing: widget.isReadOnly,
                    child: SmartTextInput(
                      label: 'Nom du contact *',
                      initialValue: _partyName,
                      onChanged: (v) => _partyName = v,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        MobileFormSection(
          title: 'Détails financiers',
          icon: Icons.money_outlined,
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
                  child: SmartTextInput(
                    label: 'Numéro du document *',
                    initialValue: _documentNumber,
                    onChanged: (v) => _documentNumber = v,
                  ),
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartTextInput(
                    label: 'Nom de la banque',
                    initialValue: _bankName,
                    onChanged: (v) => _bankName = v,
                  ),
                ),
              ],
            ),
          ),
        ),

        MobileFormSection(
          title: 'Dates & Statut',
          icon: Icons.calendar_month_outlined,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDatePicker(
                    label: 'Date d\'émission',
                    value: _issueDate,
                    onChanged: (v) => setState(() => _issueDate = v),
                  ),
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDatePicker(
                    label: 'Date d\'échéance',
                    value: _maturityDate,
                    onChanged: (v) => setState(() => _maturityDate = v),
                  ),
                ),
                const SizedBox(height: 16),
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SmartDropdown<String>(
                    label: 'Statut',
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('En attente')),
                      DropdownMenuItem(value: 'cashed', child: Text('Encaissé / Payé')),
                      DropdownMenuItem(value: 'bounced', child: Text('Impayé / Rejeté')),
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
                    maxLines: 2,
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
