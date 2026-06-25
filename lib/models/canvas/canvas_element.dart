import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ─── Element Types ────────────────────────────────────────────────
enum CanvasElementType {
  text,
  shape,
  image,
  divider,
  dynamicField,
  table,
}

// ─── Shape Kinds ──────────────────────────────────────────────────
enum ShapeKind { rectangle, circle, roundedRect }

// ─── Text Alignment ───────────────────────────────────────────────
enum CanvasTextAlign { left, center, right }

// ─── Dynamic Field Types ──────────────────────────────────────────
enum DynamicFieldType {
  companyName,
  companyAddress,
  companyPhone,
  companyEmail,
  companyVat,
  clientName,
  clientAddress,
  clientPhone,
  clientEmail,
  invoiceNumber,
  invoiceDate,
  invoiceDueDate,
  totalHT,
  totalTVA,
  totalTTC,
  currency,
  notes,
  conditions,
  custom,
}

// ─── Base Element ─────────────────────────────────────────────────
class CanvasElement {
  final String id;
  final CanvasElementType type;
  double x; // mm from left
  double y; // mm from top
  double width; // mm
  double height; // mm
  double rotation; // degrees
  double opacity; // 0.0 – 1.0
  int zIndex;
  bool isLocked;
  bool isVisible;

  CanvasElement({
    String? id,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 50,
    this.height = 20,
    this.rotation = 0,
    this.opacity = 1.0,
    this.zIndex = 0,
    this.isLocked = false,
    this.isVisible = true,
  }) : id = id ?? _uuid.v4();

  CanvasElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isLocked,
    bool? isVisible,
  }) {
    return CanvasElement(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'opacity': opacity,
        'zIndex': zIndex,
        'isLocked': isLocked,
        'isVisible': isVisible,
      };

  factory CanvasElement.fromMap(Map<String, dynamic> m) {
    final type = CanvasElementType.values.firstWhere((e) => e.name == m['type']);
    switch (type) {
      case CanvasElementType.text:
        return TextElement.fromMap(m);
      case CanvasElementType.shape:
        return ShapeElement.fromMap(m);
      case CanvasElementType.image:
        return ImageElement.fromMap(m);
      case CanvasElementType.divider:
        return DividerElement.fromMap(m);
      case CanvasElementType.dynamicField:
        return DynamicFieldElement.fromMap(m);
      case CanvasElementType.table:
        return CanvasTableElement.fromMap(m);
    }
  }
}

// ─── Text Element ─────────────────────────────────────────────────
class TextElement extends CanvasElement {
  String text;
  String fontFamily;
  double fontSize;
  int color; // ARGB int
  bool isBold;
  bool isItalic;
  bool isUnderline;
  CanvasTextAlign textAlign;
  double lineHeight;

  TextElement({
    super.id,
    super.x,
    super.y,
    super.width = 80,
    super.height = 12,
    super.rotation,
    super.opacity,
    super.zIndex,
    super.isLocked,
    super.isVisible,
    this.text = 'Nouveau texte',
    this.fontFamily = 'Roboto',
    this.fontSize = 12,
    this.color = 0xFF000000,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.textAlign = CanvasTextAlign.left,
    this.lineHeight = 1.4,
  }) : super(type: CanvasElementType.text);

