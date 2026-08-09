import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';
import '../database/database_helper.dart';
import '../models/project.dart';
import '../services/sync_service.dart';
import '../services/enterprise_service.dart';

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
    final currentEnt = EnterpriseService.instance.currentEnterprise;

    setState(() {
      _settings = settings;
      _nameController.text = (settings?.name != null && settings!.name.isNotEmpty) ? settings.name : (currentEnt?.name ?? '');
      _phoneController.text = settings?.phone ?? currentEnt?.phone ?? '';
      _emailController.text = settings?.email ?? currentEnt?.email ?? '';
      _websiteController.text = settings?.website ?? currentEnt?.website ?? '';
      _taxIdController.text = settings?.taxId ?? currentEnt?.taxId ?? '';
      _rcNumberController.text = settings?.rcNumber ?? currentEnt?.rcNumber ?? '';
      _addressController.text = settings?.address ?? currentEnt?.address ?? '';
      _ribController.text = settings?.rib ?? currentEnt?.rib ?? '';
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
        SnackBar(
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
      return Center(child: CircularProgressIndicator());
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    return BlocListener<EnterpriseBloc, EnterpriseState>(
      listener: (context, state) {
        if (state is EnterpriseLoaded) {
          _loadSettings();
        }
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Informations sur la société',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Enregistrer',
                  icon: Icons.save_rounded,
                  onPressed: _saveSettings,
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Informations sur la société',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                AppButton(
                  label: 'Enregistrer',
                  icon: Icons.save_rounded,
                  onPressed: _saveSettings,
                ),
              ],
            ),
          SizedBox(height: AppSpacing.lg),
          Container(
            padding: EdgeInsets.all(AppSpacing.xl),
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
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: 'Téléphone',
                        controller: _phoneController,
                        hint: '+216 00 000 000',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Email',
                        controller: _emailController,
                        hint: 'contact@masociete.com',
                      ),
                    ),
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: 'Site Web',
                        controller: _websiteController,
                        hint: 'www.masociete.com',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Matricule Fiscale',
                        controller: _taxIdController,
                        hint: 'MF1234567/A/B/C/000',
                      ),
                    ),
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: 'Registre de Commerce',
                        controller: _rcNumberController,
                        hint: 'RC123456789',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Adresse de votre société',
                  controller: _addressController,
                  hint: '123 Rue Exemple, Ville, Pays',
                ),
                SizedBox(height: AppSpacing.lg),
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
    ),
    );
  }
}
