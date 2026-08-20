import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../models/enterprise.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_app_bar.dart';

class CompanyInfoScreen extends StatefulWidget {
  const CompanyInfoScreen({super.key});

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

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

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final currentEnt = EnterpriseService.instance.currentEnterprise;
      final eid = EnterpriseService.instance.currentEnterpriseId;

      String name = currentEnt?.name ?? '';
      String phone = currentEnt?.phone ?? '';
      String email = currentEnt?.email ?? '';
      String website = currentEnt?.website ?? '';
      String taxId = currentEnt?.taxId ?? '';
      String rcNumber = currentEnt?.rcNumber ?? '';
      String address = currentEnt?.address ?? '';
      String rib = currentEnt?.rib ?? '';

      // Also fetch the freshest data directly from Firestore if available
      if (eid != null && eid.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('enterprises')
              .doc(eid)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            name = data['name']?.toString() ?? name;
            phone = data['phone']?.toString() ?? phone;
            email = data['email']?.toString() ?? email;
            website = data['website']?.toString() ?? website;
            taxId = (data['tax_id'] ?? data['taxId'])?.toString() ?? taxId;
            rcNumber = (data['rc_number'] ?? data['rcNumber'])?.toString() ?? rcNumber;
            address = data['address']?.toString() ?? address;
            rib = data['rib']?.toString() ?? rib;
          }
        } catch (e) {
          debugPrint('[CompanyInfoScreen] Direct Firestore fetch error: $e');
        }
      }

      if (mounted) {
        _nameController.text = name;
        _phoneController.text = phone;
        _emailController.text = email;
        _websiteController.text = website;
        _taxIdController.text = taxId;
        _rcNumberController.text = rcNumber;
        _addressController.text = address;
        _ribController.text = rib;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[CompanyInfoScreen] Error loading company settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Le nom de la société est obligatoire.'),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final eid = EnterpriseService.instance.currentEnterpriseId;
    if (eid == null || eid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucune entreprise active sélectionnée.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentEnt = EnterpriseService.instance.currentEnterprise;
      final updatedEnterprise = (currentEnt ??
              Enterprise(
                id: eid,
                name: name,
                ownerId: '',
              ))
          .copyWith(
        id: eid,
        name: name,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        website: _websiteController.text.trim(),
        taxId: _taxIdController.text.trim(),
        rcNumber: _rcNumberController.text.trim(),
        address: _addressController.text.trim(),
        rib: _ribController.text.trim(),
        updatedAt: DateTime.now(),
      );

      // 1. Save directly to Firestore and local state via EnterpriseService
      await EnterpriseService.instance.updateEnterprise(updatedEnterprise);

      // 2. Safely notify EnterpriseBloc
      if (mounted) {
        try {
          context.read<EnterpriseBloc>().add(
                EnterprisesUpdated(
                  enterprises: List<Enterprise>.from(EnterpriseService.instance.enterprises),
                  currentEnterpriseId: updatedEnterprise.id,
                ),
              );
        } catch (e) {
          debugPrint('[CompanyInfoScreen] EnterpriseBloc notification: $e');
        }
      }

      // 3. Show success notification ONLY after actual successful Firestore write
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Informations de la société enregistrées avec succès.'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CompanyInfoScreen] Error saving company settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Erreur lors de l\'enregistrement: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
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
      return const Center(child: CircularProgressIndicator());
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    return BlocListener<EnterpriseBloc, EnterpriseState>(
      listener: (context, state) {
        if (state is EnterpriseLoaded && !_isSaving) {
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gérez les coordonnées et informations légales de votre entreprise',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Enregistrer',
                    icon: Icons.save_rounded,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveSettings,
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informations sur la société',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gérez les coordonnées et informations légales de votre entreprise',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: 'Enregistrer',
                    icon: Icons.save_rounded,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _saveSettings,
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile) ...[
                    AppTextField(
                      label: 'Nom de votre société (Tireur) *',
                      controller: _nameController,
                      hint: 'Nom de votre société',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Téléphone',
                      controller: _phoneController,
                      hint: '+216 00 000 000',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Email',
                      controller: _emailController,
                      hint: 'contact@masociete.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Site Web',
                      controller: _websiteController,
                      hint: 'www.masociete.com',
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Matricule Fiscale',
                      controller: _taxIdController,
                      hint: 'MF1234567/A/B/C/000',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Registre de Commerce',
                      controller: _rcNumberController,
                      hint: 'RC123456789',
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Nom de votre société (Tireur) *',
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
                            keyboardType: TextInputType.phone,
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
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: AppTextField(
                            label: 'Site Web',
                            controller: _websiteController,
                            hint: 'www.masociete.com',
                            keyboardType: TextInputType.url,
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
                  ],
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
      ),
    );
  }
}