  @override
  TextElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isLocked,
    bool? isVisible,
    String? text,
    String? fontFamily,
    double? fontSize,
    int? color,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    CanvasTextAlign? textAlign,
    double? lineHeight,
  }) {
    return TextElement(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      textAlign: textAlign ?? this.textAlign,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'text': text,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'color': color,
        'isBold': isBold,
        'isItalic': isItalic,
        'isUnderline': isUnderline,
        'textAlign': textAlign.name,
        'lineHeight': lineHeight,
      };

  factory TextElement.fromMap(Map<String, dynamic> m) => TextElement(
        id: m['id'] as String?,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        width: (m['width'] as num).toDouble(),
        height: (m['height'] as num).toDouble(),
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: m['zIndex'] as int? ?? 0,
        isLocked: m['isLocked'] as bool? ?? false,
        isVisible: m['isVisible'] as bool? ?? true,
        text: m['text'] as String? ?? 'Texte',
        fontFamily: m['fontFamily'] as String? ?? 'Roboto',
        fontSize: (m['fontSize'] as num?)?.toDouble() ?? 12,
        color: m['color'] as int? ?? 0xFF000000,
        isBold: m['isBold'] as bool? ?? false,
        isItalic: m['isItalic'] as bool? ?? false,
        isUnderline: m['isUnderline'] as bool? ?? false,
        textAlign: CanvasTextAlign.values.firstWhere(
            (e) => e.name == (m['textAlign'] as String? ?? 'left'),
            orElse: () => CanvasTextAlign.left),
        lineHeight: (m['lineHeight'] as num?)?.toDouble() ?? 1.4,
      );
}

// ─── Shape Element ────────────────────────────────────────────────
class ShapeElement extends CanvasElement {
  ShapeKind shapeKind;
  int fillColor;
  int borderColor;
  double borderWidth;
  double borderRadius;

  ShapeElement({
    super.id,
    super.x,
    super.y,
    super.width = 40,
    super.height = 40,
    super.rotation,
    super.opacity,
    super.zIndex,
    super.isLocked,
    super.isVisible,
    this.shapeKind = ShapeKind.rectangle,
    this.fillColor = 0xFFE2E8F0,
    this.borderColor = 0xFF94A3B8,
    this.borderWidth = 1.0,
    this.borderRadius = 0,
  }) : super(type: CanvasElementType.shape);

  @override
  ShapeElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isLocked,
    bool? isVisible,
    ShapeKind? shapeKind,
    int? fillColor,
    int? borderColor,
    double? borderWidth,
    double? borderRadius,
  }) {
    return ShapeElement(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      shapeKind: shapeKind ?? this.shapeKind,
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'shapeKind': shapeKind.name,
        'fillColor': fillColor,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
        'borderRadius': borderRadius,
      };

  factory ShapeElement.fromMap(Map<String, dynamic> m) => ShapeElement(
        id: m['id'] as String?,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        width: (m['width'] as num).toDouble(),
        height: (m['height'] as num).toDouble(),
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: m['zIndex'] as int? ?? 0,
        isLocked: m['isLocked'] as bool? ?? false,
        isVisible: m['isVisible'] as bool? ?? true,
        shapeKind: ShapeKind.values.firstWhere(
            (e) => e.name == (m['shapeKind'] as String? ?? 'rectangle'),
            orElse: () => ShapeKind.rectangle),
        fillColor: m['fillColor'] as int? ?? 0xFFE2E8F0,
        borderColor: m['borderColor'] as int? ?? 0xFF94A3B8,
        borderWidth: (m['borderWidth'] as num?)?.toDouble() ?? 1.0,
        borderRadius: (m['borderRadius'] as num?)?.toDouble() ?? 0,
      );
}

// ─── Image Element ────────────────────────────────────────────────
class ImageElement extends CanvasElement {
  String? imagePath;
  String placeholder;
  int borderColor;
  double borderWidth;

  ImageElement({
    super.id,
    super.x,
    super.y,
    super.width = 40,
    super.height = 30,
    super.rotation,
    super.opacity,
    super.zIndex,
    super.isLocked,
    super.isVisible,
    this.imagePath,
    this.placeholder = 'Logo',
    this.borderColor = 0xFFE2E8F0,
    this.borderWidth = 0,
  }) : super(type: CanvasElementType.image);

