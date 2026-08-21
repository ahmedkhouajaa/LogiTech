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
  bool _showMobilePreview = true;

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
    _config['companyInfo'] = Map<String, dynamic>.from(_config['companyInfo'] as Map? ?? DocumentTemplate.defaultCompanyInfo());
    _config['documentInfo'] = Map<String, dynamic>.from(_config['documentInfo'] as Map? ?? DocumentTemplate.defaultDocumentInfo());
    _config['clientInfo'] = Map<String, dynamic>.from(_config['clientInfo'] as Map? ?? DocumentTemplate.defaultClientInfo());
    _config['tableColumns'] = List<Map<String, dynamic>>.from(
      (_config['tableColumns'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)) ?? DocumentTemplate.defaultTableColumns(),
    );
    _config['footer'] = Map<String, dynamic>.from(_config['footer'] as Map? ?? DocumentTemplate.defaultFooter());
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 10),
            const Text('Remettre à zéro le modèle ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Toutes les modifications apportées à « ${widget.template.name} » seront effacées et le modèle sera remis à sa configuration d\'origine (${widget.template.styleName.isNotEmpty ? widget.template.styleName : "Classique"}).\n\nSouhaitez-vous continuer ?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _config = widget.template.getPristinePresetConfig();
                _hasChanges = true;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Modèle réinitialisé aux valeurs d\'origine. N\'oubliez pas d\'enregistrer.'),
                  backgroundColor: AppColors.warning,
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

  void _openFullScreenPreview() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.preview_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Aperçu A4 plein écran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: _buildPreviewWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DocumentTemplate get _previewTemplate =>
      widget.template.copyWith(config: _config, name: _name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 850;
          return Column(
            children: [
              // Top bar
              _buildTopBar(isMobile),
              // Main content
              Expanded(
                child: isMobile
                    ? Column(
                        children: [
                          // Live A4 Preview Card (takes ~2/3 of space when expanded, flex: 5)
                          if (_showMobilePreview)
                            Expanded(
                              flex: 5,
                              child: _buildMobilePreviewCard(),
                            )
                          else
                            _buildMobileCollapsedPreviewHeader(),
                          // Options & Checkboxes Tabs (takes ~1/3 of space or remaining space, flex: 3, fully scrollable)
                          Expanded(
                            flex: _showMobilePreview ? 3 : 1,
                            child: _buildEditorTabs(isMobile),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Left: Preview
                          Expanded(
                            flex: 4,
                            child: _buildPreviewWidget(),
                          ),
                          // Right: Editor tabs
                          Expanded(
                            flex: 5,
                            child: _buildEditorTabs(isMobile),
                          ),
                        ],
                      ),
              ),
              // Bottom bar
              _buildBottomBar(isMobile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.sm,
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: isMobile ? 36 : 40, minHeight: isMobile ? 36 : 40),
          ),
          SizedBox(width: isMobile ? 4 : 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Éditeur de modèle',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_hasChanges) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'Modifié',
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isMobile) ...[
            IconButton(
              icon: Icon(Icons.fullscreen_rounded, size: 22, color: AppColors.primary),
              onPressed: _openFullScreenPreview,
              tooltip: 'Aperçu plein écran',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobilePreviewCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Single preview header bar (No duplicate!)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.preview_rounded, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Aperçu A4 en direct',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'Temps réel',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.success),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.fullscreen_rounded, size: 18, color: AppColors.primary),
                  onPressed: _openFullScreenPreview,
                  tooltip: 'Aperçu plein écran',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                ),
                const SizedBox(width: 2),
                InkWell(
                  onTap: () => setState(() => _showMobilePreview = false),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Expanded live A4 canvas (Takes full upper height, no duplicate inner header)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: _buildPreviewWidget(showHeader: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCollapsedPreviewHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => setState(() => _showMobilePreview = true),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.preview_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('Afficher l\'aperçu A4', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewWidget({bool showHeader = true}) {
    return TemplatePreviewWidget(
      template: _previewTemplate,
      showHeader: showHeader,
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
    );
  }

  Widget _buildEditorTabs(bool isMobile) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 10),
              labelStyle: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
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
                _buildFieldsTab(isMobile),
                _buildDecorationsTab(isMobile),
                _buildStylesTab(isMobile),
                _buildTotalsTab(isMobile),
                _buildEFactureTab(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab Builders ──────────────────────────────────────────────────

  Widget _buildFieldsTab(bool isMobile) {
    final companyInfo = Map<String, dynamic>.from(_config['companyInfo'] as Map? ?? DocumentTemplate.defaultCompanyInfo());
    final documentInfo = Map<String, dynamic>.from(_config['documentInfo'] as Map? ?? DocumentTemplate.defaultDocumentInfo());
    final clientInfo = Map<String, dynamic>.from(_config['clientInfo'] as Map? ?? DocumentTemplate.defaultClientInfo());
    final columns = List<Map<String, dynamic>>.from(
      (_config['tableColumns'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)) ?? DocumentTemplate.defaultTableColumns(),
    );
    final footer = Map<String, dynamic>.from(_config['footer'] as Map? ?? DocumentTemplate.defaultFooter());

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Activez ou désactivez les informations affichées sur vos documents : entreprise, document, client, colonnes du tableau, totaux et pied de page.',
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 14 : 20),

          // ─── 1. Informations de la Société ───────────────────
          _buildFieldSection(
            title: 'Informations de la Société',
            icon: Icons.business_rounded,
            color: const Color(0xFF1A56DB),
            isMobile: isMobile,
            children: [
              _buildToggleItem('Nom de la société', companyInfo['showName'] != false, (v) => _updateNestedConfig('companyInfo', 'showName', v), isMobile: isMobile),
              _buildToggleItem('Téléphone', companyInfo['showPhone'] != false, (v) => _updateNestedConfig('companyInfo', 'showPhone', v), isMobile: isMobile),
              _buildToggleItem('Email', companyInfo['showEmail'] != false, (v) => _updateNestedConfig('companyInfo', 'showEmail', v), isMobile: isMobile),
              _buildToggleItem('Site Web', companyInfo['showWebsite'] != false, (v) => _updateNestedConfig('companyInfo', 'showWebsite', v), isMobile: isMobile),
              _buildToggleItem('Adresse de l\'entreprise', companyInfo['showAddress'] != false, (v) => _updateNestedConfig('companyInfo', 'showAddress', v), isMobile: isMobile),
              _buildToggleItem('Logo de l\'entreprise', companyInfo['showLogo'] == true, (v) => _updateNestedConfig('companyInfo', 'showLogo', v), isMobile: isMobile),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // ─── 2. Informations du Document ─────────────────────
          _buildFieldSection(
            title: 'Informations du Document',
            icon: Icons.description_rounded,
            color: const Color(0xFF0D9488),
            isMobile: isMobile,
            children: [
              _buildToggleItem('Numéro de document (Référence)', documentInfo['showNumber'] != false, (v) => _updateNestedConfig('documentInfo', 'showNumber', v), isMobile: isMobile),
              _buildToggleItem('Date d\'émission', documentInfo['showDate'] != false, (v) => _updateNestedConfig('documentInfo', 'showDate', v), isMobile: isMobile),
              _buildToggleItem('Date d\'échéance', documentInfo['showDueDate'] != false, (v) => _updateNestedConfig('documentInfo', 'showDueDate', v), isMobile: isMobile),
              _buildToggleItem('Date de validité', documentInfo['showValidityDate'] != false, (v) => _updateNestedConfig('documentInfo', 'showValidityDate', v), isMobile: isMobile),
              _buildToggleItem('Type / Titre du document', documentInfo['showTitle'] != false, (v) => _updateNestedConfig('documentInfo', 'showTitle', v), isMobile: isMobile),
              _buildToggleItem('Statut du document', documentInfo['showStatus'] != false, (v) => _updateNestedConfig('documentInfo', 'showStatus', v), isMobile: isMobile),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // ─── 3. Informations du Client ───────────────────────
          _buildFieldSection(
            title: 'Informations du Client',
            icon: Icons.person_rounded,
            color: const Color(0xFF8B5CF6),
            isMobile: isMobile,
            children: [
              _buildToggleItem('Nom du client', clientInfo['showName'] != false, (v) => _updateNestedConfig('clientInfo', 'showName', v), isMobile: isMobile),
              _buildToggleItem('Adresse du client', clientInfo['showAddress'] != false, (v) => _updateNestedConfig('clientInfo', 'showAddress', v), isMobile: isMobile),
              _buildToggleItem('Téléphone du client', clientInfo['showPhone'] != false, (v) => _updateNestedConfig('clientInfo', 'showPhone', v), isMobile: isMobile),
              _buildToggleItem('Email du client', clientInfo['showEmail'] != false, (v) => _updateNestedConfig('clientInfo', 'showEmail', v), isMobile: isMobile),
              _buildToggleItem('Code client', clientInfo['showCode'] != false, (v) => _updateNestedConfig('clientInfo', 'showCode', v), isMobile: isMobile),
              _buildToggleItem('Matricule fiscale client (NIF)', clientInfo['showTaxId'] != false, (v) => _updateNestedConfig('clientInfo', 'showTaxId', v), isMobile: isMobile),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // ─── 4. Tableau des Articles ─────────────────────────
          _buildFieldSection(
            title: 'Tableau des Articles (Colonnes)',
            icon: Icons.table_chart_rounded,
            color: const Color(0xFF2563EB),
            isMobile: isMobile,
            children: [
              ...columns.asMap().entries.map((entry) {
                final index = entry.key;
                final col = entry.value;
                return _buildFieldToggle(
                  col['label'] as String,
                  col['visible'] == true,
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
                  isMobile: isMobile,
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addCustomColumn,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Ajouter une colonne personnalisée',
                    style: TextStyle(fontSize: isMobile ? 12 : 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 10 : 12),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // ─── 5. Totaux du Document ───────────────────────────
          _buildFieldSection(
            title: 'Totaux du Document',
            icon: Icons.calculate_rounded,
            color: const Color(0xFFD97706),
            isMobile: isMobile,
            children: [
              _buildToggleItem('Sous-total HT (Brut)', _getBoolConfig('totalBrut', 'visible', false), (v) => _updateNestedConfig('totalBrut', 'visible', v), isMobile: isMobile),
              _buildToggleItem('Total Remises', _getBoolConfig('totalRemises', 'visible', true), (v) => _updateNestedConfig('totalRemises', 'visible', v), isMobile: isMobile),
              _buildToggleItem('Total HT (Net)', _getBoolConfig('totalHT', 'visible', true), (v) => _updateNestedConfig('totalHT', 'visible', v), isMobile: isMobile),
              _buildToggleItem('Total TVA', _getBoolConfig('taxes', 'visible', true), (v) => _updateNestedConfig('taxes', 'visible', v), isMobile: isMobile),
              _buildToggleItem('Droit de Timbre fiscal', _getBoolConfig('timbre', 'visible', true), (v) => _updateNestedConfig('timbre', 'visible', v), isMobile: isMobile),
              _buildToggleItem('Total TTC', _getBoolConfig('totalTTC', 'visible', true), (v) => _updateNestedConfig('totalTTC', 'visible', v), isMobile: isMobile),
              _buildToggleItem('Montant en toutes lettres', _getBoolConfig('totalLetters', 'visible', false), (v) => _updateNestedConfig('totalLetters', 'visible', v), isMobile: isMobile),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // ─── 6. Pied de page & Mentions ──────────────────────
          _buildFieldSection(
            title: 'Pied de page & Mentions',
            icon: Icons.notes_rounded,
            color: const Color(0xFF475569),
            isMobile: isMobile,
            children: [
              _buildToggleItem('Bloc de Signature', footer['showSignature'] != false, (v) => _updateNestedConfig('footer', 'showSignature', v), isMobile: isMobile),
              _buildToggleItem('Notes supplémentaires', footer['showNotes'] != false, (v) => _updateNestedConfig('footer', 'showNotes', v), isMobile: isMobile),
              _buildToggleItem('Conditions de paiement / Conditions Générales', footer['showPaymentTerms'] != false, (v) => _updateNestedConfig('footer', 'showPaymentTerms', v), isMobile: isMobile),
              _buildToggleItem('Mentions légales / RIB bancaire', footer['showLegalNotice'] != false, (v) => _updateNestedConfig('footer', 'showLegalNotice', v), isMobile: isMobile),
              _buildToggleItem('Numéro de page (Page X / Y)', footer['showPageNumbers'] != false, (v) => _updateNestedConfig('footer', 'showPageNumbers', v), isMobile: isMobile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool isMobile = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 0 : 2),
          leading: Container(
            padding: EdgeInsets.all(isMobile ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: isMobile ? 18 : 20, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          childrenPadding: EdgeInsets.fromLTRB(isMobile ? 10 : 16, 0, isMobile ? 10 : 16, isMobile ? 8 : 12),
          children: children,
        ),
      ),
    );
  }

  Widget _buildToggleItem(String label, bool value, ValueChanged<bool> onChanged, {bool isMobile = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 4 : 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Transform.scale(
            scale: isMobile ? 0.82 : 1.0,
            child: Switch(
              value: value,
              onChanged: (v) {
                onChanged(v);
                setState(() => _hasChanges = true);
              },
              activeThumbColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  bool _getBoolConfig(String parent, String key, bool defaultValue) {
    final map = _config[parent] as Map<String, dynamic>?;
    if (map == null || !map.containsKey(key)) return defaultValue;
    return map[key] == true || map[key] == 1;
  }

  void _addCustomColumn() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle colonne', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  final columns = List<Map<String, dynamic>>.from(
                    (_config['tableColumns'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)) ?? DocumentTemplate.defaultTableColumns(),
                  );
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldToggle(String label, bool enabled, ValueChanged<bool>? onChanged, {VoidCallback? onDelete, bool isMobile = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 4 : 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, size: isMobile ? 14 : 16, color: AppColors.textTertiary),
          SizedBox(width: isMobile ? 6 : 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDelete != null) ...[
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.error, size: isMobile ? 16 : 18),
              onPressed: onDelete,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 6),
          ],
          Transform.scale(
            scale: isMobile ? 0.82 : 1.0,
            child: Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorationsTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Configurez les éléments décoratifs de votre document : bordures, filigrane, en-tête et pied de page personnalisés.',
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          // Table border settings
          const TemplateSectionHeader(title: 'Bordures du tableau'),
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
              const SizedBox(width: 10),
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
              Expanded(
                child: Text('Afficher le contour du tableau', style: TextStyle(fontSize: isMobile ? 13 : 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _getTableBoolVal('fixedHeight', false),
                onChanged: (v) => _updateNestedConfig('table', 'fixedHeight', v ?? false),
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  'Hauteur fixe du tableau (remplir avec des lignes vides sur la première page)',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStylesTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Personnalisez l\'apparence globale de votre document : style du tableau, couleurs d\'en-tête, taille de police et hauteur des lignes.',
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          // Table style radio buttons
          const TemplateSectionHeader(title: 'Style du tableau'),
          const SizedBox(height: 8),
          _buildRadioGroup([
            ('classique', 'Classique', 'Bordures complètes'),
            ('alterne', 'Alterné', 'Lignes alternées colorées'),
            ('minimaliste', 'Minimaliste', 'Bordures minimales'),
          ]),
          SizedBox(height: isMobile ? 14 : 20),
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
              const SizedBox(width: 10),
              Expanded(
                child: TemplateColorPicker(
                  label: 'Texte en-tête',
                  color: Color(_config['headerTextColor'] as int? ?? 0xFFFFFFFF),
                  onChanged: (c) => _updateConfig('headerTextColor', c.toARGB32()),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
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
              const SizedBox(width: 10),
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

  Widget _buildTotalsTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Configurez l\'apparence de la section des totaux : Total Brut, Remises, Total HT, Taxes et Total TTC.',
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          // Position section
          const TemplateSectionHeader(title: 'Position des totaux'),
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
              const SizedBox(width: 10),
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
              const SizedBox(width: 10),
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
                        Expanded(
                          child: Text('Afficher le fond coloré',
                              style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w500)),
                        ),
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
                          const SizedBox(width: 10),
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

  Widget _buildEFactureTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBox(
            'Configurez l\'affichage des éléments E-Facture (El-Fatoora) sur vos factures : QR Code, référence TTN, date de soumission et badge de statut.',
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),

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
            const SizedBox(height: 10),
            TemplateDimensionFields(
              width: _getSubDbl('qrCode', 'width', 25),
              height: _getSubDbl('qrCode', 'height', 25),
              onWidthChanged: (v) => _updateNestedConfig('qrCode', 'width', v),
              onHeightChanged: (v) => _updateNestedConfig('qrCode', 'height', v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _getSubConfig('qrCode')['showLabel'] as bool? ?? true,
                  onChanged: (v) => _updateNestedConfig('qrCode', 'showLabel', v ?? true),
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Text('Afficher étiquette', style: TextStyle(fontSize: isMobile ? 13 : 14)),
                ),
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

          SizedBox(height: isMobile ? 12 : 16),

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
            const SizedBox(height: 10),
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
                const SizedBox(width: 10),
                Expanded(
                  child: TemplateColorPicker(
                    label: 'Couleur',
                    color: Color(_getSubConfig('ttnReference')['color'] as int? ?? 0xFF1a56db),
                    onChanged: (c) => _updateNestedConfig('ttnReference', 'color', c.toARGB32()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TemplateFontStyleSelector(
              label: 'Graisse',
              value: _getSubConfig('ttnReference')['fontWeight'] as String? ?? 'Gras',
              onChanged: (v) => _updateNestedConfig('ttnReference', 'fontWeight', v),
              options: const ['Normal', 'Gras', 'Graisse'],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _getSubConfig('ttnReference')['showLabel'] as bool? ?? true,
                  onChanged: (v) => _updateNestedConfig('ttnReference', 'showLabel', v ?? true),
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Text('Afficher étiquette', style: TextStyle(fontSize: isMobile ? 13 : 14)),
                ),
              ],
            ),
            if (_getSubConfig('ttnReference')['showLabel'] == true)
              _buildTextInput(
                'Texte étiquette',
                _getSubConfig('ttnReference')['labelText'] as String? ?? 'Réf TTN:',
                (v) => _updateNestedConfig('ttnReference', 'labelText', v),
              ),
          ],

          SizedBox(height: isMobile ? 12 : 16),

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
            const SizedBox(height: 10),
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
                const SizedBox(width: 10),
                Expanded(
                  child: TemplateColorPicker(
                    label: 'Couleur',
                    color: Color(_getSubConfig('submissionDate')['color'] as int? ?? 0xFF000000),
                    onChanged: (c) => _updateNestedConfig('submissionDate', 'color', c.toARGB32()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _getSubConfig('submissionDate')['showLabel'] as bool? ?? true,
                  onChanged: (v) => _updateNestedConfig('submissionDate', 'showLabel', v ?? true),
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Text('Afficher étiquette', style: TextStyle(fontSize: isMobile ? 13 : 14)),
                ),
              ],
            ),
            if (_getSubConfig('submissionDate')['showLabel'] == true)
              _buildTextInput(
                'Texte étiquette',
                _getSubConfig('submissionDate')['labelText'] as String? ?? 'Envoyé le:',
                (v) => _updateNestedConfig('submissionDate', 'labelText', v),
              ),
          ],

          SizedBox(height: isMobile ? 12 : 16),

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
            const SizedBox(height: 10),
            TemplateDimensionFields(
              width: _getSubDbl('statusBadge', 'width', 40),
              height: _getSubDbl('statusBadge', 'height', 6),
              onWidthChanged: (v) => _updateNestedConfig('statusBadge', 'width', v),
              onHeightChanged: (v) => _updateNestedConfig('statusBadge', 'height', v),
            ),
            const SizedBox(height: 10),
            TemplateMeasurementInput(
              label: 'Taille',
              value: _getSubDbl('statusBadge', 'fontSize', 8),
              unit: 'pt',
              onChanged: (v) => _updateNestedConfig('statusBadge', 'fontSize', v),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            // Status badge preview
            Text('Aperçu',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
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

  Widget _buildBottomBar(bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _resetToDefaults,
                icon: const Icon(Icons.restore_rounded, size: 14),
                label: const Text('Réinitialiser', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _hasChanges ? _save : null,
                  icon: const Icon(Icons.save_rounded, size: 14),
                  label: const Text('Enregistrer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
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

  Widget _infoBox(String text, {bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: isMobile ? 15 : 16, color: AppColors.warning),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
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
          title: Text(opt.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(opt.$3, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }

  Widget _buildTextInput(String label, String value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          style: TextStyle(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
