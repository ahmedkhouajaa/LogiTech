import 'package:flutter/material.dart';
import '../models/hr_manager.dart';
import '../services/connectivity_service.dart';
import '../services/hr_manager_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';

class InviteManagerDialog extends StatefulWidget {
  final String enterpriseId;
  final HrManager? managerToEdit;
  final ValueChanged<HrManager>? onManagerSaved;

  const InviteManagerDialog({
    super.key,
    required this.enterpriseId,
    this.managerToEdit,
    this.onManagerSaved,
  });

  static Future<HrManager?> show(
    BuildContext context, {
    required String enterpriseId,
    HrManager? managerToEdit,
    ValueChanged<HrManager>? onManagerSaved,
  }) {
    return showDialog<HrManager>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InviteManagerDialog(
        enterpriseId: enterpriseId,
        managerToEdit: managerToEdit,
        onManagerSaved: onManagerSaved,
      ),
    );
  }

  @override
  State<InviteManagerDialog> createState() => _InviteManagerDialogState();
}

class _InviteManagerDialogState extends State<InviteManagerDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  late List<String> _selectedRoles;
  bool _isSaving = false;
  bool _isRolesDropdownOpen = false;
  bool _showRoleError = false;

  final List<String> _availableRoles = [
    'Administrateur',
    'Manager',
    'Responsable RH',
    'Comptable',
    'Superviseur',
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.managerToEdit;
    _lastNameCtrl = TextEditingController(text: edit?.lastName ?? '');
    _firstNameCtrl = TextEditingController(text: edit?.firstName ?? '');
    _emailCtrl = TextEditingController(text: edit?.email ?? '');
    _phoneCtrl = TextEditingController(text: edit?.phone ?? '');
    _selectedRoles = edit != null && edit.roles.isNotEmpty
        ? List<String>.from(edit.roles)
        : [];
  }

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final isValid = _formKey.currentState!.validate();
    if (_selectedRoles.isEmpty) {
      setState(() => _showRoleError = true);
    }
    if (!isValid || _selectedRoles.isEmpty) {
      if (_selectedRoles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Veuillez sélectionner au moins un rôle.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final isEdit = widget.managerToEdit != null;
    if (isEdit) {
      final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!allowed) return;
    }

    setState(() => _isSaving = true);
    try {
      final manager = HrManager(
        id: isEdit ? widget.managerToEdit!.id : '',
        enterpriseId: widget.enterpriseId,
        lastName: _lastNameCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        roles: _selectedRoles,
        isOwner: widget.managerToEdit?.isOwner ?? false,
        isActive: widget.managerToEdit?.isActive ?? true,
        createdAt: widget.managerToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEdit) {
        await HrManagerService.instance.updateManager(manager);
      } else {
        await HrManagerService.instance.inviteManager(manager);
      }

      if (mounted) {
        final isOnline = ConnectivityService.instance.isOnline;
        if (!isEdit && !isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Gestionnaire enregistré hors ligne - invitation en attente de synchronisation'),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        widget.onManagerSaved?.call(manager);
        Navigator.of(context).pop(manager);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isEdit = widget.managerToEdit != null;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: isMobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.95 : 660,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header: Back arrow & Title (Image 2) ────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 20, top: 14, bottom: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF0F172A)),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Retour',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEdit ? 'Modifier le gestionnaire' : 'Inviter un gestionnaire',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // ─── Scrollable Form Body ─────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom *
                      _buildFieldLabel('Nom', isRequired: true),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _lastNameCtrl,
                        hint: 'Khouaja',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Veuillez saisir le nom'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Prénom *
                      _buildFieldLabel('Prénom', isRequired: true),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _firstNameCtrl,
                        hint: 'Ahmed',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Veuillez saisir le prénom'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Email *
                      _buildFieldLabel('Email', isRequired: true),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _emailCtrl,
                        hint: 'ahmed.khouaja@societe.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Veuillez saisir l\'email';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Veuillez saisir un email valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Téléphone
                      _buildFieldLabel('Téléphone'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _phoneCtrl,
                        hint: '+216 XX XXX XXX',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Rôles *
                      _buildFieldLabel('Rôles', isRequired: true),
                      const SizedBox(height: 6),
                      _buildRolesSelector(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // ─── Footer Action Bar (Image 2) ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isEdit ? 'Enregistrer' : 'Inviter',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Field Label ───────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  // ─── Form TextField ────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }

  // ─── Roles Multi-Select Chips Box (Inline Dropdown) ──────────────────────
  Widget _buildRolesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isRolesDropdownOpen = !_isRolesDropdownOpen;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (_showRoleError && _selectedRoles.isEmpty)
                    ? AppColors.error
                    : (_isRolesDropdownOpen ? AppColors.primary : const Color(0xFFE2E8F0)),
                width: ((_showRoleError && _selectedRoles.isEmpty) || _isRolesDropdownOpen) ? 1.5 : 1.0,
              ),
              boxShadow: _isRolesDropdownOpen
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _selectedRoles.isEmpty
                      ? const Text(
                          'Sélectionner les rôles',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _selectedRoles.map((role) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    role,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedRoles.remove(role);
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                Icon(
                  _isRolesDropdownOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: _isRolesDropdownOpen ? AppColors.primary : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_showRoleError && _selectedRoles.isEmpty) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Veuillez sélectionner au moins un rôle',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (_isRolesDropdownOpen) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sélectionner les rôles',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isRolesDropdownOpen = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'Terminer',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ..._availableRoles.map((role) {
                  final isSelected = _selectedRoles.contains(role);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedRoles.remove(role);
                        } else {
                          _selectedRoles.add(role);
                        }
                        if (_selectedRoles.isNotEmpty) {
                          _showRoleError = false;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              role,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedRoles.add(role);
                                  } else {
                                    _selectedRoles.remove(role);
                                  }
                                  if (_selectedRoles.isNotEmpty) {
                                    _showRoleError = false;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