  @override
  ImageElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isLocked,
    bool? isVisible,
    String? imagePath,
    String? placeholder,
    int? borderColor,
    double? borderWidth,
  }) {
    return ImageElement(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      imagePath: imagePath ?? this.imagePath,
      placeholder: placeholder ?? this.placeholder,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'imagePath': imagePath,
        'placeholder': placeholder,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
      };

  factory ImageElement.fromMap(Map<String, dynamic> m) => ImageElement(
        id: m['id'] as String?,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        width: (m['width'] as num).toDouble(),
        height: (m['height'] as num).toDouble(),
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: m['zIndex'] as int? ?? 0,
        isLocked: m['isLocked'] as bool? ?? false,
        isVisible: m['isVisible'] as bool? ?? true,
        imagePath: m['imagePath'] as String?,
        placeholder: m['placeholder'] as String? ?? 'Logo',
        borderColor: m['borderColor'] as int? ?? 0xFFE2E8F0,
        borderWidth: (m['borderWidth'] as num?)?.toDouble() ?? 0,
      );
}

// ─── Divider Element ──────────────────────────────────────────────
class DividerElement extends CanvasElement {
  int color;
  double thickness;
  bool isVertical;

  DividerElement({
    super.id,
    super.x,
    super.y,
    super.width = 80,
    super.height = 1,
    super.rotation,
    super.opacity,
    super.zIndex,
    super.isLocked,
    super.isVisible,
    this.color = 0xFFCBD5E1,
    this.thickness = 0.5,
    this.isVertical = false,
  }) : super(type: CanvasElementType.divider);

  @override
  DividerElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isLocked,
    bool? isVisible,
    int? color,
    double? thickness,
    bool? isVertical,
  }) {
    return DividerElement(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      color: color ?? this.color,
      thickness: thickness ?? this.thickness,
      isVertical: isVertical ?? this.isVertical,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'color': color,
        'thickness': thickness,
        'isVertical': isVertical,
      };

  factory DividerElement.fromMap(Map<String, dynamic> m) => DividerElement(
        id: m['id'] as String?,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        width: (m['width'] as num).toDouble(),
        height: (m['height'] as num).toDouble(),
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: m['zIndex'] as int? ?? 0,
        isLocked: m['isLocked'] as bool? ?? false,
        isVisible: m['isVisible'] as bool? ?? true,
        color: m['color'] as int? ?? 0xFFCBD5E1,
        thickness: (m['thickness'] as num?)?.toDouble() ?? 0.5,
        isVertical: m['isVertical'] as bool? ?? false,
      );
}

// ─── Dynamic Field Element ────────────────────────────────────────
class DynamicFieldElement extends CanvasElement {
  DynamicFieldType fieldType;
  String label;
  String? customKey;
  String fontFamily;
  double fontSize;
  int color;
  bool isBold;
  bool showLabel;
  CanvasTextAlign textAlign;

  DynamicFieldElement({
    super.id,
    super.x,
    super.y,
    super.width = 60,
    super.height = 8,
    super.rotation,
    super.opacity,
    super.zIndex,
    super.isLocked,
    super.isVisible,
    this.fieldType = DynamicFieldType.companyName,
    this.label = '',
    this.customKey,
    this.fontFamily = 'Roboto',
    this.fontSize = 10,
    this.color = 0xFF000000,
    this.isBold = false,
    this.showLabel = true,
    this.textAlign = CanvasTextAlign.left,
  }) : super(type: CanvasElementType.dynamicField);

