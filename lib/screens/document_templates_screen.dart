import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/document_templates/document_templates_bloc.dart';
import '../models/document_template.dart';
import '../database/database_helper.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import 'document_template_editor_screen.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';

class DocumentTemplatesScreen extends StatefulWidget {
  const DocumentTemplatesScreen({super.key});

  @override
  State<DocumentTemplatesScreen> createState() => _DocumentTemplatesScreenState();
}

class _DocumentTemplatesScreenState extends State<DocumentTemplatesScreen> {
  StreamSubscription<String?>? _enterpriseSub;

  @override
  void initState() {
    super.initState();
    context.read<DocumentTemplatesBloc>().add(LoadDocumentTemplates());
    _enterpriseSub = EnterpriseService.instance.enterpriseStream.listen((_) {
      if (mounted) {
        context.read<DocumentTemplatesBloc>().add(LoadDocumentTemplates());
      }
    });
  }

  @override
  void dispose() {
    _enterpriseSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentTemplatesBloc, DocumentTemplatesState>(
      builder: (context, state) {
        if (state is DocumentTemplatesLoading) {
          return Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (state is DocumentTemplatesError) {
          return AppErrorWidget(message: state.message);
        }
        final templates = state is DocumentTemplatesLoaded ? state.templates : <DocumentTemplate>[];
        return _DocumentTemplatesBody(templates: templates);
      },
    );
  }
}

class _DocumentTemplatesBody extends StatelessWidget {
  final List<DocumentTemplate> templates;
  const _DocumentTemplatesBody({required this.templates});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Text(
                '${templates.length} modèle${templates.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              AppButton(
                label: 'Nouveau modèle',
                icon: Icons.add_rounded,
                onPressed: () => _createTemplate(context),
              ),
            ],
          ),
        ),
        // Template list
        Expanded(
          child: templates.isEmpty
              ? EmptyState(
                  icon: Icons.description_outlined,
                  title: 'Aucun modèle de document',
                  subtitle: 'Créez votre premier modèle pour personnaliser vos factures',
                  action: AppButton(
                    label: 'Créer un modèle',
                    icon: Icons.add_rounded,
                    onPressed: () => _createTemplate(context),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 220,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, index) => _TemplateCard(
                      template: templates[index],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _createTemplate(BuildContext context) {
    final nameController = TextEditingController(text: 'Nouveau modèle');
    String selectedPreset = 'classic';
    String selectedType = 'invoice';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('Nouveau modèle de document', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Nom du modèle',
                    hint: 'Ex: Facture standard 2026',
                    controller: nameController,
                  ),
                  const SizedBox(height: 16),
                  const Text('Type de document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'invoice', child: Text('Facture')),
                      DropdownMenuItem(value: 'quote', child: Text('Devis')),
                      DropdownMenuItem(value: 'delivery_note', child: Text('Bon de livraison')),
                      DropdownMenuItem(value: 'customer_order', child: Text('Bon de commande')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Modèle de base (Style)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildPresetOption('classic', 'Classique', 'Bleu standard, mise en page éprouvée', const Color(0xFF1A56DB), selectedPreset, (v) => setDialogState(() => selectedPreset = v)),
                  const SizedBox(height: 6),
                  _buildPresetOption('modern', 'Moderne', 'Indigo vif, lignes alternées zébrées', const Color(0xFF2563EB), selectedPreset, (v) => setDialogState(() => selectedPreset = v)),
                  const SizedBox(height: 6),
                  _buildPresetOption('minimalist', 'Minimaliste', 'Épuré, sans bordures, blanc et gris', const Color(0xFF111827), selectedPreset, (v) => setDialogState(() => selectedPreset = v)),
                  const SizedBox(height: 6),
                  _buildPresetOption('professional', 'Professionnel', 'Bleu nuit corporate, double signature', const Color(0xFF0F2942), selectedPreset, (v) => setDialogState(() => selectedPreset = v)),
                  const SizedBox(height: 6),
                  _buildPresetOption('colorful', 'Coloré', 'Émeraude / Sarcelle dynamique', const Color(0xFF0D9488), selectedPreset, (v) => setDialogState(() => selectedPreset = v)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                Map<String, dynamic> config;
                switch (selectedPreset) {
                  case 'modern':
                    config = DocumentTemplate.modernConfig();
                    break;
                  case 'minimalist':
                    config = DocumentTemplate.minimalistConfig();
                    break;
                  case 'professional':
                    config = DocumentTemplate.professionalConfig();
                    break;
                  case 'colorful':
                    config = DocumentTemplate.colorfulConfig();
                    break;
                  case 'classic':
                  default:
                    config = DocumentTemplate.classicConfig();
                    break;
                }

                final eid = EnterpriseService.instance.currentEnterpriseId ?? '';
                final template = DocumentTemplate(
                  id: DatabaseHelper.instance.newId,
                  name: name,
                  documentType: selectedType,
                  enterpriseId: eid,
                  config: config,
                );
                context.read<DocumentTemplatesBloc>().add(AddDocumentTemplate(template));
                Navigator.pop(ctx);
                _openEditor(context, template);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: const Text('Créer et Personnaliser'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetOption(String code, String title, String subtitle, Color color, String currentSelected, ValueChanged<String> onSelect) {
    final isSelected = currentSelected == code;
    return InkWell(
      onTap: () => onSelect(code),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? color : AppColors.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, DocumentTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DocumentTemplatesBloc>(),
          child: DocumentTemplateEditorScreen(template: template),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final DocumentTemplate template;

  const _TemplateCard({required this.template});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final primaryColor = Color(t.headerBgColor);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _hovered ? primaryColor : (t.isDefault ? primaryColor.withValues(alpha: 0.5) : AppColors.border),
            width: _hovered || t.isDefault ? 1.5 : 1,
          ),
          boxShadow: _hovered ? AppShadows.md : AppShadows.sm,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _openEditor(context, t),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.description_rounded, color: Color(t.headerTextColor), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _documentTypeLabel(t.documentType),
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (t.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 13, color: AppColors.success),
                            const SizedBox(width: 3),
                            Text(
                              'Par défaut',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (t.styleDescription.isNotEmpty)
                  Text(
                    t.styleDescription,
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const Spacer(),
                // Template style preview chips
                Row(
                  children: [
                    _chip(_tableStyleLabel(t.tableStyle), primaryColor),
                    const SizedBox(width: 8),
                    _chip(t.styleCode.toUpperCase(), AppColors.textTertiary),
                  ],
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    _actionBtn(Icons.edit_rounded, 'Modifier (Config)', () => _openEditor(context, t)),
                    const SizedBox(width: 8),
                    _actionBtn(Icons.copy_rounded, 'Dupliquer', () {
                      context.read<DocumentTemplatesBloc>().add(DuplicateDocumentTemplate(t));
                    }),
                    const SizedBox(width: 8),
                    _actionBtn(
                      Icons.restart_alt_rounded,
                      'Remettre à zéro (Réinitialiser)',
                      () => _confirmReset(context, t),
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    if (!t.isDefault)
                      _actionBtn(
                        Icons.star_outline_rounded,
                        'Définir par défaut',
                        () {
                          context.read<DocumentTemplatesBloc>().add(SetDefaultDocumentTemplate(t.id, t.documentType));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Modèle "${t.name}" défini par défaut'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        color: AppColors.primary,
                      ),
                    const Spacer(),
                    if (!t.isDefault)
                      _actionBtn(Icons.delete_outline_rounded, 'Supprimer', () => _confirmDelete(context, t),
                          color: AppColors.error),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (color ?? AppColors.textSecondary).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, DocumentTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DocumentTemplatesBloc>(),
          child: DocumentTemplateEditorScreen(template: template),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, DocumentTemplate template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 10),
            const Text('Remettre à zéro le modèle ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Voulez-vous réinitialiser le modèle « ${template.name} » à ses paramètres d\'origine (${template.styleName}) ?\n\nToutes les personnalisations et modifications apportées à ce modèle seront annulées.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final pristineConfig = template.getPristinePresetConfig();
              final resetTemplate = template.copyWith(
                config: pristineConfig,
                updatedAt: DateTime.now(),
              );
              context.read<DocumentTemplatesBloc>().add(UpdateDocumentTemplate(resetTemplate));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Modèle « ${template.name} » remis à zéro avec succès'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              );
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Remettre à zéro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentTemplate template) {
    if (template.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Le modèle par défaut ne peut pas être supprimé.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le modèle ?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer le modèle "${template.name}" ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              context.read<DocumentTemplatesBloc>().add(DeleteDocumentTemplate(template.id));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _documentTypeLabel(String type) {
    switch (type) {
      case 'invoice':
        return 'Facture';
      case 'quote':
        return 'Devis';
      case 'delivery_note':
        return 'Bon de livraison';
      case 'customer_order':
        return 'Bon de commande';
      default:
        return 'Document';
    }
  }

  String _tableStyleLabel(String style) {
    switch (style) {
      case 'alterne':
        return 'Lignes alternées';
      case 'minimaliste':
        return 'Minimaliste';
      case 'classique':
      default:
        return 'Classique';
    }
  }
}
