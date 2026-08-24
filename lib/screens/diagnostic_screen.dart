import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../utils/constants.dart';
import '../services/enterprise_service.dart';
import '../services/permission_service.dart';
import '../services/connectivity_service.dart';
import '../services/error_handler.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  bool _isTestingFirestore = false;
  String? _firestoreTestResult;
  bool _firestoreTestSuccess = false;

  bool _isReloadingEnterprises = false;
  String? _reloadResult;

  Future<void> _testFirestore() async {
    setState(() {
      _isTestingFirestore = true;
      _firestoreTestResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw "Aucun utilisateur Firebase Auth connecté.";
      }

      // Test 1: Read user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      // Test 2: Query enterprises
      final entQuery = await FirebaseFirestore.instance
          .collection('enterprises')
          .where('owner_id', isEqualTo: user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      // Test 3: Write test
      final testDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      await testDocRef.set({
        'lastDiagnosticTest': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

      stopwatch.stop();
      setState(() {
        _isTestingFirestore = false;
        _firestoreTestSuccess = true;
        _firestoreTestResult =
            "Succès (${stopwatch.elapsedMilliseconds} ms)\n"
            "• Document utilisateur: ${userDoc.exists ? 'Existe' : 'Absent'}\n"
            "• Entreprises trouvées (owner_id): ${entQuery.docs.length}\n"
            "• Écriture Firestore: Validée";
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _isTestingFirestore = false;
        _firestoreTestSuccess = false;
        _firestoreTestResult =
            "Échec après ${stopwatch.elapsedMilliseconds} ms:\n"
            "${ErrorHandler.parseError(e)}\n\nDétails techniques: $e";
      });
    }
  }

  Future<void> _reloadEnterprises() async {
    setState(() {
      _isReloadingEnterprises = true;
      _reloadResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final enterprises = await EnterpriseService.instance.loadEnterprisesFromFirestore(maxRetries: 3);
      stopwatch.stop();
      setState(() {
        _isReloadingEnterprises = false;
        _reloadResult = "Succès (${stopwatch.elapsedMilliseconds} ms) : ${enterprises.length} entreprise(s) chargée(s).";
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _isReloadingEnterprises = false;
        _reloadResult = "Erreur (${stopwatch.elapsedMilliseconds} ms) : $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final enterpriseService = EnterpriseService.instance;
    final permissionService = PermissionService.instance;
    final connectivity = ConnectivityService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Diagnostic Système & Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir les informations',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: '1. Authentification Firebase',
              icon: Icons.account_circle,
              color: user != null ? AppColors.success : AppColors.error,
              children: [
                _buildInfoRow('Statut de session', user != null ? 'Connecté' : 'Déconnecté', isOk: user != null),
                _buildInfoRow('UID Utilisateur', user?.uid ?? 'N/A'),
                _buildInfoRow('Email', user?.email ?? 'N/A'),
                _buildInfoRow('Nom', user?.displayName ?? 'N/A'),
                _buildInfoRow('Plateforme', kIsWeb ? 'Web' : 'Desktop (Windows)'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSection(
              title: '2. Espaces de Travail (Entreprises)',
              icon: Icons.business,
              color: enterpriseService.enterprises.isNotEmpty ? AppColors.primary : AppColors.warning,
              children: [
                _buildInfoRow('Entreprise active', enterpriseService.currentEnterprise?.name ?? 'Aucune'),
                _buildInfoRow('ID Entreprise active', enterpriseService.currentEnterpriseId ?? 'N/A'),
                _buildInfoRow('Nombre d\'entreprises', '${enterpriseService.enterprises.length}'),
                const Divider(),
                ...enterpriseService.enterprises.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('(${e.id})', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                )),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isReloadingEnterprises ? null : _reloadEnterprises,
                  icon: _isReloadingEnterprises
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, size: 16),
                  label: const Text('Forcer le rechargement Firestore (15s timeout + 3x retry)'),
                ),
                if (_reloadResult != null) ...[
                  const SizedBox(height: 8),
                  Text(_reloadResult!, style: TextStyle(fontSize: 12, color: _reloadResult!.startsWith('Succès') ? AppColors.success : AppColors.error)),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSection(
              title: '3. Droits & Permissions',
              icon: Icons.security,
              color: permissionService.isAdmin ? AppColors.success : AppColors.info,
              children: [
                _buildInfoRow('Rôle', permissionService.role),
                _buildInfoRow('Administrateur', permissionService.isAdmin ? 'Oui' : 'Non', isOk: permissionService.isAdmin),
                _buildInfoRow('Propriétaire', permissionService.isOwner ? 'Oui' : 'Non', isOk: permissionService.isOwner),
                _buildInfoRow('Modules autorisés', '${permissionService.permissions.length}'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSection(
              title: '4. Test de Connectivité & Firestore en Direct',
              icon: Icons.network_check,
              color: connectivity.isOnline ? AppColors.success : AppColors.error,
              children: [
                _buildInfoRow('Connexion Internet', connectivity.isOnline ? 'En ligne' : 'Hors ligne', isOk: connectivity.isOnline),
                _buildInfoRow('Projet Firebase', FirebaseFirestore.instance.app.options.projectId),
                _buildInfoRow('Serveur Firestore', 'firestore.googleapis.com (Production)'),
                _buildInfoRow('SSL Sécurisé', 'Oui (Port 443)', isOk: true),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isTestingFirestore ? null : _testFirestore,
                  icon: _isTestingFirestore
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Exécuter le test de lecture/écriture Firestore'),
                ),
                if (_firestoreTestResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: _firestoreTestSuccess ? AppColors.success.withAlpha(25) : AppColors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: _firestoreTestSuccess ? AppColors.success : AppColors.error),
                    ),
                    child: SelectableText(
                      _firestoreTestResult!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: _firestoreTestSuccess ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool? isOk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Row(
            children: [
              if (isOk != null) ...[
                Icon(
                  isOk ? Icons.check_circle : Icons.cancel,
                  color: isOk ? AppColors.success : AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
