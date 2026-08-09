import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../models/customer.dart';
import '../../../../database/database_helper.dart';
import '../../../../utils/constants.dart';
import '../../../../services/enterprise_service.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

class MobileCustomerFormScreen extends StatefulWidget {
  final Customer? existing;
  final bool isReadOnly;
  const MobileCustomerFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileCustomerFormScreen> createState() => _MobileCustomerFormScreenState();
}

class _MobileCustomerFormScreenState extends State<MobileCustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _isLoading = false;

  String _name = '';
  String _customerType = 'entreprise';
  String _companyName = '';
  String _email = '';
  String _phone = '';
  String _taxId = ''; // Matricule Fiscal
  String _rc = ''; // Registre de Commerce
  String _address = '';
  String _city = '';
  String _country = 'Tunisie';
  double _creditLimit = 0.0;
  bool _tvaSuspension = false;
  String _tvaAttestation = '';
  String _tvaStartDate = '';
  String _tvaEndDate = '';
  List<String> _bankAccounts = [''];
  String _priceList = 'default';
  String _notes = '';
  String _privateNote = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final c = widget.existing!;
      _name = c.name;
      _customerType = c.customerType;
      _companyName = c.companyName ?? '';
      _email = c.email ?? '';
      _phone = c.phone ?? '';
      _taxId = c.taxId ?? '';
      _rc = c.rc ?? '';
      _address = c.address ?? '';
      _city = c.city ?? '';
      _country = c.country.isEmpty ? 'Tunisie' : c.country;
      _creditLimit = c.creditLimit;
      _tvaSuspension = c.tvaSuspension;
      _tvaAttestation = c.tvaAttestation ?? '';
      _tvaStartDate = c.tvaStartDate ?? '';
      _tvaEndDate = c.tvaEndDate ?? '';
      if (c.bankAccount != null && c.bankAccount!.trim().isNotEmpty) {
        _bankAccounts = c.bankAccount!.split(RegExp(r'[\n,]|\|')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (_bankAccounts.isEmpty) _bankAccounts = [''];
      }
      _priceList = c.priceList;
      _notes = c.notes ?? '';
      _privateNote = c.privateNote ?? '';
    }
  }

  Future<void> _save() async {
    if (widget.isReadOnly) return;
    if (!_formKey.currentState!.validate()) return;
    
    if (_name.isEmpty && _companyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez entrer un nom ou une raison sociale'), backgroundColor: AppColors.error));
      return;
    }

    if (_tvaSuspension && (_tvaAttestation.trim().isEmpty || _tvaEndDate.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez renseigner le N° d\'attestation TVA et la date d\'expiration'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final validBankAccounts = _bankAccounts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final code = widget.existing?.code ?? await DatabaseHelper.instance.getNextCustomerSequence();
      if (!mounted) return;
      final customer = Customer(
        id: widget.existing?.id ?? _uuid.v4(),
        code: code,
        name: _name.isEmpty ? _companyName : _name,
        enterpriseId: widget.existing?.enterpriseId ?? EnterpriseService.instance.currentEnterpriseId,
        customerType: _customerType,
        companyName: _companyName.trim().isEmpty ? null : _companyName.trim(),
        email: _email.trim().isEmpty ? null : _email.trim(),
        phone: _phone.trim().isEmpty ? null : _phone.trim(),
        taxId: _taxId.trim().isEmpty ? null : _taxId.trim(),
        rc: _rc.trim().isEmpty ? null : _rc.trim(),
        address: _address.trim().isEmpty ? null : _address.trim(),
        city: _city.trim().isEmpty ? null : _city.trim(),
        country: _country,
        creditLimit: _creditLimit,
        tvaSuspension: _tvaSuspension,
        tvaAttestation: _tvaSuspension ? (_tvaAttestation.trim().isEmpty ? null : _tvaAttestation.trim()) : null,
        tvaStartDate: _tvaSuspension ? (_tvaStartDate.trim().isEmpty ? null : _tvaStartDate.trim()) : null,
        tvaEndDate: _tvaSuspension ? (_tvaEndDate.trim().isEmpty ? null : _tvaEndDate.trim()) : null,
        bankAccount: validBankAccounts.isEmpty ? null : validBankAccounts.join('\n'),
        priceList: _priceList,
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        privateNote: _privateNote.trim().isEmpty ? null : _privateNote.trim(),
        isDeleted: widget.existing?.isDeleted ?? false,
      );

      if (widget.existing == null) {
        context.read<CustomersBloc>().add(AddCustomer(customer));
      } else {
        context.read<CustomersBloc>().add(UpdateCustomer(customer));
      }
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.existing == null ? 'Client créé avec succès' : 'Client mis à jour'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: ${e.toString()}'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: widget.isReadOnly ? 'Détails du client' : (_isEditing ? 'Modifier le client' : 'Nouveau client'),
      isLoading: _isLoading,
      saveLabel: 'Enregistrer',
      onCancel: () => Navigator.pop(context),
      onSave: () {
        if (!widget.isReadOnly) _save();
      },
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              MobileFormSection(
                title: 'Informations Générales',
                icon: Icons.person_outline_rounded,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AbsorbPointer(
                        absorbing: widget.isReadOnly,
                        child: SmartToggleChips<String>(
                          label: 'Type de Client',
                          value: _customerType,
                          options: const ['entreprise', 'particulier'],
                          labelBuilder: (v) => v == 'entreprise' ? 'Entreprise' : 'Particulier',
                          onChanged: (v) => setState(() => _customerType = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_customerType == 'entreprise') ...[
                        SmartTextInput(
                          label: 'Raison Sociale *',
                          initialValue: _companyName,
                          onChanged: (v) { if (!widget.isReadOnly) _companyName = v; },
                        ),
                        const SizedBox(height: 16),
                      ],
                      SmartTextInput(
                        label: 'Nom Complet / Responsable',
                        initialValue: _name,
                        onChanged: (v) { if (!widget.isReadOnly) _name = v; },
                      ),
                    ],
                  ),
                ),
              ),
              
              MobileFormSection(
                title: 'Contact',
                icon: Icons.contact_phone_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: 'Téléphone *',
                        initialValue: _phone,
                        keyboardType: TextInputType.phone,
                        onChanged: (v) { if (!widget.isReadOnly) _phone = v; },
                        validator: (v) => v == null || v.trim().isEmpty ? 'Téléphone obligatoire' : null,
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Email',
                        initialValue: _email,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) { if (!widget.isReadOnly) _email = v; },
                      ),
                    ],
                  ),
                ),
              ),

              MobileFormSection(
                title: 'Comptes Bancaires (RIB / IBAN)',
                icon: Icons.account_balance_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...List.generate(_bankAccounts.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: SmartTextInput(
                                  label: 'Compte #${index + 1}',
                                  initialValue: _bankAccounts[index],
                                  onChanged: (v) { if (!widget.isReadOnly) _bankAccounts[index] = v; },
                                ),
                              ),
                              if (!widget.isReadOnly && _bankAccounts.length > 1) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                  onPressed: () => setState(() => _bankAccounts.removeAt(index)),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      if (!widget.isReadOnly)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _bankAccounts.add('')),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter un compte bancaire'),
                        ),
                    ],
                  ),
                ),
              ),

              MobileFormSection(
                title: 'Fiscalité & Finance',
                icon: Icons.account_balance_wallet_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: 'Matricule Fiscal',
                        initialValue: _taxId,
                        onChanged: (v) { if (!widget.isReadOnly) _taxId = v; },
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Registre de Commerce (RC)',
                        initialValue: _rc,
                        onChanged: (v) { if (!widget.isReadOnly) _rc = v; },
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Plafond de Crédit',
                        initialValue: _creditLimit > 0 ? _creditLimit.toString() : '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) { if (!widget.isReadOnly) _creditLimit = double.tryParse(v) ?? 0; },
                      ),
                      const SizedBox(height: 16),
                      SmartCheckbox(
                        label: 'Exonéré de TVA (Suspension)',
                        value: _tvaSuspension,
                        onChanged: widget.isReadOnly ? null : (v) => setState(() => _tvaSuspension = v ?? false),
                      ),
                      if (_tvaSuspension) ...[
                        const SizedBox(height: 16),
                        SmartTextInput(
                          label: 'N° Attestation de Suspension *',
                          initialValue: _tvaAttestation,
                          onChanged: (v) { if (!widget.isReadOnly) _tvaAttestation = v; },
                        ),
                        const SizedBox(height: 12),
                        SmartTextInput(
                          label: 'Date d\'Expiration (JJ/MM/AAAA) *',
                          initialValue: _tvaEndDate,
                          onChanged: (v) { if (!widget.isReadOnly) _tvaEndDate = v; },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              MobileFormSection(
                title: 'Adresse',
                icon: Icons.location_on_outlined,
                isInitiallyExpanded: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: 'Adresse',
                        initialValue: _address,
                        maxLines: 2,
                        onChanged: (v) { if (!widget.isReadOnly) _address = v; },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SmartTextInput(
                              label: 'Ville',
                              initialValue: _city,
                              onChanged: (v) { if (!widget.isReadOnly) _city = v; },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SmartTextInput(
                              label: 'Pays',
                              initialValue: _country,
                              onChanged: (v) { if (!widget.isReadOnly) _country = v; },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              MobileFormSection(
                title: 'Notes & Confidentialité',
                icon: Icons.notes_outlined,
                isInitiallyExpanded: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: 'Remarques Générales',
                        initialValue: _notes,
                        maxLines: 3,
                        onChanged: (v) { if (!widget.isReadOnly) _notes = v; },
                      ),
                      const SizedBox(height: 16),
                      SmartTextInput(
                        label: 'Note Privée (Interne & Confidentielle)',
                        initialValue: _privateNote,
                        maxLines: 3,
                        onChanged: (v) { if (!widget.isReadOnly) _privateNote = v; },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
