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
            _buildDialogFooter(validCount),
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
    return Row(
      children: [
        _buildBadgeChip('Total lignes: ${_validatedRows.length}', AppColors.surfaceAlt, AppColors.textPrimary),
        const SizedBox(width: 8),
        _buildBadgeChip('$create à créer', AppColors.successLight, AppColors.success),
        const SizedBox(width: 8),
        _buildBadgeChip('$update à mettre à jour', AppColors.infoLight, AppColors.info),
        if (errors > 0) ...[
          const SizedBox(width: 8),
          _buildBadgeChip('$errors erreurs', AppColors.errorLight, AppColors.error),
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
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDataTablePreview() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: _isValidating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                  headingTextStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  dataTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 11),
                  columns: const [
                    DataColumn(label: Text('STATUT')),
                    DataColumn(label: Text('ID EXISTANT (_id)')),
                    DataColumn(label: Text('CODE')),
                    DataColumn(label: Text('DÉSIGNATION / NOM')),
                    DataColumn(label: Text('TYPE')),
                    DataColumn(label: Text('CATÉGORIE')),
                    DataColumn(label: Text('PRIX VENTE HT')),
                    DataColumn(label: Text('PRIX ACHAT HT')),
                    DataColumn(label: Text('TVA %')),
                    DataColumn(label: Text('STOCK')),
                    DataColumn(label: Text('UNITÉ')),
                    DataColumn(label: Text('CODE-BARRES')),
                  ],
                  rows: _validatedRows.map((row) {
                    final isUpdate = row.isUpdate;
                    final isValid = row.isValid;

                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: !isValid
                                  ? AppColors.errorLight
                                  : isUpdate
                                      ? AppColors.infoLight
                                      : AppColors.successLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              !isValid
                                  ? 'Invalide'
                                  : isUpdate
                                      ? 'Mise à jour'
                                      : 'Nouveau',
                              style: TextStyle(
                                color: !isValid
                                    ? AppColors.error
                                    : isUpdate
                                        ? AppColors.info
                                        : AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(row.existingId ?? '-')),
                        DataCell(Text(row.code)),
                        DataCell(Text(row.displayName)),
                        DataCell(Text(row.productType)),
                        DataCell(Text(row.category)),
                        DataCell(Text('${row.sellingPrice.toStringAsFixed(3)} DT')),
                        DataCell(Text('${row.purchasePrice.toStringAsFixed(3)} DT')),
                        DataCell(Text('${row.tvaRate.toStringAsFixed(0)}%')),
                        DataCell(Text(row.stockQty.toStringAsFixed(0))),
                        DataCell(Text(row.unit)),
                        DataCell(Text(row.barcode)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }

  Widget _buildDialogFooter(int validCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
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
            onPressed: _isImporting || validCount == 0 ? null : _handleExecuteImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF93C5FD), // Soft Blue
              foregroundColor: const Color(0xFF1E3A8A),
              disabledBackgroundColor: AppColors.surfaceAlt,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            child: Text(
              'Importer $validCount articles',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
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
