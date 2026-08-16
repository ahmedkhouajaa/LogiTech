import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_management_model.dart';
import '../models/enterprise.dart';
import '../blocs/user_management/user_management_bloc.dart';
import '../blocs/user_management/user_management_event.dart';
import '../blocs/user_management/user_management_state.dart';
import '../services/enterprise_service.dart';
import '../widgets/permissions_matrix_widget.dart';
import '../utils/constants.dart';

class AddEditUserScreen extends StatefulWidget {
  final EnterpriseUserModel? userToEdit;

  const AddEditUserScreen({super.key, this.userToEdit});

  bool get isEditing => userToEdit != null;

  @override
  State<AddEditUserScreen> createState() => _AddEditUserScreenState();
}

class _AddEditUserScreenState extends State<AddEditUserScreen> {
  // Step tracking: 1 = Email Verification, 2 = Configure Access
  int _currentStep = 1;

  // Step 1 Form
  final _step1FormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // Step 2 Form
  final _step2FormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _sendInvitationEmail = true;
  final String _selectedCountryCode = '+216';

  String _verifiedUid = '';
  String _verifiedEmail = '';
  String _selectedRole = 'collaborator'; // 'admin' or 'collaborator'
  Set<String> _selectedEnterpriseIds = {};
  bool _selectAllEnterprises = false;
  Map<String, UserResourcePermission> _permissions = {};

  List<Enterprise> _ownedEnterprises = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentEid = EnterpriseService.instance.currentEnterpriseId ?? '';

    // Load available enterprises
    final userState = context.read<UserManagementBloc>().state;
    if (userState is UserManagementLoaded) {
      _ownedEnterprises = userState.ownedEnterprises;
    }
    if (_ownedEnterprises.isEmpty) {
      _ownedEnterprises = EnterpriseService.instance.enterprises;
    }

