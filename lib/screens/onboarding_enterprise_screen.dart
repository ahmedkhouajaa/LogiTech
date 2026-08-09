import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../utils/constants.dart';

class OnboardingEnterpriseScreen extends StatefulWidget {
  const OnboardingEnterpriseScreen({super.key});

  @override
  State<OnboardingEnterpriseScreen> createState() => _OnboardingEnterpriseScreenState();
}

class _OnboardingEnterpriseScreenState extends State<OnboardingEnterpriseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _rcController = TextEditingController();
  final _addressController = TextEditingController();
  final _ribController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _rcController.dispose();
    _addressController.dispose();
    _ribController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final website = _websiteController.text.trim();
      final taxId = _taxIdController.text.trim();
      final rc = _rcController.text.trim();
      final address = _addressController.text.trim();
      final rib = _ribController.text.trim();

      context.read<EnterpriseBloc>().add(
            CreateEnterprise(
              name,
              phone: phone.isNotEmpty ? phone : null,
              email: email.isNotEmpty ? email : null,
              website: website.isNotEmpty ? website : null,
              taxId: taxId.isNotEmpty ? taxId : null,
              rcNumber: rc.isNotEmpty ? rc : null,
              address: address.isNotEmpty ? address : null,
              rib: rib.isNotEmpty ? rib : null,
            ),
          );
    }
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool isRequired = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            filled: true,
            fillColor: AppColors.isDarkMode ? AppColors.surfaceAlt : const Color(0xFFF3F5F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          validator: isRequired
              ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 780),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.lg,
              ),
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Créer une nouvelle entreprise',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bienvenue ! Veuillez configurer votre entreprise pour accéder au tableau de bord.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (isMobile) ...[
                      _buildField('Nom de votre société (Tireur)', _nameController, hint: 'Mon Entreprise', isRequired: true),
                      const SizedBox(height: 16),
                      _buildField('Téléphone', _phoneController, hint: '27755999', keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      _buildField('Email', _emailController, hint: 'ahmed@gmail.com', keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildField('Site Web', _websiteController, hint: 'www.ahmed.com'),
                      const SizedBox(height: 16),
                      _buildField('Matricule Fiscale', _taxIdController, hint: 'MF1234567/A/B/C/000'),
                      const SizedBox(height: 16),
                      _buildField('Registre de Commerce', _rcController, hint: 'RC123456789'),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildField('Nom de votre société (Tireur)', _nameController, hint: 'Mon Entreprise', isRequired: true),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildField('Téléphone', _phoneController, hint: '27755999', keyboardType: TextInputType.phone),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField('Email', _emailController, hint: 'ahmed@gmail.com', keyboardType: TextInputType.emailAddress),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildField('Site Web', _websiteController, hint: 'www.ahmed.com'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField('Matricule Fiscale', _taxIdController, hint: 'MF1234567/A/B/C/000'),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildField('Registre de Commerce', _rcController, hint: 'RC123456789'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildField('Adresse de votre société', _addressController, hint: '123 Rue Exemple, Ville, Pays'),
                    const SizedBox(height: 20),
                    _buildField('Coordonnées bancaires (RIB)', _ribController, hint: 'BIAT - Agence X - RIB: 08001002003004005006'),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        onPressed: _isSaving ? null : _submitForm,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Créer l\'entreprise',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
