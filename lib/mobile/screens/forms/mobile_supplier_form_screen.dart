import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/suppliers/suppliers_bloc.dart';
import '../../../../models/supplier.dart';
import '../../../../utils/constants.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';

class MobileSupplierFormScreen extends StatefulWidget {
  final Supplier? existing;
  final bool isReadOnly;
  const MobileSupplierFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileSupplierFormScreen> createState() => _MobileSupplierFormScreenState();
}

class _MobileSupplierFormScreenState extends State<MobileSupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _isLoading = false;

  String _name = '';
  String _email = '';
  String _phone = '';
  String _taxId = ''; // Matricule Fiscal
  String _rc = ''; // Registre de Commerce
  String _address = '';
  String _city = '';
  String _notes = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final s = widget.existing!;
      _name = s.name;
      _email = s.email ?? '';
      _phone = s.phone ?? '';
      _taxId = s.taxId ?? '';
      _rc = s.rc ?? '';
      _address = s.address ?? '';
      _city = s.city ?? '';
      _notes = s.notes ?? '';
    }
  }

  void _save() {
    if (widget.isReadOnly) return;
    if (!_formKey.currentState!.validate()) return;
    
    if (_name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer un nom ou une raison sociale'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supplier = Supplier(
        id: widget.existing?.id ?? _uuid.v4(),
        code: widget.existing?.code ?? 'FOU-${DateTime.now().millisecondsSinceEpoch % 10000}',
        name: _name.trim(),
        email: _email.trim().isEmpty ? null : _email.trim(),
        phone: _phone.trim().isEmpty ? null : _phone.trim(),
        taxId: _taxId.trim().isEmpty ? null : _taxId.trim(),
        rc: _rc.trim().isEmpty ? null : _rc.trim(),
        address: _address.trim().isEmpty ? null : _address.trim(),
        city: _city.trim().isEmpty ? null : _city.trim(),
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        isDeleted: widget.existing?.isDeleted ?? false,
      );

      if (widget.existing == null) {
        context.read<SuppliersBloc>().add(AddSupplier(supplier));
      } else {
        context.read<SuppliersBloc>().add(UpdateSupplier(supplier));
      }
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.existing == null ? 'Fournisseur créé avec succès' : 'Fournisseur mis à jour'),
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
      title: widget.isReadOnly ? 'Détails du fournisseur' : (_isEditing ? 'Modifier le fournisseur' : 'Nouveau fournisseur'),
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
                icon: Icons.business_rounded,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: 'Nom Complet / Raison Sociale *',
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
                title: 'Fiscalité',
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
                      SmartTextInput(
                        label: 'Ville',
                        initialValue: _city,
                        onChanged: (v) { if (!widget.isReadOnly) _city = v; },
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
