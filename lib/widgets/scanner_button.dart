import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';
import '../services/ai_document_scanner_service.dart';

typedef OnScanDataExtracted = void Function(AiScanResult result);

/// A sleek scanner button styled in the app's signature blue theme across Desktop, Android, and Web.
class ScannerButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? documentTitle;
  final String? documentType;
  final bool isSmall;
  final bool compact;
  final VoidCallback? onScanComplete;
  final OnScanDataExtracted? onScanDataExtracted;

  const ScannerButton({
    super.key,
    this.onPressed,
    this.documentTitle,
    this.documentType,
    this.isSmall = false,
    this.compact = false,
    this.onScanComplete,
    this.onScanDataExtracted,
  });

  /// Opens the clean blue document scanner dialog supporting single or multiple files
  static Future<void> showScannerDialog(
    BuildContext context, {
    required String documentTitle,
    required String documentType,
    VoidCallback? onScanComplete,
    OnScanDataExtracted? onScanDataExtracted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DocumentScannerDialog(
        documentTitle: documentTitle,
        documentType: documentType,
        onScanComplete: onScanComplete,
        onScanDataExtracted: onScanDataExtracted,
      ),
    );
  }

  @override
  State<ScannerButton> createState() => _ScannerButtonState();
}

class _ScannerButtonState extends State<ScannerButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.isSmall || widget.compact ? 36.0 : 40.0;
    const primaryBlue = Color(0xFF2563EB); // App signature royal blue

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: effectiveHeight,
        decoration: BoxDecoration(
          color: _isHovered
              ? primaryBlue.withValues(alpha: 0.10)
              : primaryBlue.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered
                ? primaryBlue.withValues(alpha: 0.75)
                : primaryBlue.withValues(alpha: 0.40),
            width: _isHovered ? 1.3 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: _isHovered ? 0.16 : 0.05),
              blurRadius: _isHovered ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed ??
                () {
                  ScannerButton.showScannerDialog(
                    context,
                    documentTitle: widget.documentTitle ?? context.tr('Document'),
                    documentType: widget.documentType ?? 'document',
                    onScanComplete: widget.onScanComplete,
                    onScanDataExtracted: widget.onScanDataExtracted,
                  );
                },
            borderRadius: BorderRadius.circular(8),
            splashColor: primaryBlue.withValues(alpha: 0.15),
            highlightColor: primaryBlue.withValues(alpha: 0.08),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10.0 : 14.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: widget.compact ? 16 : 17,
                    color: primaryBlue,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    context.tr('Scanner'),
                    style: TextStyle(
                      fontSize: widget.compact ? 12.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      color: primaryBlue,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Document scanner dialog matching the user's reference in blue, with multi-file upload support and AI integration.
class DocumentScannerDialog extends StatefulWidget {
  final String documentTitle;
  final String documentType;
  final VoidCallback? onScanComplete;
  final OnScanDataExtracted? onScanDataExtracted;

  const DocumentScannerDialog({
    super.key,
    required this.documentTitle,
    required this.documentType,
    this.onScanComplete,
    this.onScanDataExtracted,
  });

  @override
  State<DocumentScannerDialog> createState() => _DocumentScannerDialogState();
}

class _DocumentScannerDialogState extends State<DocumentScannerDialog> {
  bool _isHovered = false;
  bool _isProcessing = false;
  final List<PlatformFile> _selectedFiles = [];
  AiScanResult? _scanResult;
  bool _showRawText = false;
  bool _isCheckingHealth = false;
  bool _isServerOnline = false;
  bool _isModelConfigured = false;
  String _currentHost = '';

  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 Mo

  @override
  void initState() {
    super.initState();
    _checkAiService();
  }

  Future<void> _checkAiService() async {
    setState(() => _isCheckingHealth = true);
    final health = await AiDocumentScannerService.instance.checkServiceHealth();
    if (mounted) {
      setState(() {
        _isCheckingHealth = false;
        _isServerOnline = health['is_online'] == true;
        _isModelConfigured = health['model_configured'] == true;
        _currentHost = health['url']?.toString() ?? '';
      });
    }
  }

  String _getDocumentLabel() {
    final lower = widget.documentType.toLowerCase();
    if (lower.contains('invoice') || lower.contains('facture')) {
      return 'facture';
    }
    if (lower.contains('order') || lower.contains('commande')) {
      return 'commande';
    }
    if (lower.contains('voucher') || lower.contains('reception')) {
      return 'bon de réception';
    }
    if (lower.contains('inventory') || lower.contains('inventaire')) {
      return "fiche d'inventaire";
    }
    return 'document';
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} Mo';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} Ko';
  }

  int get _totalSizeBytes =>
      _selectedFiles.fold<int>(0, (sum, file) => sum + file.size);

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpeg', 'jpg', 'png', 'webp', 'heic', 'pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        int oversizedCount = 0;
        final List<PlatformFile> validFiles = [];

        for (final file in result.files) {
          if (file.size > _maxFileSizeBytes) {
            oversizedCount++;
          } else {
            final isDuplicate = _selectedFiles.any(
              (f) => f.name == file.name && f.size == file.size,
            );
            if (!isDuplicate) {
              validFiles.add(file);
            }
          }
        }

        if (oversizedCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$oversizedCount ${context.tr('fichier(s) dépassent la limite de 10 Mo et ont été ignorés.')}',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(validFiles);
          });
          // Automatiquement lancer l'extraction IA
          await _runAiScan();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Erreur de sélection')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _runAiScan() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _scanResult = null;
    });

    try {
      final result = await AiDocumentScannerService.instance.scanDocuments(
        files: _selectedFiles,
        documentType: widget.documentType,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scanResult = result;
        });

        if (!result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Erreur d\'extraction IA')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeFile(PlatformFile file) {
    setState(() {
      _selectedFiles.removeWhere((f) => f.name == file.name && f.size == file.size);
      if (_selectedFiles.isEmpty) {
        _scanResult = null;
        _isProcessing = false;
      }
    });
  }

  void _showAiConfigDialog() {
    final controller = TextEditingController(text: _currentHost);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings_suggest_rounded, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text(context.tr('Configuration du Service IA')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Adresse du microservice Python local :'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'http://localhost:8000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('Pour connecter l\'API du modèle IA de votre ami, modifiez le fichier "ai_service/.env" et lancez "start_service.bat".'),
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Fermer')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              await AiDocumentScannerService.instance.setCustomHost(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
              _checkAiService();
            },
            child: Text(context.tr('Enregistrer et Tester')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    const primaryBlue = Color(0xFF2563EB);
    final docLabel = _getDocumentLabel();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 32,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row with Title, AI Status Indicator and Close Button
              Row(
                children: [
                  Icon(Icons.document_scanner_rounded, color: primaryBlue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${context.tr('Scanner')} - ${widget.documentTitle}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // AI Status Chip
                  InkWell(
                    onTap: _showAiConfigDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isServerOnline
                            ? (_isModelConfigured
                                ? AppColors.success.withValues(alpha: 0.12)
                                : primaryBlue.withValues(alpha: 0.10))
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isServerOnline
                              ? (_isModelConfigured ? AppColors.success : primaryBlue)
                              : AppColors.warning,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isServerOnline
                                  ? (_isModelConfigured ? AppColors.success : primaryBlue)
                                  : AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isCheckingHealth
                                ? '...'
                                : (_isServerOnline
                                    ? (_isModelConfigured ? 'IA Connectée' : 'Service Actif')
                                    : 'Hors-ligne'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isServerOnline
                                  ? (_isModelConfigured ? AppColors.success : primaryBlue)
                                  : AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.settings, size: 12, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Flexible scrollable content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Upload Dropzone Card
                      MouseRegion(
                        onEnter: (_) => setState(() => _isHovered = true),
                        onExit: (_) => setState(() => _isHovered = false),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _isProcessing ? null : _pickFiles,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: _selectedFiles.isEmpty ? 32 : 16,
                            ),
                            decoration: BoxDecoration(
                              color: _isHovered
                                  ? primaryBlue.withValues(alpha: 0.04)
                                  : primaryBlue.withValues(alpha: 0.015),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isHovered
                                    ? primaryBlue.withValues(alpha: 0.80)
                                    : primaryBlue.withValues(alpha: 0.35),
                                width: _isHovered ? 1.5 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: _isHovered ? 0.12 : 0.03),
                                  blurRadius: _isHovered ? 12 : 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: _selectedFiles.isEmpty ? 54 : 40,
                                  height: _selectedFiles.isEmpty ? 54 : 40,
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      color: primaryBlue,
                                      size: _selectedFiles.isEmpty ? 26 : 20,
                                    ),
                                  ),
                                ),
                                SizedBox(height: _selectedFiles.isEmpty ? 14 : 8),
                                Text(
                                  _selectedFiles.isEmpty
                                      ? context.tr('Glissez-déposez vos images ou documents de $docLabel ici, ou cliquez pour parcourir')
                                      : context.tr('Cliquez pour ajouter d\'autres documents ou images...'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: _selectedFiles.isEmpty ? 14.0 : 13.0,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'JPEG, PNG, WebP, HEIC, PDF (Sélection multiple supportée)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Processing progress indicator
                      if (_isProcessing) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryBlue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: primaryBlue),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${context.tr('Extraction IA en cours sur')} ${_selectedFiles.length} ${context.tr('fichier(s)...')}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryBlue),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.tr('Détection du texte, du fournisseur, des articles et des totaux...'),
                                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Multi-file selection chips/list
                      if (_selectedFiles.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedFiles.length} ${context.tr('fichier(s) importé(s)')} (${_formatFileSize(_totalSizeBytes)})',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                if (!_isProcessing)
                                  TextButton.icon(
                                    onPressed: _runAiScan,
                                    icon: const Icon(Icons.refresh_rounded, size: 15, color: primaryBlue),
                                    label: Text(
                                      context.tr('Réanalyser'),
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: primaryBlue),
                                    ),
                                  ),
                                TextButton.icon(
                                  onPressed: _pickFiles,
                                  icon: const Icon(Icons.add_rounded, size: 15, color: primaryBlue),
                                  label: Text(
                                    context.tr('Ajouter'),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: primaryBlue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 110),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _selectedFiles.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final file = _selectedFiles[index];
                              final isPdf = file.extension?.toLowerCase() == 'pdf';

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                      size: 16,
                                      color: isPdf ? Colors.red : primaryBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        file.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      _formatFileSize(file.size),
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _removeFile(file),
                                      child: Icon(Icons.close_rounded, size: 15, color: AppColors.textTertiary),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // AI Extracted Data Card Display
                      if (_scanResult != null && _scanResult!.success && _scanResult!.extractedData != null) ...[
                        const SizedBox(height: 16),
                        _buildExtractedDataCard(_scanResult!.extractedData!, _scanResult!.source),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.tr('Annuler'),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _selectedFiles.isEmpty
                        ? _pickFiles
                        : () {
                            Navigator.pop(context);
                            if (_scanResult != null) {
                              widget.onScanDataExtracted?.call(_scanResult!);
                            }
                            widget.onScanComplete?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${_selectedFiles.length} ${context.tr('document(s) analysé(s) par l\'IA et importé(s) avec succès !')}',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                    icon: Icon(
                      _selectedFiles.isEmpty ? Icons.folder_open_rounded : Icons.check_circle_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _selectedFiles.isEmpty
                          ? context.tr('Parcourir')
                          : '${context.tr('Valider et importer')} (${_selectedFiles.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a structured preview of the AI-extracted document information
  Widget _buildExtractedDataCard(ExtractedDocumentData data, String source) {
    const primaryBlue = Color(0xFF2563EB);
    final isFriendModel = source == 'friend_ai_model';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(
                  isFriendModel ? Icons.auto_awesome : Icons.check_circle_rounded,
                  color: primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFriendModel
                        ? context.tr('Extraction IA Réussie (Modèle de votre ami)')
                        : context.tr('Extraction IA Réussie (Mode Démo / Fallback)'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFriendModel
                        ? AppColors.success.withValues(alpha: 0.15)
                        : Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isFriendModel ? 'API Directe' : 'Simulation',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isFriendModel ? AppColors.success : Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Data Row (Document Number, Date, Supplier)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (data.documentNumber != null)
                      _buildMetaChip(
                        icon: Icons.tag_rounded,
                        label: context.tr('N° Doc'),
                        value: data.documentNumber!,
                      ),
                    if (data.documentDate != null)
                      _buildMetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: context.tr('Date'),
                        value: data.documentDate!,
                      ),
                    if (data.supplierName != null)
                      _buildMetaChip(
                        icon: Icons.business_rounded,
                        label: context.tr('Fournisseur'),
                        value: data.supplierName!,
                      ),
                    if (data.supplierTaxId != null)
                      _buildMetaChip(
                        icon: Icons.badge_rounded,
                        label: context.tr('MF'),
                        value: data.supplierTaxId!,
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // Dedicated Text Field for Python Response (with "OK")
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'OK',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('Texte extrait (OCR & LLM) :'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        final textToCopy = _scanResult?.textResponse ?? data.rawText;
                        Clipboard.setData(ClipboardData(text: textToCopy));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('Texte copié dans le presse-papiers !')),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 14, color: primaryBlue),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('Copier'),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: primaryBlue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _scanResult?.textResponse.isNotEmpty == true
                          ? _scanResult!.textResponse
                          : (data.rawText.isNotEmpty ? data.rawText : 'OK'),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // Extracted Items Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${data.items.length} ${context.tr('article(s) extrait(s)')}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Taux TVA standard: 19%',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (data.items.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: data.items.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = data.items[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.productName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item.quantity.toStringAsFixed(0)} x ${item.unitPrice.toStringAsFixed(3)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item.totalTtc.toStringAsFixed(3)} ${data.currency}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),

                // Financial Summary Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Total HT', '${data.totalHt.toStringAsFixed(3)} ${data.currency}'),
                      _buildSummaryItem('TVA', '${data.totalTva.toStringAsFixed(3)} ${data.currency}'),
                      _buildSummaryItem('Timbre', '${data.stampDuty.toStringAsFixed(3)} ${data.currency}'),
                      _buildSummaryItem(
                        'Total TTC',
                        '${data.totalTtc.toStringAsFixed(3)} ${data.currency}',
                        isBold: true,
                        color: primaryBlue,
                      ),
                    ],
                  ),
                ),

                // Expandable Raw Text Toggle
                if (data.rawText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _showRawText = !_showRawText),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _showRawText ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 16,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showRawText ? context.tr('Masquer le texte OCR brut') : context.tr('Voir le texte OCR brut extrait'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: primaryBlue),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showRawText)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          data.rawText,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isBold = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 12.5 : 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