  String get displayLabel {
    if (label.isNotEmpty) return label;
    switch (fieldType) {
      case DynamicFieldType.companyName:
        return 'Nom de l\'entreprise';
      case DynamicFieldType.companyAddress:
        return 'Adresse entreprise';
      case DynamicFieldType.companyPhone:
        return 'Tél. entreprise';
      case DynamicFieldType.companyEmail:
        return 'Email entreprise';
      case DynamicFieldType.companyVat:
        return 'N° TVA';
      case DynamicFieldType.clientName:
        return 'Nom client';
      case DynamicFieldType.clientAddress:
        return 'Adresse client';
      case DynamicFieldType.clientPhone:
        return 'Tél. client';
      case DynamicFieldType.clientEmail:
        return 'Email client';
      case DynamicFieldType.invoiceNumber:
        return 'N° Facture';
      case DynamicFieldType.invoiceDate:
        return 'Date facture';
      case DynamicFieldType.invoiceDueDate:
        return 'Date échéance';
      case DynamicFieldType.totalHT:
        return 'Total HT';
      case DynamicFieldType.totalTVA:
        return 'Total TVA';
      case DynamicFieldType.totalTTC:
        return 'Total TTC';
      case DynamicFieldType.currency:
        return 'Devise';
      case DynamicFieldType.notes:
        return 'Notes';
      case DynamicFieldType.conditions:
        return 'Conditions';
      case DynamicFieldType.custom:
        return customKey ?? 'Champ personnalisé';
    }
  }

  String get sampleValue {
    switch (fieldType) {
      case DynamicFieldType.companyName:
        return 'Mon Entreprise SARL';
      case DynamicFieldType.companyAddress:
        return '123 Rue de la Paix, Alger';
      case DynamicFieldType.companyPhone:
        return '+213 555 123 456';
      case DynamicFieldType.companyEmail:
        return 'contact@entreprise.dz';
      case DynamicFieldType.companyVat:
        return '001234567890123';
      case DynamicFieldType.clientName:
        return 'Client Exemple';
      case DynamicFieldType.clientAddress:
        return '456 Avenue Ahmed, Oran';
      case DynamicFieldType.clientPhone:
        return '+213 555 789 012';
      case DynamicFieldType.clientEmail:
        return 'client@exemple.dz';
      case DynamicFieldType.invoiceNumber:
        return 'FAC-2026-0001';
      case DynamicFieldType.invoiceDate:
        return '22/06/2026';
      case DynamicFieldType.invoiceDueDate:
        return '22/07/2026';
      case DynamicFieldType.totalHT:
        return '150 000,00';
      case DynamicFieldType.totalTVA:
        return '28 500,00';
      case DynamicFieldType.totalTTC:
        return '178 500,00';
      case DynamicFieldType.currency:
        return 'DZD';
      case DynamicFieldType.notes:
        return 'Notes de la facture...';
      case DynamicFieldType.conditions:
        return 'Conditions générales de vente...';
      case DynamicFieldType.custom:
        return customKey ?? '—';
    }
  }

  @override
  DynamicFieldElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isLocked,
    bool? isVisible,
    DynamicFieldType? fieldType,
    String? label,
    String? customKey,
    String? fontFamily,
    double? fontSize,
    int? color,
    bool? isBold,
    bool? showLabel,
    CanvasTextAlign? textAlign,
  }) {
    return DynamicFieldElement(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      fieldType: fieldType ?? this.fieldType,
      label: label ?? this.label,
      customKey: customKey ?? this.customKey,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      isBold: isBold ?? this.isBold,
      showLabel: showLabel ?? this.showLabel,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'fieldType': fieldType.name,
        'label': label,
        'customKey': customKey,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'color': color,
        'isBold': isBold,
        'showLabel': showLabel,
        'textAlign': textAlign.name,
      };

  factory DynamicFieldElement.fromMap(Map<String, dynamic> m) =>
      DynamicFieldElement(
        id: m['id'] as String?,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        width: (m['width'] as num).toDouble(),
        height: (m['height'] as num).toDouble(),
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: m['zIndex'] as int? ?? 0,
        isLocked: m['isLocked'] as bool? ?? false,
        isVisible: m['isVisible'] as bool? ?? true,
        fieldType: DynamicFieldType.values.firstWhere(
            (e) => e.name == (m['fieldType'] as String? ?? 'companyName'),
            orElse: () => DynamicFieldType.companyName),
        label: m['label'] as String? ?? '',
        customKey: m['customKey'] as String?,
        fontFamily: m['fontFamily'] as String? ?? 'Roboto',
        fontSize: (m['fontSize'] as num?)?.toDouble() ?? 10,
        color: m['color'] as int? ?? 0xFF000000,
        isBold: m['isBold'] as bool? ?? false,
        showLabel: m['showLabel'] as bool? ?? true,
        textAlign: CanvasTextAlign.values.firstWhere(
            (e) => e.name == (m['textAlign'] as String? ?? 'left'),
            orElse: () => CanvasTextAlign.left),
      );
}

