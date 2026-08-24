import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/import_export_service.dart';

class FieldMapperWidget extends StatefulWidget {
  final ImportTargetType targetType;
  final List<String> sourceHeaders;
  final List<Map<String, dynamic>> rawRows;
  final Map<String, String?> currentMapping;
  final Map<String, dynamic> fallbackValues;
  final ValueChanged<Map<String, String?>> onMappingChanged;
  final ValueChanged<Map<String, dynamic>> onFallbackValuesChanged;

  const FieldMapperWidget({
    super.key,
    required this.targetType,
    required this.sourceHeaders,
    required this.rawRows,
    required this.currentMapping,
    required this.fallbackValues,
    required this.onMappingChanged,
    required this.onFallbackValuesChanged,
  });

  @override
  State<FieldMapperWidget> createState() => _FieldMapperWidgetState();
}

class _FieldMapperWidgetState extends State<FieldMapperWidget> {
  late Map<String, String?> _mapping;
  late Map<String, dynamic> _fallbacks;

  @override
  void initState() {
    super.initState();
    _mapping = Map<String, String?>.from(widget.currentMapping);
    _fallbacks = Map<String, dynamic>.from(widget.fallbackValues);

    if (_mapping.isEmpty) {
      _autoMapAll();
    }
  }

  void _autoMapAll() {
    final suggested = ImportExportService.instance.suggestFieldMappings(
      targetType: widget.targetType,
      sourceHeaders: widget.sourceHeaders,
    );
    setState(() {
      _mapping = suggested;
    });
    widget.onMappingChanged(_mapping);
  }

  void _resetAll() {
    setState(() {
      _mapping.clear();
      _fallbacks.clear();
    });
    widget.onMappingChanged(_mapping);
    widget.onFallbackValuesChanged(_fallbacks);
  }

  @override
  Widget build(BuildContext context) {
    final definitions = ImportExportService.targetFieldDefinitions[widget.targetType] ?? [];
    final isMobile = AppBreakpoints.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.alt_route_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mappage visuel des champs (${widget.targetType.label})',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Associez les colonnes de votre fichier aux champs de LogiTech Pro.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _autoMapAll,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Auto-mappage'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _resetAll,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Réinitialiser',
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Mapping table header
        if (!isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'CHAMP LOGITECH PRO',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'COLONNE SOURCE DÉTECTÉE (FICHIER)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'VALEUR PAR DÉFAUT (SI VIDE)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Mapping rows
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: isMobile
                ? BorderRadius.circular(AppRadius.md)
                : const BorderRadius.vertical(bottom: Radius.circular(AppRadius.md)),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: definitions.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final def = definitions[index];
              final mappedSource = _mapping[def.key];
              final isMapped = mappedSource != null && mappedSource.isNotEmpty && mappedSource != '__skip__';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: isMobile
                    ? _buildMobileRow(def, mappedSource, isMapped)
                    : _buildDesktopRow(def, mappedSource, isMapped),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Live preview of first 2-3 rows
        _buildPreviewSection(),
      ],
    );
  }

  Widget _buildDesktopRow(TargetFieldDefinition def, String? mappedSource, bool isMapped) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Target field
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    def.label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (def.isRequired) ...[
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                def.description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Source dropdown selector
        Expanded(
          flex: 4,
          child: _buildSourceDropdown(def, mappedSource, isMapped),
        ),
        const SizedBox(width: 16),

        // Fallback default
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 38,
            child: TextFormField(
              initialValue: _fallbacks[def.key]?.toString() ?? '',
              onChanged: (val) {
                _fallbacks[def.key] = val;
                widget.onFallbackValuesChanged(_fallbacks);
              },
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Valeur fixe (facultatif)',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileRow(TargetFieldDefinition def, String? mappedSource, bool isMapped) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              def.label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (def.isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          def.description,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 8),
        _buildSourceDropdown(def, mappedSource, isMapped),
      ],
    );
  }

  Widget _buildSourceDropdown(TargetFieldDefinition def, String? mappedSource, bool isMapped) {
    final availableHeaders = ['__skip__', ...widget.sourceHeaders];

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isMapped ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isMapped ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.sourceHeaders.contains(mappedSource) ? mappedSource : '__skip__',
          isExpanded: true,
          icon: Icon(
            Icons.unfold_more_rounded,
            size: 16,
            color: isMapped ? AppColors.primary : AppColors.textSecondary,
          ),
          style: TextStyle(
            color: isMapped ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isMapped ? FontWeight.w600 : FontWeight.w400,
          ),
          dropdownColor: AppColors.surface,
          items: availableHeaders.map((header) {
            if (header == '__skip__') {
              return DropdownMenuItem<String>(
                value: '__skip__',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      'Ignorer ce champ',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            }
            return DropdownMenuItem<String>(
              value: header,
              child: Text(
                header,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          onChanged: (newVal) {
            setState(() {
              _mapping[def.key] = (newVal == '__skip__' ? null : newVal);
            });
            widget.onMappingChanged(_mapping);
          },
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    if (widget.rawRows.isEmpty) return const SizedBox.shrink();

    final transformedPreview = ImportExportService.instance.transformMappedRows(
      targetType: widget.targetType,
      sourceRows: widget.rawRows.take(3).toList(),
      fieldMapping: _mapping,
      fallbackValues: _fallbacks,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Aperçu du résultat mappé (3 premières lignes)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
              headingTextStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              dataTextStyle: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
              columns: _mapping.entries
                  .where((e) => e.value != null && e.value != '__skip__')
                  .map((e) => DataColumn(label: Text(e.key.toUpperCase())))
                  .toList(),
              rows: transformedPreview.map((row) {
                return DataRow(
                  cells: _mapping.entries
                      .where((e) => e.value != null && e.value != '__skip__')
                      .map((e) {
                    final cellVal = row[e.key];
                    return DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          cellVal != null ? cellVal.toString() : '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
