import 'package:flutter/material.dart';
import '../models/custom_field_definition.dart';
import '../services/custom_fields_service.dart';
import '../utils/constants.dart';

class CustomFieldsFormSection extends StatefulWidget {
  final String documentType;
  final Map<String, dynamic>? initialValues;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool isMobile;
  final bool readOnly;

  const CustomFieldsFormSection({
    super.key,
    required this.documentType,
    this.initialValues,
    required this.onChanged,
    this.isMobile = false,
    this.readOnly = false,
  });

  @override
  State<CustomFieldsFormSection> createState() => _CustomFieldsFormSectionState();
}

class _CustomFieldsFormSectionState extends State<CustomFieldsFormSection> {
  List<CustomFieldDefinition> _definitions = [];
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  @override
  void didUpdateWidget(CustomFieldsFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentType != widget.documentType) {
      _loadFields();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFields() async {
    setState(() => _isLoading = true);
    final defs = await CustomFieldsService.instance.getCustomFields(widget.documentType);
    if (!mounted) return;

    _values.clear();
    for (var c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();

    if (widget.initialValues != null) {
      _values.addAll(widget.initialValues!);
    }

    for (var def in defs) {
      // Find initial value by id, name, or key
      final existingVal = widget.initialValues?[def.id] ??
          widget.initialValues?[def.name] ??
          widget.initialValues?[def.key] ??
          def.defaultValue ??
          '';

      _values[def.id] = existingVal.toString();
      _controllers[def.id] = TextEditingController(text: existingVal.toString());
    }

    setState(() {
      _definitions = defs;
      _isLoading = false;
    });

    widget.onChanged(_values);
  }

  void _onFieldChanged(String fieldId, String val) {
    _values[fieldId] = val;
    widget.onChanged(_values);
  }

  Future<void> _pickDate(CustomFieldDefinition field) async {
    DateTime initial = DateTime.now();
    final curVal = _values[field.id]?.toString();
    if (curVal != null && curVal.isNotEmpty) {
      try {
        initial = DateTime.parse(curVal);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final str = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      _controllers[field.id]?.text = str;
      _onFieldChanged(field.id, str);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_definitions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Champs personnalisés',
                style: TextStyle(
                  fontSize: widget.isMobile ? 14 : 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${_definitions.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoColumn = constraints.maxWidth > 580;

              if (isTwoColumn) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: _definitions.map((field) {
                    final itemWidth = (constraints.maxWidth - 16) / 2;
                    return SizedBox(
                      width: itemWidth,
                      child: _buildFormField(field),
                    );
                  }).toList(),
                );
              }

              return Column(
                children: _definitions.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildFormField(field),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(CustomFieldDefinition field) {
    final controller = _controllers[field.id];
    final isDate = field.type == 'date';
    final isNumber = field.type == 'number';
    final isTextarea = field.type == 'textarea';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                field.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (field.isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 5),
        if (isDate)
          InkWell(
            onTap: widget.readOnly ? null : () => _pickDate(field),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: IgnorePointer(
              child: TextFormField(
                controller: controller,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: field.placeholder ?? 'AAAA-MM-JJ',
                  hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                  filled: true,
                  fillColor: AppColors.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
        else
          TextFormField(
            controller: controller,
            readOnly: widget.readOnly,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : (isTextarea ? TextInputType.multiline : TextInputType.text),
            maxLines: isTextarea ? 3 : 1,
            decoration: InputDecoration(
              hintText: field.placeholder ?? 'Saisir ${field.name.toLowerCase()}...',
              hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.background,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 13),
            validator: (v) {
              if (field.isRequired && (v == null || v.trim().isEmpty)) {
                return 'Ce champ est obligatoire';
              }
              return null;
            },
            onChanged: (v) => _onFieldChanged(field.id, v.trim()),
          ),
      ],
    );
  }
}
