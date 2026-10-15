import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/electronic_invoice_config.dart';
import '../services/electronic_invoice_service.dart';
import '../services/enterprise_service.dart';
import '../utils/constants.dart';
import '../widgets/sidebar_menu.dart';
import '../services/app_navigation_service.dart';
import '../l10n/app_localizations.dart';
import 'electronic_invoice_guide_screen.dart';
import '../services/electronic_invoice_guide_pdf_service.dart';
import '../utils/guide_pdf_opener/guide_pdf_opener.dart';

class ElectronicInvoiceScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ElectronicInvoiceScreen({super.key, this.onBack});

  @override
  State<ElectronicInvoiceScreen> createState() => _ElectronicInvoiceScreenState();
}

class _ElectronicInvoiceScreenState extends State<ElectronicInvoiceScreen> {
  final ElectronicInvoiceService _service = ElectronicInvoiceService.instance;

  @override
  void initState() {
    super.initState();
    _service.loadConfig();
  }

  Future<void> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[ElectronicInvoiceScreen] Error opening URL: $e');
    }
  }

  void _showActivationDialog(ElectronicInvoiceConfig current) {
    final enterprise = EnterpriseService.instance.currentEnterprise;
    final matriculeController = TextEditingController(
      text: current.matriculeFiscal.isNotEmpty
          ? current.matriculeFiscal
          : (enterprise?.taxId ?? ''),
    );
    final ttnCodeController = TextEditingController(text: current.ttnMemberCode);
    final taxCodeController = TextEditingController(text: current.taxCode);

    String selectedEnv = current.environment;
    String selectedSig = current.signatureType;
    bool autoXml = current.autoGenerateXml;
    bool showQr = current.showQrCode;
    bool autoEmail = current.autoSendEmail;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      current.isActive
                          ? context.tr('Paramètres Facture Électronique TTN')
                          : context.tr('Activer la Facturation Électronique'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  context.tr('Vos identifiants officiels TTN (Tunisie Trade Net) et Tuntrust garantissent la validité fiscale de vos factures.'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF166534),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Matricule Fiscal
                        Text(
                          '${context.tr('Matricule Fiscal de l\'entreprise')} *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: matriculeController,
                          style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Ex: 1234567A/M/000',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? context.tr('Veuillez renseigner le matricule fiscal')
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Code Adhérent TTN
                        Text(
                          '${context.tr('Code Adhérent TTN / Identifiant')} *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: ttnCodeController,
                          style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Ex: TTN-2026-98421',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? context.tr('Veuillez renseigner le code adhérent TTN')
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Environnement (Sandbox vs Production)
                        Text(
                          context.tr('Environnement'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => selectedEnv = 'sandbox'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedEnv == 'sandbox'
                                        ? AppColors.primary.withValues(alpha: 0.12)
                                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedEnv == 'sandbox'
                                          ? AppColors.primary
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      width: selectedEnv == 'sandbox' ? 1.5 : 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    context.tr('Sandbox (Test)'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: selectedEnv == 'sandbox'
                                          ? AppColors.primary
                                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => selectedEnv = 'production'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedEnv == 'production'
                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedEnv == 'production'
                                          ? const Color(0xFF10B981)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      width: selectedEnv == 'production' ? 1.5 : 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    context.tr('Production (Réel)'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: selectedEnv == 'production'
                                          ? const Color(0xFF10B981)
                                          : (isDark ? Colors.white70 : AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Signature Type
                        Text(
                          context.tr('Certificat & Signature Électronique'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedSig,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: [
                                DropdownMenuItem(
                                  value: 'digigo',
                                  child: Text(context.tr('Tuntrust Digigo (Cloud Certifié)'), style: const TextStyle(fontSize: 13)),
                                ),
                                DropdownMenuItem(
                                  value: 'token_usb',
                                  child: Text(context.tr('Clé USB Cryptographique ANCE'), style: const TextStyle(fontSize: 13)),
                                ),
                                DropdownMenuItem(
                                  value: 'software',
                                  child: Text(context.tr('Certificat Logiciel (.p12 / .pfx)'), style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setModalState(() => selectedSig = v);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Options Checkboxes
                        SwitchListTile(
                          value: autoXml,
                          onChanged: (v) => setModalState(() => autoXml = v),
                          title: Text(context.tr('Générer le fichier XML TEF homologué'), style: const TextStyle(fontSize: 13)),
                          subtitle: Text(context.tr('Création instantanée pour échange EDI TTN'), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppColors.textSecondary)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeTrackColor: AppColors.primary,
                        ),
                        SwitchListTile(
                          value: showQr,
                          onChanged: (v) => setModalState(() => showQr = v),
                          title: Text(context.tr('Afficher le QR Code fiscal El-Fatoora'), style: const TextStyle(fontSize: 13)),
                          subtitle: Text(context.tr('Empreinte fiscale vérifiable par scan'), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppColors.textSecondary)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeTrackColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.tr('Annuler'), style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final messenger = ScaffoldMessenger.of(context);
                      final successText = context.tr('Facturation électronique configurée et activée avec succès !');
                      await _service.activateEInvoicing(
                        ttnMemberCode: ttnCodeController.text,
                        matriculeFiscal: matriculeController.text,
                        taxCode: taxCodeController.text,
                        environment: selectedEnv,
                        signatureType: selectedSig,
                        autoGenerateXml: autoXml,
                        showQrCode: showQr,
                        autoSendEmail: autoEmail,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(successText),
                              ],
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    current.isActive ? context.tr('Mettre à jour') : context.tr('Activer maintenant'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTuntrustInfoDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('Signature Électronique Tuntrust'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('L\'Agence Nationale de Certification Électronique (Tuntrust) est l\'autorité officielle en Tunisie délivrant les certificats de signature numérique reconnus par l\'État.'),
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildInfoBullet('Digigo (Cloud) : signature mobile simple sans token USB.'),
                    const SizedBox(height: 6),
                    _buildInfoBullet('Token USB cryptographique physique pour postes fixes.'),
                    const SizedBox(height: 6),
                    _buildInfoBullet('Conforme aux standards eIDAS & législation tunisienne.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Fermer')),
          ),
          ElevatedButton.icon(
            onPressed: () => _openExternalUrl('https://www.tuntrust.tn'),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: Text(context.tr('Visiter Tuntrust.tn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTtnInfoDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hub_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('Adhésion TTN (Tunisie Trade Net)'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Tunisie Trade Net gère la plateforme nationale de télé-facturation (El Fatoora). L\'adhésion vous attribue un code émetteur officiel pour télé-transmettre vos factures signées.'),
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildInfoBullet('Télécharger le formulaire officiel d\'adhésion TTN.'),
                    const SizedBox(height: 6),
                    _buildInfoBullet('Fournir votre Matricule Fiscal et pièce d\'identité du gérant.'),
                    const SizedBox(height: 6),
                    _buildInfoBullet('Recevez votre code adhérent et activez-le sur LogiTech.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Fermer')),
          ),
          ElevatedButton.icon(
            onPressed: () => _openExternalUrl('https://www.tradenet.com.tn'),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: Text(context.tr('Portail TTN.com.tn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(text),
            style: const TextStyle(fontSize: 12, height: 1.3),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<ElectronicInvoiceConfig>(
      valueListenable: _service.configNotifier,
      builder: (context, config, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 900;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 36,
                  vertical: isMobile ? 16 : 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Bar
                        _buildTopHeader(isDark, config, isMobile),
                        const SizedBox(height: 24),

                        // Main Content (Hero on Left + 3 Step Cards on Right)
                        if (isMobile) ...[
                          _buildHeroSection(isDark, config, isMobile),
                          const SizedBox(height: 24),
                          _buildStepCardsList(isDark, config, isMobile),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Hero section (55% width)
                              Expanded(
                                flex: 11,
                                child: _buildHeroSection(isDark, config, isMobile),
                              ),
                              const SizedBox(width: 32),
                              // Right: 3 Step Cards (45% width)
                              Expanded(
                                flex: 9,
                                child: _buildStepCardsList(isDark, config, isMobile),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Guide elFatoora & Facture Électronique Card
                        _buildGuideBannerCard(isDark, isMobile),

                        const SizedBox(height: 32),

                        // Modèles d'emails TTN (Prêts à l'emploi avec copie en 1 clic)
                        _buildEmailTemplatesSection(isDark, isMobile),

                        const SizedBox(height: 36),

                        // FAQ / Information Section
                        _buildFaqSection(isDark, isMobile),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─── TOP HEADER ────────────────────────────────────────────────────────────
  Widget _buildTopHeader(bool isDark, ElectronicInvoiceConfig config, bool isMobile) {
    return Row(
      children: [
        if (widget.onBack != null) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: widget.onBack,
            tooltip: context.tr('Retour'),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Facture électronique'),
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('Télé-transmission sécurisée, raccordement TTN et signature numérique Tuntrust'),
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: config.isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: config.isActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: config.isActive ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                config.isActive
                    ? '${context.tr('Actif')} (${config.isProduction ? 'Production' : 'Test'})'
                    : context.tr('Non activé'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: config.isActive
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── HERO SECTION (LEFT) ───────────────────────────────────────────────────
  Widget _buildHeroSection(bool isDark, ElectronicInvoiceConfig config, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pill Tag: "La facture électronique est disponible sur LogiTech."
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0369A1).withValues(alpha: 0.15) : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.5) : const Color(0xFFBAE6FD),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.electric_bolt_rounded,
                  size: 15,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('La facture électronique est disponible sur LogiTech.'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Headline: "Facturez en toute Tranquillité"
          Text(
            context.tr('Facturez en toute\nTranquillité'),
            style: TextStyle(
              fontSize: isMobile ? 28 : 38,
              fontWeight: FontWeight.w900,
              height: 1.15,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle paragraph
          Text(
            context.tr('La facture électronique fait désormais partie du quotidien. Avec LogiTech, vous êtes accompagné pas à pas pour facturer en toute sécurité, sans changer vos habitudes et en restant protégé.'),
            style: TextStyle(
              fontSize: isMobile ? 14 : 15.5,
              height: 1.55,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 24),

          // Benefits checks
          _buildBenefitItem(isDark, Icons.verified_user_rounded, 'Conforme à 100% à la législation fiscale tunisienne (Loi de Finances).'),
          const SizedBox(height: 10),
          _buildBenefitItem(isDark, Icons.sync_rounded, 'Génération instantanée du flux XML TEF et télé-transmission TTN.'),
          const SizedBox(height: 10),
          _buildBenefitItem(isDark, Icons.qr_code_2_rounded, 'QR Code de vérification fiscale et archivage probant légal 10 ans.'),
          const SizedBox(height: 28),

          // Primary CTA Button: "Activer la facturation électronique →"
          SizedBox(
            width: isMobile ? double.infinity : null,
            child: ElevatedButton.icon(
              onPressed: () => _showActivationDialog(config),
              icon: Icon(
                config.isActive ? Icons.settings_suggest_rounded : Icons.check_circle_outline_rounded,
                size: 20,
              ),
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.isActive
                          ? context.tr('Gérer la facturation électronique')
                          : context.tr('Activer la facturation électronique'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Subtext note under button
          Text(
            context.tr('L\'obtention de la signature électronique et la demande d\'adhésion à la TTN peuvent être réalisées simultanément.'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(bool isDark, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF10B981)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.tr(text),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // ─── STEP CARDS (RIGHT SIDE) ───────────────────────────────────────────────
  Widget _buildStepCardsList(bool isDark, ElectronicInvoiceConfig config, bool isMobile) {
    return Column(
      children: [
        // Step 01: Tuntrust
        _buildStepCard(
          stepNumber: '01',
          title: 'Obtenir la signature électronique',
          subtitle: 'Certificat électronique délivré par l\'ANCE / Tuntrust pour authentifier légalement vos factures.',
          brandLabel: 'tuntrust',
          brandColor: const Color(0xFF10B981),
          brandIcon: Icons.fingerprint_rounded,
          iconData: Icons.draw_rounded,
          iconBgColor: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          isDark: isDark,
          onTap: _showTuntrustInfoDialog,
        ),
        const SizedBox(height: 16),

        // Step 02: TTN
        _buildStepCard(
          stepNumber: '02',
          title: 'Soumettre une demande d\'adhésion TTN',
          subtitle: 'Raccordement au réseau de télé-facturation TTN (Tunisie Trade Net) pour l\'échange EDI et El Fatoora.',
          brandLabel: 'T.T.N',
          brandColor: const Color(0xFFEF4444),
          brandIcon: Icons.language_rounded,
          iconData: Icons.cloud_upload_rounded,
          iconBgColor: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          isDark: isDark,
          onTap: _showTtnInfoDialog,
        ),
        const SizedBox(height: 16),

        // Step 03: LogiTech
        _buildStepCard(
          stepNumber: '03',
          title: 'Créer et générer la facture électroniquement via LogiTech',
          subtitle: 'Émission automatique au format XML TEF signé, QR Code de contrôle fiscal et archivage certifié 10 ans.',
          brandLabel: 'LogiTech',
          brandColor: const Color(0xFF0284C7),
          brandIcon: Icons.all_inclusive_rounded,
          iconData: Icons.qr_code_rounded,
          iconBgColor: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          isDark: isDark,
          onTap: () {
            AppNavigationService.instance.navigateToModule(context, AppModule.documentTemplates);
          },
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String subtitle,
    required String brandLabel,
    required Color brandColor,
    required IconData brandIcon,
    required IconData iconData,
    required Color iconBgColor,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step illustration with large badge & icon
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Large watermark step number
                    Text(
                      stepNumber,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                        height: 1,
                      ),
                    ),
                    // Icon container
                    Container(
                      margin: const EdgeInsets.only(top: 8, left: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? iconColor.withValues(alpha: 0.3) : const Color(0xFFBAE6FD),
                        ),
                      ),
                      child: Icon(iconData, color: iconColor, size: 26),
                    ),
                  ],
                ),
                const SizedBox(width: 18),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Partner / Authority brand indicator (Tuntrust / TTN / LogiTech)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: brandColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(brandIcon, size: 12, color: brandColor),
                                const SizedBox(width: 5),
                                Text(
                                  brandLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: brandColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: isDark ? Colors.white24 : AppColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Step Title
                      Text(
                        context.tr(title),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Step Subtitle
                      Text(
                        context.tr(subtitle),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── FAQ SECTION ───────────────────────────────────────────────────────────
  Widget _buildFaqSection(bool isDark, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                context.tr('Foire aux questions & Réglementation El Fatoora'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFaqTile(
            isDark: isDark,
            question: 'Qu\'est-ce que la facture électronique (El Fatoora) en Tunisie ?',
            answer: 'La facture électronique est un document fiscal émis, transmis et archivé sous forme numérique normée (format XML TEF). Elle contient une signature électronique qualifiée délivrée par Tuntrust et transite obligatoirement par le réseau sécurisé de Tunisie Trade Net (TTN).',
          ),
          _buildFaqTile(
            isDark: isDark,
            question: 'La facture électronique est-elle obligatoire ?',
            answer: 'Oui, elle est rendue obligatoire progressivement par la législation tunisienne pour les grandes entreprises, les marchés publics de l\'État et s\'étend désormais à toutes les sociétés assujetties à la TVA.',
          ),
          _buildFaqTile(
            isDark: isDark,
            question: 'Combien de temps prend l\'obtention du certificat Tuntrust et l\'adhésion TTN ?',
            answer: 'En moyenne 3 à 5 jours ouvrés. Avec la solution Digigo, vous pouvez obtenir votre certificat en ligne rapidement. Dès l\'obtention de votre code adhérent TTN, vous l\'insérez dans LogiTech et la facturation est immédiatement opérationnelle.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile({
    required bool isDark,
    required String question,
    required String answer,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          context.tr(question),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              context.tr(answer),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── GUIDE BANNER CARD (elFatoora & LogiTech Guide) ─────────────────────────
  Widget _buildGuideBannerCard(bool isDark, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildInvoicePreviewMockup(isDark)),
                const SizedBox(height: 20),
                _buildGuideBannerContent(isDark, isMobile),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildInvoicePreviewMockup(isDark),
                const SizedBox(width: 32),
                Expanded(
                  child: _buildGuideBannerContent(isDark, isMobile),
                ),
              ],
            ),
    );
  }

  Widget _buildInvoicePreviewMockup(bool isDark) {
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // FACTURE & N°
          Text(
            'FACTURE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'N° 20250123',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),

          // QR Code Graphic
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              size: 82,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // Simulated Barcode
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              16,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                width: (index % 3 == 0) ? 2.5 : (index % 2 == 0 ? 1.5 : 1.0),
                height: 14,
                color: isDark ? Colors.white60 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Blue separator line
          Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 8),

          // Date & TTN reference note
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Date 24-11-2025',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('Copie de la facture enregistrée chez TTN sous la référence unique :'),
              style: TextStyle(
                fontSize: 6.8,
                height: 1.25,
                color: isDark ? Colors.white38 : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '15432154564564564789315255464',
              style: TextStyle(
                fontSize: 6.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBannerContent(bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Guide simplifié de connexion entre LogiTech et le système elFatoora'),
          style: TextStyle(
            fontSize: isMobile ? 17 : 21,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr(
            'Grâce à ce guide clair et accessible, vous pourrez finaliser facilement la connexion entre LogiTech et le système de facturation électronique elFatoora. Il vous explique, étape par étape, ce dont vous avez besoin pour démarrer, comme la signature électronique et l\'accès de test, sans entrer dans des aspects techniques complexes. Vous y trouverez également les problèmes les plus courants rencontrés par les utilisateurs, avec des explications simples pour les résoudre et assurer une utilisation sereine du système.',
          ),
          style: TextStyle(
            fontSize: isMobile ? 12.5 : 13.5,
            height: 1.6,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 18),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final openingMsg = context.tr('Ouverture du guide dans Chrome...');
            messenger.showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text(openingMsg),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            try {
              final bytes = await ElectronicInvoiceGuidePdfService.instance.generateGuidePdf();
              if (mounted) {
                await GuidePdfOpener.openPdfInChrome(
                  bytes,
                  'Guide_Facturation_Electronique_LogiTech_elFatoora.pdf',
                  context,
                );
              }
            } catch (e) {
              debugPrint('[ElectronicInvoiceScreen] Error opening in Chrome: $e');
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ElectronicInvoiceGuideScreen(),
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('Découvrez la facture électronique'),
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── EMAIL TEMPLATES SECTION ───────────────────────────────────────────────
  Widget _buildEmailTemplatesSection(bool isDark, bool isMobile) {
    const templateConfigText = '''Bonjour,

Veuillez trouver ci-dessous les informations nécessaires pour la configuration de l'accès au service TTN :

Client : [Nom de l'entreprise]
Matricule fiscal : [Matricule fiscal – 13 caractères, sans séparateurs]
Adresse IP publique fixe : 46.224.185.96
Personne habilitée à signer : [Nom et prénom]
Numéro de série du certificat électronique (hexadécimal) : [Numéro de série]
Adresse email associée au certificat électronique : [Adresse email]
Mode de connexion : Webservice

Nous restons à votre disposition pour toute information complémentaire.''';

    const templateProdText = '''Bonjour,

Suite à la validation des tests, nous souhaitons procéder au passage en environnement de production pour l'entreprise suivante :

Entreprise : [Nom de l'entreprise]
Matricule fiscal : [Matricule fiscal – 13 caractères, sans séparateurs ni espaces]
Adresse(s) IP publique(s) fixe(s) : 46.224.185.96
Numéro de série du certificat de signature électronique (hexadécimal) : [Numéro de série]

Nous restons à votre disposition pour toute information complémentaire.''';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Modèles d\'emails officiels TTN / elFatoora'),
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('Copiez directement ces modèles prêts à l\'emploi pour vos échanges avec Tunisie Trade Net'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isMobile) ...[
            _buildTemplateCard(
              title: 'Modèle - Demande de configuration TTN',
              content: templateConfigText,
              recipient: 'commercial@elfatoora.tn, support@elfatoora.tn',
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildTemplateCard(
              title: 'Modèle - Passage en production',
              content: templateProdText,
              recipient: 'support@elfatoora.tn, commercial@elfatoora.tn',
              isDark: isDark,
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTemplateCard(
                    title: 'Modèle - Demande de configuration TTN',
                    content: templateConfigText,
                    recipient: 'commercial@elfatoora.tn, support@elfatoora.tn',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildTemplateCard(
                    title: 'Modèle - Passage en production',
                    content: templateProdText,
                    recipient: 'support@elfatoora.tn, commercial@elfatoora.tn',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateCard({
    required String title,
    required String content,
    required String recipient,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
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
              Expanded(
                child: Text(
                  context.tr(title),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(context.tr('Modèle copié dans le presse-papiers !')),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.copy_rounded, size: 15, color: AppColors.primary),
                label: Text(
                  context.tr('Copier'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${context.tr('Destinataire')} : $recipient',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
