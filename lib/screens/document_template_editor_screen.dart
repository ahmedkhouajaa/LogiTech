import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/document_templates/document_templates_bloc.dart';
import '../models/document_template.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/template_editor_widgets.dart';
import '../widgets/template_preview_widget.dart';

class DocumentTemplateEditorScreen extends StatefulWidget {
  final DocumentTemplate template;

  const DocumentTemplateEditorScreen({super.key, required this.template});

  @override
  State<DocumentTemplateEditorScreen> createState() =>
      _DocumentTemplateEditorScreenState();
}

class _DocumentTemplateEditorScreenState
    extends State<DocumentTemplateEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _config;
  late String _name;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _config = Map<String, dynamic>.from(widget.template.config);
    _name = widget.template.name;
    // Deep-copy nested maps
    for (final key in _config.keys.toList()) {
      if (_config[key] is Map) {
        _config[key] = Map<String, dynamic>.from(_config[key] as Map);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateConfig(String key, dynamic value) {
    setState(() {
      _config[key] = value;
      _hasChanges = true;
    });
  }

  void _updateNestedConfig(String parent, String key, dynamic value) {
    setState(() {
      final map = Map<String, dynamic>.from(
          _config[parent] as Map<String, dynamic>? ?? {});
      map[key] = value;
      _config[parent] = map;
      _hasChanges = true;
    });
  }

  void _save() {
    final updated = widget.template.copyWith(
      name: _name,
      config: Map<String, dynamic>.from(_config),
      updatedAt: DateTime.now(),
    );
    context.read<DocumentTemplatesBloc>().add(UpdateDocumentTemplate(updated));
    setState(() => _hasChanges = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Modèle enregistré avec succès'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser ?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Toutes les modifications seront remplacées par les valeurs par défaut. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _config = DocumentTemplate.defaultConfig();
                _hasChanges = true;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  DocumentTemplate get _previewTemplate =>
      widget.template.copyWith(config: _config, name: _name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Top bar
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
              boxShadow: AppShadows.sm,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Text('Éditeur de modèle',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (_hasChanges)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Text('Non enregistré',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning)),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(_name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Row(
              children: [
                // Left: Preview
                Expanded(
                  flex: 4,
                  child: TemplatePreviewWidget(
                    template: _previewTemplate,
                    onPositionChanged: (itemKey, newX, newY) {
                      setState(() {
                        final map = Map<String, dynamic>.from(
                            _config[itemKey] as Map<String, dynamic>? ?? {});
                        map['positionX'] = newX;
                        if (itemKey != 'totals') {
                          map['positionY'] = newY;
                        }
                        _config[itemKey] = map;
                        _hasChanges = true;
                      });
                    },
                  ),
                ),
                // Right: Editor tabs
                Expanded(
                  flex: 5,
                  child: Container(
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        // Tab bar
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textSecondary,
                            indicatorColor: AppColors.primary,
                            labelStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            tabs: const [
                              Tab(text: 'Champs'),
                              Tab(text: 'Décorations'),
                              Tab(text: 'Styles'),
                              Tab(text: 'Totaux'),
                              Tab(text: 'E-Facture'),
                            ],
                          ),
                        ),
                        // Tab content
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildFieldsTab(),
                              _buildDecorationsTab(),
                              _buildStylesTab(),
                              _buildTotalsTab(),
                              _buildEFactureTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ─── Tab Builders ──────────────────────────────────────────────────

  Widget _buildFieldsTab() {
    final columns = List<Map<String, dynamic>>.from(_config['tableColumns'] ?? DocumentTemplate.defaultConfig()['tableColumns']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Configurez les colonnes visibles dans le tableau de votre document : désignation, quantité, prix unitaire, TVA, etc.',
          ),
          const SizedBox(height: 16),
          ...columns.asMap().entries.map((entry) {
            final index = entry.key;
            final col = entry.value;
            return _buildFieldToggle(
              col['label'] as String,
              col['visible'] as bool,
              (v) {
                setState(() {
                  columns[index]['visible'] = v;
                  _config['tableColumns'] = columns;
                  _hasChanges = true;
                });
              },
              onDelete: col['type'] == 'custom'
                  ? () {
                      setState(() {
                        columns.removeAt(index);
                        _config['tableColumns'] = columns;
                        _hasChanges = true;
                      });
                    }
                  : null,
            );
          }),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addCustomColumn,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter une colonne personnalisée'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _addCustomColumn() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle colonne'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(labelText: 'Nom de la colonne', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                setState(() {
                  final columns = List<Map<String, dynamic>>.from(_config['tableColumns'] ?? DocumentTemplate.defaultConfig()['tableColumns']);
                  columns.insert(columns.length - 1, {
                    'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    'label': textController.text.trim(),
                    'visible': true,
                    'type': 'custom',
                  });
                  _config['tableColumns'] = columns;
                  _hasChanges = true;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldToggle(String label, bool enabled, ValueChanged<bool>? onChanged, {VoidCallback? onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          if (onDelete != null) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              onPressed: onDelete,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
          ],
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDecorationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Configurez les éléments décoratifs de votre document : bordures, filigrane, en-tête et pied de page personnalisés.',
          ),
          const SizedBox(height: 16),
          // Table border settings
          TemplateSectionHeader(title: 'Bordures du tableau'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TemplateColorPicker(
                  label: 'Couleur bordure',
                  color: Color(_getTableVal('borderColor', 0xFFE2E8F0)),
                  onChanged: (c) => _updateNestedConfig('table', 'borderColor', c.toARGB32()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TemplateMeasurementInput(
                  label: 'Épaisseur bordure',
                  value: _getTableDoubleVal('borderWidth', 0.3),
                  unit: 'pt',
                  onChanged: (v) => _updateNestedConfig('table', 'borderWidth', v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _getTableBoolVal('showOutline', true),
                onChanged: (v) => _updateNestedConfig('table', 'showOutline', v ?? true),
                activeColor: AppColors.primary,
              ),
              const Text('Afficher le contour du tableau', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _getTableBoolVal('fixedHeight', false),
                onChanged: (v) => _updateNestedConfig('table', 'fixedHeight', v ?? false),
                activeColor: AppColors.primary,
              ),
              const Expanded(
                child: Text(
                  'Hauteur fixe du tableau (remplir avec des lignes vides sur la première page)',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStylesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Personnalisez l\'apparence globale de votre document : style du tableau, couleurs d\'en-tête, taille de police et hauteur des lignes.',
          ),
          const SizedBox(height: 16),
          // Table style radio buttons
          TemplateSectionHeader(title: 'Style du tableau'),
          const SizedBox(height: 8),
          _buildRadioGroup([
            ('classique', 'Classique', 'Bordures complètes'),
            ('alterne', 'Alterné', 'Lignes alternées colorées'),
            ('minimaliste', 'Minimaliste', 'Bordures minimales'),
          ]),
          const SizedBox(height: 20),
          // Header colors
          Row(
            children: [
              Expanded(
                child: TemplateColorPicker(
                  label: 'Fond en-tête',
                  color: Color(_config['headerBgColor'] as int? ?? 0xFF1a56db),
                  onChanged: (c) => _updateConfig('headerBgColor', c.toARGB32()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TemplateColorPicker(
                  label: 'Texte en-tête',
                  color: Color(_config['headerTextColor'] as int? ?? 0xFFFFFFFF),
                  onChanged: (c) => _updateConfig('headerTextColor', c.toARGB32()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TemplateMeasurementInput(
                  label: 'Taille police',
                  value: (_config['fontSize'] as num?)?.toDouble() ?? 10,
                  unit: 'pt',
                  onChanged: (v) => _updateConfig('fontSize', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TemplateMeasurementInput(
                  label: 'Hauteur ligne',
                  value: (_config['rowHeight'] as num?)?.toDouble() ?? 8,
                  onChanged: (v) => _updateConfig('rowHeight', v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Configurez l\'apparence de la section des totaux : Total Brut, Remises, Total HT, Taxes et Total TTC.',
          ),
          const SizedBox(height: 16),
          // Position section
          TemplateSectionHeader(title: 'Position des totaux'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TemplateMeasurementInput(
                  label: 'Position X',
                  value: _getTotalsVal('positionX', 130),
                  onChanged: (v) => _updateNestedConfig('totals', 'positionX', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TemplateMeasurementInput(
                  label: 'Largeur',
                  value: _getTotalsVal('width', 65),
                  onChanged: (v) => _updateNestedConfig('totals', 'width', v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TemplateMeasurementInput(
                  label: 'Espacement lignes',
                  value: _getTotalsVal('lineSpacing', 7),
                  onChanged: (v) => _updateNestedConfig('totals', 'lineSpacing', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TemplateMeasurementInput(
                  label: 'Largeur étiquettes',
                  value: _getTotalsVal('labelWidth', 35),
                  onChanged: (v) => _updateNestedConfig('totals', 'labelWidth', v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Total Brut
          TotalFieldEditor(
            title: 'Total Brut',
            config: _getSubConfig('totalBrut'),
            onChanged: (c) => _updateConfig('totalBrut', c),
          ),
          // Total Remises
          TotalFieldEditor(
            title: 'Total Remises',
            config: _getSubConfig('totalRemises'),
            onChanged: (c) => _updateConfig('totalRemises', c),
          ),
          // Total HT
          TotalFieldEditor(
            title: 'Total HT',
            config: _getSubConfig('totalHT'),
            onChanged: (c) => _updateConfig('totalHT', c),
          ),
          // Taxes
          TotalFieldEditor(
            title: 'Lignes de Taxes',
            config: _getSubConfig('taxes'),
            onChanged: (c) => _updateConfig('taxes', c),
          ),
          // Total TTC
          TotalFieldEditor(
            title: 'Total TTC',
            titleColor: AppColors.primary,
            config: _getSubConfig('totalTTC'),
            onChanged: (c) => _updateConfig('totalTTC', c),
            extraWidgets: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5EE),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _getSubConfig('totalTTC')['showColoredBg'] as bool? ?? true,
                          onChanged: (v) {
                            final c = Map<String, dynamic>.from(_getSubConfig('totalTTC'));
                            c['showColoredBg'] = v ?? true;
                            _updateConfig('totalTTC', c);
                          },
                          activeColor: AppColors.primary,
                        ),
                        const Text('Afficher le fond coloré',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (_getSubConfig('totalTTC')['showColoredBg'] == true) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TemplateColorPicker(
                              label: 'Couleur fond',
                              color: Color(_getSubConfig('totalTTC')['bgColor'] as int? ?? 0xFF2D3748),
                              onChanged: (c) {
                                final cfg = Map<String, dynamic>.from(_getSubConfig('totalTTC'));
                                cfg['bgColor'] = c.toARGB32();
                                _updateConfig('totalTTC', cfg);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TemplateMeasurementInput(
                              label: 'Padding',
                              value: (_getSubConfig('totalTTC')['padding'] as num?)?.toDouble() ?? 4,
                              onChanged: (v) {
                                final cfg = Map<String, dynamic>.from(_getSubConfig('totalTTC'));
                                cfg['padding'] = v;
                                _updateConfig('totalTTC', cfg);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Total en lettres
          TotalFieldEditor(
            title: 'Total en lettres',
            config: _getSubConfig('totalLetters'),
            onChanged: (c) => _updateConfig('totalLetters', c),
          ),
        ],
      ),
    );
  }

  Widget _buildEFactureTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Configurez l\'affichage des éléments E-Facture (El-Fatoora) sur vos factures : QR Code, référence TTN, date de soumission et badge de statut.',
          ),
          const SizedBox(height: 16),

          // ─── QR Code ────────────────────────────────────
          TemplateEnableHeader(
            title: 'Code QR El-Fatoora',
            enabled: _getSubConfig('qrCode')['enabled'] as bool? ?? true,
            onChanged: (v) => _updateNestedConfig('qrCode', 'enabled', v),
          ),
          if (_getSubConfig('qrCode')['enabled'] == true) ...[
            TemplatePositionFields(
              positionX: _getSubDbl('qrCode', 'positionX', 15),
              positionY: _getSubDbl('qrCode', 'positionY', 98),
              onXChanged: (v) => _updateNestedConfig('qrCode', 'positionX', v),
              onYChanged: (v) => _updateNestedConfig('qrCode', 'positionY', v),
            ),
            const SizedBox(height: 12),
            TemplateDimensionFields(
              width: _getSubDbl('qrCode', 'width', 25),
              height: _getSubDbl('qrCode', 'height', 25),
              onWidthChanged: (v) => _updateNestedConfig('qrCode', 'width', v),
              onHeightChanged: (v) => _updateNestedConfig('qrCode', 'height', v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _getSubConfig('qrCode')['showLabel'] as bool? ?? true,
                  onChanged: (v) => _updateNestedConfig('qrCode', 'showLabel', v ?? true),
                  activeColor: AppColors.primary,
                ),
                const Text('Afficher étiquette', style: TextStyle(fontSize: 14)),
              ],
            ),
            if (_getSubConfig('qrCode')['showLabel'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildTextInput(
                  'Texte étiquette',
                  _getSubConfig('qrCode')['labelText'] as String? ?? 'E-Facture',
                  (v) => _updateNestedConfig('qrCode', 'labelText', v),
                ),
              ),
          ],

          const SizedBox(height: 16),

          // ─── Référence TTN ──────────────────────────────
          TemplateEnableHeader(
            title: 'Référence TTN',
            enabled: _getSubConfig('ttnReference')['enabled'] as bool? ?? true,
            onChanged: (v) => _updateNestedConfig('ttnReference', 'enabled', v),
          ),
          if (_getSubConfig('ttnReference')['enabled'] == true) ...[
            TemplatePositionFields(
              positionX: _getSubDbl('ttnReference', 'positionX', 45),
              positionY: _getSubDbl('ttnReference', 'positionY', 99),
              onXChanged: (v) => _updateNestedConfig('ttnReference', 'positionX', v),
              onYChanged: (v) => _updateNestedConfig('ttnReference', 'positionY', v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TemplateMeasurementInput(
                    label: 'Taille',
                    value: _getSubDbl('ttnReference', 'fontSize', 9),
                    unit: 'pt',
                    onChanged: (v) => _updateNestedConfig('ttnReference', 'fontSize', v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TemplateColorPicker(
                    label: 'Couleur',
                    color: Color(_getSubConfig('ttnReference')['color'] as int? ?? 0xFF1a56db),
                    onChanged: (c) => _updateNestedConfig('ttnReference', 'color', c.toARGB32()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TemplateFontStyleSelector(
              label: 'Graisse',
              value: _getSubConfig('ttnReference')['fontWeight'] as String? ?? 'Gras',
              onChanged: (v) => _updateNestedConfig('ttnReference', 'fontWeight', v),
              options: const ['Normal', 'Gras', 'Graisse'],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _getSubConfig('ttnReference')['showLabel'] as bool? ?? true,
                  onChanged: (v) => _updateNestedConfig('ttnReference', 'showLabel', v ?? true),
                  activeColor: AppColors.primary,
                ),
                const Text('Afficher étiquette', style: TextStyle(fontSize: 14)),
              ],
            ),
            if (_getSubConfig('ttnReference')['showLabel'] == true)
              _buildTextInput(
                'Texte étiquette',
                _getSubConfig('ttnReference')['labelText'] as String? ?? 'Réf TTN:',
                (v) => _updateNestedConfig('ttnReference', 'labelText', v),
              ),
          ],

          const SizedBox(height: 16),

          // ─── Date de soumission ─────────────────────────
          TemplateEnableHeader(
            title: 'Date de soumission',
            enabled: _getSubConfig('submissionDate')['enabled'] as bool? ?? true,
            onChanged: (v) => _updateNestedConfig('submissionDate', 'enabled', v),
          ),
          if (_getSubConfig('submissionDate')['enabled'] == true) ...[
            TemplatePositionFields(
              positionX: _getSubDbl('submissionDate', 'positionX', 45),
              positionY: _getSubDbl('submissionDate', 'positionY', 232),
              onXChanged: (v) => _updateNestedConfig('submissionDate', 'positionX', v),
              onYChanged: (v) => _updateNestedConfig('submissionDate', 'positionY', v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TemplateMeasurementInput(
                    label: 'Taille',
                    value: _getSubDbl('submissionDate', 'fontSize', 8),
                    unit: 'pt',
                    onChanged: (v) => _updateNestedConfig('submissionDate', 'fontSize', v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TemplateColorPicker(
                    label: 'Couleur',
                    color: Color(_getSubConfig('submissionDate')['color'] as int? ?? 0xFF000000),
                    onChanged: (c) => _updateNestedConfig('submissionDate', 'color', c.toARGB32()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _getSubConfig('submissionDate')['showLabel'] as bool? ?? true,
                  onChanged: (v) => _updateNestedConfig('submissionDate', 'showLabel', v ?? true),
                  activeColor: AppColors.primary,
                ),
                const Text('Afficher étiquette', style: TextStyle(fontSize: 14)),
              ],
            ),
            if (_getSubConfig('submissionDate')['showLabel'] == true)
              _buildTextInput(
                'Texte étiquette',
                _getSubConfig('submissionDate')['labelText'] as String? ?? 'Envoyé le:',
                (v) => _updateNestedConfig('submissionDate', 'labelText', v),
              ),
          ],

          const SizedBox(height: 16),

          // ─── Badge de statut ────────────────────────────
          TemplateEnableHeader(
            title: 'Badge de statut',
            enabled: _getSubConfig('statusBadge')['enabled'] as bool? ?? true,
            onChanged: (v) => _updateNestedConfig('statusBadge', 'enabled', v),
          ),
          if (_getSubConfig('statusBadge')['enabled'] == true) ...[
            TemplatePositionFields(
              positionX: _getSubDbl('statusBadge', 'positionX', 45),
              positionY: _getSubDbl('statusBadge', 'positionY', 239),
              onXChanged: (v) => _updateNestedConfig('statusBadge', 'positionX', v),
              onYChanged: (v) => _updateNestedConfig('statusBadge', 'positionY', v),
            ),
            const SizedBox(height: 12),
            TemplateDimensionFields(
              width: _getSubDbl('statusBadge', 'width', 40),
              height: _getSubDbl('statusBadge', 'height', 6),
              onWidthChanged: (v) => _updateNestedConfig('statusBadge', 'width', v),
              onHeightChanged: (v) => _updateNestedConfig('statusBadge', 'height', v),
            ),
            const SizedBox(height: 12),
            TemplateMeasurementInput(
              label: 'Taille',
              value: _getSubDbl('statusBadge', 'fontSize', 8),
              unit: 'pt',
              onChanged: (v) => _updateNestedConfig('statusBadge', 'fontSize', v),
            ),
            const SizedBox(height: 16),
            // Status badge preview
            const Text('Aperçu',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _statusBadge('EN ATTENTE', const Color(0xFFF59E0B)),
                _statusBadge('ENVOYÉ', const Color(0xFF3B82F6)),
                _statusBadge('VALIDÉ', const Color(0xFF10B981)),
                _statusBadge('REJETÉ', const Color(0xFFEF4444)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restore_rounded, size: 16),
            label: const Text('Réinitialiser aux valeurs par défaut'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const Spacer(),
          AppButton(
            label: 'Annuler',
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          AppButton(
            label: 'Enregistrer le modèle',
            icon: Icons.save_rounded,
            onPressed: _hasChanges ? _save : null,
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioGroup(List<(String, String, String)> options) {
    final currentStyle = _config['tableStyle'] as String? ?? 'classique';
    return Column(
      children: options.map((opt) {
        return RadioListTile<String>(
          title: Text(opt.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(opt.$3, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          value: opt.$1,
          groupValue: currentStyle,
          onChanged: (v) => _updateConfig('tableStyle', v),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }

  Widget _buildTextInput(String label, String value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  // ─── Config Accessors ──────────────────────────────────────────────

  Map<String, dynamic> _getSubConfig(String key) =>
      Map<String, dynamic>.from(_config[key] as Map<String, dynamic>? ?? {});

  double _getTotalsVal(String key, double fallback) {
    final totals = _config['totals'] as Map<String, dynamic>?;
    return (totals?[key] as num?)?.toDouble() ?? fallback;
  }

  double _getSubDbl(String parent, String key, double fallback) {
    final map = _config[parent] as Map<String, dynamic>?;
    return (map?[key] as num?)?.toDouble() ?? fallback;
  }

  int _getTableVal(String key, int fallback) {
    final table = _config['table'] as Map<String, dynamic>?;
    return table?[key] as int? ?? fallback;
  }

  double _getTableDoubleVal(String key, double fallback) {
    final table = _config['table'] as Map<String, dynamic>?;
    return (table?[key] as num?)?.toDouble() ?? fallback;
  }

  bool _getTableBoolVal(String key, bool fallback) {
    final table = _config['table'] as Map<String, dynamic>?;
    return table?[key] as bool? ?? fallback;
  }
}
