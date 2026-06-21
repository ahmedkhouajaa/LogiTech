import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import '../database/database_helper.dart';
import '../models/project.dart';
import '../services/sync_service.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  bool _isLoading = true;
  CompanySettings? _settings;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _rcNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _ribController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getCompanySettings();
    setState(() {
      _settings = settings;
      _nameController.text = settings.name;
      _phoneController.text = settings.phone ?? '';
      _emailController.text = settings.email ?? '';
      _websiteController.text = settings.website ?? '';
      _taxIdController.text = settings.taxId ?? '';
      _rcNumberController.text = settings.rcNumber ?? '';
      _addressController.text = settings.address ?? '';
      _ribController.text = settings.rib ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;
    
    final updatedSettings = _settings!.copyWith(
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      website: _websiteController.text,
      taxId: _taxIdController.text,
      rcNumber: _rcNumberController.text,
      address: _addressController.text,
      rib: _ribController.text,
    );

    await DatabaseHelper.instance.updateCompanySettings(updatedSettings);
    SyncService.instance.triggerSync();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations enregistrées avec succès'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _rcNumberController.dispose();
    _addressController.dispose();
    _ribController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Informations sur la société', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              AppButton(
                label: 'Enregistrer',
                icon: Icons.save_rounded,
                onPressed: _saveSettings,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
                    Expanded(
                      child: AppTextField(
                        label: 'Nom de votre société (Tireur)',
                        controller: _nameController,
                        hint: 'Nom de votre société',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: 'Téléphone',
                        controller: _phoneController,
                        hint: '+216 00 000 000',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Email',
                        controller: _emailController,
                        hint: 'contact@masociete.com',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: 'Site Web',
                        controller: _websiteController,
                        hint: 'www.masociete.com',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Matricule Fiscale',
                        controller: _taxIdController,
                        hint: 'MF1234567/A/B/C/000',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: 'Registre de Commerce',
                        controller: _rcNumberController,
                        hint: 'RC123456789',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Adresse de votre société',
                  controller: _addressController,
                  hint: '123 Rue Exemple, Ville, Pays',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Coordonnées bancaires (RIB)',
                  controller: _ribController,
                  hint: 'BIAT - Agence X - RIB: 08001002003004005006',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
