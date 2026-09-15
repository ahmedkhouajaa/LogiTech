import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/enterprise_service.dart';
import '../services/permission_service.dart';
import '../utils/constants.dart';
import '../l10n/app_localizations.dart';
import '../utils/firestore_safe_helper.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _isSendingReset = false;

  bool _isGoogleUser = false;
  String _userRole = 'Collaborateur';
  bool _isOwner = false;
  DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');

        // Fetch from Firestore
        final uData = await FirestoreSafeHelper.getDocData(
              FirebaseFirestore.instance.collection('users'),
              user.uid,
            ) ??
            {};

        final name = uData['name']?.toString().isNotEmpty == true
            ? uData['name'].toString()
            : (user.displayName ?? (user.email?.split('@').first ?? 'Utilisateur'));

        final email = uData['email']?.toString().isNotEmpty == true
            ? uData['email'].toString()
            : (user.email ?? '');

        final phone = uData['phone']?.toString() ??
            uData['phoneNumber']?.toString() ??
            uData['phone_number']?.toString() ??
            '';

        final role = uData['role']?.toString().toLowerCase();
        _isOwner = uData['isOwner'] == true || PermissionService.instance.isOwner;
        if (_isOwner) {
          _userRole = 'Propriétaire';
        } else if (role == 'admin' || role == 'administrateur' || PermissionService.instance.isAdmin) {
          _userRole = 'Administrateur';
        } else {
          _userRole = 'Collaborateur';
        }

        if (uData['createdAt'] is Timestamp) {
          _createdAt = (uData['createdAt'] as Timestamp).toDate();
        }

        _nameController.text = name;
        _emailController.text = email;
        _phoneController.text = phone;
      }
    } catch (e) {
      debugPrint('[PersonalInfoScreen] Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Utilisateur non authentifié.')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim();

      // 1. Update Firebase Auth displayName
      try {
        await user.updateDisplayName(newName);
      } catch (authError) {
        debugPrint('[PersonalInfoScreen] Note: Auth displayName update: $authError');
      }

      // 2. Update Firestore users collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': newName,
        'phone': newPhone,
        'phoneNumber': newPhone,
        'phone_number': newPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update enterprise members array in current enterprise if present
      final curEid = EnterpriseService.instance.currentEnterpriseId;
      if (curEid != null && curEid.isNotEmpty) {
        try {
          final entRef = FirebaseFirestore.instance.collection('enterprises').doc(curEid);
          final entSnap = await entRef.get();
          if (entSnap.exists) {
            final members = List<Map<String, dynamic>>.from(
              (entSnap.data()?['members'] as List? ?? []).map((m) => Map<String, dynamic>.from(m)),
            );
            bool updated = false;
            for (final m in members) {
              if (m['uid'] == user.uid || (m['email'] != null && m['email'] == user.email)) {
                m['name'] = newName;
                m['phone'] = newPhone;
                m['phoneNumber'] = newPhone;
                m['phone_number'] = newPhone;
                updated = true;
              }
            }
            if (updated) {
              await entRef.set({
                'members': members,
                'updated_at': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true));
            }
          }
        } catch (entError) {
          debugPrint('[PersonalInfoScreen] Note: Enterprise member update: $entError');
        }
      }

      // 4. Refresh permissions in-memory cache
      await PermissionService.instance.loadPermissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(context.tr('Informations personnelles mises à jour avec succès !')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('${context.tr('Erreur')} : $e')),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? _emailController.text.trim();
    if (user == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Utilisateur non authentifié.')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword == currentPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.tr('Le nouveau mot de passe doit être différent de votre mot de passe actuel.')),
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Les nouveaux mots de passe ne correspondent pas.')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      debugPrint('[PersonalInfoScreen] Validating current password for: $email');

      // 1. Reauthenticate by signing in with the current email & password.
      // This immediately refreshes the auth token and safely works across Windows, Android, and Web without hanging.
      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: email,
              password: currentPassword,
            )
            .timeout(
              const Duration(seconds: 12),
              onTimeout: () => throw TimeoutException('La vérification du mot de passe a expiré. Veuillez vérifier votre connexion.'),
            );
      } on FirebaseAuthException catch (authErr) {
        debugPrint('[PersonalInfoScreen] Re-auth error: code=${authErr.code}, message=${authErr.message}');
        if (authErr.code == 'too-many-requests') {
          throw 'Trop de tentatives infructueuses. Veuillez patienter quelques instants avant de réessayer.';
        }
        if (authErr.code == 'network-request-failed') {
          throw 'Impossible de contacter le serveur. Veuillez vérifier votre connexion Internet.';
        }
        // Any other authentication failure when checking old password means the password was wrong
        throw 'Votre mot de passe actuel est incorrect. Veuillez vérifier votre saisie.';
      } catch (e) {
        if (e is TimeoutException) rethrow;
        debugPrint('[PersonalInfoScreen] Re-auth unexpected error: $e');
        throw 'Votre mot de passe actuel est incorrect. Veuillez vérifier votre saisie.';
      }

      debugPrint('[PersonalInfoScreen] Re-auth successful. Updating password...');

      // 2. Update to new password
      final activeUser = userCredential.user ?? FirebaseAuth.instance.currentUser;
      if (activeUser == null) {
        throw 'Session utilisateur expirée.';
      }

      await activeUser
          .updatePassword(newPassword)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Le délai d\'attente pour la mise à jour du mot de passe a expiré.'),
          );

      debugPrint('[PersonalInfoScreen] Password successfully updated!');

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(context.tr('Mot de passe mis à jour avec succès !')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[PersonalInfoScreen] FirebaseAuthException: ${e.code} - ${e.message}');
      String msg = 'Erreur lors du changement de mot de passe.';
      final code = e.code.toLowerCase();
      final message = (e.message ?? '').toLowerCase();

      if (code.contains('wrong-password') ||
          code.contains('invalid-credential') ||
          code.contains('invalid_login_credentials') ||
          code.contains('internal-error') ||
          message.contains('internal error') ||
          message.contains('password') ||
          message.contains('credential')) {
        msg = 'Votre mot de passe actuel est incorrect. Veuillez vérifier votre saisie.';
      } else if (code.contains('weak-password')) {
        msg = 'Le nouveau mot de passe doit comporter au moins 6 caractères.';
      } else if (code.contains('requires-recent-login')) {
        msg = 'Session expirée. Veuillez vous déconnecter et vous reconnecter.';
      } else if (code.contains('too-many-requests')) {
        msg = 'Trop de tentatives. Veuillez patienter quelques minutes.';
      } else if (e.message != null && e.message!.isNotEmpty && !message.contains('internal error')) {
        msg = e.message!;
      } else {
        msg = 'Votre mot de passe actuel est incorrect. Veuillez vérifier votre saisie.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on TimeoutException catch (te) {
      debugPrint('[PersonalInfoScreen] TimeoutException: $te');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.timer_off_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(te.message ?? 'Le délai d\'attente a expiré. Veuillez vérifier votre connexion.')),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PersonalInfoScreen] Error: $e');
      String errText = e.toString().replaceFirst('Exception: ', '');
      if (errText.toLowerCase().contains('internal error') || errText.toLowerCase().contains('invalid')) {
        errText = 'Votre mot de passe actuel est incorrect. Veuillez vérifier votre saisie.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(errText)),
              ],
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Aucune adresse e-mail trouvée.')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Un e-mail de réinitialisation a été envoyé à')} $email.'),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
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
        setState(() => _isSendingReset = false);
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

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 32.0,
        vertical: isMobile ? 16.0 : 28.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Profile Header Card
              _buildProfileHeaderCard(isDark, isMobile),
              const SizedBox(height: 24),

              // 2. Personal Information Form Card
              _buildPersonalInfoCard(isDark),
              const SizedBox(height: 24),

              // 3. Security & Password Change Card
              _buildSecurityPasswordCard(isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HERO PROFILE HEADER ──────────────────────────────────────────────────
  Widget _buildProfileHeaderCard(bool isDark, bool isMobile) {
    final name = _nameController.text.trim();

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name.isNotEmpty ? name : context.tr('Utilisateur'),
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  context.tr(_userRole),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _emailController.text.isNotEmpty ? _emailController.text : context.tr('Compte actif'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          if (_createdAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  '${context.tr('Membre depuis')} ${_createdAt!.day.toString().padLeft(2, '0')}/${_createdAt!.month.toString().padLeft(2, '0')}/${_createdAt!.year}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── PERSONAL INFO SECTION ────────────────────────────────────────────────
  Widget _buildPersonalInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Coordonnées personnelles'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('Modifiez vos informations d\'identification et de contact'),
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),

            // Nom complet
            _buildFieldLabel('Nom complet', isRequired: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(
                hint: 'Entrez votre nom et prénom',
                prefixIcon: Icons.badge_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return context.tr('Nom complet obligatoire');
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Email
            _buildFieldLabel('Adresse e-mail'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              readOnly: true,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'adresse@exemple.com',
                prefixIcon: Icons.alternate_email_rounded,
                suffixWidget: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isGoogleUser ? Icons.g_mobiledata_rounded : Icons.lock_outline_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isGoogleUser ? 'Google' : context.tr('Compte vérifié'),
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('L\'adresse e-mail est liée à votre compte d\'authentification unique.'),
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 18),

            // Téléphone
            _buildFieldLabel('Numéro de téléphone'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                hint: '+216 -- --- ---',
                prefixIcon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: 24),

            // Bouton Enregistrer
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSavingProfile ? null : _saveProfile,
                  icon: _isSavingProfile
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isSavingProfile ? context.tr('Enregistrement...') : context.tr('Enregistrer les coordonnées'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SECURITY & PASSWORD SECTION ──────────────────────────────────────────
  Widget _buildSecurityPasswordCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.border : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Sécurité & Mot de passe'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('Mettez à jour votre mot de passe pour sécuriser l\'accès à votre compte.'),
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),

            if (_isGoogleUser) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.info, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        context.tr('Vous êtes connecté via un compte Google. Votre authentification et mot de passe sont sécurisés directement par votre compte Google.'),
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Ancien mot de passe
              _buildFieldLabel('Ancien mot de passe', isRequired: true),
              const SizedBox(height: 6),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: _inputDecoration(
                  hint: 'Saisissez votre mot de passe actuel',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixWidget: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.tr('Veuillez entrer votre mot de passe actuel');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Nouveau mot de passe
              _buildFieldLabel('Nouveau mot de passe', isRequired: true),
              const SizedBox(height: 6),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: _inputDecoration(
                  hint: 'Au moins 6 caractères',
                  prefixIcon: Icons.vpn_key_outlined,
                  suffixWidget: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.tr('Veuillez entrer un nouveau mot de passe');
                  }
                  if (v.trim().length < 6) {
                    return context.tr('Le mot de passe doit contenir au moins 6 caractères.');
                  }
                  if (_currentPasswordController.text.trim().isNotEmpty &&
                      v.trim() == _currentPasswordController.text.trim()) {
                    return context.tr('Le nouveau mot de passe doit être différent de votre mot de passe actuel.');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Confirmer le nouveau mot de passe
              _buildFieldLabel('Confirmer le nouveau mot de passe', isRequired: true),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: _inputDecoration(
                  hint: 'Confirmez votre nouveau mot de passe',
                  prefixIcon: Icons.lock_reset_rounded,
                  suffixWidget: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.tr('Confirmer le mot de passe');
                  }
                  if (v.trim() != _newPasswordController.text.trim()) {
                    return context.tr('Les nouveaux mots de passe ne correspondent pas.');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Row with Forgot link and Submit button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _isSendingReset ? null : _sendPasswordResetEmail,
                    icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    label: Text(
                      _isSendingReset ? context.tr('Envoi en cours...') : context.tr('Mot de passe oublié ?'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isChangingPassword ? null : _changePassword,
                      icon: _isChangingPassword
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.key_rounded, size: 18),
                      label: Text(
                        _isChangingPassword ? context.tr('Modification...') : context.tr('Modifier le mot de passe'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          context.tr(label),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixWidget,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: context.tr(hint),
      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13.5),
      prefixIcon: Icon(prefixIcon, size: 19, color: AppColors.textSecondary),
      suffixIcon: suffixWidget,
      filled: true,
      fillColor: isDark ? AppColors.sidebarBg : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.error),
      ),
    );
  }
}
