import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../utils/constants.dart';

/// Color picker field with a preview swatch.
class TemplateColorPicker extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  const TemplateColorPicker({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    Color tempColor = color;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: (c) => tempColor = c,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              onChanged(tempColor);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}

/// Numeric input field with unit label (mm, pt, etc.).
class TemplateMeasurementInput extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final ValueChanged<double> onChanged;
  final double? min;
  final double? max;

  const TemplateMeasurementInput({
    super.key,
    required this.label,
    required this.value,
    this.unit = 'mm',
    required this.onChanged,
    this.min,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label ($unit)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 2)),
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) {
              double clamped = parsed;
              if (min != null && clamped < min!) clamped = min!;
              if (max != null && clamped > max!) clamped = max!;
              onChanged(clamped);
            }
          },
        ),
      ],
    );
  }
}

/// Dropdown selector for font style: Normal / Gras / Graisse.
class TemplateFontStyleSelector extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> options;

  const TemplateFontStyleSelector({
    super.key,
    this.label = 'Style',
    required this.value,
    required this.onChanged,
    this.options = const ['Normal', 'Gras'],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: options.contains(value) ? value : options.first,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
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
}

/// Section header with optional visibility toggle.
class TemplateSectionHeader extends StatelessWidget {
  final String title;
  final bool? visible;
  final ValueChanged<bool>? onVisibleChanged;
  final Color? titleColor;

  const TemplateSectionHeader({
    super.key,
    required this.title,
    this.visible,
    this.onVisibleChanged,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: titleColor ?? AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (visible != null && onVisibleChanged != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: visible,
                  onChanged: (v) => onVisibleChanged!(v ?? false),
                  activeColor: AppColors.primary,
                ),
                Text(
                  visible! ? 'Visible' : 'Masqué',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Row with Position X and Position Y inputs.
class TemplatePositionFields extends StatelessWidget {
  final double positionX;
  final double positionY;
  final ValueChanged<double> onXChanged;
  final ValueChanged<double> onYChanged;

  const TemplatePositionFields({
    super.key,
    required this.positionX,
    required this.positionY,
    required this.onXChanged,
    required this.onYChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: TemplateMeasurementInput(label: 'Position X', value: positionX, onChanged: onXChanged)),
        const SizedBox(width: 12),
        Expanded(child: TemplateMeasurementInput(label: 'Position Y', value: positionY, onChanged: onYChanged)),
      ],
    );
  }
}

/// Row with Width and Height inputs.
class TemplateDimensionFields extends StatelessWidget {
  final double width;
  final double height;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onHeightChanged;
  final String widthLabel;
  final String heightLabel;

  const TemplateDimensionFields({
    super.key,
    required this.width,
    required this.height,
    required this.onWidthChanged,
    required this.onHeightChanged,
    this.widthLabel = 'Largeur',
    this.heightLabel = 'Hauteur',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: TemplateMeasurementInput(label: widthLabel, value: width, onChanged: onWidthChanged)),
        const SizedBox(width: 12),
        Expanded(child: TemplateMeasurementInput(label: heightLabel, value: height, onChanged: onHeightChanged)),
      ],
    );
  }
}

/// A total field editor row (fontSize + color + style) used in Totaux tab.
class TotalFieldEditor extends StatelessWidget {
  final String title;
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Color? titleColor;
  final List<Widget>? extraWidgets;

  const TotalFieldEditor({
    super.key,
    required this.title,
    required this.config,
    required this.onChanged,
    this.titleColor,
    this.extraWidgets,
  });

  void _update(String key, dynamic value) {
    final newConfig = Map<String, dynamic>.from(config);
    newConfig[key] = value;
    onChanged(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = config['visible'] as bool? ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TemplateSectionHeader(
          title: title,
          titleColor: titleColor,
          visible: isVisible,
          onVisibleChanged: (v) => _update('visible', v),
        ),
        if (isVisible) ...[
          Row(
            children: [
              Expanded(
                child: TemplateMeasurementInput(
                  label: 'Taille police',
                  value: (config['fontSize'] as num?)?.toDouble() ?? 10,
                  unit: 'pt',
                  onChanged: (v) => _update('fontSize', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TemplateColorPicker(
                  label: 'Couleur',
                  color: Color(config['color'] as int? ?? 0xFF000000),
                  onChanged: (c) => _update('color', c.toARGB32()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TemplateFontStyleSelector(
                  value: config['style'] as String? ?? 'Normal',
                  onChanged: (v) => _update('style', v),
                ),
              ),
            ],
          ),
          if (extraWidgets != null) ...extraWidgets!,
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Enableable section header with checkbox.
class TemplateEnableHeader extends StatelessWidget {
  final String title;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const TemplateEnableHeader({
    super.key,
    required this.title,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          Checkbox(
            value: enabled,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.primary,
          ),
          const Text('Activé', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
