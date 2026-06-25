import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocProvider, ReadContext;
import 'package:provider/provider.dart';
import '../../blocs/canvas_editor/canvas_editor_state.dart';
import '../../blocs/document_templates/document_templates_bloc.dart';
import '../../models/document_template.dart';
import '../../models/canvas/canvas_element.dart';
import '../../utils/constants.dart';
import 'canvas_workspace.dart';
import 'toolbox_panel.dart';
import 'properties_panel.dart';

/// The main invoice designer screen – Canva-like editor.
class InvoiceDesignerScreen extends StatefulWidget {
  final CanvasDocument? initialDocument;
  final DocumentTemplate? initialTemplate;

  const InvoiceDesignerScreen({super.key, this.initialDocument, this.initialTemplate});

  @override
  State<InvoiceDesignerScreen> createState() => _InvoiceDesignerScreenState();
}

class _InvoiceDesignerScreenState extends State<InvoiceDesignerScreen> {
  late CanvasEditorState _editorState;
  DocumentTemplate? _template;
  
  Widget? _cachedTopBar;
  Widget? _cachedBottomBar;

  @override
  void initState() {
    super.initState();
    _template = widget.initialTemplate;
    
    CanvasDocument doc;
    if (_template != null && _template!.config.containsKey('canvas_document')) {
      try {
        final jsonStr = _template!.config['canvas_document'] as String;
        doc = CanvasDocument.fromJson(jsonStr);
      } catch (_) {
        doc = CanvasDocument.defaultInvoiceTemplate();
      }
    } else {
      doc = widget.initialDocument ?? CanvasDocument.defaultInvoiceTemplate();
    }
    
    if (_template != null) {
      doc.name = _template!.name;
    }
    
    _editorState = CanvasEditorState(document: doc);
  }

  @override
  void dispose() {
    _editorState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<DocumentTemplatesBloc>(),
      child: ChangeNotifierProvider.value(
        value: _editorState,
        child: Scaffold(
        backgroundColor: const Color(0xFF1E1E2E),
        body: KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Row(
                  children: [
                    // ─── Left: Toolbox ────────────────
                    const SizedBox(
                      width: 240,
                      child: ToolboxPanel(),
                    ),
                    // ─── Center: Canvas Workspace ─────
                    const Expanded(
                      child: CanvasWorkspace(),
                    ),
                    // ─── Right: Properties Panel ──────
                    const SizedBox(
                      width: 300,
                      child: PropertiesPanel(),
                    ),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    ),
  );
}

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final ctrl = HardwareKeyboard.instance.isControlPressed;

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _editorState.deleteSelected();
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _editorState.redo();
      } else {
        _editorState.undo();
      }
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyD) {
      if (_editorState.selectedElementId != null) {
        _editorState.duplicateElement(_editorState.selectedElementId!);
      }
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyG) {
      _editorState.toggleGrid();
    }
  }

  Widget _buildTopBar() {
    return Consumer<CanvasEditorState>(
      builder: (context, state, _) {
        if ((state.isDragging || state.isResizing) && _cachedTopBar != null) {
          return _cachedTopBar!;
        }

        final child = Container(
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A3C),
            border: Border(bottom: BorderSide(color: Color(0xFF3A3A4C))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Back button
              _topBarIconButton(
                Icons.arrow_back_rounded,
                'Retour',
                () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              // Document name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A4C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_rounded, size: 14, color: Color(0xFF8B8BA7)),
                    const SizedBox(width: 6),
                    Text(
                      state.document.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (state.isDirty)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Undo / Redo
              _topBarIconButton(
                Icons.undo_rounded,
                'Annuler (Ctrl+Z)',
                state.canUndo ? () => state.undo() : null,
              ),
              _topBarIconButton(
                Icons.redo_rounded,
                'Rétablir (Ctrl+Shift+Z)',
                state.canRedo ? () => state.redo() : null,
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: const Color(0xFF3A3A4C)),
              const SizedBox(width: 8),
              // Grid toggle
              _topBarToggle(
                Icons.grid_4x4_rounded,
                'Grille',
                state.document.showGrid,
                () => state.toggleGrid(),
              ),
              _topBarToggle(
                Icons.near_me_rounded,
                'Aimanter',
                state.document.snapToGrid,
                () => state.toggleSnap(),
              ),
              const Spacer(),
              // Zoom controls
              _topBarIconButton(
                Icons.remove_rounded,
                'Zoom arrière',
                () => state.zoomOut(),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A4C),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(state.zoom * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              _topBarIconButton(
                Icons.add_rounded,
                'Zoom avant',
                () => state.zoomIn(),
              ),
              _topBarIconButton(
                Icons.fit_screen_rounded,
                'Réinitialiser zoom',
                () => state.resetZoom(),
              ),
              const SizedBox(width: 16),
              // Save button
              _saveButton(state),
            ],
          ),
        );

        _cachedTopBar = child;
        return child;
      },
    );
  }

  Widget _topBarIconButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: onPressed != null
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF4A4A5C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBarToggle(IconData icon, String tooltip, bool active, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? AppColors.primaryLight : const Color(0xFF8B8BA7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _saveButton(CanvasEditorState state) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            state.markSaved();
            if (_template != null) {
              final updatedConfig = Map<String, dynamic>.from(_template!.config);
              updatedConfig['canvas_document'] = state.document.toJson();
              final updatedTemplate = _template!.copyWith(
                name: state.document.name,
                config: updatedConfig,
              );
              context.read<DocumentTemplatesBloc>().add(UpdateDocumentTemplate(updatedTemplate));
              _template = updatedTemplate;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Modèle enregistré avec succès !'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.save_rounded, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text('Enregistrer', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Consumer<CanvasEditorState>(
      builder: (context, state, _) {
        if ((state.isDragging || state.isResizing) && _cachedBottomBar != null) {
          return _cachedBottomBar!;
        }

        final sel = state.selectedElement;
        final child = Container(
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A3C),
            border: Border(top: BorderSide(color: Color(0xFF3A3A4C))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _statusItem(Icons.layers_rounded, '${state.elements.length} éléments'),
              const SizedBox(width: 16),
              if (sel != null) ...[
                _statusItem(Icons.open_with_rounded, 'X: ${sel.x.toStringAsFixed(1)} Y: ${sel.y.toStringAsFixed(1)}'),
                const SizedBox(width: 12),
                _statusItem(Icons.aspect_ratio_rounded, '${sel.width.toStringAsFixed(1)} × ${sel.height.toStringAsFixed(1)} mm'),
              ],
              const Spacer(),
              _statusItem(Icons.straighten_rounded, 'A4 (210 × 297 mm)'),
            ],
          ),
        );

        _cachedBottomBar = child;
        return child;
      },
    );
  }

  Widget _statusItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF8B8BA7)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Color(0xFF8B8BA7), fontSize: 11)),
      ],
    );
  }
}
