import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/document_templates/document_templates_bloc.dart';
import '../models/document_template.dart';
import '../models/canvas/canvas_element.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import 'document_template_editor_screen.dart';
import 'designer/invoice_designer_screen.dart';

class DocumentTemplatesScreen extends StatelessWidget {
  const DocumentTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentTemplatesBloc, DocumentTemplatesState>(
      builder: (context, state) {
        if (state is DocumentTemplatesLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (state is DocumentTemplatesError) {
          return Center(child: Text('Erreur: ${state.message}'));
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
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const Spacer(),
              AppButton(
                label: 'Designer avancé',
                icon: Icons.design_services_rounded,
                isPrimary: false,
                onPressed: () {
                  final newTemplate = DocumentTemplate(
                    id: DatabaseHelper.instance.newId,
                    name: 'Modèle visuel ${templates.length + 1}',
                    documentType: 'invoice',
                    config: {
                      'canvas_document': CanvasDocument.defaultInvoiceTemplate().toJson(),
                    },
                  );
                  context.read<DocumentTemplatesBloc>().add(AddDocumentTemplate(newTemplate));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<DocumentTemplatesBloc>(),
                        child: InvoiceDesignerScreen(initialTemplate: newTemplate),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
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
                      maxCrossAxisExtent: 380,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 200,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau modèle', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: AppTextField(
            label: 'Nom du modèle',
            hint: 'Ex: Facture standard',
            controller: nameController,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final template = DocumentTemplate(
                id: DatabaseHelper.instance.newId,
                name: name,
              );
              context.read<DocumentTemplatesBloc>().add(AddDocumentTemplate(template));
              Navigator.pop(ctx);
              _openEditor(context, template);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Créer'),
          ),
        ],
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: _hovered ? AppColors.primary : AppColors.border, width: _hovered ? 2 : 1),
          boxShadow: _hovered ? AppShadows.md : AppShadows.sm,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _openEditor(context, t),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.description_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            _documentTypeLabel(t.documentType),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (t.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Text('Par défaut', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ),
                  ],
                ),
                const Spacer(),
                // Template style preview chips
                Row(
                  children: [
                    _chip(t.tableStyle, Color(t.headerBgColor)),
                    const SizedBox(width: 8),
                    _chip('${t.fontSize.toInt()} pt', AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                // Actions
                Row(
                  children: [
                    _actionBtn(Icons.edit_rounded, 'Modifier (Config)', () => _openEditor(context, t)),
                    const SizedBox(width: 8),
                    _actionBtn(Icons.design_services_rounded, 'Designer visuel', () => _openVisualDesigner(context, t)),
                    const SizedBox(width: 8),
                    _actionBtn(Icons.copy_rounded, 'Dupliquer', () {
                      context.read<DocumentTemplatesBloc>().add(DuplicateDocumentTemplate(t));
                    }),
                    const SizedBox(width: 8),
                    if (!t.isDefault)
                      _actionBtn(Icons.star_outline_rounded, 'Par défaut', () {
                        context.read<DocumentTemplatesBloc>().add(SetDefaultDocumentTemplate(t.id, t.documentType));
                      }),
                    const Spacer(),
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
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
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

  void _openVisualDesigner(BuildContext context, DocumentTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DocumentTemplatesBloc>(),
          child: InvoiceDesignerScreen(initialTemplate: template),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentTemplate template) {
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
      case 'invoice': return 'Facture';
      case 'quote': return 'Devis';
      case 'delivery_note': return 'Bon de livraison';
      default: return 'Document';
    }
  }
}
