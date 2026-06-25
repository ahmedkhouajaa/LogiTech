import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../../blocs/canvas_editor/canvas_editor_state.dart';
import '../../models/canvas/canvas_element.dart';
import '../../utils/constants.dart';

/// Right panel – context-sensitive properties for the selected element.
class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({super.key});

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  Widget? _cachedWidget;

  @override
  Widget build(BuildContext context) {
    return Consumer<CanvasEditorState>(
      builder: (context, state, _) {
        final el = state.selectedElement;

        if ((state.isDragging || state.isResizing) && _cachedWidget != null) {
          return _cachedWidget!;
        }

        final child = Theme(
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
              border: Border(left: BorderSide(color: Color(0xFF3A3A4C))),
            ),
            child: el == null ? _buildNoSelection(state) : _buildProperties(context, state, el),
          ),
        );

        _cachedWidget = child;
        return child;
      },
    );
  }

  Widget _buildNoSelection(CanvasEditorState state) {
    return Column(
      children: [
        _panelHeader('Propriétés du document'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Document'),
                const SizedBox(height: 8),
                _propTextField(
                  'Nom du modèle',
                  state.document.name,
                  (v) => state.setDocumentName(v),
                ),
                const SizedBox(height: 12),
                _sectionTitle('Marges (mm)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _propNumberField('Haut', state.document.marginTop,
                        (v) => state.setMargins(top: v))),
                    const SizedBox(width: 8),
                    Expanded(child: _propNumberField('Bas', state.document.marginBottom,
                        (v) => state.setMargins(bottom: v))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _propNumberField('Gauche', state.document.marginLeft,
                        (v) => state.setMargins(left: v))),
                    const SizedBox(width: 8),
                    Expanded(child: _propNumberField('Droite', state.document.marginRight,
                        (v) => state.setMargins(right: v))),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('Grille'),
                const SizedBox(height: 8),
                _propNumberField('Taille grille (mm)', state.document.gridSize,
                    (v) => state.setGridSize(v)),
                const SizedBox(height: 16),
                _sectionTitle('Éléments'),
                const SizedBox(height: 8),
                ...state.elements.map((el) => _elementListTile(state, el)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _elementListTile(CanvasEditorState state, CanvasElement el) {
    IconData icon;
    String label;
    if (el is TextElement) {
      icon = Icons.text_fields_rounded;
      label = el.text.length > 20 ? '${el.text.substring(0, 20)}...' : el.text;
    } else if (el is ShapeElement) {
      icon = Icons.category_rounded;
      label = el.shapeKind.name;
    } else if (el is ImageElement) {
      icon = Icons.image_rounded;
      label = el.placeholder;
    } else if (el is DividerElement) {
      icon = Icons.remove_rounded;
      label = 'Séparateur';
    } else if (el is DynamicFieldElement) {
      icon = Icons.data_object_rounded;
      label = el.displayLabel;
    } else if (el is CanvasTableElement) {
      icon = Icons.table_chart_rounded;
      label = 'Tableau';
    } else {
      icon = Icons.widgets_rounded;
      label = 'Élément';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => state.selectElement(el.id),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: state.selectedElementId == el.id
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF8B8BA7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (el.isLocked)
                const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFF59E0B)),
              if (!el.isVisible)
                const Icon(Icons.visibility_off_rounded, size: 12, color: Color(0xFF6B6B7F)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProperties(BuildContext context, CanvasEditorState state, CanvasElement el) {
    return Column(
      children: [
        _panelHeader(_getElementTitle(el)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Common Properties ─────────────────
                _sectionTitle('Position & Taille'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _propNumberField('X (mm)', el.x, (v) {
                      el.x = v;
                      state.updateElementWithHistory(el.id, el);
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _propNumberField('Y (mm)', el.y, (v) {
                      el.y = v;
                      state.updateElementWithHistory(el.id, el);
                    })),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _propNumberField('Largeur', el.width, (v) {
                      el.width = v;
                      state.updateElementWithHistory(el.id, el);
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _propNumberField('Hauteur', el.height, (v) {
                      el.height = v;
                      state.updateElementWithHistory(el.id, el);
                    })),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _propNumberField('Rotation (°)', el.rotation, (v) {
                      el.rotation = v;
                      state.updateElementWithHistory(el.id, el);
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _propSlider('Opacité', el.opacity, 0, 1, (v) {
                      el.opacity = v;
                      state.updateElement(el.id, el);
                    })),
                  ],
                ),
                const SizedBox(height: 16),
                // ─── Actions Row ───────────────────────
                _buildActionsRow(context, state, el),
                const SizedBox(height: 16),
                // ─── Type-Specific Properties ──────────
                if (el is TextElement) _buildTextProps(state, el),
                if (el is ShapeElement) _buildShapeProps(context, state, el),
                if (el is DynamicFieldElement) _buildDynamicFieldProps(context, state, el),
                if (el is CanvasTableElement) _buildTableProps(context, state, el),
                if (el is DividerElement) _buildDividerProps(context, state, el),
                if (el is ImageElement) _buildImageProps(state, el),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getElementTitle(CanvasElement el) {
    if (el is TextElement) return 'Texte';
    if (el is ShapeElement) return 'Forme';
    if (el is ImageElement) return 'Image';
    if (el is DividerElement) return 'Séparateur';
    if (el is DynamicFieldElement) return 'Champ dynamique';
    if (el is CanvasTableElement) return 'Tableau';
    return 'Élément';
  }

  Widget _buildActionsRow(BuildContext context, CanvasEditorState state, CanvasElement el) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _actionButton(Icons.content_copy_rounded, 'Dupliquer',
            () => state.duplicateElement(el.id)),
        _actionButton(Icons.flip_to_front_rounded, 'Avant',
            () => state.bringToFront(el.id)),
        _actionButton(Icons.flip_to_back_rounded, 'Arrière',
            () => state.sendToBack(el.id)),
        _actionButton(
          el.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
          el.isLocked ? 'Déverrouiller' : 'Verrouiller',
          () => state.toggleLock(el.id),
        ),
        _actionButton(
          el.isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          el.isVisible ? 'Masquer' : 'Afficher',
          () => state.toggleVisibility(el.id),
        ),
        _actionButton(Icons.delete_rounded, 'Supprimer',
            () => state.removeElement(el.id), danger: true),
      ],
    );
  }

  Widget _actionButton(IconData icon, String tooltip, VoidCallback onTap,
      {bool danger = false}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: danger
                  ? const Color(0xFF3A2020)
                  : const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: danger ? const Color(0xFF5A3030) : const Color(0xFF3A3A4C),
              ),
            ),
            child: Icon(icon, size: 16,
                color: danger ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1)),
          ),
        ),
      ),
    );
  }

  // ─── Text Properties ────────────────────────────────────────────

  Widget _buildTextProps(CanvasEditorState state, TextElement el) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Texte'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3A3A4C)),
          ),
          child: SmartTextField(
            value: el.text,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.all(10),
              hintText: 'Entrez votre texte...',
              hintStyle: TextStyle(color: Color(0xFF6B6B7F)),
            ),
            submitOnEveryChar: true,
            onChanged: (v) {
              el.text = v;
              state.updateElement(el.id, el);
            },
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Style'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _propNumberField('Taille', el.fontSize, (v) {
              el.fontSize = v;
              state.updateElement(el.id, el);
            })),
            const SizedBox(width: 8),
            Expanded(child: _propNumberField('Interligne', el.lineHeight, (v) {
              el.lineHeight = v;
              state.updateElement(el.id, el);
            })),
          ],
        ),
        const SizedBox(height: 8),
        // Bold, Italic, Underline toggles
        Row(
          children: [
            _styleToggle('B', el.isBold, (v) {
              el.isBold = v;
              state.updateElement(el.id, el);
            }, fontWeight: FontWeight.bold),
            const SizedBox(width: 4),
            _styleToggle('I', el.isItalic, (v) {
              el.isItalic = v;
              state.updateElement(el.id, el);
            }, fontStyle: FontStyle.italic),
            const SizedBox(width: 4),
            _styleToggle('U', el.isUnderline, (v) {
              el.isUnderline = v;
              state.updateElement(el.id, el);
            }, textDecoration: TextDecoration.underline),
            const Spacer(),
            // Alignment
            ...[
              (CanvasTextAlign.left, Icons.format_align_left_rounded),
              (CanvasTextAlign.center, Icons.format_align_center_rounded),
              (CanvasTextAlign.right, Icons.format_align_right_rounded),
            ].map((a) => _alignToggle(a.$2, el.textAlign == a.$1, () {
                  el.textAlign = a.$1;
                  state.updateElement(el.id, el);
                })),
          ],
        ),
        const SizedBox(height: 12),
        _colorProperty('Couleur du texte', Color(el.color), (c) {
          el.color = c.toARGB32();
          state.updateElementWithHistory(el.id, el);
        }),
      ],
    );
  }

  // ─── Shape Properties ───────────────────────────────────────────

  Widget _buildShapeProps(BuildContext context, CanvasEditorState state, ShapeElement el) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Forme'),
        const SizedBox(height: 8),
        _propDropdown<ShapeKind>(
          'Type',
          el.shapeKind,
          ShapeKind.values,
          (v) => v.name,
          (v) {
            el.shapeKind = v;
            state.updateElementWithHistory(el.id, el);
          },
        ),
        const SizedBox(height: 12),
        _colorProperty('Remplissage', Color(el.fillColor), (c) {
          el.fillColor = c.toARGB32();
          state.updateElementWithHistory(el.id, el);
        }),
        const SizedBox(height: 8),
        _colorProperty('Bordure', Color(el.borderColor), (c) {
          el.borderColor = c.toARGB32();
          state.updateElementWithHistory(el.id, el);
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _propNumberField('Épaisseur', el.borderWidth, (v) {
              el.borderWidth = v;
              state.updateElement(el.id, el);
            })),
            const SizedBox(width: 8),
            if (el.shapeKind == ShapeKind.roundedRect)
              Expanded(child: _propNumberField('Arrondi', el.borderRadius, (v) {
                el.borderRadius = v;
                state.updateElement(el.id, el);
              })),
          ],
        ),
      ],
    );
  }

  // ─── Dynamic Field Properties ───────────────────────────────────

  Widget _buildDynamicFieldProps(
      BuildContext context, CanvasEditorState state, DynamicFieldElement el) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Champ dynamique'),
        const SizedBox(height: 8),
        _propDropdown<DynamicFieldType>(
          'Type de champ',
          el.fieldType,
          DynamicFieldType.values,
          (v) {
            // French labels
            final labels = {
              DynamicFieldType.companyName: 'Nom entreprise',
              DynamicFieldType.companyAddress: 'Adresse entreprise',
              DynamicFieldType.companyPhone: 'Tél. entreprise',
              DynamicFieldType.companyEmail: 'Email entreprise',
              DynamicFieldType.companyVat: 'N° TVA',
              DynamicFieldType.clientName: 'Nom client',
              DynamicFieldType.clientAddress: 'Adresse client',
              DynamicFieldType.clientPhone: 'Tél. client',
              DynamicFieldType.clientEmail: 'Email client',
              DynamicFieldType.invoiceNumber: 'N° Facture',
              DynamicFieldType.invoiceDate: 'Date',
              DynamicFieldType.invoiceDueDate: 'Échéance',
              DynamicFieldType.totalHT: 'Total HT',
              DynamicFieldType.totalTVA: 'Total TVA',
              DynamicFieldType.totalTTC: 'Total TTC',
              DynamicFieldType.currency: 'Devise',
              DynamicFieldType.notes: 'Notes',
              DynamicFieldType.conditions: 'Conditions',
              DynamicFieldType.custom: 'Personnalisé',
            };
            return labels[v] ?? v.name;
          },
          (v) {
            el.fieldType = v;
            state.updateElementWithHistory(el.id, el);
          },
        ),
        const SizedBox(height: 8),
        _propTextField('Étiquette', el.label, (v) {
          el.label = v;
          state.updateElement(el.id, el);
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _propNumberField('Taille police', el.fontSize, (v) {
              el.fontSize = v;
              state.updateElement(el.id, el);
            })),
            const SizedBox(width: 8),
            _styleToggle('B', el.isBold, (v) {
              el.isBold = v;
              state.updateElement(el.id, el);
            }, fontWeight: FontWeight.bold),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _checkboxProp('Afficher étiquette', el.showLabel, (v) {
              el.showLabel = v;
              state.updateElement(el.id, el);
            }),
          ],
        ),
        const SizedBox(height: 8),
        _colorProperty('Couleur', Color(el.color), (c) {
          el.color = c.toARGB32();
          state.updateElementWithHistory(el.id, el);
        }),
      ],
    );
  }

  // ─── Table Properties ───────────────────────────────────────────

  Widget _buildTableProps(
      BuildContext context, CanvasEditorState state, CanvasTableElement el) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Tableau'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _propNumberField('Colonnes', el.columnCount.toDouble(), (v) {
              el.columnCount = v.round();
              state.updateElementWithHistory(el.id, el);
            })),
            const SizedBox(width: 8),
            Expanded(child: _propNumberField('Lignes', el.rowCount.toDouble(), (v) {
              el.rowCount = v.round();
              state.updateElementWithHistory(el.id, el);
            })),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _propNumberField('Taille en-tête', el.headerFontSize, (v) {
              el.headerFontSize = v;
              state.updateElement(el.id, el);
            })),
            const SizedBox(width: 8),
            Expanded(child: _propNumberField('Taille cellule', el.cellFontSize, (v) {
              el.cellFontSize = v;
              state.updateElement(el.id, el);
            })),
          ],
        ),
        const SizedBox(height: 8),
        _propNumberField('Espacement', el.cellPadding, (v) {
          el.cellPadding = v;
          state.updateElement(el.id, el);
        }),
        const SizedBox(height: 12),
        _colorProperty('Fond en-tête', Color(el.headerBgColor), (c) {
          el.headerBgColor = c.toARGB32();
          state.updateElementWithHistory(el.id, el);
        }),
        const SizedBox(height: 8),
        _colorProperty('Texte en-tête', Color(el.headerTextColor), (c) {
          el.headerTextColor = c.toARGB32();
          state.updateElementWithHistory(el.id, el);
        }),
        const SizedBox(height: 8),
        _colorProperty('Couleur bordure', Color(el.borderColor), (c) {
          el.borderColor = c.toARGB32();
          state.updateElementWithHistory(el.id, el);
        }),
        const SizedBox(height: 8),
        _propNumberField('Épaisseur bordure', el.borderWidth, (v) {
          el.borderWidth = v;
          state.updateElement(el.id, el);
        }),
        const SizedBox(height: 12),
        _sectionTitle('En-têtes de colonnes'),
        const SizedBox(height: 8),
        ...el.headers.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _propTextField(
              'Col ${entry.key + 1}',
              entry.value,
              (v) {
                el.headers[entry.key] = v;
                state.updateElement(el.id, el);
              },
            ),
          );
        }),
      ],
    );
  }

  // ─── Divider Properties ─────────────────────────────────────────

  Widget _buildDividerProps(
      BuildContext context, CanvasEditorState state, DividerElement el) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Séparateur'),
        const SizedBox(height: 8),
        _propNumberField('Épaisseur', el.thickness, (v) {
          el.thickness = v;
          state.updateElement(el.id, el);
        }),
        const SizedBox(height: 8),
        _colorProperty('Couleur', Color(el.color), (c) {
          el.color = c.toARGB32();
          state.updateElementWithHistory(el.id, el);
        }),
        const SizedBox(height: 8),
        _checkboxProp('Vertical', el.isVertical, (v) {
          el.isVertical = v;
          state.updateElement(el.id, el);
        }),
      ],
    );
  }

  // ─── Image Properties ───────────────────────────────────────────

  Widget _buildImageProps(CanvasEditorState state, ImageElement el) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Image'),
        const SizedBox(height: 8),
        _propTextField('Titre placeholder', el.placeholder, (v) {
          el.placeholder = v;
          state.updateElement(el.id, el);
        }),
        const SizedBox(height: 8),
        _propNumberField('Épaisseur bordure', el.borderWidth, (v) {
          el.borderWidth = v;
          state.updateElement(el.id, el);
        }),
      ],
    );
  }

  // ─── Shared Widgets ─────────────────────────────────────────────

  Widget _panelHeader(String title) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF3A3A4C))),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B6B7F),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _propTextField(String label, String value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B8BA7))),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A3A4C)),
          ),
          child: SmartTextField(
            value: value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _propNumberField(String label, double value, ValueChanged<double> onChanged) {
    final strValue = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B8BA7))),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A3A4C)),
          ),
          child: SmartTextField(
            value: strValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
      ],
    );
  }

  Widget _propSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${(value * 100).round()}%',
            style: const TextStyle(fontSize: 11, color: Color(0xFF8B8BA7))),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: AppColors.primaryLight,
              inactiveTrackColor: const Color(0xFF3A3A4C),
              thumbColor: AppColors.primaryLight,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
      ],
    );
  }

  Widget _colorProperty(String label, Color color, ValueChanged<Color> onChanged) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B8BA7))),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showColorPicker(context, label, color, onChanged),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF3A3A4C)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF3A3A4C)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(
      BuildContext context, String label, Color current, ValueChanged<Color> onChanged) {
    Color temp = current;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3C),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => temp = c,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              onChanged(temp);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Widget _styleToggle(String text, bool active, ValueChanged<bool> onChanged,
      {FontWeight? fontWeight, FontStyle? fontStyle, TextDecoration? textDecoration}) {
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.2)
              : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? AppColors.primaryLight : const Color(0xFF3A3A4C),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: fontWeight ?? FontWeight.normal,
            fontStyle: fontStyle,
            decoration: textDecoration,
            color: active ? AppColors.primaryLight : const Color(0xFF8B8BA7),
          ),
        ),
      ),
    );
  }

  Widget _alignToggle(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(left: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16,
            color: active ? AppColors.primaryLight : const Color(0xFF6B6B7F)),
      ),
    );
  }

  Widget _checkboxProp(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: value ? AppColors.primaryLight : const Color(0xFF3A3A4C),
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 12, color: AppColors.primaryLight)
                : null,
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _propDropdown<T>(String label, T value, List<T> items,
      String Function(T) toLabel, ValueChanged<T> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8B8BA7))),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A3A4C)),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF2A2A3C),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            iconEnabledColor: const Color(0xFF8B8BA7),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(toLabel(i)))).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// A specialized TextField wrapper that resolves standard Flutter usability bugs
/// in visually complex editors:
/// 1. Prevents cursor jumping when updating state in real-time.
/// 2. Saves values automatically when losing focus (clicking outside the field),
///    not just when pressing Enter.
/// 3. Prevents parent theme overrides.
class SmartTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextStyle style;
  final InputDecoration decoration;
  final bool submitOnEveryChar;
  final TextInputType? keyboardType;

  const SmartTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    required this.style,
    required this.decoration,
    this.submitOnEveryChar = false,
    this.keyboardType,
  });

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late String _lastSubmittedValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _lastSubmittedValue = widget.value;
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant SmartTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.value;
      _lastSubmittedValue = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _submitValue();
    }
  }

  void _submitValue() {
    if (widget.submitOnEveryChar) return;
    if (_controller.text != _lastSubmittedValue) {
      _lastSubmittedValue = _controller.text;
      widget.onChanged(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      style: widget.style,
      decoration: widget.decoration,
      keyboardType: widget.keyboardType,
      onChanged: (v) {
        if (widget.submitOnEveryChar) {
          widget.onChanged(v);
        }
      },
      onSubmitted: (_) => _submitValue(),
    );
  }
}

