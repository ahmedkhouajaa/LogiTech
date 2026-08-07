import 'package:flutter/material.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart'; // For formatDateLong

// ---------------------------------------------------------
// SMART DATE PICKER
// ---------------------------------------------------------
class SmartDatePicker extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool showPresets;

  const SmartDatePicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showPresets = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              locale: Locale('fr', 'FR'),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: AppColors.surface,
                      surface: AppColors.surface,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatDateLong(value),
                    style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                  ),
                ),
                Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
        if (showPresets) ...[
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPreset('Aujourd\'hui', DateTime.now()),
                SizedBox(width: 8),
                _buildPreset('Demain', DateTime.now().add(const Duration(days: 1))),
                SizedBox(width: 8),
                _buildPreset('+1 Semaine', DateTime.now().add(const Duration(days: 7))),
                SizedBox(width: 8),
                _buildPreset('+1 Mois', DateTime.now().add(const Duration(days: 30))),
              ],
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildPreset(String text, DateTime presetDate) {
    // Determine if this preset is currently selected (ignoring time)
    bool isSelected = value.year == presetDate.year && value.month == presetDate.month && value.day == presetDate.day;
    return InkWell(
      onTap: () => onChanged(presetDate),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SMART DROPDOWN (Searchable)
// ---------------------------------------------------------
class SmartDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  final String? errorText;

  const SmartDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Sélectionner...',
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<T>> dropdownItems = List.from(items);
    final hasSelected = dropdownItems.any((item) => item.value == value);
    if (value != null && !hasSelected) {
      dropdownItems.add(DropdownMenuItem<T>(
        value: value,
        child: Text('Sélectionner...', style: const TextStyle(fontSize: 16)),
      ));
    }
    final dropdownKey = ValueKey('${dropdownItems.length}_${dropdownItems.fold("", (prev, item) => "${prev}_${item.value}")}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        DropdownButtonFormField(
          key: dropdownKey,
          dropdownColor: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          value: value,
          items: dropdownItems,
          onChanged: onChanged,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 16),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            errorText: errorText,
          ),
          icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class SmartSearchableSelector extends StatelessWidget {
  final String label;
  final String hint;
  final String? selectedText;
  final VoidCallback onTap;
  final bool hasError;
  final String? errorText;

  const SmartSearchableSelector({
    super.key,
    required this.label,
    required this.hint,
    required this.selectedText,
    required this.onTap,
    this.hasError = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AbsorbPointer(
            child: TextFormField(
              controller: TextEditingController(text: selectedText ?? hint),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceAlt,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: Icon(Icons.arrow_drop_down_rounded, size: 24, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: hasError ? AppColors.error : AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: hasError ? AppColors.error : AppColors.border),
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        if (hasError && errorText != null) ...[
          SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(errorText!, style: TextStyle(color: AppColors.error, fontSize: 11)),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------
// SMART NUMBER INPUT (With Stepper)
// ---------------------------------------------------------
class SmartNumberInput extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final String? suffix;

  const SmartNumberInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999999,
    this.step = 1,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        Row(
          children: [
            _buildButton(Icons.remove, () {
              if (value - step >= min) onChanged(value - step);
            }),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: ValueKey(value.toString()),
                initialValue: value == value.truncateToDouble() ? value.toInt().toString() : value.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  suffixText: suffix,
                ),
                onChanged: (v) {
                  final val = double.tryParse(v);
                  if (val != null) {
                    if (val >= min && val <= max) onChanged(val);
                  }
                },
              ),
            ),
            SizedBox(width: 8),
            _buildButton(Icons.add, () {
              if (value + step <= max) onChanged(value + step);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.sm,
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

// ---------------------------------------------------------
// SMART TOGGLE CHIPS
// ---------------------------------------------------------
class SmartToggleChips<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const SmartToggleChips({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: options.map((option) {
              final isSelected = value == option;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(option),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: isSelected
                          ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labelBuilder(option),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// SMART TEXT INPUT
// ---------------------------------------------------------
class SmartTextInput extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final String? suffixText;

  const SmartTextInput({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint = '',
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
    this.suffixIcon,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 16),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            suffixIcon: suffixIcon,
            suffixText: suffixText,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// SMART CHECKBOX
// ---------------------------------------------------------
class SmartCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const SmartCheckbox({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
