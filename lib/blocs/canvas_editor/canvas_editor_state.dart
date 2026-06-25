import 'package:flutter/material.dart';
import '../../models/canvas/canvas_element.dart';

/// Manages the entire state of the canvas invoice designer.
/// Uses ChangeNotifier for simple, efficient rebuilds.
class CanvasEditorState extends ChangeNotifier {
  CanvasDocument _document;
  String? _selectedElementId;
  final List<CanvasDocument> _undoStack = [];
  final List<CanvasDocument> _redoStack = [];
  double _zoom = 1.0;
  final Offset _panOffset = Offset.zero;
  bool _isDirty = false;

  // Drag state
  String? _draggingElementId;
  Offset? _dragStartOffset;

  // Resize state
  String? _resizingElementId;
  String? _resizeHandle; // 'tl','tr','bl','br','t','b','l','r'
  Offset? _resizeStartOffset;
  double _resizeStartX = 0;
  double _resizeStartY = 0;
  double _resizeStartW = 0;
  double _resizeStartH = 0;

  CanvasEditorState({CanvasDocument? document})
      : _document = document ?? CanvasDocument.defaultInvoiceTemplate();

  // ─── Getters ────────────────────────────────────────────────────

  CanvasDocument get document => _document;
  List<CanvasElement> get elements => _document.elements;
  String? get selectedElementId => _selectedElementId;
  double get zoom => _zoom;
  Offset get panOffset => _panOffset;
  bool get isDirty => _isDirty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isDragging => _draggingElementId != null;
  bool get isResizing => _resizingElementId != null;

  CanvasElement? get selectedElement {
    if (_selectedElementId == null) return null;
    try {
      return _document.elements
          .firstWhere((e) => e.id == _selectedElementId);
    } catch (_) {
      return null;
    }
  }

  List<CanvasElement> get sortedElements {
    final sorted = List<CanvasElement>.from(_document.elements);
    sorted.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return sorted;
  }

  // ─── History ────────────────────────────────────────────────────

  void _pushUndo() {
    _undoStack.add(CanvasDocument.fromMap(_document.toMap()));
    _redoStack.clear();
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _isDirty = true;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(CanvasDocument.fromMap(_document.toMap()));
    _document = _undoStack.removeLast();
    _selectedElementId = null;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(CanvasDocument.fromMap(_document.toMap()));
    _document = _redoStack.removeLast();
    _selectedElementId = null;
    notifyListeners();
  }

  // ─── Selection ──────────────────────────────────────────────────

  void selectElement(String? id) {
    _selectedElementId = id;
    notifyListeners();
  }

  void deselectAll() {
    _selectedElementId = null;
    notifyListeners();
  }

  // ─── Add Elements ───────────────────────────────────────────────

  void addElement(CanvasElement element) {
    _pushUndo();
    element.zIndex = _document.elements.isEmpty
        ? 1
        : _document.elements
                .map((e) => e.zIndex)
                .reduce((a, b) => a > b ? a : b) +
            1;
    _document.elements.add(element);
    _selectedElementId = element.id;
    notifyListeners();
  }

  // ─── Remove ─────────────────────────────────────────────────────

  void removeElement(String id) {
    _pushUndo();
    _document.elements.removeWhere((e) => e.id == id);
    if (_selectedElementId == id) _selectedElementId = null;
    notifyListeners();
  }

  void deleteSelected() {
    if (_selectedElementId != null) {
      final el = selectedElement;
      if (el != null && !el.isLocked) {
        removeElement(_selectedElementId!);
      }
    }
  }

  // ─── Duplicate ──────────────────────────────────────────────────

  void duplicateElement(String id) {
    final el = _document.elements.cast<CanvasElement?>().firstWhere(
        (e) => e!.id == id,
        orElse: () => null);
    if (el == null) return;
    _pushUndo();
    final map = el.toMap();
    map.remove('id');
    map['x'] = (el.x + 5);
    map['y'] = (el.y + 5);
    final newEl = CanvasElement.fromMap(map);
    newEl.zIndex = _document.elements
            .map((e) => e.zIndex)
            .reduce((a, b) => a > b ? a : b) +
        1;
    _document.elements.add(newEl);
    _selectedElementId = newEl.id;
    notifyListeners();
  }

