import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../blocs/projects/projects_bloc.dart';
import '../../../../blocs/customers/customers_bloc.dart';
import '../../../../models/project.dart';
import '../../../../models/customer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/constants.dart';
import '../../widgets/forms/mobile_form_screen.dart';
import '../../widgets/forms/mobile_form_section.dart';
import '../../widgets/forms/mobile_smart_fields.dart';
import '../../../../widgets/searchable_dropdown_field.dart';
import '../../../../services/enterprise_service.dart';
import 'package:business_manager_pro/services/error_handler.dart';

class MobileProjectFormScreen extends StatefulWidget {
  final Project? existing;
  final bool isReadOnly;
  const MobileProjectFormScreen({super.key, this.existing, this.isReadOnly = false});

  @override
  State<MobileProjectFormScreen> createState() => _MobileProjectFormScreenState();
}

class _MobileProjectFormScreenState extends State<MobileProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _isLoading = false;

  String _name = '';
  String _description = '';
  String? _selectedCustomerId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  double _budget = 0.0;
  ProjectStatus _status = ProjectStatus.planning;
  double _progress = 0.0;
  String _notes = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(LoadCustomers());

    if (widget.existing != null) {
      final p = widget.existing!;
      _name = p.name;
      _description = p.description ?? '';
      _selectedCustomerId = p.customerId;
      _startDate = p.startDate;
      _endDate = p.endDate;
      _budget = p.budget;
      _status = p.status;
      _progress = p.progress;
      _notes = p.notes ?? '';
    }
  }

  void _save() {
    if (widget.isReadOnly) return;
    if (!_formKey.currentState!.validate()) return;
    
    if (_name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Veuillez entrer le nom du projet')), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final project = Project(
        id: widget.existing?.id ?? _uuid.v4(),
        name: _name.trim(),
        description: _description.trim().isEmpty ? null : _description.trim(),
        customerId: _selectedCustomerId,
        startDate: _startDate,
        endDate: _endDate,
        budget: _budget,
        status: _status,
        progress: _progress,
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
        enterpriseId: widget.existing?.enterpriseId ?? EnterpriseService.instance.currentEnterpriseId,
        isDeleted: widget.existing?.isDeleted ?? false,
      );

      if (widget.existing == null) {
        context.read<ProjectsBloc>().add(AddProject(project));
      } else {
        context.read<ProjectsBloc>().add(UpdateProject(project));
      }
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.existing == null ? context.tr('Projet créé avec succès') : context.tr('Projet mis à jour')),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      ErrorHandler.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFormScreen(
      title: widget.isReadOnly ? context.tr('Détails du projet') : (_isEditing ? context.tr('Modifier le projet') : context.tr('Nouveau projet')),
      isLoading: _isLoading,
      saveLabel: context.tr('Enregistrer'),
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
                title: context.tr('Informations'),
                icon: Icons.info_outline_rounded,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmartTextInput(
                        label: '${context.tr('Nom du Projet')} *',
                        initialValue: _name,
                        onChanged: (v) { if (!widget.isReadOnly) _name = v; },
                      ),
                      SizedBox(height: 16),
                      SmartTextInput(
                        label: context.tr('Description'),
                        initialValue: _description,
                        maxLines: 2,
                        onChanged: (v) { if (!widget.isReadOnly) _description = v; },
                      ),
                      SizedBox(height: 16),
                      BlocBuilder<CustomersBloc, CustomersState>(
                        builder: (context, state) {
                          final customers = state is CustomersLoaded ? state.customers : <Customer>[];
                          return AbsorbPointer(
                            absorbing: widget.isReadOnly,
                            child: SmartSearchableSelector(
                              label: context.tr('Client (Optionnel)'),
                              hint: context.tr('Aucun client'),
                              selectedText: _selectedCustomerId != null
                                  ? (customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)?.companyName?.isNotEmpty == true
                                      ? customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)!.companyName!
                                      : customers.cast<Customer?>().firstWhere((c) => c?.id == _selectedCustomerId, orElse: () => null)?.name)
                                  : null,
                              onTap: () async {
                                final res = await showCustomerSelectDialog(context, customers, selectedCustomerId: _selectedCustomerId);
                                if (res != null && mounted && !widget.isReadOnly) {
                                  setState(() => _selectedCustomerId = res);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              MobileFormSection(
                title: context.tr('Planification & Budget'),
                icon: Icons.calendar_month_outlined,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SmartDatePicker(
                              label: context.tr('Date de Début'),
                              value: _startDate,
                              onChanged: (v) { if (!widget.isReadOnly) setState(() => _startDate = v); },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: SmartDatePicker(
                              label: context.tr('Date de Fin (Opt)'),
                              value: _endDate ?? DateTime.now(),
                              onChanged: (v) { if (!widget.isReadOnly) setState(() => _endDate = v); },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      SmartTextInput(
                        label: context.tr('Budget Estimé'),
                        initialValue: _budget > 0 ? _budget.toString() : '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) { if (!widget.isReadOnly) _budget = double.tryParse(v) ?? 0; },
                      ),
                    ],
                  ),
                ),
              ),

              MobileFormSection(
                title: context.tr('Suivi & Avancement'),
                icon: Icons.track_changes_outlined,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AbsorbPointer(
                        absorbing: widget.isReadOnly,
                        child: SmartDropdown<ProjectStatus>(
                          label: context.tr('Statut du Projet'),
                          value: _status,
                          items: ProjectStatus.values.map((s) {
                            String label = '';
                            switch(s) {
                              case ProjectStatus.planning: label = context.tr('Planification'); break;
                              case ProjectStatus.active: label = context.tr('En cours'); break;
                              case ProjectStatus.onHold: label = context.tr('En pause'); break;
                              case ProjectStatus.completed: label = context.tr('Terminé'); break;
                              case ProjectStatus.cancelled: label = context.tr('Annulé'); break;
                            }
                            return DropdownMenuItem(value: s, child: Text(label, style: const TextStyle(fontSize: 16)));
                          }).toList(),
                          onChanged: (v) { if (!widget.isReadOnly && v != null) setState(() => _status = v); },
                          hint: context.tr('Statut'),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text('${context.tr('Avancement')}: ${_progress.toInt()}%', style: const TextStyle(fontWeight: FontWeight.w500)),
                      SizedBox(height: 8),
                      Slider(
                        value: _progress,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.border,
                        onChanged: widget.isReadOnly ? null : (v) => setState(() => _progress = v),
                      ),
                    ],
                  ),
                ),
              ),

              MobileFormSection(
                title: context.tr('Notes'),
                icon: Icons.notes_outlined,
                isInitiallyExpanded: false,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SmartTextInput(
                    label: context.tr('Remarques / Notes'),
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
