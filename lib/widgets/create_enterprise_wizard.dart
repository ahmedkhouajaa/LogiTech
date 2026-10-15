import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../services/enterprise_service.dart';
import '../support_admin/services/promo_code_service.dart';
import '../services/permission_service.dart';
import '../utils/constants.dart';
import '../utils/company_logo_helper.dart';

/// Clean, professional 3-Step Wizard for Creating a New Enterprise
/// (Dialog inside the app or Full-Screen Onboarding on first login).
class CreateEnterpriseWizard extends StatefulWidget {
  final bool isDismissible;
  final bool isOnboarding;
  final VoidCallback? onCancel;
  final VoidCallback? onSuccess;

  const CreateEnterpriseWizard({
    super.key,
    this.isDismissible = true,
    this.isOnboarding = false,
    this.onCancel,
    this.onSuccess,
  });

  @override
  State<CreateEnterpriseWizard> createState() => _CreateEnterpriseWizardState();
}

class _CreateEnterpriseWizardState extends State<CreateEnterpriseWizard> {
  int _currentStep = 0;
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _rcController = TextEditingController();
  final _addressController = TextEditingController();
  final _ribController = TextEditingController();
  final _partnerCodeController = TextEditingController();

  bool _hasPartnerCode = false;
  bool _hasExistingPartnerCode = false;
  String? _existingPartnerCode;
  String? _validatedPromoBenefit;

  bool _isSubmitting = false;
  String? _logoBase64;
  bool _isPickingLogo = false;