  // ─── Update Element ─────────────────────────────────────────────

  void updateElement(String id, CanvasElement updated) {
    final idx = _document.elements.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _document.elements[idx] = updated;
    notifyListeners();
  }

  /// Commits a property change with undo history
  void updateElementWithHistory(String id, CanvasElement updated) {
    _pushUndo();
    updateElement(id, updated);
  }

  // ─── Move (Drag) ────────────────────────────────────────────────

  void startDrag(String id, Offset globalPosition) {
    final el = _document.elements.cast<CanvasElement?>().firstWhere(
        (e) => e!.id == id,
        orElse: () => null);
    if (el == null || el.isLocked) return;
    _draggingElementId = id;
    _dragStartOffset = globalPosition;
    _pushUndo();
  }

  void updateDrag(Offset globalPosition, double scale) {
    if (_draggingElementId == null || _dragStartOffset == null) return;
    final el = _document.elements.cast<CanvasElement?>().firstWhere(
        (e) => e!.id == _draggingElementId,
        orElse: () => null);
    if (el == null) return;

    final delta = globalPosition - _dragStartOffset!;
    // Convert screen delta to mm (considering zoom)
    final dxMm = delta.dx / scale;
    final dyMm = delta.dy / scale;

    double newX = el.x + dxMm;
    double newY = el.y + dyMm;

    // Snap to grid
    if (_document.snapToGrid) {
      final grid = _document.gridSize;
      newX = (newX / grid).round() * grid;
      newY = (newY / grid).round() * grid;
    }

    // Clamp within page bounds
    newX = newX.clamp(0, _document.pageWidth - el.width);
    newY = newY.clamp(0, _document.pageHeight - el.height);

    el.x = newX;
    el.y = newY;
    _dragStartOffset = globalPosition;
    notifyListeners();
  }

  void endDrag() {
    _draggingElementId = null;
    _dragStartOffset = null;
  }

  // ─── Resize ─────────────────────────────────────────────────────

  void startResize(String id, String handle, Offset globalPosition) {
    final el = _document.elements.cast<CanvasElement?>().firstWhere(
        (e) => e!.id == id,
        orElse: () => null);
    if (el == null || el.isLocked) return;
    _resizingElementId = id;
    _resizeHandle = handle;
    _resizeStartOffset = globalPosition;
    _resizeStartX = el.x;
    _resizeStartY = el.y;
    _resizeStartW = el.width;
    _resizeStartH = el.height;
    _pushUndo();
  }

  void updateResize(Offset globalPosition, double scale) {
    if (_resizingElementId == null || _resizeStartOffset == null) return;
    final el = _document.elements.cast<CanvasElement?>().firstWhere(
        (e) => e!.id == _resizingElementId,
        orElse: () => null);
    if (el == null) return;

    final delta = globalPosition - _resizeStartOffset!;
    final dxMm = delta.dx / scale;
    final dyMm = delta.dy / scale;

    double newX = _resizeStartX;
    double newY = _resizeStartY;
    double newW = _resizeStartW;
    double newH = _resizeStartH;

    const minSize = 5.0;

    switch (_resizeHandle) {
      case 'br':
        newW = (_resizeStartW + dxMm).clamp(minSize, _document.pageWidth - newX);
        newH = (_resizeStartH + dyMm).clamp(minSize, _document.pageHeight - newY);
        break;
      case 'bl':
        final deltaW = dxMm;
        newX = (_resizeStartX + deltaW).clamp(0, _resizeStartX + _resizeStartW - minSize);
        newW = _resizeStartW - (newX - _resizeStartX);
        newH = (_resizeStartH + dyMm).clamp(minSize, _document.pageHeight - newY);
        break;
      case 'tr':
        final deltaH = dyMm;
        newY = (_resizeStartY + deltaH).clamp(0, _resizeStartY + _resizeStartH - minSize);
        newH = _resizeStartH - (newY - _resizeStartY);
        newW = (_resizeStartW + dxMm).clamp(minSize, _document.pageWidth - newX);
        break;
      case 'tl':
        final deltaW = dxMm;
        final deltaH = dyMm;
        newX = (_resizeStartX + deltaW).clamp(0, _resizeStartX + _resizeStartW - minSize);
        newY = (_resizeStartY + deltaH).clamp(0, _resizeStartY + _resizeStartH - minSize);
        newW = _resizeStartW - (newX - _resizeStartX);
        newH = _resizeStartH - (newY - _resizeStartY);
        break;
      case 'r':
        newW = (_resizeStartW + dxMm).clamp(minSize, _document.pageWidth - newX);
        break;
      case 'l':
        newX = (_resizeStartX + dxMm).clamp(0, _resizeStartX + _resizeStartW - minSize);
        newW = _resizeStartW - (newX - _resizeStartX);
        break;
      case 'b':
        newH = (_resizeStartH + dyMm).clamp(minSize, _document.pageHeight - newY);
        break;
      case 't':
        newY = (_resizeStartY + dyMm).clamp(0, _resizeStartY + _resizeStartH - minSize);
        newH = _resizeStartH - (newY - _resizeStartY);
        break;
    }

    // Snap to grid
    if (_document.snapToGrid) {
      final grid = _document.gridSize;
      newX = (newX / grid).round() * grid;
      newY = (newY / grid).round() * grid;
      newW = (newW / grid).round() * grid;
      newH = (newH / grid).round() * grid;
      if (newW < minSize) newW = minSize;
      if (newH < minSize) newH = minSize;
    }

    el.x = newX;
    el.y = newY;
    el.width = newW;
    el.height = newH;
    notifyListeners();
  }