// ─── Table Element ────────────────────────────────────────────────
class CanvasTableElement extends CanvasElement {
  int columnCount;
  int rowCount;
  List<String> headers;
  int headerBgColor;
  int headerTextColor;
  double headerFontSize;
  double cellFontSize;
  int borderColor;
  double borderWidth;
  double cellPadding;

  CanvasTableElement({
    super.id,
    super.x,
    super.y,
    super.width = 170,
    super.height = 60,
    super.rotation,
    super.opacity,
    super.zIndex,
    super.isLocked,
    super.isVisible,
    this.columnCount = 5,
    this.rowCount = 4,
    List<String>? headers,
    this.headerBgColor = 0xFF1a56db,
    this.headerTextColor = 0xFFFFFFFF,
    this.headerFontSize = 9,
    this.cellFontSize = 8,
    this.borderColor = 0xFFE2E8F0,
    this.borderWidth = 0.5,
    this.cellPadding = 4,
  })  : headers = headers ?? ['Désignation', 'Qté', 'P.U.', 'TVA', 'Total'],
        super(type: CanvasElementType.table);

  @override
  CanvasTableElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isLocked,
    bool? isVisible,
    int? columnCount,
    int? rowCount,
    List<String>? headers,
    int? headerBgColor,
    int? headerTextColor,
    double? headerFontSize,
    double? cellFontSize,
    int? borderColor,
    double? borderWidth,
    double? cellPadding,
  }) {
    return CanvasTableElement(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      columnCount: columnCount ?? this.columnCount,
      rowCount: rowCount ?? this.rowCount,
      headers: headers ?? List.from(this.headers),
      headerBgColor: headerBgColor ?? this.headerBgColor,
      headerTextColor: headerTextColor ?? this.headerTextColor,
      headerFontSize: headerFontSize ?? this.headerFontSize,
      cellFontSize: cellFontSize ?? this.cellFontSize,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cellPadding: cellPadding ?? this.cellPadding,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'columnCount': columnCount,
        'rowCount': rowCount,
        'headers': headers,
        'headerBgColor': headerBgColor,
        'headerTextColor': headerTextColor,
        'headerFontSize': headerFontSize,
        'cellFontSize': cellFontSize,
        'borderColor': borderColor,
        'borderWidth': borderWidth,
        'cellPadding': cellPadding,
      };

  factory CanvasTableElement.fromMap(Map<String, dynamic> m) =>
      CanvasTableElement(
        id: m['id'] as String?,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        width: (m['width'] as num).toDouble(),
        height: (m['height'] as num).toDouble(),
        rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (m['opacity'] as num?)?.toDouble() ?? 1.0,
        zIndex: m['zIndex'] as int? ?? 0,
        isLocked: m['isLocked'] as bool? ?? false,
        isVisible: m['isVisible'] as bool? ?? true,
        columnCount: m['columnCount'] as int? ?? 5,
        rowCount: m['rowCount'] as int? ?? 4,
        headers: (m['headers'] as List?)?.cast<String>(),
        headerBgColor: m['headerBgColor'] as int? ?? 0xFF1a56db,
        headerTextColor: m['headerTextColor'] as int? ?? 0xFFFFFFFF,
        headerFontSize: (m['headerFontSize'] as num?)?.toDouble() ?? 9,
        cellFontSize: (m['cellFontSize'] as num?)?.toDouble() ?? 8,
        borderColor: m['borderColor'] as int? ?? 0xFFE2E8F0,
        borderWidth: (m['borderWidth'] as num?)?.toDouble() ?? 0.5,
        cellPadding: (m['cellPadding'] as num?)?.toDouble() ?? 4,
      );
}

