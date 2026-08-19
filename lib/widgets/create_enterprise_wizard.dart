import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../utils/constants.dart';

/// 3-Step Wizard for Creating a New Enterprise (Dialog or Full-Screen Onboarding).
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

  bool _isSubmitting = false;

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

      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isMobile),
          _buildProgressStepper(isMobile),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 18 : 28,
                vertical: 20,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _buildCurrentStepContent(isMobile),
              ),
            ),
          ),
          _buildFooter(isMobile),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 18 : 28,
        isMobile ? 18 : 24,
        isMobile ? 14 : 20,
        14,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.business_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isOnboarding
                      ? 'Créer votre entreprise'
                      : 'Créer une nouvelle entreprise',
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getStepSubtitle(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isDismissible && !widget.isOnboarding)
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.textTertiary),
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

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Étape 1/3 • Informations de la société';
      case 1:
        return 'Étape 2/3 • Identifiants légaux & fiscalité';
      case 2:
        return 'Étape 3/3 • Coordonnées bancaires & Validation';
      default:
        return '';
    }
  }

  // ─── Progress Stepper ────────────────────────────────────────────────

  Widget _buildProgressStepper(bool isMobile) {
    final steps = [
      {'title': 'Société', 'icon': Icons.storefront_rounded},
      {'title': 'Légal', 'icon': Icons.badge_rounded},
      {'title': 'Banque & Récap', 'icon': Icons.verified_rounded},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 18 : 28, vertical: 8),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepBefore = index ~/ 2;
                final isDone = _currentStep > stepBefore;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.primary
                          : AppColors.border.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }

              final stepIndex = index ~/ 2;
              final isActive = _currentStep == stepIndex;
              final isCompleted = _currentStep > stepIndex;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : isCompleted
                              ? AppColors.success
                              : (AppColors.isDarkMode
                                  ? AppColors.surfaceAlt
                                  : const Color(0xFFE2E8F0)),
                      shape: BoxShape.circle,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : Text(
                              '${stepIndex + 1}',
                              style: TextStyle(
                                color: (isActive || isCompleted)
                                    ? Colors.white
                                    : AppColors.textTertiary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      steps[stepIndex]['title'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive
                            ? AppColors.primary
                            : isCompleted
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3.0,
              backgroundColor: AppColors.isDarkMode
                  ? AppColors.surfaceAlt
                  : const Color(0xFFEEF2F6),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Current Step Content ────────────────────────────────────────────

  Widget _buildCurrentStepContent(bool isMobile) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(isMobile);
      case 1:
        return _buildStep2(isMobile);
      case 2:
        return _buildStep3(isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Informations de la société ──────────────────────────────

  Widget _buildStep1(bool isMobile) {
    return Form(
      key: _step1Key,
      child: Column(
        key: const ValueKey(0),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'Informations générales',
            description: 'Renseignez le nom et les coordonnées de contact de votre société.',
          ),
          const SizedBox(height: 18),
          _buildFormField(
            label: 'Nom de votre société (Tireur)',
            controller: _nameController,
            hint: 'Ex: LogiTech Solutions',
            icon: Icons.business_rounded,
            isRequired: true,
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
          const SizedBox(height: 16),
          if (isMobile) ...[
            _buildFormField(
              label: 'Numéro de téléphone',
              controller: _phoneController,
              hint: 'Ex: 27 755 999',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              label: 'Adresse Email',
              controller: _emailController,
              hint: 'Ex: contact@masociete.com',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return 'Veuillez saisir une adresse email valide.';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildFormField(
              label: 'Site Web (optionnel)',
              controller: _websiteController,
              hint: 'Ex: www.masociete.com',
              icon: Icons.language_rounded,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'Numéro de téléphone',
                    controller: _phoneController,
                    hint: 'Ex: 27 755 999',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    label: 'Adresse Email',
                    controller: _emailController,
                    hint: 'Ex: contact@masociete.com',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
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
            const SizedBox(height: 16),
            _buildFormField(
              label: 'Site Web (optionnel)',
              controller: _websiteController,
              hint: 'Ex: www.masociete.com',
              icon: Icons.language_rounded,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Step 2: Identifiants légaux ────────────────────────────────────

  Widget _buildStep2(bool isMobile) {
    return Form(
      key: _step2Key,
      child: Column(
        key: const ValueKey(1),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.gavel_rounded,
            title: 'Identifiants fiscaux & juridiques',
            description: 'Ces mentions figureront sur vos factures et bons officiels.',
          ),
          const SizedBox(height: 18),
          if (isMobile) ...[
            _buildFormField(
              label: 'Matricule Fiscale',
              controller: _taxIdController,
              hint: 'Ex: 1234567/A/B/C/000',
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              label: 'Registre de Commerce (RC)',
              controller: _rcController,
              hint: 'Ex: RC123456789',
              icon: Icons.badge_rounded,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildFormField(
                    label: 'Matricule Fiscale',
                    controller: _taxIdController,
                    hint: 'Ex: 1234567/A/B/C/000',
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    label: 'Registre de Commerce (RC)',
                    controller: _rcController,
                    hint: 'Ex: RC123456789',
                    icon: Icons.badge_rounded,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Adresse de votre société',
            controller: _addressController,
            hint: 'Ex: 123 Rue de la République, Tunis, Tunisie',
            icon: Icons.location_on_rounded,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Coordonnées bancaires & Récapitulatif ──────────────────

  Widget _buildStep3(bool isMobile) {
    return Form(
      key: _step3Key,
      child: Column(
        key: const ValueKey(2),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.account_balance_rounded,
            title: 'Coordonnées bancaires',
            description: 'Indiquez le RIB de l\'entreprise pour les règlements clients.',
          ),
          const SizedBox(height: 18),
          _buildFormField(
            label: 'Coordonnées bancaires (RIB)',
            controller: _ribController,
            hint: 'Ex: BIAT - Agence X - RIB: 08001002003004005006',
            icon: Icons.credit_card_rounded,
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(isMobile),
        ],
      ),
    );
  }

  // ─── Summary Card ───────────────────────────────────────────────────

  Widget _buildSummaryCard(bool isMobile) {
    final companyName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Mon Entreprise';
    final initialLetter = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'E';

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode
            ? AppColors.surfaceAlt.withValues(alpha: 0.6)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    initialLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Prêt pour création',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.phone_rounded,
            label: 'Téléphone',
            value: _phoneController.text.trim(),
          ),
          _buildSummaryRow(
            icon: Icons.email_rounded,
            label: 'Email',
            value: _emailController.text.trim(),
          ),
          _buildSummaryRow(
            icon: Icons.language_rounded,
            label: 'Site Web',
            value: _websiteController.text.trim(),
          ),
          _buildSummaryRow(
            icon: Icons.receipt_long_rounded,
            label: 'Matricule Fiscale',
            value: _taxIdController.text.trim(),
          ),
          _buildSummaryRow(
            icon: Icons.badge_rounded,
            label: 'RC',
            value: _rcController.text.trim(),
          ),
          _buildSummaryRow(
            icon: Icons.location_on_rounded,
            label: 'Adresse',
            value: _addressController.text.trim(),
          ),
          _buildSummaryRow(
            icon: Icons.credit_card_rounded,
            label: 'RIB',
            value: _ribController.text.trim(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final hasValue = value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasValue ? value : 'Non renseigné',
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                color: hasValue ? AppColors.textPrimary : AppColors.textTertiary,
                fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.isDarkMode
                ? AppColors.surfaceAlt
                : const Color(0xFFF3F5F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
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

  Widget _buildFooter(bool isMobile) {
    final isLastStep = _currentStep == 2;
    final isFirstStep = _currentStep == 0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 28,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.isDarkMode
            ? AppColors.surface.withValues(alpha: 0.95)
            : const Color(0xFFFAFCFF),
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Action (Cancel on Step 1, Back on Step 2/3)
          if (!isFirstStep)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 20,
                  vertical: 12,
                ),
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _goToPreviousStep,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          else if (widget.isDismissible && !widget.isOnboarding)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 20,
                  vertical: 12,
                ),
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (widget.onCancel != null) {
                  widget.onCancel!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          else
            const SizedBox.shrink(),

          // Right Action (Next on Step 1/2, Create on Step 3)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 18 : 26,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _isSubmitting
                ? null
                : (isLastStep ? _submitForm : _goToNextStep),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLastStep ? 'Créer l\'entreprise' : 'Suivant',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                        size: 16,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
