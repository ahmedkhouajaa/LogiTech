import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../blocs/canvas_editor/canvas_editor_state.dart';
import '../../models/canvas/canvas_element.dart';
import '../../utils/constants.dart';

/// Left panel – component library from which users drag elements onto the canvas.
class ToolboxPanel extends StatefulWidget {
  const ToolboxPanel({super.key});

  @override
  State<ToolboxPanel> createState() => _ToolboxPanelState();
}

class _ToolboxPanelState extends State<ToolboxPanel> {
  String _searchQuery = '';
  String _activeCategory = 'structure';

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          surface: Color(0xFF2A2A3C),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A3C),
          border: Border(right: BorderSide(color: Color(0xFF3A3A4C))),
        ),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3A3A4C)),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un composant...',
                    hintStyle: TextStyle(color: Color(0xFF6B6B7F), fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF6B6B7F)),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            // Category tabs
            _buildCategoryTabs(),
            const Divider(height: 1, color: Color(0xFF3A3A4C)),
            // Items grid
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: _buildCategoryContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = [
      ('structure', Icons.view_module_rounded, 'Structure'),
      ('data', Icons.data_object_rounded, 'Données'),
      ('shapes', Icons.category_rounded, 'Formes'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: categories.map((cat) {
          final isActive = _activeCategory == cat.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeCategory = cat.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isActive
                      ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.$2, size: 16,
                        color: isActive ? AppColors.primaryLight : const Color(0xFF8B8BA7)),
                    const SizedBox(height: 2),
                    Text(cat.$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive ? AppColors.primaryLight : const Color(0xFF8B8BA7),
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryContent() {
    switch (_activeCategory) {
      case 'structure':
        return _buildStructureItems();
      case 'data':
        return _buildDataItems();
      case 'shapes':
        return _buildShapeItems();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStructureItems() {
    final items = [
      _ToolboxItem(
        icon: Icons.text_fields_rounded,
        label: 'Texte',
        description: 'Bloc de texte libre',
        color: const Color(0xFF3B82F6),
        onTap: () => _addElement(TextElement(
          x: 50, y: 50, width: 60, height: 10,
          text: 'Nouveau texte',
        )),
      ),
      _ToolboxItem(
        icon: Icons.table_chart_rounded,
        label: 'Tableau',
        description: 'Tableau des articles',
        color: const Color(0xFF10B981),
        onTap: () => _addElement(CanvasTableElement(
          x: 15, y: 80, width: 180, height: 60,
        )),
      ),
      _ToolboxItem(
        icon: Icons.remove_rounded,
        label: 'Séparateur',
        description: 'Ligne de division',
        color: const Color(0xFF8B5CF6),
        onTap: () => _addElement(DividerElement(
          x: 15, y: 50, width: 180, height: 1,
        )),
      ),
      _ToolboxItem(
        icon: Icons.image_rounded,
        label: 'Image',
        description: 'Logo ou signature',
        color: const Color(0xFFF59E0B),
        onTap: () => _addElement(ImageElement(
          x: 15, y: 15, width: 35, height: 25,
          placeholder: 'Logo',
        )),
      ),
    ];
    return _buildItemGrid(items);
  }

  Widget _buildDataItems() {
    final companyFields = [
      _ToolboxItem(
        icon: Icons.business_rounded,
        label: 'Nom entreprise',
        description: 'Raison sociale',
        color: const Color(0xFF3B82F6),
        onTap: () => _addDynamicField(DynamicFieldType.companyName, fontSize: 14, isBold: true),
      ),
      _ToolboxItem(
        icon: Icons.location_on_rounded,
        label: 'Adresse',
        description: 'Adresse entreprise',
        color: const Color(0xFF3B82F6),
        onTap: () => _addDynamicField(DynamicFieldType.companyAddress, fontSize: 9),
      ),
      _ToolboxItem(
        icon: Icons.phone_rounded,
        label: 'Téléphone',
        description: 'Tél. entreprise',
        color: const Color(0xFF3B82F6),
        onTap: () => _addDynamicField(DynamicFieldType.companyPhone, fontSize: 9),
      ),
      _ToolboxItem(
        icon: Icons.email_rounded,
        label: 'Email',
        description: 'Email entreprise',
        color: const Color(0xFF3B82F6),
        onTap: () => _addDynamicField(DynamicFieldType.companyEmail, fontSize: 9),
      ),
    ];

    final clientFields = [
      _ToolboxItem(
        icon: Icons.person_rounded,
        label: 'Client',
        description: 'Nom du client',
        color: const Color(0xFF10B981),
        onTap: () => _addDynamicField(DynamicFieldType.clientName, fontSize: 11, isBold: true),
      ),
      _ToolboxItem(
        icon: Icons.location_on_rounded,
        label: 'Adresse client',
        description: 'Adresse du client',
        color: const Color(0xFF10B981),
        onTap: () => _addDynamicField(DynamicFieldType.clientAddress, fontSize: 9),
      ),
    ];

    final invoiceFields = [
      _ToolboxItem(
        icon: Icons.tag_rounded,
        label: 'N° Facture',
        description: 'Numéro de facture',
        color: const Color(0xFFF59E0B),
        onTap: () => _addDynamicField(DynamicFieldType.invoiceNumber, fontSize: 10, isBold: true),
      ),
      _ToolboxItem(
        icon: Icons.calendar_today_rounded,
        label: 'Date',
        description: 'Date de facturation',
        color: const Color(0xFFF59E0B),
        onTap: () => _addDynamicField(DynamicFieldType.invoiceDate, fontSize: 9),
      ),
      _ToolboxItem(
        icon: Icons.event_rounded,
        label: 'Échéance',
        description: 'Date d\'échéance',
        color: const Color(0xFFF59E0B),
        onTap: () => _addDynamicField(DynamicFieldType.invoiceDueDate, fontSize: 9),
      ),
    ];

    final totalFields = [
      _ToolboxItem(
        icon: Icons.calculate_rounded,
        label: 'Total HT',
        description: 'Montant hors taxes',
        color: const Color(0xFF8B5CF6),
        onTap: () => _addDynamicField(DynamicFieldType.totalHT, fontSize: 10, showLabel: true, label: 'Total HT:'),
      ),
      _ToolboxItem(
        icon: Icons.percent_rounded,
        label: 'Total TVA',
        description: 'Montant de la TVA',
        color: const Color(0xFF8B5CF6),
        onTap: () => _addDynamicField(DynamicFieldType.totalTVA, fontSize: 10, showLabel: true, label: 'Total TVA:'),
      ),
      _ToolboxItem(
        icon: Icons.payments_rounded,
        label: 'Total TTC',
        description: 'Montant TTC',
        color: const Color(0xFF8B5CF6),
        onTap: () => _addDynamicField(DynamicFieldType.totalTTC, fontSize: 12, isBold: true, showLabel: true, label: 'Total TTC:', color: 0xFF1a56db),
      ),
    ];

    final otherFields = [
      _ToolboxItem(
        icon: Icons.notes_rounded,
        label: 'Notes',
        description: 'Notes de bas de page',
        color: const Color(0xFF6B7280),
        onTap: () => _addDynamicField(DynamicFieldType.notes, fontSize: 8, showLabel: true, label: 'Notes:'),
      ),
      _ToolboxItem(
        icon: Icons.gavel_rounded,
        label: 'Conditions',
        description: 'Conditions générales',
        color: const Color(0xFF6B7280),
        onTap: () => _addDynamicField(DynamicFieldType.conditions, fontSize: 8, showLabel: true, label: 'Conditions:'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Entreprise'),
        _buildItemGrid(companyFields),
        const SizedBox(height: 12),
        _sectionLabel('Client'),
        _buildItemGrid(clientFields),
        const SizedBox(height: 12),
        _sectionLabel('Facture'),
        _buildItemGrid(invoiceFields),
        const SizedBox(height: 12),
        _sectionLabel('Totaux'),
        _buildItemGrid(totalFields),
        const SizedBox(height: 12),
        _sectionLabel('Autres'),
        _buildItemGrid(otherFields),
      ],
    );
  }

  Widget _buildShapeItems() {
    final items = [
      _ToolboxItem(
        icon: Icons.rectangle_outlined,
        label: 'Rectangle',
        description: 'Forme rectangulaire',
        color: const Color(0xFF3B82F6),
        onTap: () => _addElement(ShapeElement(
          x: 50, y: 50, width: 40, height: 30,
          shapeKind: ShapeKind.rectangle,
        )),
      ),
      _ToolboxItem(
        icon: Icons.circle_outlined,
        label: 'Cercle',
        description: 'Forme circulaire',
        color: const Color(0xFF10B981),
        onTap: () => _addElement(ShapeElement(
          x: 50, y: 50, width: 30, height: 30,
          shapeKind: ShapeKind.circle,
        )),
      ),
      _ToolboxItem(
        icon: Icons.rounded_corner_rounded,
        label: 'Rectangle arrondi',
        description: 'Coins arrondis',
        color: const Color(0xFF8B5CF6),
        onTap: () => _addElement(ShapeElement(
          x: 50, y: 50, width: 40, height: 30,
          shapeKind: ShapeKind.roundedRect,
          borderRadius: 4,
        )),
      ),
    ];
    return _buildItemGrid(items);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B6B7F),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildItemGrid(List<_ToolboxItem> items) {
    final filtered = _searchQuery.isEmpty
        ? items
        : items.where((i) =>
            i.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            i.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: filtered.map((item) => _buildToolboxButton(item)).toList(),
    );
  }

  Widget _buildToolboxButton(_ToolboxItem item) {
    return Tooltip(
      message: item.description,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 104,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3A3A4C)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, size: 16, color: item.color),
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFCBD5E1),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addElement(CanvasElement element) {
    context.read<CanvasEditorState>().addElement(element);
  }

  void _addDynamicField(DynamicFieldType fieldType, {
    double fontSize = 10,
    bool isBold = false,
    bool showLabel = false,
    String label = '',
    int color = 0xFF000000,
  }) {
    _addElement(DynamicFieldElement(
      x: 50, y: 50, width: 60, height: 8,
      fieldType: fieldType,
      fontSize: fontSize,
      isBold: isBold,
      showLabel: showLabel,
      label: label,
      color: color,
    ));
  }
}

class _ToolboxItem {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ToolboxItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });
}
