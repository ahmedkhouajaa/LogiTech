import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/document_numbering_config.dart';
import '../services/document_numbering_service.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';

class DocumentNumberingScreen extends StatefulWidget {
  const DocumentNumberingScreen({super.key});

  @override
  State<DocumentNumberingScreen> createState() => _DocumentNumberingScreenState();
}

class _DocumentNumberingScreenState extends State<DocumentNumberingScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  // Selected document type key (defaults to 'quotes' - Devis)
  String _selectedKey = 'quotes';

  // Map of all configs for current enterprise
  Map<String, DocumentNumberingConfig> _configs = {};
  // Snapshot of originally loaded configs to track changes count
  Map<String, DocumentNumberingConfig> _originalConfigs = {};

  // Maximum sequence existing in database for each collection
  final Map<String, int> _maxExistingSequences = {};

  // Controllers for currently selected document
  late TextEditingController _prefixController;
  late TextEditingController _currentNumberController;
  late TextEditingController _numberLengthController;

  StreamSubscription<String?>? _enterpriseSub;
  VoidCallback? _serviceListener;

  @override
  void initState() {
    super.initState();
    _prefixController = TextEditingController();
    _currentNumberController = TextEditingController();
    _numberLengthController = TextEditingController();

    // Listen to real-time sync updates from Firestore (across Android, Web, Desktop)
    _serviceListener = () {
      if (!mounted) return;
      _onRemoteSyncUpdate();
    };
    DocumentNumberingService.instance.notifier.addListener(_serviceListener!);

    // Re-sync if the user switches enterprises/workspaces
    _enterpriseSub = EnterpriseService.instance.enterpriseStream.listen((entId) {
      if (!mounted) return;
      _loadData();
    });

    _loadData();
  }

  @override
  void dispose() {
    if (_serviceListener != null) {
      DocumentNumberingService.instance.notifier.removeListener(_serviceListener!);
    }
    _enterpriseSub?.cancel();
    _prefixController.dispose();
    _currentNumberController.dispose();
    _numberLengthController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final entId = EnterpriseService.instance.currentEnterpriseId ?? 'default';

    try {
      final loadedConfigs = await DocumentNumberingService.loadAllConfigs(entId);
      _configs = Map.from(loadedConfigs);
      _originalConfigs = {
        for (var e in loadedConfigs.entries) e.key: e.value.copyWith(),
      };

      for (var e in loadedConfigs.entries) {
        _maxExistingSequences[e.key] = e.value.currentNumber;
      }

      // Load accurate max sequence for the selected document type
      await _loadMaxSequenceFor(_selectedKey);

      _updateControllersFor(_selectedKey);
    } catch (e) {
      debugPrint('[DocumentNumberingScreen] Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMaxSequenceFor(String key) async {
    if (_maxExistingSequences.containsKey(key)) return;

    final entId = EnterpriseService.instance.currentEnterpriseId ?? 'default';
    final maxSeq = await DocumentNumberingService.getMaxExistingSequence(key, entId);
    _maxExistingSequences[key] = maxSeq;
  }

  void _updateControllersFor(String key) {
    final cfg = _configs[key] ?? DocumentNumberingConfig.fromMap(key, null);
    _prefixController.text = cfg.prefix;
    _currentNumberController.text = cfg.currentNumber.toString();
    _numberLengthController.text = cfg.numberLength.toString();
  }

  /// Handles real-time cloud updates from other platforms (Android, Web, Desktop)
  void _onRemoteSyncUpdate() {
    final entId = EnterpriseService.instance.currentEnterpriseId ?? 'default';
    final cached = DocumentNumberingService.getCachedConfigs(entId);
    if (cached.isEmpty) return;

    bool currentDocUpdated = false;

    for (final entry in cached.entries) {
      final key = entry.key;
      final remote = entry.value;
      final currentLocal = _configs[key];
      final original = _originalConfigs[key];

      // Check if this document type was modified locally by the user
      final isDirty = currentLocal != null && original != null && currentLocal != original;

      if (!isDirty) {
        // Safe to update with remote changes
        _configs[key] = remote;
        _originalConfigs[key] = remote.copyWith();
        _maxExistingSequences[key] = remote.currentNumber;

        if (key == _selectedKey) {
          currentDocUpdated = true;
        }
      }
    }

    if (currentDocUpdated && mounted) {
      _updateControllersFor(_selectedKey);
      setState(() {});
    }
  }

  DocumentNumberingConfig get _currentConfig {
    return _configs[_selectedKey] ?? DocumentNumberingConfig.fromMap(_selectedKey, null);
  }

  int get _maxExistingSequence {
    return _maxExistingSequences[_selectedKey] ?? 0;
  }

  int get _unsavedChangesCount {
    int count = 0;
    for (final key in _configs.keys) {
      final cur = _configs[key];
      final orig = _originalConfigs[key];
      if (cur == null || orig == null) continue;

      if (cur != orig) {
        count++;
      }
    }
    return count;
  }

  void _onTypeChanged(String? newKey) async {
    if (newKey == null || newKey == _selectedKey) return;

    // Sync current controllers into config state before switching
    _syncFormToCurrentConfig();

    setState(() => _selectedKey = newKey);

    await _loadMaxSequenceFor(newKey);
    _updateControllersFor(newKey);
    setState(() {});
  }

  void _syncFormToCurrentConfig() {
    final cur = _currentConfig;
    final parsedNum = int.tryParse(_currentNumberController.text.trim()) ?? cur.currentNumber;
    final parsedLen = int.tryParse(_numberLengthController.text.trim()) ?? cur.numberLength;

    _configs[_selectedKey] = cur.copyWith(
      prefix: _prefixController.text.trim().toUpperCase(),
      currentNumber: parsedNum > 0 ? parsedNum : 1,
      numberLength: parsedLen > 0 && parsedLen <= 10 ? parsedLen : 6,
    );
  }

  Future<void> _saveAll() async {
    _syncFormToCurrentConfig();

    // Validate current number rule: currentNumber must be >= maxExistingSequence
    final cur = _currentConfig;
    final maxSeq = _maxExistingSequence;

    if (cur.currentNumber < maxSeq) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${context.tr('Le numéro actuel')} (${cur.currentNumber}) ${context.tr('ne peut pas être inférieur au dernier numéro utilisé')} ($maxSeq) ${context.tr('pour')} ${context.tr(cur.definition.label)}.',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final entId = EnterpriseService.instance.currentEnterpriseId ?? 'default';

    try {
      // Find all genuinely modified configs to prevent clobbering concurrent changes from other devices
      final modifiedList = <DocumentNumberingConfig>[];
      for (final entry in _configs.entries) {
        final orig = _originalConfigs[entry.key];
        if (orig == null || entry.value != orig) {
          modifiedList.add(entry.value);
        }
      }

      if (modifiedList.isEmpty) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      await DocumentNumberingService.saveModifiedConfigs(entId, modifiedList);

      for (final cfg in modifiedList) {
        _originalConfigs[cfg.docTypeKey] = cfg.copyWith();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('Paramètres enregistrés et synchronisés sur tous vos appareils !'),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[DocumentNumberingScreen] Error saving configs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Erreur')} : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final unsavedCount = _unsavedChangesCount;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 32.0,
        vertical: isMobile ? 16.0 : 24.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Title, Sync Badge, and "Enregistrer (X)" Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          context.tr('Numérotation des Documents'),
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.success),
                              const SizedBox(width: 5),
                              Text(
                                context.tr('Synchronisé en temps réel'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: (unsavedCount > 0 && !_isSaving) ? _saveAll : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        '${context.tr('Enregistrer')} ($unsavedCount)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: unsavedCount > 0 ? AppColors.primary : AppColors.textTertiary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // CARD 1: Type de Document selector
              _buildTypeSelectorCard(isDark),
              const SizedBox(height: 20),

              // CARD 2: Configuration panel for selected document type
              _buildConfigFormCard(isDark, isMobile),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CARD 1: DOCUMENT TYPE SELECTOR ───────────────────────────────────────
  Widget _buildTypeSelectorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Type de Document'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Sélectionner un type de document'),
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.sidebarBg : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.border : AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedKey,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                dropdownColor: isDark ? AppColors.surface : Colors.white,
                items: DocumentTypeDefinition.allTypes.map((def) {
                  return DropdownMenuItem<String>(
                    value: def.key,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr(def.dropdownLabel),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: def.category == 'Vente'
                                ? Colors.blue.withValues(alpha: 0.1)
                                : Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.tr(def.category),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: def.category == 'Vente' ? Colors.blue : Colors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onTypeChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD 2: CONFIGURATION FORM ───────────────────────────────────────────
  Widget _buildConfigFormCard(bool isDark, bool isMobile) {
    final cfg = _currentConfig;
    final def = cfg.definition;
    final nextNumber = cfg.currentNumber + 1;
    final maxSeq = _maxExistingSequence;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Document Title & Category Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(def.label),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  context.tr(def.category),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Configurez les paramètres de numérotation pour ce type de document'),
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Row 1: Préfixe & Numéro Actuel
            if (isMobile) ...[
              _buildPrefixField(isDark),
              const SizedBox(height: 16),
              _buildCurrentNumberField(isDark, nextNumber, maxSeq),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPrefixField(isDark)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildCurrentNumberField(isDark, nextNumber, maxSeq)),
                ],
              ),
            ],
            const SizedBox(height: 18),

            // Row 2: Longueur du Numéro & Inclure l'Année
            if (isMobile) ...[
              _buildNumberLengthField(isDark),
              const SizedBox(height: 16),
              _buildIncludeYearSwitch(cfg),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildNumberLengthField(isDark)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildIncludeYearSwitch(cfg)),
                ],
              ),
            ],
            const SizedBox(height: 18),

            // Row 3: Activé Switch
            _buildEnabledSwitch(cfg),
            const SizedBox(height: 24),

            // Row 4: Aperçu
            Text(
              context.tr('Aperçu'),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.sidebarBg : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                cfg.preview,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FIELD BUILDERS ───────────────────────────────────────────────────────
  Widget _buildPrefixField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Préfixe'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _prefixController,
          textCapitalization: TextCapitalization.characters,
          decoration: _inputDecoration(isDark, hint: 'Ex: FAC, DEV, BL'),
          onChanged: (val) {
            setState(() {
              _configs[_selectedKey] = _currentConfig.copyWith(
                prefix: val.trim().toUpperCase(),
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildCurrentNumberField(bool isDark, int nextNumber, int maxSeq) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildFieldLabel('Numéro Actuel'),
            const SizedBox(width: 6),
            Text(
              '( ${context.tr('Le prochain numéro')}: $nextNumber )',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _currentNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration(isDark, hint: 'Ex: 1'),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return context.tr('Veuillez saisir un numéro');
            }
            final numVal = int.tryParse(val.trim());
            if (numVal == null || numVal <= 0) {
              return context.tr('Numéro invalide');
            }
            if (numVal < maxSeq) {
              return '${context.tr('Ne peut pas être inférieur au dernier numéro utilisé')} ($maxSeq)';
            }
            return null;
          },
          onChanged: (val) {
            final numVal = int.tryParse(val.trim());
            if (numVal != null && numVal > 0) {
              setState(() {
                _configs[_selectedKey] = _currentConfig.copyWith(currentNumber: numVal);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildNumberLengthField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Longueur du Numéro'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _numberLengthController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration(isDark, hint: 'Ex: 6'),
          onChanged: (val) {
            final len = int.tryParse(val.trim());
            if (len != null && len > 0 && len <= 10) {
              setState(() {
                _configs[_selectedKey] = _currentConfig.copyWith(numberLength: len);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildIncludeYearSwitch(DocumentNumberingConfig cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Inclure l\'Année'),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch.adaptive(
              value: cfg.includeYear,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                setState(() {
                  _configs[_selectedKey] = cfg.copyWith(includeYear: val);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnabledSwitch(DocumentNumberingConfig cfg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Activé'),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch.adaptive(
              value: cfg.isEnabled,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                setState(() {
                  _configs[_selectedKey] = cfg.copyWith(isEnabled: val);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      context.tr(text),
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {required String hint}) {
    return InputDecoration(
      hintText: context.tr(hint),
      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13.5),
      filled: true,
      fillColor: isDark ? AppColors.sidebarBg : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.error),
      ),
    );
  }
}