    if (widget.isEditing) {
      _currentStep = 2;
      final user = widget.userToEdit!;
      _verifiedUid = user.uid;
      _verifiedEmail = user.email;

      final nameParts = user.name.split(' ');
      _firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
      _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      _phoneController.text = user.phone ?? '';

      _selectedRole = user.isAdmin ? 'admin' : 'collaborator';
      _selectedEnterpriseIds = Set<String>.from(user.enterprises);
      if (currentEid.isNotEmpty && !_selectedEnterpriseIds.contains(currentEid)) {
        _selectedEnterpriseIds.add(currentEid);
      }

      _permissions = user.permissions.isNotEmpty
          ? Map<String, UserResourcePermission>.from(user.permissions)
          : (_selectedRole == 'admin'
              ? UserPermissionResources.getAdminDefaultPermissions()
              : UserPermissionResources.getCollaboratorDefaultPermissions());

      _selectAllEnterprises = _ownedEnterprises.isNotEmpty &&
          _ownedEnterprises.every((e) => _selectedEnterpriseIds.contains(e.id));
    } else {
      _currentStep = 1;
      _selectedRole = 'collaborator';
      _permissions = UserPermissionResources.getCollaboratorDefaultPermissions();
      if (currentEid.isNotEmpty) {
        _selectedEnterpriseIds.add(currentEid);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onVerifyEmail() {
    if (_step1FormKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final currentEnterpriseId = EnterpriseService.instance.currentEnterpriseId ?? '';
      context.read<UserManagementBloc>().add(
            VerifyUserEmailEvent(
              email: email,
              currentEnterpriseId: currentEnterpriseId,
            ),
          );
    }
  }

  void _onRoleChanged(String newRole) {
    setState(() {
      _selectedRole = newRole;
      if (newRole == 'admin') {
        _permissions = UserPermissionResources.getAdminDefaultPermissions();
      } else {
        _permissions = UserPermissionResources.getCollaboratorDefaultPermissions();
      }
    });
  }

  void _toggleAllEnterprises(bool? value) {
    final checked = value ?? false;
    setState(() {
      _selectAllEnterprises = checked;
      if (checked) {
        _selectedEnterpriseIds = _ownedEnterprises.map((e) => e.id).toSet();
      } else {
        final currentEid = EnterpriseService.instance.currentEnterpriseId ?? '';
        _selectedEnterpriseIds = currentEid.isNotEmpty ? {currentEid} : {};
      }
    });
  }

  void _toggleEnterprise(String id) {
    setState(() {
      if (_selectedEnterpriseIds.contains(id)) {
        _selectedEnterpriseIds.remove(id);
      } else {
        _selectedEnterpriseIds.add(id);
      }
      _selectAllEnterprises = _ownedEnterprises.isNotEmpty &&
          _ownedEnterprises.every((e) => _selectedEnterpriseIds.contains(e.id));
    });
  }

  void _onSaveUser() {
    if (_selectedEnterpriseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner au moins une entreprise.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final phone = _phoneController.text.trim().isNotEmpty
        ? '$_selectedCountryCode ${_phoneController.text.trim()}'
        : null;
    final password = _passwordController.text.trim();
    final currentEnterpriseId = EnterpriseService.instance.currentEnterpriseId ?? '';

    setState(() => _isSaving = true);

    if (widget.isEditing) {
      context.read<UserManagementBloc>().add(
            UpdateEnterpriseUserEvent(
              targetUid: _verifiedUid,
              name: fullName.isNotEmpty ? fullName : widget.userToEdit!.name,
              phone: phone,
              role: _selectedRole,
              selectedEnterpriseIds: _selectedEnterpriseIds.toList(),
              permissions: _permissions,
              currentEnterpriseId: currentEnterpriseId,
            ),
          );
    } else {
      context.read<UserManagementBloc>().add(
            AddEnterpriseUserEvent(
              email: _verifiedEmail,
              name: fullName.isNotEmpty ? fullName : _verifiedEmail.split('@').first,
              phone: phone,
              password: password.isNotEmpty ? password : null,
              sendInvitationEmail: _sendInvitationEmail,
              role: _selectedRole,
              selectedEnterpriseIds: _selectedEnterpriseIds.toList(),
              permissions: _permissions,
              currentEnterpriseId: currentEnterpriseId,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserManagementBloc, UserManagementState>(
      listener: (context, state) {
        if (state is EmailVerificationSuccess) {
          setState(() {
            _verifiedEmail = state.email;
            final parts = state.name.split(' ');
            _firstNameController.text = parts.isNotEmpty ? parts.first : '';
            _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            _currentStep = 2;
          });
        } else if (state is EmailVerificationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (state is UserOperationSuccess) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is UserOperationFailure) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Text(
            widget.isEditing
                ? 'Modifier l\'utilisateur'
                : (_currentStep == 1 ? 'Inviter un utilisateur' : 'Créer un nouvel utilisateur'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (_currentStep == 2 && !widget.isEditing) {
                setState(() => _currentStep = 1);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: isMobile ? 16 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── STEP 1: EMAIL VERIFICATION ─────────────────────────────────────────────

  Widget _buildStep1() {
    final isVerifying = context.watch<UserManagementBloc>().state is EmailVerificationInProgress;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inviter un utilisateur',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saisissez l\'adresse email d\'un nouvel utilisateur à créer pour l\'entreprise.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),

            // Email Field
            Text(
              'Adresse Email de l\'utilisateur *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'exemple@domaine.com',
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.textTertiary, size: 20),
                filled: true,
                fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Veuillez saisir une adresse email.';
                }
                if (!val.contains('@') || !val.contains('.')) {
                  return 'Format d\'adresse email non valide.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _onVerifyEmail(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seuls les nouveaux utilisateurs sans compte existant peuvent être ajoutés ici. Un compte leur sera créé.',
                      style: TextStyle(fontSize: 12, color: const Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: isVerifying ? null : _onVerifyEmail,
                  icon: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    isVerifying ? 'Vérification...' : 'Suivant',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 2: CONFIGURE ACCESS & PERMISSIONS ─────────────────────────────────

  Widget _buildStep2() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: User Profile Details
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Informations de l\'utilisateur' : 'Créer un nouvel utilisateur',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Read-only email
                Text('Adresse Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: _verifiedEmail,
                  readOnly: true,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textTertiary, size: 20),
                    filled: true,
                    fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 16),

                // Prénom and Nom
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 500;
                    if (isNarrow) {
                      return Column(
                        children: [
                          _buildTextInput('Prénom', _firstNameController, 'Saisissez le prénom'),
                          const SizedBox(height: 16),
                          _buildTextInput('Nom', _lastNameController, 'Saisissez le nom'),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: _buildTextInput('Prénom', _firstNameController, 'Saisissez le prénom')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextInput('Nom', _lastNameController, 'Saisissez le nom')),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Mot de passe (Image 3 style)
                if (!widget.isEditing) ...[
                  Text(
                    'Mot de Passe',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Saisissez le mot de passe (optionnel)',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Minimum 8 caractères. Laissez vide pour générer un mot de passe temporaire et envoyer une invitation.',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 12),

                  // Option: Send Invitation Email checkbox
                  CheckboxListTile(
                    title: const Text(
                      'Envoyer une invitation par email',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Permet à l\'utilisateur de définir son mot de passe lors de sa première connexion',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    value: _sendInvitationEmail,
                    activeColor: const Color(0xFF2563EB),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) => setState(() => _sendInvitationEmail = val ?? true),
                  ),
                  const SizedBox(height: 8),
                ],

                // Numéro de Téléphone
                Text('Numéro de Téléphone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Text('🇹🇳', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(_selectedCountryCode, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: '99 243 905',
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Role Selection
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rôle de l\'Utilisateur',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 500;
                    if (isNarrow) {
                      return Column(
                        children: [
                          _buildRoleCard(
                            roleKey: 'admin',
                            title: 'Admin',
                            subtitle: 'Accès complet',
                            isSelected: _selectedRole == 'admin',
                          ),
                          const SizedBox(height: 12),
                          _buildRoleCard(
                            roleKey: 'collaborator',
                            title: 'Collaborateur',
                            subtitle: 'Accès standard pour les employés',
                            isSelected: _selectedRole == 'collaborator',
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _buildRoleCard(
                            roleKey: 'admin',
                            title: 'Admin',
                            subtitle: 'Accès complet',
                            isSelected: _selectedRole == 'admin',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildRoleCard(
                            roleKey: 'collaborator',
                            title: 'Collaborateur',
                            subtitle: 'Accès standard pour les employés',
                            isSelected: _selectedRole == 'collaborator',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 3: Enterprise Access Checkboxes
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accès aux entreprises',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sélectionnez les entreprises auxquelles cet utilisateur aura accès',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Master Checkbox: "Accéder à toutes les entreprises"
                CheckboxListTile(
                  title: const Text(
                    'Accéder à toutes les entreprises',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Coche automatiquement toutes vos entreprises',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: _selectAllEnterprises,
                  activeColor: const Color(0xFF2563EB),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _toggleAllEnterprises,
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // List of Enterprises
                ..._ownedEnterprises.map((ent) {
                  final isSelected = _selectedEnterpriseIds.contains(ent.id);
                  final isCurrent = ent.id == EnterpriseService.instance.currentEnterpriseId;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFBFDBFE) : AppColors.border,
                      ),
                    ),
                    child: CheckboxListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ent.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Entreprise actuelle',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: ent.email != null
                          ? Text(ent.email!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)
                          : null,
                      value: isSelected,
                      activeColor: const Color(0xFF2563EB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (_) => _toggleEnterprise(ent.id),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 4: Permissions Matrix
          PermissionsMatrixWidget(
            permissions: _permissions,
            onChanged: (updated) => setState(() => _permissions = updated),
            isReadOnly: false,
          ),
          const SizedBox(height: 28),

          // Section 5: Bottom Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (!widget.isEditing) {
                        setState(() => _currentStep = 1);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Retour', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _onSaveUser,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(
                      _isSaving
                          ? 'Enregistrement...'
                          : (widget.isEditing ? 'Enregistrer' : 'Créer et ajouter'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextInput(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            filled: true,
            fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String roleKey,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onRoleChanged(roleKey),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : (AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF1E40AF) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? const Color(0xFF3B82F6) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 22)
            else
              Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textTertiary, size: 22),
          ],
        ),
      ),
    );
  }
}