// ─── Canvas Document ──────────────────────────────────────────────
class CanvasDocument {
  final String id;
  String name;
  double pageWidth; // mm (A4 = 210)
  double pageHeight; // mm (A4 = 297)
  double marginTop;
  double marginBottom;
  double marginLeft;
  double marginRight;
  int backgroundColor;
  bool showGrid;
  double gridSize; // mm
  bool snapToGrid;
  List<CanvasElement> elements;

  CanvasDocument({
    String? id,
    this.name = 'Nouveau modèle',
    this.pageWidth = 210,
    this.pageHeight = 297,
    this.marginTop = 15,
    this.marginBottom = 15,
    this.marginLeft = 15,
    this.marginRight = 15,
    this.backgroundColor = 0xFFFFFFFF,
    this.showGrid = true,
    this.gridSize = 5,
    this.snapToGrid = true,
    List<CanvasElement>? elements,
  })  : id = id ?? _uuid.v4(),
        elements = elements ?? [];

  CanvasDocument copyWith({
    String? name,
    double? pageWidth,
    double? pageHeight,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    int? backgroundColor,
    bool? showGrid,
    double? gridSize,
    bool? snapToGrid,
    List<CanvasElement>? elements,
  }) {
    return CanvasDocument(
      id: id,
      name: name ?? this.name,
      pageWidth: pageWidth ?? this.pageWidth,
      pageHeight: pageHeight ?? this.pageHeight,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      showGrid: showGrid ?? this.showGrid,
      gridSize: gridSize ?? this.gridSize,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      elements: elements ?? this.elements.map((e) {
        // Deep copy each element
        return CanvasElement.fromMap(e.toMap());
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'pageWidth': pageWidth,
        'pageHeight': pageHeight,
        'marginTop': marginTop,
        'marginBottom': marginBottom,
        'marginLeft': marginLeft,
        'marginRight': marginRight,
        'backgroundColor': backgroundColor,
        'showGrid': showGrid,
        'gridSize': gridSize,
        'snapToGrid': snapToGrid,
        'elements': elements.map((e) => e.toMap()).toList(),
      };

  String toJson() => jsonEncode(toMap());

  factory CanvasDocument.fromMap(Map<String, dynamic> m) {
    return CanvasDocument(
      id: m['id'] as String?,
      name: m['name'] as String? ?? 'Modèle',
      pageWidth: (m['pageWidth'] as num?)?.toDouble() ?? 210,
      pageHeight: (m['pageHeight'] as num?)?.toDouble() ?? 297,
      marginTop: (m['marginTop'] as num?)?.toDouble() ?? 15,
      marginBottom: (m['marginBottom'] as num?)?.toDouble() ?? 15,
      marginLeft: (m['marginLeft'] as num?)?.toDouble() ?? 15,
      marginRight: (m['marginRight'] as num?)?.toDouble() ?? 15,
      backgroundColor: m['backgroundColor'] as int? ?? 0xFFFFFFFF,
      showGrid: m['showGrid'] as bool? ?? true,
      gridSize: (m['gridSize'] as num?)?.toDouble() ?? 5,
      snapToGrid: m['snapToGrid'] as bool? ?? true,
      elements: (m['elements'] as List?)
              ?.map((e) =>
                  CanvasElement.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  factory CanvasDocument.fromJson(String json) =>
      CanvasDocument.fromMap(jsonDecode(json) as Map<String, dynamic>);

  /// Creates a default professional invoice template with pre-placed elements
  factory CanvasDocument.defaultInvoiceTemplate() {
    return CanvasDocument(
      name: 'Facture par défaut',
      elements: [
        // Company logo placeholder
        ImageElement(
          x: 15,
          y: 15,
          width: 35,
          height: 25,
          placeholder: 'LOGO',
          zIndex: 1,
        ),
        // Company name
        DynamicFieldElement(
          x: 55,
          y: 15,
          width: 80,
          height: 8,
          fieldType: DynamicFieldType.companyName,
          fontSize: 14,
          isBold: true,
          zIndex: 2,
        ),
        // Company address
        DynamicFieldElement(
          x: 55,
          y: 24,
          width: 80,
          height: 6,
          fieldType: DynamicFieldType.companyAddress,
          fontSize: 9,
          zIndex: 3,
        ),
        // Invoice title
        TextElement(
          x: 140,
          y: 15,
          width: 55,
          height: 12,
          text: 'FACTURE',
          fontSize: 20,
          isBold: true,
          color: 0xFF1a56db,
          textAlign: CanvasTextAlign.right,
          zIndex: 4,
        ),
        // Invoice number
        DynamicFieldElement(
          x: 140,
          y: 30,
          width: 55,
          height: 6,
          fieldType: DynamicFieldType.invoiceNumber,
          fontSize: 10,
          isBold: true,
          textAlign: CanvasTextAlign.right,
          zIndex: 5,
        ),
        // Invoice date
        DynamicFieldElement(
          x: 140,
          y: 37,
          width: 55,
          height: 6,
          fieldType: DynamicFieldType.invoiceDate,
          fontSize: 9,
          textAlign: CanvasTextAlign.right,
          zIndex: 6,
        ),
        // Divider
        DividerElement(
          x: 15,
          y: 50,
          width: 180,
          height: 1,
          color: 0xFF1a56db,
          thickness: 1.0,
          zIndex: 7,
        ),
        // Client details
        DynamicFieldElement(
          x: 15,
          y: 55,
          width: 80,
          height: 6,
          fieldType: DynamicFieldType.clientName,
          fontSize: 11,
          isBold: true,
          showLabel: true,
          label: 'Client:',
          zIndex: 8,
        ),
        DynamicFieldElement(
          x: 15,
          y: 62,
          width: 80,
          height: 6,
          fieldType: DynamicFieldType.clientAddress,
          fontSize: 9,
          zIndex: 9,
        ),
        // Items table
        CanvasTableElement(
          x: 15,
          y: 80,
          width: 180,
          height: 60,
          zIndex: 10,
        ),
        // Totals section
        DynamicFieldElement(
          x: 130,
          y: 150,
          width: 65,
          height: 6,
          fieldType: DynamicFieldType.totalHT,
          fontSize: 10,
          showLabel: true,
          label: 'Total HT:',
          textAlign: CanvasTextAlign.right,
          zIndex: 11,
        ),
        DynamicFieldElement(
          x: 130,
          y: 158,
          width: 65,
          height: 6,
          fieldType: DynamicFieldType.totalTVA,
          fontSize: 10,
          showLabel: true,
          label: 'Total TVA:',
          textAlign: CanvasTextAlign.right,
          zIndex: 12,
        ),
        DynamicFieldElement(
          x: 130,
          y: 166,
          width: 65,
          height: 8,
          fieldType: DynamicFieldType.totalTTC,
          fontSize: 12,
          isBold: true,
          showLabel: true,
          label: 'Total TTC:',
          color: 0xFF1a56db,
          textAlign: CanvasTextAlign.right,
          zIndex: 13,
        ),
        // Notes
        DynamicFieldElement(
          x: 15,
          y: 200,
          width: 100,
          height: 15,
          fieldType: DynamicFieldType.notes,
          fontSize: 8,
          showLabel: true,
          label: 'Notes:',
          zIndex: 14,
        ),
      ],
    );
  }
}
