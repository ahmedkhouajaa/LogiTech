import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../services/update_service.dart';

class AdminPublishUpdateDialog extends StatefulWidget {
  const AdminPublishUpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AdminPublishUpdateDialog(),
    );
  }

  @override
  State<AdminPublishUpdateDialog> createState() => _AdminPublishUpdateDialogState();
}

class _AdminPublishUpdateDialogState extends State<AdminPublishUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _androidUrlController = TextEditingController();
  final _windowsUrlController = TextEditingController();
  final _changelogController = TextEditingController();
  bool _forceUpdate = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _versionController.text = data['version']?.toString() ?? AppConfig.appVersion;
        _androidUrlController.text = data['androidUrl']?.toString() ?? data['android_url']?.toString() ?? '';
        _windowsUrlController.text = data['windowsUrl']?.toString() ?? data['windows_url']?.toString() ?? '';
        _changelogController.text = data['changelog']?.toString() ?? '';
        _forceUpdate = data['forceUpdate'] == true || data['force_update'] == true;
      } else {
        _versionController.text = AppConfig.appVersion;
      }
    } catch (e) {
      _versionController.text = AppConfig.appVersion;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _versionController.dispose();
    _androidUrlController.dispose();
    _windowsUrlController.dispose();
    _changelogController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final version = _versionController.text.trim();
      final androidUrl = _androidUrlController.text.trim();
      final windowsUrl = _windowsUrlController.text.trim();
      final changelog = _changelogController.text.trim();

      await FirebaseFirestore.instance.collection('app_config').doc('version').set({
        'version': version,
        'androidUrl': androidUrl,
        'windowsUrl': windowsUrl,
        'changelog': changelog,
        'forceUpdate': _forceUpdate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      // Check for update locally
      await UpdateService.instance.checkForUpdate(silent: false);

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Version $version publiée avec succès sur Firestore !'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la publication : $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Diffuser une mise à jour',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Configurez la nouvelle version pour tous les utilisateurs',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Version field
                        TextFormField(
                          controller: _versionController,
                          decoration: InputDecoration(
                            labelText: 'Numéro de version (ex: 1.0.1)',
                            hintText: '1.0.1',
                            prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            helperText: 'Version actuelle dans le code : ${AppConfig.appVersion}',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Veuillez saisir un numéro de version';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Android APK URL
                        TextFormField(
                          controller: _androidUrlController,
                          decoration: InputDecoration(
                            labelText: 'Lien direct APK Android (GitHub Releases / direct)',
                            hintText: 'https://github.com/.../app-release.apk',
                            prefixIcon: const Icon(Icons.android_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Windows EXE URL
                        TextFormField(
                          controller: _windowsUrlController,
                          decoration: InputDecoration(
                            labelText: 'Lien direct Windows EXE (GitHub Releases / direct)',
                            hintText: 'https://github.com/.../LogiTech-Setup.exe',
                            prefixIcon: const Icon(Icons.desktop_windows_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Changelog
                        TextFormField(
                          controller: _changelogController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Notes de mise à jour (Nouveautés & Corrections)',
                            hintText: '- Ajout des permissions utilisateurs\n- Optimisation de la synchronisation\n- Correction de bugs mineurs',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Force update toggle
                        SwitchListTile(
                          value: _forceUpdate,
                          onChanged: (val) => setState(() => _forceUpdate = val),
                          title: const Text(
                            'Mise à jour obligatoire (Forcée)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Bloque l\'accès à l\'application tant que l\'utilisateur n\'a pas mis à jour.',
                            style: TextStyle(fontSize: 12),
                          ),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.primary,
                        ),

                        const SizedBox(height: 24),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                              child: const Text('Annuler'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _publish,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(_isSaving ? 'Publication...' : 'Publier la mise à jour'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
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
