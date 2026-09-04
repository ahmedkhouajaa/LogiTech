import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../utils/constants.dart';
import '../../services/article_import_export_service.dart';

class ArticleImportDialog extends StatefulWidget {
  final VoidCallback onImportSuccess;

  const ArticleImportDialog({
    super.key,
    required this.onImportSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onImportSuccess,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ArticleImportDialog(
        onImportSuccess: onImportSuccess,
      ),
    );
  }

  @override
  State<ArticleImportDialog> createState() => _ArticleImportDialogState();
}

class _ArticleImportDialogState extends State<ArticleImportDialog>
    with SingleTickerProviderStateMixin {
  String? _pickedFileName;
  Map<String, dynamic>? _parsedFile;
  List<Map<String, dynamic>> _rawRows = [];
  Map<String, String?> _fieldMapping = {};
  final Map<String, dynamic> _fallbackValues = {};

  List<ArticleImportRow> _validatedRows = [];
  bool _isValidating = false;
  bool _isImporting = false;
  double _importProgress = 0.0;
  String _importStatus = '';
  bool _isDownloadingTemplate = false;
  String _filterMode = 'all'; // 'all', 'valid', 'error'

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);
    final validCount = _validatedRows.where((r) => r.isValid).length;
    final updateCount = _validatedRows.where((r) => r.isValid && r.isUpdate).length;
    final createCount = _validatedRows.where((r) => r.isValid && !r.isUpdate).length;
    final errorCount = _validatedRows.where((r) => !r.isValid).length;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Modal Header
            _buildDialogHeader(),

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions Box (Matching Finco / ERP reference)
                    _buildInstructionsBox(),
                    const SizedBox(height: 16),

                    // Download Template Row
                    _buildDownloadTemplateRow(),
                    const SizedBox(height: 16),

                    // File Picker Dropzone
                    _buildFilePickerDropzone(),

                    // If file is selected and parsed
                    if (_parsedFile != null) ...[
                      const SizedBox(height: 20),
                      _buildValidationSummaryChips(validCount, createCount, updateCount, errorCount),
                      const SizedBox(height: 16),
                      _buildDataTablePreview(),
                    ],

                    if (_isImporting) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: _importProgress,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(_importStatus, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            _buildDialogFooter(validCount, errorCount),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Importer des Articles depuis Excel',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Téléchargez un fichier Excel pour importer des articles. Téléchargez le modèle pour voir le format requis.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 22),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Soft Blue
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructions d\'importation',
            style: TextStyle(
              color: const Color(0xFF1E40AF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildInstructionBullet('Téléchargez le modèle Excel en utilisant le bouton ci-dessous'),
          _buildInstructionBullet('Remplissez vos données d\'articles en suivant le format d\'exemple fourni'),
          _buildInstructionBullet('Laissez la colonne _id vide pour les nouveaux articles, ou remplissez-la pour mettre à jour des articles existants'),
          _buildInstructionBullet('productType doit valoir « produit » (stock géré) ou « service » (sans stock) ou « matière première »'),
          _buildInstructionBullet('sellingPrice (prix de vente HT) et purchasePrice (prix d\'achat HT) en devises (ex. 120.500 ou 2150.000)'),
          _buildInstructionBullet('tvaRate (taux TVA) : pourcentage (ex. 19, 7, 13 ou 0)'),
        ],
      ),
    );
  }

  Widget _buildInstructionBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(color: const Color(0xFF1E40AF), fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: const Color(0xFF1E3A8A), fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadTemplateRow() {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: _isDownloadingTemplate ? null : _handleDownloadExcelTemplate,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
        icon: _isDownloadingTemplate
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded, size: 16),
        label: const Text(
          'Télécharger le modèle Excel',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildFilePickerDropzone() {
    final isFileSelected = _pickedFileName != null;

    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isFileSelected ? AppColors.primary : AppColors.border,
            width: isFileSelected ? 1.5 : 1,
            style: isFileSelected ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isFileSelected ? Icons.task_alt_rounded : Icons.inventory_2_outlined,
              size: 36,
              color: isFileSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              _pickedFileName ?? 'Glissez-déposez ou cliquez pour sélectionner votre fichier d\'articles (.xlsx, .csv, .json)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Formats pris en charge : Microsoft Excel (.xlsx), CSV (.csv), JSON (.json)',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationSummaryChips(int valid, int create, int update, int errors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterBadgeChip(
                label: 'Toutes (${_validatedRows.length})',
                bg: _filterMode == 'all' ? AppColors.textPrimary : AppColors.surfaceAlt,
                text: _filterMode == 'all' ? Colors.white : AppColors.textPrimary,
                isSelected: _filterMode == 'all',
                onTap: () => setState(() => _filterMode = 'all'),
              ),
              const SizedBox(width: 8),
              _buildFilterBadgeChip(
                label: 'Valides ($valid)',
                bg: _filterMode == 'valid' ? AppColors.success : AppColors.successLight,
                text: _filterMode == 'valid' ? Colors.white : AppColors.success,
                isSelected: _filterMode == 'valid',
                onTap: () => setState(() => _filterMode = 'valid'),
              ),
              const SizedBox(width: 8),
              _buildBadgeChip('$create à créer', AppColors.surfaceAlt, AppColors.textSecondary),
              const SizedBox(width: 8),
              _buildBadgeChip('$update à mettre à jour', AppColors.infoLight, AppColors.info),
              if (errors > 0) ...[
                const SizedBox(width: 8),
                _buildFilterBadgeChip(
                  label: '$errors erreur(s)',
                  bg: _filterMode == 'error' ? AppColors.error : AppColors.errorLight,
                  text: _filterMode == 'error' ? Colors.white : AppColors.error,
                  isSelected: _filterMode == 'error',
                  icon: Icons.error_outline_rounded,
                  onTap: () => setState(() => _filterMode = 'error'),
                ),
              ],
            ],
          ),
        ),
        if (errors > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: valid > 0
                  ? AppColors.warning.withValues(alpha: 0.08)
                  : AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: valid > 0
                    ? AppColors.warning.withValues(alpha: 0.35)
                    : AppColors.error.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  valid > 0 ? Icons.info_outline_rounded : Icons.block_rounded,
                  color: valid > 0 ? AppColors.warning : AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    valid > 0
                        ? '$valid article(s) valide(s) seront importés. Les $errors ligne(s) contenant des erreurs ou doublons seront ignorées.'
                        : 'Importation impossible : toutes les $errors ligne(s) contiennent des erreurs à corriger.',
                    style: TextStyle(
                      color: valid > 0 ? AppColors.warning : AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_filterMode != 'error')
                  TextButton.icon(
                    onPressed: () => setState(() => _filterMode = 'error'),
                    style: TextButton.styleFrom(
                      foregroundColor: valid > 0 ? AppColors.warning : AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.filter_list_rounded, size: 14),
                    label: const Text(
                      'Voir les erreurs',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBadgeChip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFilterBadgeChip({
    required String label,
    required Color bg,
    required Color text,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? text.withValues(alpha: 0.6) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: text),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: text,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTablePreview() {
    final displayedRows = _validatedRows.where((r) {
      if (_filterMode == 'valid') return r.isValid;
      if (_filterMode == 'error') return !r.isValid;
      return true;
    }).toList();

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: _isValidating
          ? const Center(child: CircularProgressIndicator())
          : displayedRows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _filterMode == 'error'
                              ? Icons.check_circle_outline_rounded
                              : Icons.inventory_2_outlined,
                          size: 36,
                          color: _filterMode == 'error' ? AppColors.success : AppColors.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterMode == 'error'
                              ? 'Félicitations ! Aucune ligne ne comporte d\'erreur.'
                              : 'Aucun article à afficher pour ce filtre.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowMinHeight: 38,
                      dataRowMaxHeight: 44,
                      headingRowHeight: 40,
                      columnSpacing: 20,
                      horizontalMargin: 16,
                      headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                      headingTextStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      dataTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 11),
                      columns: const [
                        DataColumn(label: Text('STATUT')),
                        DataColumn(label: Text('LIGNE')),
                        DataColumn(label: Text('DÉSIGNATION / NOM')),
                        DataColumn(label: Text('CODE')),
                        DataColumn(label: Text('TYPE')),
                        DataColumn(label: Text('CATÉGORIE')),
                        DataColumn(label: Text('PRIX VENTE HT')),
                        DataColumn(label: Text('PRIX ACHAT HT')),
                        DataColumn(label: Text('TVA %')),
                        DataColumn(label: Text('STOCK')),
                        DataColumn(label: Text('UNITÉ')),
                        DataColumn(label: Text('CODE-BARRES')),
                        DataColumn(label: Text('ID EXISTANT (_id)')),
                      ],
                      rows: displayedRows.map((row) {
                        final isUpdate = row.isUpdate;
                        final isValid = row.isValid;

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (!isValid) return AppColors.error.withValues(alpha: 0.05);
                            if (isUpdate) return AppColors.info.withValues(alpha: 0.03);
                            return null;
                          }),
                          cells: [
                            DataCell(
                              !isValid
                                  ? Tooltip(
                                      message: 'Cliquez pour voir les erreurs :\n${row.errors.join('\n')}',
                                      waitDuration: const Duration(milliseconds: 300),
                                      child: InkWell(
                                        onTap: () => _showRowErrorsDialog(row),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.errorLight,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.error_outline_rounded, size: 12, color: AppColors.error),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${row.errors.length} erreur${row.errors.length > 1 ? 's' : ''}',
                                                style: TextStyle(
                                                  color: AppColors.error,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isUpdate ? AppColors.infoLight : AppColors.successLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isUpdate ? Icons.sync_rounded : Icons.add_circle_outline_rounded,
                                            size: 12,
                                            color: isUpdate ? AppColors.info : AppColors.success,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isUpdate ? 'Mise à jour' : 'Nouveau',
                                            style: TextStyle(
                                              color: isUpdate ? AppColors.info : AppColors.success,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            DataCell(Text('Ligne ${row.rowIndex}', style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  row.displayName.isNotEmpty ? row.displayName : '(sans nom)',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            DataCell(Text(row.code.isNotEmpty ? row.code : '-')),
                            DataCell(Text(row.productType)),
                            DataCell(Text(row.category.isNotEmpty ? row.category : '-')),
                            DataCell(Text('${row.sellingPrice.toStringAsFixed(3)} DT')),
                            DataCell(Text('${row.purchasePrice.toStringAsFixed(3)} DT')),
                            DataCell(Text('${row.tvaRate.toStringAsFixed(0)}%')),
                            DataCell(Text(row.stockQty.toStringAsFixed(0))),
                            DataCell(Text(row.unit)),
                            DataCell(Text(row.barcode.isNotEmpty ? row.barcode : '-')),
                            DataCell(Text(row.existingId ?? '-')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
    );
  }

  void _showRowErrorsDialog(ArticleImportRow row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Détail des erreurs - Ligne ${row.rowIndex}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Article : ${row.displayName.isNotEmpty ? row.displayName : "(sans désignation)"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (row.code.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text('Code article : ${row.code}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
                const SizedBox(height: 14),
                Text(
                  'Erreurs bloquantes :',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                for (final err in row.errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            err,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (row.warnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Avertissements :',
                    style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  for (final warn in row.warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              warn,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(int validCount, int errorCount) {
    final canImport = !_isImporting && validCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (validCount > 0 && errorCount > 0)
            Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  '$validCount article(s) valide(s) prêt(s) à être importé(s) • $errorCount ignoré(s)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (validCount > 0)
            Text(
              '$validCount article(s) prêts à être importés.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          else if (errorCount > 0)
            Row(
              children: [
                Icon(Icons.block_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Text(
                  'Aucun article valide ($errorCount erreurs).',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          Row(
            children: [
              OutlinedButton(
                onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: canImport ? _handleExecuteImport : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canImport ? const Color(0xFF93C5FD) : AppColors.surfaceAlt,
                  foregroundColor: canImport ? const Color(0xFF1E3A8A) : AppColors.textTertiary,
                  disabledBackgroundColor: AppColors.surfaceAlt,
                  disabledForegroundColor: AppColors.textTertiary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                child: Text(
                  validCount == 0
                      ? 'Aucun article valide'
                      : (errorCount > 0 ? 'Importer les $validCount articles valides' : 'Importer $validCount articles'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownloadExcelTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    try {
      final path = await ArticleImportExportService.instance.downloadExcelTemplate();
      if (mounted) {
        setState(() => _isDownloadingTemplate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Modèle Excel téléchargé avec succès : $path'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloadingTemplate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'json', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          final parsed = ArticleImportExportService.instance.parseArticleFile(bytes, file.name);
          final rawRows = (parsed['rows'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final headers = (parsed['headers'] as List).map((e) => e.toString()).toList();

          // Auto-mapping
          final autoMapping = ArticleImportExportService.instance.autoSuggestMappings(headers);

          setState(() {
            _pickedFileName = file.name;
            _parsedFile = parsed;
            _rawRows = rawRows;
            _fieldMapping = autoMapping;
          });

          await _revalidateRows();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de fichier : $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _revalidateRows() async {
    setState(() => _isValidating = true);
    final validated = await ArticleImportExportService.instance.validateAndPrepareRows(
      rawRows: _rawRows,
      fieldMapping: _fieldMapping,
      fallbackValues: _fallbackValues,
    );
    if (mounted) {
      setState(() {
        _validatedRows = validated;
        _isValidating = false;
      });
    }
  }

  Future<void> _handleExecuteImport() async {
    final validRows = _validatedRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucun article valide à importer.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatus = 'Lancement de l\'importation des articles...';
    });

    try {
      final result = await ArticleImportExportService.instance.executeArticleImport(
        context: context,
        rows: _validatedRows,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _importProgress = prog;
              _importStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isImporting = false);

        if (!result.success) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
                  const SizedBox(width: 8),
                  const Text('Échec de l\'importation', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Text(
                result.message,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          );
          return;
        }

        Navigator.of(context).pop();
        widget.onImportSuccess();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                const SizedBox(width: 8),
                const Text('Importation Réussie', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Text(
              result.message,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'importation : $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

