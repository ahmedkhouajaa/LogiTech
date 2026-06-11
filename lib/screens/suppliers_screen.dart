import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/suppliers/suppliers_bloc.dart';
import '../models/supplier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/data_table_widget.dart';
import '../widgets/dashboard_card.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    context.read<SuppliersBloc>().add(LoadSuppliers());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppSearchBar(onChanged: (v) => setState(() => _search = v.toLowerCase())),
              const Spacer(),
              AppButton(label: 'Nouveau fournisseur', icon: Icons.add_rounded, onPressed: () => _showDialog(context, null)),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<SuppliersBloc, SuppliersState>(
            builder: (context, state) {
              if (state is SuppliersLoading) return const Center(child: CircularProgressIndicator());
              if (state is SuppliersError) return Center(child: Text('Erreur: ${state.message}'));
              if (state is SuppliersLoaded) {
                final filtered = _search.isEmpty ? state.suppliers
                    : state.suppliers.where((s) => s.name.toLowerCase().contains(_search) || s.code.toLowerCase().contains(_search)).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: DataTableWidget<Supplier>(
                      columns: const ['Code', 'Nom', 'Téléphone', 'Email', 'Ville', 'Solde'],
                      rows: filtered,
                      emptyMessage: 'Aucun fournisseur trouvé',
                      cellBuilder: (s) => [
                        DataCell(Text(s.code, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(s.phone ?? '—')),
                        DataCell(Text(s.email ?? '—')),
                        DataCell(Text(s.city ?? '—')),
                        DataCell(Text(formatCurrency(s.balance))),
                      ],
                      onEdit: (s) => _showDialog(context, s),
                      onDelete: (s) => context.read<SuppliersBloc>().add(DeleteSupplier(s.id)),
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

  void _showDialog(BuildContext context, Supplier? existing) {
    showDialog(context: context, builder: (_) => BlocProvider.value(
      value: context.read<SuppliersBloc>(),
      child: _SupplierDialog(existing: existing),
    ));
  }
}

class _SupplierDialog extends StatefulWidget {
  final Supplier? existing;
  const _SupplierDialog({this.existing});
  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _cityCtrl, _taxCtrl, _rcCtrl, _notesCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _codeCtrl = TextEditingController(text: s?.code ?? 'FOU-${DateTime.now().millisecondsSinceEpoch % 10000}');
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _cityCtrl = TextEditingController(text: s?.city ?? '');
    _taxCtrl = TextEditingController(text: s?.taxId ?? '');
    _rcCtrl = TextEditingController(text: s?.rc ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    for (var c in [_codeCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _cityCtrl, _taxCtrl, _rcCtrl, _notesCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)]),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.lg), topRight: Radius.circular(AppRadius.lg)),
              ),
              child: Row(children: [
                const Icon(Icons.factory_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(widget.existing == null ? 'Nouveau fournisseur' : 'Modifier fournisseur', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: AppTextField(label: 'Code *', controller: _codeCtrl, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                      const SizedBox(width: 16),
                      Expanded(child: AppTextField(label: 'Nom *', controller: _nameCtrl, validator: (v) => v!.isEmpty ? 'Requis' : null)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: AppTextField(label: 'Téléphone', controller: _phoneCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: AppTextField(label: 'Email', controller: _emailCtrl)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: AppTextField(label: 'Adresse', controller: _addressCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: AppTextField(label: 'Ville', controller: _cityCtrl)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: AppTextField(label: 'NIF', controller: _taxCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: AppTextField(label: 'RC', controller: _rcCtrl)),
                    ]),
                    const SizedBox(height: 16),
                    AppTextField(label: 'Notes', controller: _notesCtrl, maxLines: 2),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                const Spacer(),
                AppButton(label: 'Enregistrer', icon: Icons.save_rounded, onPressed: _save),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final supplier = Supplier(
      id: widget.existing?.id ?? const Uuid().v4(),
      code: _codeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      taxId: _taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim(),
      rc: _rcCtrl.text.trim().isEmpty ? null : _rcCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    if (widget.existing == null) {
      context.read<SuppliersBloc>().add(AddSupplier(supplier));
    } else {
      context.read<SuppliersBloc>().add(UpdateSupplier(supplier));
    }
    Navigator.pop(context);
  }
}
