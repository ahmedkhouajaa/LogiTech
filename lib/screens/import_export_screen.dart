import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../utils/constants.dart';
import '../services/enterprise_service.dart';
import '../services/import_export_service.dart';
import '../services/permission_service.dart';
import '../models/user_management_model.dart';
import '../widgets/import_export/import_confirmation_dialog.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen>
    with SingleTickerProviderStateMixin {
  // ─── Tab Index (0 = Export, 1 = Restore) ─────────────────────────
  int _activeTab = 0;

  // ─── Export State ─────────────────────────────────────────────────
  bool _isLoadingCounts = false;
  Map<String, int> _collectionCounts = {};
  final Set<String> _selectedExportCollections = {};
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';

  // ─── Native Restore State ─────────────────────────────────────────
  String? _nativeFileName;
  Map<String, dynamic>? _parsedNativeBackup;
  final DuplicateHandlingStrategy _nativeDuplicateStrategy = DuplicateHandlingStrategy.overwrite;
  final Set<String> _selectedRestoreCollections = {};
  bool _isRestoring = false;
  double _restoreProgress = 0.0;
  String _restoreStatus = '';

  @override
  void initState() {
    super.initState();
    _selectedExportCollections.addAll(ImportExportService.backupCollections.keys);
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoadingCounts = true);
    final counts = await ImportExportService.instance.getCollectionCounts();
    if (mounted) {
      setState(() {
        _collectionCounts = counts;
        _isLoadingCounts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppBreakpoints.isMobile(context);

    return ValueListenableBuilder<bool>(
      valueListenable: PermissionService.instance.permissionsNotifier,
      builder: (context, _, __) {
        final canRead = PermissionService.instance.canRead(UserPermissionResources.importExport);
        final canCreate = PermissionService.instance.canCreate(UserPermissionResources.importExport);
        final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.importExport);
        final canDelete = PermissionService.instance.canDelete(UserPermissionResources.importExport);

        if (!canRead) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_outline_rounded, color: AppColors.error, size: 32),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Accès Restreint',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vous ne disposez pas des permissions nécessaires pour accéder à l\'Import / Export des données. Veuillez contacter votre administrateur.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(isMobile),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: _activeTab == 0
                        ? _buildExportTab(isMobile, canCreate: canCreate, key: const ValueKey('export'))
                        : _buildNativeRestoreTab(isMobile, canUpdate: canUpdate, canDelete: canDelete, key: const ValueKey('restore')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ─── TOP BAR WITH ANIMATED TOGGLE ─────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        20,
        isMobile ? 16 : 28,
        20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import / Export des Données',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: isMobile ? 17 : 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sauvegardez ou restaurez l\'ensemble des données de votre entreprise.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isMobile ? 11 : 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Custom Tab Toggle ──
          Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                _buildToggleTab(
                  index: 0,
                  icon: Icons.backup_rounded,
                  label: 'Sauvegarde (Export .json)',
                  isMobile: isMobile,
                ),
                const SizedBox(width: 4),
                _buildToggleTab(
                  index: 1,
                  icon: Icons.restore_page_rounded,
                  label: 'Restauration LogiTech',
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab({
    required int index,
    required IconData icon,
    required String label,
    required bool isMobile,
  }) {
    final isActive = _activeTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ─── TAB 1: EXPORT / SAUVEGARDE (.JSON) ───────────────────────────
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildExportTab(bool isMobile, {bool canCreate = true, Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Enterprise Info Card ──
          _buildCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.business_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        EnterpriseService.instance.currentEnterprise?.name ?? 'Non définie',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sauvegarde complète de toutes vos collections dans un fichier JSON.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _buildIconButton(
                  icon: Icons.refresh_rounded,
                  isLoading: _isLoadingCounts,
                  onTap: _loadCounts,
                  tooltip: 'Actualiser les compteurs',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Permission Notice Banner (Read-Only Mode) ──
          if (!canCreate) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warningLight.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mode consultation active : Vous pouvez visualiser le statut et les volumes des collections, mais la génération d\'exportation est désactivée (Autorisation administrateur requise).',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),

          // ── Section Header: Collections ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionLabel(
                'COLLECTIONS À EXPORTER (${_selectedExportCollections.length}/${ImportExportService.backupCollections.length})',
              ),
              Row(
                children: [
                  _buildTextAction(
                    icon: Icons.select_all_rounded,
                    label: 'Tout',
                    onTap: () {
                      setState(() {
                        _selectedExportCollections.addAll(ImportExportService.backupCollections.keys);
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildTextAction(
                    label: 'Aucun',
                    onTap: () {
                      setState(() => _selectedExportCollections.clear());
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Collections Grid ──
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 2,
              mainAxisExtent: 60,
              crossAxisSpacing: 10,
              mainAxisSpacing: 8,
            ),
            itemCount: ImportExportService.backupCollections.length,
            itemBuilder: (context, index) {
              final key = ImportExportService.backupCollections.keys.elementAt(index);
              final label = ImportExportService.backupCollections[key]!;
              final isSelected = _selectedExportCollections.contains(key);
              final count = _collectionCounts[key] ?? 0;

              return _buildCollectionTile(
                key: key,
                label: label,
                isSelected: isSelected,
                count: count,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedExportCollections.remove(key);
                    } else {
                      _selectedExportCollections.add(key);
                    }
                  });
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Export Progress ──
          if (_isExporting) ...[
            _buildCard(
              borderColor: AppColors.primary.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _exportStatus,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${(_exportProgress * 100).toInt()}%',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: _exportProgress,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Export Button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isExporting || _selectedExportCollections.isEmpty || !canCreate
                  ? null
                  : _handleExportBackup,
              style: ElevatedButton.styleFrom(
                backgroundColor: canCreate ? AppColors.primary : AppColors.surfaceAlt,
                foregroundColor: canCreate ? Colors.white : AppColors.textTertiary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              icon: Icon(canCreate ? Icons.download_rounded : Icons.lock_outline_rounded, size: 20),
              label: Text(
                canCreate
                    ? 'GÉNÉRER ET TÉLÉCHARGER LE FICHIER JSON (${_selectedExportCollections.length} collections)'
                    : 'EXPORTATION DÉSACTIVÉE (Autorisation administrateur requise)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportBackup() async {
    if (!PermissionService.instance.canCreate(UserPermissionResources.importExport)) {
      _showErrorDialog('Permission insuffisante : Vous ne disposez pas de l\'autorisation requise de l\'administrateur pour exporter des données.');
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportStatus = 'Initialisation de l\'exportation...';
    });

    try {
      final savedPath = await ImportExportService.instance.exportEnterpriseBackup(
        selectedCollections: _selectedExportCollections,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _exportProgress = prog;
              _exportStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isExporting = false);
        _showSuccessDialog(
          title: 'Sauvegarde Réussie !',
          message: savedPath != null
              ? 'Le fichier de sauvegarde JSON a été enregistré avec succès :\n$savedPath'
              : 'La sauvegarde JSON a été téléchargée dans votre navigateur.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _showErrorDialog('Erreur lors de l\'exportation : $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ─── TAB 2: RESTAURATION LOGITECH (.JSON) ─────────────────────────
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildNativeRestoreTab(bool isMobile, {bool canUpdate = true, bool canDelete = true, Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ──
          _buildCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.restore_page_rounded, color: AppColors.info, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restauration Directe LogiTech Pro',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Restaurez directement une sauvegarde (.json) générée par LogiTech Pro.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Permission Notice Banner (Read-Only Mode) ──
          if (!canUpdate) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warningLight.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mode consultation active : Vous pouvez inspecter des sauvegardes mais l\'action de restauration et d\'importation des données est désactivée (Autorisation administrateur requise).',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),

          // ── File Picker Drop Zone ──
          InkWell(
            onTap: canUpdate ? _pickNativeBackupFile : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                color: !canUpdate
                    ? AppColors.surfaceAlt.withValues(alpha: 0.5)
                    : _nativeFileName != null
                        ? AppColors.primary.withValues(alpha: 0.03)
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: !canUpdate
                      ? AppColors.border
                      : _nativeFileName != null
                          ? AppColors.primary
                          : AppColors.border,
                  width: _nativeFileName != null ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: !canUpdate
                          ? AppColors.surfaceAlt
                          : _nativeFileName != null
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      !canUpdate
                          ? Icons.lock_outline_rounded
                          : _nativeFileName != null
                              ? Icons.check_circle_rounded
                              : Icons.cloud_upload_rounded,
                      color: !canUpdate
                          ? AppColors.textTertiary
                          : _nativeFileName != null
                              ? AppColors.primary
                              : AppColors.textTertiary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nativeFileName ?? 'Sélectionner un fichier de sauvegarde (.json)',
                    style: TextStyle(
                      color: !canUpdate
                          ? AppColors.textTertiary
                          : _nativeFileName != null
                              ? AppColors.primary
                              : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !canUpdate
                        ? 'La sélection de fichier est restreinte (Autorisation administrateur requise)'
                        : _nativeFileName != null
                            ? 'Cliquez pour changer de fichier de sauvegarde'
                            : 'Cliquez ici pour charger votre fichier JSON de sauvegarde LogiTech Pro.',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Parsed Backup Details ──
          if (_parsedNativeBackup != null) ...[
            _buildParsedBackupDetails(isMobile),
            const SizedBox(height: 24),

            // ── Restore Progress ──
            if (_isRestoring) ...[
              _buildCard(
                borderColor: AppColors.primary.withValues(alpha: 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _restoreStatus,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '${(_restoreProgress * 100).toInt()}%',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: _restoreProgress,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Restore Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isRestoring || _selectedRestoreCollections.isEmpty || !canUpdate
                    ? null
                    : _promptNativeRestoreConfirmation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canUpdate ? AppColors.primary : AppColors.surfaceAlt,
                  foregroundColor: canUpdate ? Colors.white : AppColors.textTertiary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                icon: Icon(canUpdate ? Icons.settings_backup_restore_rounded : Icons.lock_outline_rounded, size: 22),
                label: Text(
                  canUpdate
                      ? 'RESTAURER (${_selectedRestoreCollections.length} collections)'
                      : 'RESTAURATION DÉSACTIVÉE (Autorisation administrateur requise)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParsedBackupDetails(bool isMobile) {
    final rawCollections = _parsedNativeBackup!['collections'] ?? _parsedNativeBackup!['data'] ?? {};
    final appName = _parsedNativeBackup!['appName'] ?? 'LogiTech Backup';
    final exportDate = _parsedNativeBackup!['exportDate'] ?? 'Inconnue';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionLabel('CONTENU DU FICHIER ANALYSÉ'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$appName • $exportDate',
                  style: TextStyle(
                    color: AppColors.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (rawCollections is Map) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rawCollections.entries.map((e) {
                final count = e.value is List ? (e.value as List).length : 0;
                final isSelected = _selectedRestoreCollections.contains(e.key);
                final label = ImportExportService.backupCollections[e.key] ?? e.key.toString();

                return FilterChip(
                  label: Text('$label ($count)'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedRestoreCollections.add(e.key.toString());
                      } else {
                        _selectedRestoreCollections.remove(e.key.toString());
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickNativeBackupFile() async {
    if (!PermissionService.instance.canUpdate(UserPermissionResources.importExport)) {
      _showErrorDialog('Permission insuffisante : Vous ne disposez pas de l\'autorisation requise de l\'administrateur pour charger et importer des données.');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'lgbk', 'logitech-backup'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        Uint8List? bytes = pickedFile.bytes;
        if (bytes == null && pickedFile.path != null) {
          bytes = await File(pickedFile.path!).readAsBytes();
        }

        if (bytes != null) {
          final content = utf8.decode(bytes);
          final parsed = ImportExportService.instance.parseNativeBackup(content);
          final rawCollections = parsed['collections'] ?? parsed['data'] ?? {};

          setState(() {
            _nativeFileName = pickedFile.name;
            _parsedNativeBackup = parsed;
            _selectedRestoreCollections.clear();
            if (rawCollections is Map) {
              _selectedRestoreCollections.addAll(rawCollections.keys.map((e) => e.toString()));
            }
          });
        }
      }
    } catch (e) {
      _showErrorDialog('Impossible de lire le fichier : $e');
    }
  }

  Future<void> _promptNativeRestoreConfirmation() async {
    if (!PermissionService.instance.canUpdate(UserPermissionResources.importExport)) {
      _showErrorDialog('Permission insuffisante : Vous ne disposez pas de l\'autorisation requise de l\'administrateur pour restaurer des données.');
      return;
    }

    final isFull = _selectedRestoreCollections.length == ImportExportService.backupCollections.length;
    final enterpriseName = EnterpriseService.instance.currentEnterprise?.name ?? 'Votre Entreprise';

    final confirmed = await ImportConfirmationDialog.show(
      context: context,
      isFullImport: isFull,
      selectedCollectionKeys: _selectedRestoreCollections.toList(),
      enterpriseName: enterpriseName,
    );

    if (confirmed) {
      _executeNativeRestore();
    }
  }

  Future<void> _executeNativeRestore() async {
    if (_parsedNativeBackup == null) return;

    final canUpdate = PermissionService.instance.canUpdate(UserPermissionResources.importExport);
    if (!canUpdate) {
      _showErrorDialog('Permission insuffisante : Vous ne disposez pas de l\'autorisation requise de l\'administrateur pour exécuter une restauration.');
      return;
    }

    final canDelete = PermissionService.instance.canDelete(UserPermissionResources.importExport);

    setState(() {
      _isRestoring = true;
      _restoreProgress = 0.0;
      _restoreStatus = 'Démarrage de la restauration...';
    });

    try {
      final result = await ImportExportService.instance.restoreNativeBackup(
        backupData: _parsedNativeBackup!,
        selectedCollections: _selectedRestoreCollections,
        duplicateStrategy: _nativeDuplicateStrategy,
        shouldDeleteBeforeRestore: canDelete,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _restoreProgress = prog;
              _restoreStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isRestoring = false);

        _showSuccessDialog(
          title: result.success ? 'Restauration terminée' : 'Avertissement',
          message: result.message,
        );
        _loadCounts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        _showErrorDialog('Erreur lors de la restauration : $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ─── REUSABLE UI COMPONENTS ───────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCard({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildTextAction({IconData? icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionTile({
    required String key,
    required String label,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.04)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────
  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Erreur',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          error,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceAlt,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
