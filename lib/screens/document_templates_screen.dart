import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/document_templates/document_templates_bloc.dart';
import '../models/document_template.dart';
import '../database/database_helper.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';
import '../widgets/custom_app_bar.dart';
import 'document_template_editor_screen.dart';
import 'package:business_manager_pro/widgets/app_error_widget.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';

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
        Builder(
          builder: (context) {
            final isMobile = MediaQuery.of(context).size.width < 600;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMobile) ...[
                          Text(
                            context.tr('Modèles de documents'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          '${templates.length} modèle${templates.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (PermissionService.instance.canCreate(UserPermissionResources.settingsDocTemplates))
                    ElevatedButton.icon(
                      onPressed: () => _createTemplate(context),
                      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      label: Text(
                        isMobile ? 'Nouveau' : 'Nouveau modèle',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        // Template list
        Expanded(
          child: templates.isEmpty
              ? EmptyState(
                  icon: Icons.description_outlined,
                  title: context.tr('Aucun modèle de document'),
                  subtitle: context.tr('Créez votre premier modèle pour personnaliser vos factures'),
                  action: PermissionService.instance.canCreate(UserPermissionResources.settingsDocTemplates)
                      ? AppButton(
                          label: context.tr('Créer un modèle'),
                          icon: Icons.add_rounded,
                          onPressed: () => _createTemplate(context),
                        )
                      : null,
                )
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 24,
                  ),
                  child: Builder(
                    builder: (context) {
                      final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.4);
                      final cardExtent = (205.0 * textScale).clamp(200.0, 255.0);
                      final maxCrossExtent = (380.0 * textScale).clamp(360.0, 480.0);

                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: maxCrossExtent,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: cardExtent,
                        ),
                        itemCount: templates.length,
                        itemBuilder: (context, index) => _TemplateCard(
                          template: templates[index],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _createTemplate(BuildContext context) {
    final assignedTypes = templates
        .where((t) => !t.isDefault)
        .map((t) => t.documentType)
        .toSet();
    final availableTypes = DocumentTemplate.supportedDocumentTypes
        .where((d) => !assignedTypes.contains(d['key']))
        .toList();

    if (availableTypes.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              const Text('Tous les types sont assignés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'Tous les 16 types de documents (Ventes, Achats et Stock) possèdent déjà un modèle personnalisé dédié.\n\nPour créer un nouveau modèle pour un document spécifique, vous devez d\'abord supprimer le modèle existant correspondant.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text(context.tr('Compris')),
            ),
          ],
        ),
      );
      return;
    }

    String selectedType = availableTypes.first['key'] as String;
    final nameController = TextEditingController(
      text: 'Modèle ${availableTypes.first['label']}',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text(context.tr('Nouveau modèle de document'), style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: context.tr('Nom du modèle'),
                    hint: 'Ex: Modèle Facture Standard',
                    controller: nameController,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('Type de document'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${availableTypes.length} disponible${availableTypes.length > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: availableTypes.map((d) {
                      final cat = d['category'] as String;
                      final catColor = _getCategoryColor(cat);
                      return DropdownMenuItem<String>(
                        value: d['key'] as String,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(d['icon'] as IconData, size: 15, color: catColor),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d['label'] as String,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                          final doc = availableTypes.firstWhere((d) => d['key'] == val);
                          nameController.text = 'Modèle ${doc['label']}';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final defaultTpl = templates.where((t) => t.isDefault).firstOrNull;
                final config = defaultTpl != null
                    ? Map<String, dynamic>.from(defaultTpl.config)
                    : DocumentTemplate.classicConfig();

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
              child: Text(context.tr('Créer et Personnaliser')),
            ),
          ],
        ),
      ),
    );
  }

  static Color _getCategoryColor(String category) {
    switch (category) {
      case 'Ventes':
        return const Color(0xFF1A56DB);
      case 'Achats':
        return const Color(0xFFD97706);
      case 'Stock':
        return const Color(0xFF0D9488);
      default:
        return AppColors.primary;
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Color(t.headerBgColor);
    final docLabel = DocumentTemplate.getDocumentTypeLabel(t.documentType);
    final docIcon = DocumentTemplate.getDocumentTypeIcon(t.documentType);

    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final displayName = (t.name.trim().toLowerCase() == 'classique' && t.isDefault)
        ? 'Modèle Standard'
        : t.name;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? primaryColor : borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(_hovered ? (isDark ? 60 : 18) : (isDark ? 25 : 6)),
              blurRadius: _hovered ? 12 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored Document Accent Top Stripe
              Container(
                height: 3.5,
                color: primaryColor,
              ),

              // Card Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Icon + Title + Status Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: primaryColor.withAlpha(isDark ? 40 : 18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              t.isDefault ? Icons.auto_stories_rounded : docIcon,
                              color: primaryColor,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.isDefault
                                      ? 'Par défaut (tous documents)'
                                      : 'Dédié : ${context.tr(docLabel)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.isDefault
                                        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                        : primaryColor,
                                    fontWeight: t.isDefault ? FontWeight.w500 : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (t.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(isDark ? 35 : 18),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withAlpha(isDark ? 70 : 40),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Par défaut',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: primaryColor.withAlpha(isDark ? 35 : 18),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: primaryColor.withAlpha(isDark ? 70 : 40),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Dédié',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Description
                      Text(
                        t.styleDescription.isNotEmpty
                            ? t.styleDescription
                            : 'Mise en page standard avec en-tête structuré et récapitulatif net.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const Spacer(),

                      // Clean Format & Palette Metadata (No redundant "Classic" chips)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'En-tête teinté',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Format A4',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      const SizedBox(height: 8),

                      // Actions
                      Row(
                        children: [
                          _actionBtn(
                            Icons.copy_rounded,
                            context.tr('Dupliquer'),
                            () => _duplicateTemplate(context, t),
                          ),
                          const SizedBox(width: 6),
                          _actionBtn(
                            Icons.restart_alt_rounded,
                            context.tr('Remettre à zéro (Réinitialiser)'),
                            () => _confirmReset(context, t),
                            color: const Color(0xFFF59E0B),
                          ),
                          if (!t.isDefault) ...[
                            const SizedBox(width: 6),
                            _actionBtn(
                              Icons.delete_outline_rounded,
                              context.tr('Supprimer'),
                              () => _confirmDelete(context, t),
                              color: const Color(0xFFEF4444),
                            ),
                          ],
                          const Spacer(),
                          InkWell(
                            onTap: () => _openEditor(context, t),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(isDark ? 35 : 18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withAlpha(isDark ? 70 : 40),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune_rounded, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Personnaliser',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  void _duplicateTemplate(BuildContext context, DocumentTemplate template) {
    final state = context.read<DocumentTemplatesBloc>().state;
    final allTemplates = state is DocumentTemplatesLoaded ? state.templates : <DocumentTemplate>[];
    final assignedTypes = allTemplates
        .where((t) => !t.isDefault)
        .map((t) => t.documentType)
        .toSet();
    final availableTypes = DocumentTemplate.supportedDocumentTypes
        .where((d) => !assignedTypes.contains(d['key']))
        .toList();

    if (availableTypes.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text(context.tr('Aucun document disponible'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            context.tr('Tous les 16 types de documents possèdent déjà un modèle personnalisé dédié.\n\nPour dupliquer ce modèle, vous devez d\'abord supprimer un modèle existant pour libérer son type de document.'),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text(context.tr('Compris')),
            ),
          ],
        ),
      );
      return;
    }

    final nameController = TextEditingController(text: '${template.name} (copie)');
    String targetType = availableTypes.first['key'] as String;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text(context.tr('Dupliquer le modèle'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: context.tr('Nom de la copie'),
                  controller: nameController,
                ),
                const SizedBox(height: 16),
                Text(context.tr('Assigner au type de document :'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: targetType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: availableTypes.map((d) {
                    final cat = d['category'] as String;
                    final catColor = _DocumentTemplatesBody._getCategoryColor(cat);
                    return DropdownMenuItem<String>(
                      value: d['key'] as String,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(d['icon'] as IconData, size: 14, color: catColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr(d['label'] as String),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              context.tr(cat),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => targetType = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final duplicate = template.copyWith(
                  id: DatabaseHelper.instance.newId,
                  name: name,
                  documentType: targetType,
                  isDefault: false,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                context.read<DocumentTemplatesBloc>().add(AddDocumentTemplate(duplicate));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${context.tr('Modèle dupliqué pour')} « ${context.tr(DocumentTemplate.getDocumentTypeLabel(targetType))} »'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              child: Text(context.tr('Dupliquer')),
            ),
          ],
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
            Text(context.tr('Remettre à zéro le modèle ?'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          '${context.tr('Voulez-vous réinitialiser le modèle')} « ${template.name} » ${context.tr('à ses paramètres d\'origine')} (${template.styleName}) ?\n\n${context.tr('Toutes les personnalisations et modifications apportées à ce modèle seront annulées.')}',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Annuler')),
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
                  content: Text('${context.tr('Modèle')} « ${template.name} » ${context.tr('remis à zéro avec succès')}'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              );
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(context.tr('Remettre à zéro')),
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
          content: Text(context.tr('Le modèle par défaut ne peut pas être supprimé.')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final docLabel = DocumentTemplate.getDocumentTypeLabel(template.documentType);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text(context.tr('Supprimer le modèle ?'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.tr('Voulez-vous vraiment supprimer le modèle')} « ${template.name} » ?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.tr('Les documents')} « ${context.tr(docLabel)} » ${context.tr('réutiliseront automatiquement le modèle par défaut de l\'application.')}',
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Annuler'))),
          ElevatedButton(
            onPressed: () {
              context.read<DocumentTemplatesBloc>().add(DeleteDocumentTemplate(template.id));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${context.tr('Modèle supprimé. Les documents')} « ${context.tr(docLabel)} » ${context.tr('utilisent le modèle par défaut.')}'),
                  backgroundColor: AppColors.info,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(context.tr('Supprimer')),
          ),
        ],
      ),
    );
  }
}