  void endResize() {
    _resizingElementId = null;
    _resizeHandle = null;
    _resizeStartOffset = null;
  }

  // ─── Layer Operations ───────────────────────────────────────────

  void bringToFront(String id) {
    _pushUndo();
    final maxZ = _document.elements
        .map((e) => e.zIndex)
        .reduce((a, b) => a > b ? a : b);
    final el = _document.elements.firstWhere((e) => e.id == id);
    el.zIndex = maxZ + 1;
    notifyListeners();
  }

  void sendToBack(String id) {
    _pushUndo();
    final minZ = _document.elements
        .map((e) => e.zIndex)
        .reduce((a, b) => a < b ? a : b);
    final el = _document.elements.firstWhere((e) => e.id == id);
    el.zIndex = minZ - 1;
    notifyListeners();
  }

  // ─── Lock/Unlock ────────────────────────────────────────────────

  void toggleLock(String id) {
    final el = _document.elements.firstWhere((e) => e.id == id);
    el.isLocked = !el.isLocked;
    notifyListeners();
  }

  void toggleVisibility(String id) {
    final el = _document.elements.firstWhere((e) => e.id == id);
    el.isVisible = !el.isVisible;
    notifyListeners();
  }

  // ─── Zoom ───────────────────────────────────────────────────────

  void setZoom(double z) {
    _zoom = z.clamp(0.25, 4.0);
    notifyListeners();
  }

  void zoomIn() => setZoom(_zoom + 0.1);
  void zoomOut() => setZoom(_zoom - 0.1);
  void resetZoom() => setZoom(1.0);

  // ─── Document Settings ──────────────────────────────────────────

  void toggleGrid() {
    _document.showGrid = !_document.showGrid;
    notifyListeners();
  }

  void toggleSnap() {
    _document.snapToGrid = !_document.snapToGrid;
    notifyListeners();
  }

  void setGridSize(double size) {
    _document.gridSize = size;
    notifyListeners();
  }

  void setDocumentName(String name) {
    _document.name = name;
    _isDirty = true;
    notifyListeners();
  }

  void setMargins({double? top, double? bottom, double? left, double? right}) {
    if (top != null) _document.marginTop = top;
    if (bottom != null) _document.marginBottom = bottom;
    if (left != null) _document.marginLeft = left;
    if (right != null) _document.marginRight = right;
    notifyListeners();
  }

  // ─── Load/Reset ─────────────────────────────────────────────────

  void loadDocument(CanvasDocument doc) {
    _document = doc;
    _selectedElementId = null;
    _undoStack.clear();
    _redoStack.clear();
    _isDirty = false;
    notifyListeners();
  }

  void resetToDefault() {
    _pushUndo();
    _document = CanvasDocument.defaultInvoiceTemplate();
    _selectedElementId = null;
    notifyListeners();
  }

  void markSaved() {
    _isDirty = false;
    notifyListeners();
  }
}
