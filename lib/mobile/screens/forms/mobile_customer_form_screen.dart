import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../models/customer.dart';
import '../../../../utils/constants.dart';
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
  String _notes = '';

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
      _notes = c.notes ?? '';
    }
  }

  void _save() {
    if (widget.isReadOnly) return;
    if (!_formKey.currentState!.validate()) return;
    
    if (_name.isEmpty && _companyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer un nom ou une raison sociale'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final customer = Customer(
        id: widget.existing?.id ?? _uuid.v4(),
        code: widget.existing?.code ?? 'CLI-${DateTime.now().millisecondsSinceEpoch % 10000}',
        name: _name.isEmpty ? _companyName : _name,
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
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
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
                        label: 'Téléphone',
                        initialValue: _phone,
                        keyboardType: TextInputType.phone,
                        onChanged: (v) { if (!widget.isReadOnly) _phone = v; },
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
                title: 'Notes',
                icon: Icons.notes_outlined,
                isInitiallyExpanded: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SmartTextInput(
                    label: 'Remarques',
                    initialValue: _notes,
                    maxLines: 3,
                    onChanged: (v) { if (!widget.isReadOnly) _notes = v; },
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