  bool get _isFirstEnterpriseOnboarding =>
      widget.isOnboarding && EnterpriseService.instance.enterprises.isEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.isOnboarding) {
      _checkExistingPartnerCode();
    }
  }

  Future<void> _checkExistingPartnerCode() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && mounted) {
          final code = doc.data()?['partnerCode']?.toString();
          final benefit = doc.data()?['promoBenefit']?.toString();
          if (code != null && code.trim().isNotEmpty) {
            setState(() {
              _hasExistingPartnerCode = true;
              _existingPartnerCode = code.trim().toUpperCase();
              _validatedPromoBenefit = benefit;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _onPromoCodeChanged(String val) async {
    final clean = val.trim().toUpperCase();
    if (clean.isEmpty) {
      if (mounted) setState(() => _validatedPromoBenefit = null);
      return;
    }
    final res = await PromoCodeService.instance.validatePromoCode(clean);
    if (mounted) {
      setState(() {
        if (res.isValid && res.isPredefinedPromo) {
          _validatedPromoBenefit = res.benefitSummary;
        } else {
          _validatedPromoBenefit = null;
        }
      });
    }
  }

  Future<void> _pickLogo() async {
    setState(() => _isPickingLogo = true);
    try {
      final logo = await CompanyLogoHelper.pickAndProcessLogo(context: context);
      if (logo != null && mounted) {
        setState(() => _logoBase64 = logo);
      }
    } finally {
      if (mounted) setState(() => _isPickingLogo = false);
    }
  }

  void _removeLogo() {
    setState(() => _logoBase64 = null);
  }

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
    _partnerCodeController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (_currentStep == 0) {
      if (_step1Key.currentState?.validate() ?? false) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      if (_step2Key.currentState?.validate() ?? false) {
        setState(() => _currentStep = 2);
      }
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep = _currentStep - 1);
    }
  }

  void _submitForm() {
    if (_isSubmitting) return;

    if (!widget.isOnboarding &&
        !PermissionService.instance.isAdmin &&
        EnterpriseService.instance.enterprises.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Action réservée aux administrateurs'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_step3Key.currentState?.validate() ?? true) {
      setState(() => _isSubmitting = true);

      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final website = _websiteController.text.trim();
      final taxId = _taxIdController.text.trim();
      final rc = _rcController.text.trim();
      final address = _addressController.text.trim();
      final rib = _ribController.text.trim();

      if (!widget.isOnboarding && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final String? partnerCodeToSubmit = _hasExistingPartnerCode
          ? _existingPartnerCode
          : (_hasPartnerCode && _partnerCodeController.text.trim().isNotEmpty
              ? _partnerCodeController.text.trim().toUpperCase()
              : null);

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
              logoUrl: _logoBase64,
              partnerCode: partnerCodeToSubmit,
            ),
          );

      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 640;

    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 90 : 25),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───────────────────────────────────────────────
              _buildHeader(isDark, isMobile, borderColor),

              // ─── Stepper ──────────────────────────────────────────────
              _buildStepper(isDark, isMobile, borderColor),

              // ─── Step Content ─────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 18 : 26,
                    vertical: 20,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildCurrentStepContent(isDark, isMobile),
                  ),
                ),
              ),

              // ─── Footer ───────────────────────────────────────────────
              _buildFooter(isDark, isMobile, borderColor),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, bool isMobile, Color borderColor) {
    final title = widget.isOnboarding
        ? 'Créer votre entreprise'
        : 'Nouvelle entreprise';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(isDark ? 40 : 20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withAlpha(isDark ? 70 : 35),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.business_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Renseignez les informations de votre structure commerciale.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isDismissible && !widget.isOnboarding)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              tooltip: 'Fermer',
              splashRadius: 20,
              onPressed: () {
                if (widget.onCancel != null) {
                  widget.onCancel!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
    );
  }

  // ─── Stepper ────────────────────────────────────────────────────────

  Widget _buildStepper(bool isDark, bool isMobile, Color borderColor) {
    final stepLabels = ['Société', 'Légal & Fiscal', 'Banque & Récap'];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = _currentStep > index;
          final isActive = _currentStep == index;

          Color barColor;
          if (isCompleted) {
            barColor = const Color(0xFF10B981);
          } else if (isActive) {
            barColor = AppColors.primary;
          } else {
            barColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
          }

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < 2 ? 8.0 : 0.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (isCompleted) ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          isMobile
                              ? '${index + 1}. ${stepLabels[index]}'
                              : 'Étape ${index + 1} • ${stepLabels[index]}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : (isCompleted ? FontWeight.w600 : FontWeight.w500),
                            color: isActive
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : (isCompleted
                                    ? const Color(0xFF10B981)
                                    : (isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8))),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Current Step Content ────────────────────────────────────────────

  Widget _buildCurrentStepContent(bool isDark, bool isMobile) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(isDark, isMobile);
      case 1:
        return _buildStep2(isDark, isMobile);
      case 2:
        return _buildStep3(isDark, isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Informations de la société ──────────────────────────────

  Widget _buildStep1(bool isDark, bool isMobile) {
    return Form(
      key: _step1Key,
      child: Column(
        key: const ValueKey(0),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogoPickerSection(isDark, isMobile),
          const SizedBox(height: 14),
          _buildFormField(
            label: 'Nom de votre société (Raison sociale)',
            controller: _nameController,
            hint: 'Ex: LogiTech Solutions',
            icon: Icons.business_rounded,
            isRequired: true,
            isDark: isDark,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Le nom de votre société est obligatoire.';
              }
              if (v.trim().length < 2) {
                return 'Le nom doit contenir au moins 2 caractères.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          if (isMobile) ...[
            _buildFormField(
              label: 'Numéro de téléphone',
              controller: _phoneController,
              hint: 'Ex: 27 755 999',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _buildFormField(
              label: 'Adresse email',
              controller: _emailController,
              hint: 'Ex: contact@masociete.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              isDark: isDark,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Adresse email invalide.';
                  }
                }
                return null;
              },
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'Numéro de téléphone',
                    controller: _phoneController,
                    hint: 'Ex: 27 755 999',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildFormField(
                    label: 'Adresse email',
                    controller: _emailController,
                    hint: 'Ex: contact@masociete.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    isDark: isDark,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(v.trim())) {
                          return 'Adresse email invalide.';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _buildFormField(
            label: 'Site Web (optionnel)',
            controller: _websiteController,
            hint: 'Ex: www.masociete.com',
            icon: Icons.language_rounded,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Identifiants légaux & fiscalité ─────────────────────────

  Widget _buildStep2(bool isDark, bool isMobile) {
    return Form(
      key: _step2Key,
      child: Column(
        key: const ValueKey(1),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 15,
                color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ces mentions figureront automatiquement sur vos factures et devis.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            _buildFormField(
              label: 'Matricule Fiscale',
              controller: _taxIdController,
              hint: 'Ex: 1234567/A/B/C/000',
              icon: Icons.receipt_long_outlined,
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _buildFormField(
              label: 'Registre de Commerce (RC)',
              controller: _rcController,
              hint: 'Ex: RC123456789',
              icon: Icons.badge_outlined,
              isDark: isDark,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'Matricule Fiscale',
                    controller: _taxIdController,
                    hint: 'Ex: 1234567/A/B/C/000',
                    icon: Icons.receipt_long_outlined,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildFormField(
                    label: 'Registre de Commerce (RC)',
                    controller: _rcController,
                    hint: 'Ex: RC123456789',
                    icon: Icons.badge_outlined,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _buildFormField(
            label: 'Adresse du siège social',
            controller: _addressController,
            hint: 'Ex: 123 Rue de la République, Tunis, Tunisie',
            icon: Icons.location_on_outlined,
            maxLines: 2,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Coordonnées bancaires & Finalisation ────────────────────

  Widget _buildStep3(bool isDark, bool isMobile) {
    return Form(
      key: _step3Key,
      child: Column(
        key: const ValueKey(2),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField(
            label: 'Coordonnées bancaires (RIB)',
            controller: _ribController,
            hint: 'Ex: BIAT - Agence X - RIB: 08001002003004005006',
            icon: Icons.credit_card_outlined,
            isDark: isDark,
          ),
          if (_isFirstEnterpriseOnboarding) ...[
            const SizedBox(height: 16),
            _buildPartnerCodeSection(isDark, isMobile),
          ],
          const SizedBox(height: 18),
          _buildSummaryPreview(isDark, isMobile),
        ],
      ),
    );
  }

  // ─── Summary Preview ────────────────────────────────────────────────

  Widget _buildSummaryPreview(bool isDark, bool isMobile) {
    final companyName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Mon Entreprise';
    final initialLetter = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'E';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    initialLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Organisation LogiTech prête à être initialisée',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF10B981).withAlpha(isDark ? 80 : 50),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Prêt',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 10),
          _buildCompactRecapRow('Téléphone', _phoneController.text.trim(), isDark),
          _buildCompactRecapRow('Matricule Fiscale', _taxIdController.text.trim(), isDark),
          _buildCompactRecapRow('RIB', _ribController.text.trim(), isDark),
        ],
      ),
    );
  }

  Widget _buildCompactRecapRow(String label, String value, bool isDark) {
    final hasVal = value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasVal ? value : 'Non renseigné',
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasVal ? FontWeight.w600 : FontWeight.w400,
                color: hasVal
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                fontStyle: hasVal ? FontStyle.normal : FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerCodeSection(bool isDark, bool isMobile) {
    if (_hasExistingPartnerCode && _existingPartnerCode != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withAlpha(isDark ? 30 : 15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF10B981).withAlpha(isDark ? 70 : 40),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
            const SizedBox(width: 8),
            Text(
              'Code partenaire appliqué : $_existingPartnerCode',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 16,
                    color: _hasPartnerCode
                        ? AppColors.primary
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "J'ai un code promo / partenaire",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _hasPartnerCode ? FontWeight.w600 : FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: _hasPartnerCode,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  setState(() {
                    _hasPartnerCode = val;
                    if (!val) {
                      _partnerCodeController.clear();
                    }
                  });
                },
              ),
            ],
          ),
          if (_hasPartnerCode) ...[
            const SizedBox(height: 8),
            _buildFormField(
              label: 'Code promo',
              controller: _partnerCodeController,
              hint: 'Entrez votre code partenaire',
              icon: Icons.local_offer_outlined,
              isDark: isDark,
              onChanged: _onPromoCodeChanged,
            ),
            if (_validatedPromoBenefit != null && _validatedPromoBenefit!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Avantage : $_validatedPromoBenefit',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── Logo Picker Section ────────────────────────────────────────────

  Widget _buildLogoPickerSection(bool isDark, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _isPickingLogo
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    )
                  : (_logoBase64 != null
                      ? CompanyLogoHelper.buildLogoWidget(
                          logoUrl: _logoBase64,
                          fit: BoxFit.contain,
                        )
                      : Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 24,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Logo de l\'entreprise',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _logoBase64 != null ? 'Importé' : 'Optionnel',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _logoBase64 != null
                              ? const Color(0xFF10B981)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Format PNG ou JPG. Utilisé sur vos devis et factures.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: _isPickingLogo ? null : _pickLogo,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.upload_file_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _logoBase64 != null ? 'Changer' : 'Choisir un logo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_logoBase64 != null) ...[
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _removeLogo,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Text(
                            'Supprimer',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Input Field Builder ────────────────────────────────────────────

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon,
              size: 17,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
          validator: validator ??
              (isRequired
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
                  : null),
        ),
      ],
    );
  }

  // ─── Footer Navigation ───────────────────────────────────────────────

  Widget _buildFooter(bool isDark, bool isMobile, Color borderColor) {
    final isLastStep = _currentStep == 2;
    final isFirstStep = _currentStep == 0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 24,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Action (Annuler / Précédent)
          if (!isFirstStep)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                side: BorderSide(color: borderColor, width: 1),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 18,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: _goToPreviousStep,
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: const Text(
                'Précédent',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            )
          else if (widget.isDismissible && !widget.isOnboarding)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              ),
              onPressed: () {
                if (widget.onCancel != null) {
                  widget.onCancel!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Annuler',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            )
          else
            const SizedBox.shrink(),

          // Right Action (Continuer / Créer l'entreprise)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 18 : 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: _isSubmitting
                ? null
                : (isLastStep ? _submitForm : _goToNextStep),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLastStep ? 'Créer l\'entreprise' : 'Continuer',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isLastStep
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 15,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
