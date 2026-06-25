import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/projects/projects_bloc.dart';
import '../models/project.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'custom_app_bar.dart';

class CreateProjectDialog extends StatefulWidget {
  final Project? project;
  const CreateProjectDialog({super.key, this.project});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _costController;
  late final TextEditingController _revenueController;
  
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descController = TextEditingController(text: widget.project?.description ?? '');
    _costController = TextEditingController(text: widget.project?.budget.toStringAsFixed(2) ?? '0.00');
    _revenueController = TextEditingController(text: '0.00'); // Assuming revenue isn't stored in budget
    _startDate = widget.project?.startDate;
    _endDate = widget.project?.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _costController.dispose();
    _revenueController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (widget.project != null) {
        final updated = widget.project!.copyWith(
          name: _nameController.text,
          description: _descController.text.isEmpty ? null : _descController.text,
          startDate: _startDate ?? DateTime.now(),
          endDate: _endDate,
          budget: double.tryParse(_costController.text) ?? 0,
        );
        context.read<ProjectsBloc>().add(UpdateProject(updated));
      } else {
        final project = Project(
          id: const Uuid().v4(),
          name: _nameController.text,
          description: _descController.text.isEmpty ? null : _descController.text,
          startDate: _startDate ?? DateTime.now(),
          endDate: _endDate,
          budget: double.tryParse(_costController.text) ?? 0,
          status: ProjectStatus.planning,
        );
        context.read<ProjectsBloc>().add(AddProject(project));
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart ? 'SÉLECTIONNER LA DATE DE DÉBUT' : 'SÉLECTIONNER LA DATE DE FIN',
      cancelText: 'ANNULER',
      confirmText: 'CONFIRMER',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary, // header background color and selected day color
              onPrimary: Colors.white, // header text color and selected day text color
              onSurface: AppColors.textPrimary, // body text color
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary, // button text color
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              backgroundColor: Colors.white,
              elevation: 10,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      elevation: 10,
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                border: const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.project != null ? 'Modifier le Projet' : 'Créer un Nouveau Projet', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(widget.project != null ? 'Modifiez les informations du projet ci-dessous.' : 'Remplissez les informations ci-dessous pour initialiser le projet.', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 24, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Informations Générales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Nom du Projet',
                        controller: _nameController,
                        hint: 'Saisissez le nom du projet',
                        validator: (v) => v == null || v.isEmpty ? 'Ce champ est requis' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Description',
                        controller: _descController,
                        hint: 'Saisissez la description du projet (optionnel)',
                        maxLines: 3,
                      ),
                      
                      const SizedBox(height: AppSpacing.xl),
                      const Text('Planification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, true),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date de Début Prévue',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Text(_startDate != null ? formatDate(_startDate!) : 'Sélectionner la date', style: TextStyle(color: _startDate != null ? AppColors.textPrimary : AppColors.textTertiary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date de Fin Prévue',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 10),
                                    Text(_endDate != null ? formatDate(_endDate!) : 'Sélectionner la date', style: TextStyle(color: _endDate != null ? AppColors.textPrimary : AppColors.textTertiary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: AppSpacing.xl),
                      const Text('Détails Financiers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Budget Alloué (Coût Estimé)',
                              controller: _costController,
                              prefix: const Icon(Icons.payments_outlined, size: 18, color: AppColors.textSecondary),
                              suffix: const Padding(
                                padding: EdgeInsets.only(top: 14, right: 12),
                                child: Text('TND', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              label: 'Revenu Estimé',
                              controller: _revenueController,
                              prefix: const Icon(Icons.trending_up_rounded, size: 18, color: AppColors.success),
                              suffix: const Padding(
                                padding: EdgeInsets.only(top: 14, right: 12),
                                child: Text('TND', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Confirmer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
